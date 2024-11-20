#=
# Geomorphometry over Greenland
=#

# Load packages first.  We use Rasters.jl and GeometryOps.jl for 
# geospatial processing, and GADM.jl to get the outline of Greenland.

using Rasters, RasterDataSources, ArchGDAL
import GeometryOps as GO, GeoInterface as GI

# First, get the outline of Greenland.
import GADM

greenland_table = GADM.get("GRL")
greenland = GO.tuples(GI.geometry(only(greenland_table.rows)));

# Next, load the elevation raster - this is a SRTM DEM of Groenland.

dem = Raster("DEM.vrt"; lazy = true)

using RangeExtractor

strategy = FixedGridTiling{2}(2915)
strategy = FixedGridTiling{2}(12)

# Figure out which tiles we need
tile_raster_axes = ntuple(2) do i
    lookup_values = val(dims(dem)[i])
    new_step = step(lookup_values) * strategy.tilesize[i]
    return rebuild(dims(dem)[i], range(; start = first(lookup_values), step = new_step, stop = last(lookup_values)))
end

# Now, we can get the extents of the tiles we need.
tile_raster = Raster(falses(tile_raster_axes...); crs = GI.crs(dem))
tile_raster = rasterize!(last, tile_raster,  greenland; fill = true, boundary = :touches)

required_tile_indices = findall(tile_raster)

# Now, we can extract the ranges per tile:
tile_ranges = map(required_tile_indices) do tile_idx
    RangeExtractor.relevant_range_from_tile_origin(axes(dem), tile_to_ranges(strategy, tile_idx))
end

# Now we can actually perform the extraction.
ext2poly(e::GI.Extents.Extent) = GI.Polygon([GI.LinearRing([(e.X[1], e.Y[1]), (e.X[2], e.Y[1]), (e.X[2], e.Y[2]), (e.X[1], e.Y[2]), (e.X[1], e.Y[1])])])

temperature = Raster(WorldClim{Climate}, :prec; month = 1)
dem = ras # for now - replace these with the actual MODIS/SST and Copernicus data!

histograms = RangeExtractor.extract(dem, tile_ranges; strategy, threaded = true) do A
    masked_dem = if GO.contains(greenland, ext2poly(GI.extent(A)))
        # work around Rasters.jl issue with masking where geometry fully contains raster.
        A
    else
        mask(A; with = greenland)
    end

    aspect_raster = Geomorphometry.aspect(masked_dem)

    hist = FHist.Hist1D(; binedges = 0.0:1.0:360.0)
    weighted_hist = FHist.Hist1D(; binedges = 0.0:1.0:360.0)

    for (val, selector) in zip(aspect_raster, DimSelectors(aspect_raster; selectors = Near))
        
        (ismissing(val) || isnan(val)) && continue
        temp = temperature[selector]
        temp === missingval(temperature) && continue
        # push the aspect value weighted by temperature.
        # selecting temperature with the dimselector is equivalent to nearest interpolation.  
        push!(hist, val)
        push!(weighted_hist, val, temp + 273.15) # c to k
    end

    return hist, weighted_hist
end

final = mapfoldl(last, +, histograms) / mapfoldl(first, +, histograms)

plot(final)