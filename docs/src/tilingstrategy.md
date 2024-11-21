# Tiling Strategies

RangeExtractor allows you to configure how the `extract` function handles tiling by passing a tiling strategy.  A tiling strategy must:
- subtype `AbstractTilingStrategy`

A tiling strategy splits the input ranges into tiles.  The simplest strategy is to use a fixed grid.  But you can also use an R-tree formulation via SpatialIndexing.jl.

## Tile visiting strategies

In general, you may want to minimize or maximize the number of I/O overlaps.  So you can visit tiles in a specific order.  You could, for example, use Graphs.jl to find which tiles connect to each other, or are connected via shared ranges, and iterate over them so as to minimize the amount of time that intermediate data for those shared ranges is held in memory.

This doesn't exist right now, but it's a good idea and something I want to work on in the future.