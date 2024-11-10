using Test, TestItems

@testitem "All contained" tags=[:Correctness, :Base] begin
    array = rand(20, 20)
    ranges = [
        (1:10, 1:10),
        (11:20, 11:20),
        (1:10, 11:20),
        (11:20, 1:10),
    ]

    tiling_scheme = TiledExtractor.FixedGridTiling{2}(10)

    op = TiledExtractor.TileOperation((x, meta) -> sum(x), (x, meta) -> sum(x))
    results = TiledExtractor._extract(array, ranges, nothing, tiling_scheme, op, sum)

    @test results == [sum(view(array, r...)) for r in ranges]
end

@testitem "Mixed contained and shared" tags=[:Correctness, :Base] begin
    array = rand(20, 20)
    ranges = [
        (1:10, 1:10),  # Contained in top-left tile
        (5:15, 5:15),  # Shared across all four tiles
        (11:20, 11:20) # Contained in bottom-right tile
    ]

    tiling_scheme = TiledExtractor.FixedGridTiling{2}(10)

    op = TiledExtractor.TileOperation((x, meta) -> sum(x), (x, meta) -> sum(x))
    results = TiledExtractor._extract(array, ranges, nothing, tiling_scheme, op, sum)
    # NOTE: this has to be approximate, since the order of summation is different for the two
    # different approaches.
    @test results ≈ [sum(view(array, r...)) for r in ranges]
    # They should be about eps() apart, and we can test that,
    # but the input is nondeterministic, so we can't do it.
    # Maybe the input should be deterministic?  TODO.
    # @test all(abs.(results .- [sum(view(array, r...)) for r in ranges]) .<= eps.(results))
end

@testitem "All shared" tags=[:Correctness, :Base] begin
    array = rand(20, 20)
    ranges = [
        (1:15, 1:15),
        (10:20, 10:20),
    ]

    tiling_scheme = TiledExtractor.FixedGridTiling{2}(10)

    op = TiledExtractor.TileOperation((x, meta) -> sum(x), (x, meta) -> sum(x))
    results = TiledExtractor._extract(array, ranges, nothing, tiling_scheme, op, sum)

    @test results ≈ [sum(view(array, r...)) for r in ranges]
    # @test all(abs.(results .- [sum(view(array, r...)) for r in ranges]) .<= eps.(results))
end

@testitem "3D" tags=[:Correctness, :Base] begin
    data = rand(10, 10, 10)
    ranges = [
        (1:5, 1:5, 1:5),
        (6:10, 6:10, 6:10),
        (1:5, 6:10, 1:5),
        (6:10, 1:5, 1:5),
        (1:5, 1:5, 6:10),
        (1:7, 3:10, 6:10),
        (5:10, 1:5, 4:10),
        (6:10, 6:10, 1:5),
    ]

    tiling_scheme = FixedGridTiling{3}(5)

    op = TiledExtractor.TileOperation((x, meta) -> sum(x), (x, meta) -> sum(x))
    results = TiledExtractor._extract(data, ranges, nothing, tiling_scheme, op, sum)

    @test results ≈ [sum(view(data, r...)) for r in ranges]
end

@testitem "Rasters.jl worldwide zonal" tags=[:Correctness, :Rasters] begin
    using Rasters, RasterDataSources, ArchGDAL
    using NaturalEarth
    import GeoInterface as GI

    ras = Raster(WorldClim{Climate}, :tmin, month=1)
    all_countries = naturalearth("admin_0_countries", 10)

    zonal_values = Rasters.zonal(sum, ras; of = all_countries, boundary = :touches, progress = false, threaded = false)

    op = TiledExtractor.TileOperation(
        (x, meta) -> zonal(sum, x, of=meta, boundary = :touches, progress = false, threaded = false), 
        (x, meta) -> zonal(sum, x, of=meta, boundary = :touches, progress = false, threaded = false)
    )

    extents = GI.extent.(all_countries.geometry)
    ranges = Rasters.DD.dims2indices.((ras,), Touches.(extents))
    scheme = FixedGridTiling{2}(100)

    tiled_zonal_values = TiledExtractor._extract(ras, ranges, all_countries.geometry, scheme, op, sum)

    @test tiled_zonal_values ≈ zonal_values
end

@testitem "OnlineStats" tags=[:Correctness, :OnlineStats] begin
    using OnlineStats

    data = rand(1000, 1000)
    chunk_size = 100
    tiling_scheme = FixedGridTiling{2}(chunk_size)

    ranges = [
        (1:200, 1:200),
        (300:500, 300:500),
        (600:800, 600:800),
        (100:400, 500:800),
        (500:700, 100:300)
    ]

    # Create an OnlineStats Series that tracks mean, median and variance
    op = TiledExtractor.TileOperation(
        # For things contained in a tile, return the value of the series.
        (x, meta) -> value(fit!(Series(Mean(), KahanSum(), Variance()), x)), 
        # For things shared across tiles, return the series itself, so we can merge them later.
        (x, meta) -> fit!(Series(Mean(), KahanSum(), Variance()), x)
    )

    # Function to combine results from different tiles
    function combine_series(series_list)
        # Extract the first statistic, and an iterator over the rest of them.
        combined, rest = Iterators.peel(series_list)
        # Merge the rest into the first.
        for s in rest
            merge!(combined, s)
        end
        # Return the value of the combined statistic.
        return value(combined)
    end

    results = TiledExtractor._extract(TiledExtractor.Static.False(), data, ranges, nothing, tiling_scheme, op, combine_series)

    # Calculate expected results directly
    expected = map(ranges) do r
        s = Series(Mean(), KahanSum(), Variance())
        fit!(s, view(data, r...))
        value(s)
    end

    # Test that results match
    for (result, expect) in zip(results, expected)
        @test result[1] ≈ expect[1]  # Mean
        @test result[2] ≈ expect[2]  # Kahan (compensated) sum
        @test result[3] ≈ expect[3]  # Variance
    end
end
