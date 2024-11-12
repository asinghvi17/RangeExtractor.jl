```@meta
CurrentModule = TiledExtractor
```

# TiledExtractor

Documentation for [TiledExtractor](https://github.com/asinghvi17/TiledExtractor.jl).

# Flow of control

TiledExtractor is designed to efficiently process large arrays by splitting them into manageable tiles and performing operations on each tile independently. This approach is particularly useful when working with arrays that are too large to fit in memory, and for arrays where I/O is a bottleneck (e.g. S3 or cloud hosted arrays).

## Inputs

The user provides us three pieces of data: 
- `data`: the array in question, that we want to extract ranges from.
- `ranges`: the ranges to extract from said array, as a vector of tuples of AbstractUnitRanges.
- `metadata`: associated metadata for each element in `ranges`.

The user also provides some configuration structs:

- [`TilingStrategy`](@ref): determines how to divide the array into tiles.  
    - This can be simple, naive, grid-based tiling ([`FixedGridTiling`](@ref)).
    - Can also be tiled by a spatial index like an STR-tree or R-tree.
- [`TileOperation`](@ref): defines how to process the data in each tile.  
    - There are two potential ways a range can interact with a tile: 
        - Either it is fully contained within the tile (`contained`), 
        - or it overlaps with the tile and also other tiles (`shared`). 
    - The [`TileOperation`](@ref) determines how the data from each tile is combined to form the final result.
    - The default [`TileOperation`](@ref) allows maximal flexibility but can be slow on the compiler.  We provide several other [`TileOperation`](@ref)s as well, such as the [`RecombiningTileOperation`](@ref) which is a convenience for when the function that the user wants to apply requires the whole tile array to be in-memory at once.  
    - Users are also free to implement their own [`TileOperation`](@ref)s, so long as they implement the [`AbstractTileOperation`](@ref) interface.

In future, we plan to add tile iteration schemes, so that users can minimize memory or IO usage by defining a specific order to iterate over tiles.  This might involve graph algorithms or other strategies.

## Processing

First, we bin the ranges into tiles generated by the `TilingStrategy`.  This results in three dictionaries:
- `contained_ranges`: `Tile → Ranges fully inside it`.  Maps tile indices to indices in the `ranges` vector, that are fully contained within that tile, 
- `shared_ranges`: `Tile → Ranges that overlap it`.  Maps tile indices to indices in the `ranges` vector, that overlap with that tile and also other tiles.
- `shared_ranges_indices`: `Range → Tiles it overlaps with`.  Maps indices in the `ranges` vector to the tile indices that they overlap with.  This is essentially the inverse mapping of `shared_ranges`.

For each tile that has data that we want, we then read it into memory, and construct a [`TileState`](@ref) object.  This contains the tile data and index, the contained and shared ranges, and views of the metadata for those ranges.

Then, we apply the given [`TileOperation`](@ref) to that state.  This puts the data into a Channel, which we then drain by a supporting asynchronous task.  While Julia is waiting on IO, that can process the data so CPU power is maximally utilized.

## Outputs

Finally, we combine the results from each tile into a final result vector, and return it.

Shared tile results are usually eagerly combined to reduce memory strain.  All results are written to the vector in the correct fashion.


!!! tip
    For a concrete example, refer to the README!