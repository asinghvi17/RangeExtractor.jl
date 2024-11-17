using RangeExtractor
using TiledIteration, StatsBase
using OnlineStats

array = rand(Float16, 10_000, 10_000)

available_rects = collect(TileIterator(axes(array), (100, 100)))

ranges = sample(available_rects, 100, replace=false)

op = RecombiningTileOperation(
    (x) -> fit!(Mean(), x),
)

op2 = RangeExtractor.TileOperation(
    (x) -> fit!(Mean(), x),
    (x) -> fit!(Mean(), x),
    (results, args...; kwargs...) -> foldl(merge!, results)
)

strategy = FixedGridTiling{2}(350)

results = @time RangeExtractor.extract(array, ranges; operation = op, tiling_scheme = strategy, combine = identity, threaded = false)

real_results = @time [op.f(view(array, r...)) for r in ranges]