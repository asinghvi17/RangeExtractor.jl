using Test, TestItems

@testitem "Rasters zonal extension" tags=[:Rasters, :Extensions] begin
    using Rasters, RasterDataSources, ArchGDAL
    using NaturalEarth
    import GeoInterface as GI

    set_temp = false
    if !haskey(ENV, "RASTERDATASOURCES_PATH")
       ENV["RASTERDATASOURCES_PATH"] = mktempdir()
       set_temp = true
    end

    ras = Raster(WorldClim{Climate}, :tmin, month=1)
    all_countries = naturalearth("admin_0_countries", 10)

    zonal_values = Rasters.zonal(sum, ras; of = all_countries, boundary = :touches, progress = false, threaded = false)

    scheme = FixedGridTiling{2}(100)

    tiled_threaded = zonal(sum, ras, scheme; of = all_countries, boundary = :touches, threaded=true, progress = false)
    tiled_single = zonal(sum, ras, scheme; of = all_countries, boundary = :touches, threaded=false, progress = false)

    @test tiled_threaded ≈ zonal_values
    @test tiled_single ≈ zonal_values
    @test tiled_threaded ≈ tiled_single

    if set_temp
        rm(ENV["RASTERDATASOURCES_PATH"])
    end
end