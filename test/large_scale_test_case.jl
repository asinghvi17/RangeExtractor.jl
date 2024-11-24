@testset "Large scale test case" begin

    using RangeExtractor
    using TiledIteration, StatsBase
    using OnlineStats

    using Chairmarks, Statistics

    array = rand(Float16, 50_000, 50_000)

    available_rects = collect(TileIterator(axes(array), (100, 100)))

    ranges = sample(available_rects, 1000, replace=false)

    op = RecombiningTileOperation(
        (x) -> value(fit!(Mean(), x)),
    )

    op2 = RangeExtractor.TileOperation(
        (x, meta) -> value(fit!(Mean(), x)),
        (x, meta) -> fit!(Mean(), x),
        (results, args...; kwargs...) -> value(foldl(merge!, results))
    )

    strategy = FixedGridTiling{2}(350)

    results = RangeExtractor.extract(op, array, ranges; strategy = strategy, threaded = false, progress = false)
    results_2 = RangeExtractor.extract(op2, array, ranges; strategy = strategy, threaded = false, progress = false)
    real_results = [op.f(view(array, r...)) for r in ranges]

    @test results == real_results # here, == is fine, since the operation is the same and has access to the same data
    @test results_2 ≈ real_results # here, == is NOT fine, since the operation iterates over the values in a different order.


    # benchmarking
    results_singlethreaded_benchmark = @be RangeExtractor.extract($op, $array, $ranges; strategy = $strategy, threaded = false, progress = false) seconds=5
    results_2_singlethreaded_benchmark = @be RangeExtractor.extract($op2, $array, $ranges; strategy = $strategy, threaded = false, progress = false) seconds=5
    results_multithreaded_benchmark = @be RangeExtractor.extract($op, $array, $ranges; strategy = $strategy, threaded = true, progress = false) seconds=5
    results_2_multithreaded_benchmark = @be RangeExtractor.extract($op2, $array, $ranges; strategy = $strategy, threaded = true, progress = false) seconds=5
    real_results_benchmark = @be [$(op).f(view($array, r...)) for r in $(ranges)]

    _sprint_pretty(x) = sprint((io, i...) -> show(io, MIME"text/plain"(), i...), x)

    println("""

    Large scale test case

    $(size(array)) matrix, $(length(ranges)) ranges

    Single threaded:
    - Recombining operation: $(Statistics.median(results_singlethreaded_benchmark) |> _sprint_pretty)
    - Incremental operation: $(Statistics.median(results_2_singlethreaded_benchmark) |> _sprint_pretty)

    Multithreaded:
    - Recombining operation: $(Statistics.median(results_multithreaded_benchmark) |> _sprint_pretty)
    - Incremental operation: $(Statistics.median(results_2_multithreaded_benchmark) |> _sprint_pretty)

    Pure array comprehension: $(Statistics.median(real_results_benchmark) |> _sprint_pretty)
    """)


end