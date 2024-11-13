using RangeExtractor
using TiledIteration, StatsBase
using OnlineStats

array = rand(Float16, 10_000, 10_000)

available_rects = collect(TileIterator(axes(array), (100, 100)))

ranges = sample(available_rects, 100, replace=false)

op = TileOperation(
    (x, meta) -> fit!(Mean(), x),
)

strategy = FixedGridTiling{2}(350)

results = RangeExtractor.extract(array, ranges; operation = op, tiling_scheme = strategy, combine = (x -> foldl(merge!, x)))