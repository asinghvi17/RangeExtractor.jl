# # Get the data

# ## HydroBasins shapefiles
using Downloads, ZipFile

using Shapefile, GeometryOps

using Rasters, ArchGDAL

# basin_zip_files = [
#     "https://data.hydrosheds.org/file/hydrobasins/standard/hybas_$(region)_lev01-12_v1c.zip"
#     for region in ("af", "ar", "as", "au", "eu", "gr", "na", "sa", "si")
# ]

# # Retrieve, unzip, and load Africa basins
africa_basin_zip_file = "https://data.hydrosheds.org/file/hydrobasins/standard/hybas_af_lev01-12_v1c.zip"
download_dir = get(ENV, "RASTERDATASOURCES_PATH", tempdir())
download_zip_path = joinpath(download_dir, "africa_basins.zip")
download_unzip_dir = joinpath(download_dir, "africa_basins")

isfile(download_zip_path) || Downloads.download(africa_basin_zip_file, download_zip_path)

if !isdir(download_unzip_dir)
    # decompress the zip file
    r = ZipFile.Reader(download_zip_path)

    for f in r.files
        fn = f.name
        path = mkpath(joinpath(download_unzip_dir, dirname(fn)))
        write(joinpath(path, basename(fn)), read(f))
    end

    close(r)
end

levels = 1:12
level_filenames = ["hybas_af_lev$(lpad(l, 2, '0'))_v1c.shp" for l in levels]
level_shapefiles = Shapefile.Table.(joinpath.(download_unzip_dir, level_filenames))

# ## Gridded Population of the World (30 arcsec)

# # Download and load the GPW (Gridded Population of the World) dataset
# using PythonCall, CondaPkg

# earthaccess = pyimport("earthaccess")

# auth = earthaccess.login()

# results = earthaccess.search_data(
#     short_name="NSIDC-0051",
#     temporal=("2022-11-01", "2022-11-30"),
#     bounding_box=(-180, 0, 180, 90)
# )

# downloaded_files = earthaccess.download(
#     results,
#     local_path=".",
# )

using Rasters, ArchGDAL
Rasters.checkmem!(false)
full_pop = Raster("/Users/singhvi/Downloads/gpw-v4-population-count-rev11_2020_30_sec_tif/gpw_v4_population_count_rev11_2020_30_sec.tif")
full_pop_lazy = Raster("/Users/singhvi/Downloads/gpw-v4-population-count-rev11_2020_30_sec_tif/gpw_v4_population_count_rev11_2020_30_sec.tif"; lazy=true)


# # Benchmarking: Rasters.jl vs RangeExtractor.jl

using Chairmarks, BenchmarkTools
using RangeExtractor

"Using Rasters.jl, extract the sum of all values in each geometry."
function _extract_rasters(raster, geometries)
    return zonal(sum, raster; of = geometries, threaded = true, progress = false)
end


zonal_lambda(data, geom) = zonal(sum, data; of = geom, threaded = false, progress = false)
# setup benchmarking code
"Using RangeExtractor.jl, extract the sum of all values in each geometry."
Base.@constprop :aggressive function _extract_rangeextractor(raster, geometries; threaded = false)
    geoms = Rasters._get_geometries(geometries, nothing)
    extents = Shapefile.GeoInterface.extent.(geoms)
    ranges = Rasters.dims2indices.((raster,), Touches.(extents))
    RangeExtractor.extract(
        RangeExtractor.RecombiningTileOperation(zonal_lambda), 
        raster, ranges, geoms; 
        strategy = FixedGridTiling((1800, 578*3)), 
        threaded,
        progress = false # just to avoid crowding the progress bar.
    )
end


@be _extract_rangeextractor($full_pop, $level_shapefiles[1]) seconds=10
@be _extract_rasters($full_pop, $level_shapefiles[1]) seconds=10

@be _extract_rangeextractor($full_pop, $level_shapefiles[2]) seconds=10
@be _extract_rasters($full_pop, $level_shapefiles[2]) seconds=10

@be _extract_rangeextractor($full_pop_lazy, $level_shapefiles[2]) seconds=10
@be _extract_rasters($full_pop_lazy, $level_shapefiles[2]) seconds=10

@be _extract_rangeextractor($full_pop, $level_shapefiles[11]; threaded = Serial()) seconds=10
@be _extract_rangeextractor($full_pop, $level_shapefiles[11]; threaded = AsyncSingleThreaded()) seconds=10
@be _extract_rasters($full_pop, $level_shapefiles[11]) seconds=10

@be _extract_rangeextractor($full_pop, $level_shapefiles[12]; threaded = Serial()) seconds=10
@be _extract_rangeextractor($full_pop, $level_shapefiles[12]; threaded = AsyncSingleThreaded()) seconds=10
@be _extract_rasters($full_pop, $level_shapefiles[12]) seconds=10


using BenchmarkTools, Chairmarks

range_extractor_result = @time RangeExtractor.extract(full_pop, ranges, geoms; tiling_scheme = FixedGridTiling{2}((1800, 578*3)), operation = RangeExtractor.RecombiningTileOperation(zonal_lambda), combine = sum, threaded = false)

zonal_result = @time zonal(sum, full_pop; of = geoms, threaded = true)

@test range_extractor_result ≈ zonal_result # different order of summation leads to small floating point differences.

range_extractor_result = @time RangeExtractor.extract(chunked_pop, ranges, geoms; tiling_scheme = FixedGridTiling{2}((1800, 578*3)), operation = RangeExtractor.RecombiningTileOperation(zonal_lambda), combine = sum, threaded = false)

zonal_result = @time zonal(sum, chunked_pop; of = geoms, threaded = true)

range_extractor_result = @time RangeExtractor.extract(slow_pop, ranges, geoms; tiling_scheme = FixedGridTiling{2}((1800, 578*3)), operation = RangeExtractor.RecombiningTileOperation(zonal_lambda), combine = sum, threaded = false)

zonal_result = @time zonal(sum, DiskArrays.cache(slow_pop); of = geoms, threaded = true)

@test range_extractor_result ≈ zonal_result # different order of summation leads to small floating point differences.






# # Array types that have slow IO



using DiskArrays
import DiskArrays as DA

struct SlowIODiskArray{T, N, A <: AbstractArray{T,N}, RS} <: DA.AbstractDiskArray{T,N}
    data::A
    chunksize::NTuple{N,Int}
    batchstrategy::RS
    sleep_time::Float64
end

function SlowIODiskArray(
    data::AbstractArray{T, N}; 
    chunksize=size(data), 
    batchstrategy=DiskArrays.ChunkRead(DiskArrays.NoStepRange(),0.5), 
    sleep_time=0.3
    ) where {T, N}
    return SlowIODiskArray{T, N, typeof(data), typeof(batchstrategy)}(data, chunksize, batchstrategy, sleep_time)
end

Base.parent(d::SlowIODiskArray) = d.data

DA.batchstrategy(d::SlowIODiskArray) = d.batchstrategy
DA.haschunks(d::SlowIODiskArray) = DA.Unchunked()
DA.eachchunk(a::SlowIODiskArray) = DA.GridChunks(a, a.chunksize)

function DA.readblock!(a::SlowIODiskArray, aout, i::DA.OrdinalRange...)
    sleep(a.sleep_time)
    aout .= a.data[i...]
end

function DA.writeblock!(a::SlowIODiskArray, v, i::DA.OrdinalRange...)
    view(a.data, i...) .= v
end

Base.size(a::SlowIODiskArray) = size(a.data)
# Base.eachindex(a::SlowIODiskArray) = eachindex(a.data)
Base.axes(a::SlowIODiskArray) = axes(a.data)
Base.length(a::SlowIODiskArray) = length(a.data)
# Base.size(a::SlowIODiskArray) = size(a.data)


chunked_pop = modify(full_pop) do A
    DA.TestTypes.ChunkedDiskArray(A, (600, 578))
end

slow_pop = modify(full_pop) do A
    SlowIODiskArray(A; chunksize = (600, 578), sleep_time = 0.0001)
end


# # Profiling Rasters.jl zonal


@time zonal(sum, full_pop_lazy; of = level_shapefiles[1], threaded = false)
@time zonal(sum, full_pop_lazy; of = level_shapefiles[1], threaded = false) # 44s
@time zonal(sum, full_pop; of = level_shapefiles[1], threaded = false) # 3.8 s
@time zonal(sum, full_pop; of = level_shapefiles[2], threaded = false) # 2.2 s
@time zonal(sum, full_pop; of = level_shapefiles[3], threaded = false) # 1.6 s
@time zonal(sum, full_pop; of = level_shapefiles[4], threaded = false) # 1.6 s
@time zonal(sum, full_pop; of = level_shapefiles[5], threaded = false) # 1.9 S
@time zonal(sum, full_pop; of = level_shapefiles[6], threaded = false) # 2.1 s
@time zonal(sum, full_pop; of = level_shapefiles[7], threaded = false) # 2.4 s
@time zonal(sum, full_pop; of = level_shapefiles[8], threaded = false) # 3.5 s
@time zonal(sum, full_pop; of = level_shapefiles[9], threaded = false) # 3.9 s
@time zonal(sum, full_pop; of = level_shapefiles[10], threaded = false) # 4.5 s
@time zonal(sum, full_pop; of = level_shapefiles[11], threaded = false) # 4.7 s
@time zonal(sum, full_pop; of = level_shapefiles[12], threaded = false) # 4.9 s

@time zonal(sum, chunked_pop; of = level_shapefiles[9], threaded = false); # 3.9 s
@time zonal(sum, chunked_pop; of = level_shapefiles[10], threaded = false); # 4.5 s
@time zonal(sum, chunked_pop; of = level_shapefiles[11], threaded = false); # 4.7 s
@time zonal(sum, chunked_pop; of = level_shapefiles[12], threaded = false); # 4.9 s



@time zonal(sum, slow_pop; of = level_shapefiles[9], threaded = false); # 3.9 s
@time zonal(sum, slow_pop; of = level_shapefiles[10], threaded = false); # 4.5 s
@time zonal(sum, slow_pop; of = level_shapefiles[11], threaded = false); # 4.7 s
@time zonal(sum, slow_pop; of = level_shapefiles[12], threaded = false); # 4.9 s
