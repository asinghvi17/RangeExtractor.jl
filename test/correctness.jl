using Test, TestItems

@testitem "All contained" tags=[:Correctness, :Base] begin
    array = rand(20, 20)
    ranges = [
        (1:10, 1:10),
        (11:20, 11:20),
        (1:10, 11:20),
        (11:20, 1:10),
    ]

    strategy = RangeExtractor.FixedGridTiling{2}(10)

    op = RangeExtractor.RecombiningTileOperation(sum)
    # Test both threaded and non-threaded versions
    results_threaded = extract(op, array, ranges; strategy=strategy, threaded=true)
    results_single = extract(op, array, ranges; strategy=strategy, threaded=false)
    expected = [sum(view(array, r...)) for r in ranges]

    @test results_threaded == expected
    @test results_single == expected
    @test results_threaded == results_single
end

@testitem "Mixed contained and shared" tags=[:Correctness, :Base] begin
    array = rand(20, 20)
    ranges = [
        (1:10, 1:10),  # Contained in top-left tile
        (5:15, 5:15),  # Shared across all four tiles
        (11:20, 11:20) # Contained in bottom-right tile
    ]

    strategy = RangeExtractor.FixedGridTiling{2}(10)

    results_threaded = extract(sum, array, ranges; strategy=strategy, threaded=true)
    results_single = extract(sum, array, ranges; strategy=strategy, threaded=false)
    expected = [sum(view(array, r...)) for r in ranges] 

    # NOTE: this has to be approximate, since the order of summation is different for the two
    # different approaches.
    @test results_threaded ≈ expected
    @test results_single ≈ expected
    @test results_threaded ≈ results_single
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

    strategy = RangeExtractor.FixedGridTiling{2}(10)

    op = RangeExtractor.RecombiningTileOperation(sum)
    results_threaded = extract(op, array, ranges; strategy=strategy, threaded=true)
    results_single = extract(op, array, ranges; strategy=strategy, threaded=false)
    expected = [sum(view(array, r...)) for r in ranges]

    @test results_threaded ≈ expected
    @test results_single ≈ expected
    @test results_threaded ≈ results_single
    # @test all(abs.(results .- [sum(view(array, r...)) for r in ranges]) .<= eps.(results))
end

@testitem "Shared across many tiles" tags=[:Correctness, :Base] begin
    array = rand(20, 20)
    ranges = [(1:10, 1:10),]
    strategy = FixedGridTiling{2}(5)

    expected = [sum(view(array, r...)) for r in ranges]

    @testset "RecombiningTileOperation" begin
        op = RecombiningTileOperation(sum)

        results_threaded = extract(op, array, ranges; strategy=strategy, threaded=true)
        results_single = extract(op, array, ranges; strategy=strategy, threaded=false)

        @test results_threaded ≈ expected
        @test results_single ≈ expected
        @test results_threaded ≈ results_single
    end

    @testset "TileOperation" begin
        op = RangeExtractor.TileOperation(; contained = (x, meta) -> sum(x), shared = (x, meta) -> sum(x), combine = (x, useless...) -> sum(x))

        results_threaded = extract(op, array, ranges; strategy=strategy, threaded=true)
        results_single = extract(op, array, ranges; strategy=strategy, threaded=false)

        @test results_threaded ≈ expected
        @test results_single ≈ expected
        @test results_threaded ≈ results_single
    end
end


@testitem "Shared broadcasting/correctness bug" tags=[:Correctness, :Base] begin
    array = rand(20, 20)
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

    strategy = FixedGridTiling{3}(5)

    op = RangeExtractor.RecombiningTileOperation(sum)
    results_threaded = extract(op, data, ranges; strategy=strategy, threaded=true)
    results_single = extract(op, data, ranges; strategy=strategy, threaded=false)
    expected = [sum(view(data, r...)) for r in ranges]

    @test results_threaded ≈ expected
    @test results_single ≈ expected
    @test results_threaded ≈ results_single
end

@testitem "Rasters.jl worldwide zonal" tags=[:Correctness, :Rasters] begin
    using Rasters, RasterDataSources, ArchGDAL
    using NaturalEarth
    import GeoInterface as GI

    import RangeExtractor: extract

    set_temp = false
    if !haskey(ENV, "RASTERDATASOURCES_PATH")
       ENV["RASTERDATASOURCES_PATH"] = mktempdir()
       set_temp = true
    end

    ras = Raster(WorldClim{Climate}, :tmin, month=1)
    all_countries = naturalearth("admin_0_countries", 10)

    zonal_values = Rasters.zonal(sum, ras; of = all_countries, boundary = :touches, progress = false, threaded = false)

    op = RangeExtractor.RecombiningTileOperation(
        (x, meta) -> zonal(sum, x, of=meta, boundary = :touches, progress = false, threaded = false), 
    )

    geoms = all_countries.geometry
    extents = GI.extent.(geoms)
    ranges = Rasters.DD.dims2indices.((ras,), Touches.(extents))
    scheme = FixedGridTiling{2}(100)

    tiled_threaded = extract(op, ras, ranges, all_countries.geometry; 
         strategy=scheme, threaded=true)
    tiled_single = extract(op, ras, ranges, all_countries.geometry; 
         strategy=scheme, threaded=false)

    @test tiled_threaded ≈ zonal_values
    @test tiled_single ≈ zonal_values
    @test tiled_threaded ≈ tiled_single

    if set_temp
        rm(ENV["RASTERDATASOURCES_PATH"])
    end
end

@testitem "OnlineStats" tags=[:Correctness, :OnlineStats] begin
    using OnlineStats

    data = rand(1000, 1000)
    chunk_size = 100
    strategy = FixedGridTiling{2}(chunk_size)

    ranges = [
        (1:200, 1:200),
        (300:500, 300:500),
        (600:800, 600:800),
        (100:400, 500:800),
        (500:700, 100:300)
    ]

    # Create an OnlineStats Series that tracks mean, median and variance
    op = RangeExtractor.TileOperation(
        # For things contained in a tile, return the value of the series.
        (x, meta) -> value(fit!(Series(Mean(), KahanSum(), Variance()), x)), 
        # For things shared across tiles, return the series itself, so we can merge them later.
        (x, meta) -> fit!(Series(Mean(), KahanSum(), Variance()), x),
        (results, args...) -> value(foldl(merge!, results))
    )


    results_threaded = extract(op, data, ranges;
        strategy=strategy, threaded=true)
    results_single = extract(op, data, ranges;
        strategy=strategy, threaded=false)

    # Calculate expected results directly
    expected = map(ranges) do r
        s = Series(Mean(), KahanSum(), Variance())
        fit!(s, view(data, r...))
        value(s)
    end

    # Test that results match for both threaded and single-threaded versions
    
    for (result, expect) in zip(results_single, expected)
        @test result[1] ≈ expect[1]  # Mean
        @test result[2] ≈ expect[2]  # Kahan (compensated) sum
        @test result[3] ≈ expect[3]  # Variance
    end

    for (result, expect) in zip(results_threaded, expected)
        @test result[1] ≈ expect[1]  # Mean
        @test result[2] ≈ expect[2]  # Kahan (compensated) sum
        @test result[3] ≈ expect[3]  # Variance
    end

    # Test that threaded and single-threaded results match each other
    for (t, s) in zip(results_threaded, results_single)
        @test t[1] ≈ s[1]  # Mean
        @test t[2] ≈ s[2]  # Kahan sum
        @test t[3] ≈ s[3]  # Variance
    end
end
