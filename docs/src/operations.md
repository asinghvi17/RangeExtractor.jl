# Operations

RangeExtractor allows you to configure what the `extract` function does by passing operators.  An operator must:
- subtype `AbstractTileOperator`
- be callable, and take a single argument that is a `TileState`
- return or do _something_ with the tile state

This also ties in to the concept of contained and shared ranges.  Ranges that are fully contained within a tile are simply operated on and returned.  However, for ranges that are split between multiple tiles, there are a few options.

The simplest option is to store the subsections relevant to each range, combine them when all relevant tiles have been read, and then operate on the combined result.  This is the most flexible option, but it is very memory intensive.  Plus, if you're using `extract` to operate on a range that is larger than memory, you're out of luck.

Another option is to compute some intermediate value.  For example - if you are interested in the sum of all values within the range, you could sum up the values from each tile, and return the result.  This could be done in a `AdditiveTileOperator` that uses the same function to operate on each tile as well as to combine.

You can also write a specific operator for your use case, for example if you want to use `Rasters.zonal`, but need specific metadata handling and argument order, or keyword argument passthrough, you could create a `ZonalTileOperator` that holds all relevant state and can call `Rasters.zonal` with the correct arguments.