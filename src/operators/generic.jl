
"""
    TileOperation(; contained, shared, combine)
    TileOperation(operation)

Create a tile operation that can operate on a [`TileState`](@ref)
and return a tuple of results from the contained and shared ranges.

It calls the `contained` function on each contained range, and the `shared` function on each shared range.

`contained` and `shared` are called with the signature `func(data, metadata)`, where `data` is a view of the tile data on the current range, and `metadata` is the metadata for that range.

`combine` is called with the signature `combine(shared_results, shared_tile_idxs, metadata)`, where `shared_results` is an array of results from the `shared` function, `shared_tile_idxs` is an array of the tile indices that the shared results came from, and `metadata` is the metadata for that range.

If constructed with a single function, that function is used for both contained and shared operations.

# Arguments
- `contained`: Function to apply to contained (non-overlapping) regions
- `shared`: Function to apply to shared (overlapping) regions

# Examples
```julia
# Different functions for contained and shared regions
op = TileOperation(
    contained = (data, meta) -> sum(data),
    shared = (data, meta) -> sum(data),
    combine = (x, _u, _w) -> sum(x)
)

# Same function for all three
op = TileOperation((data, meta) -> mean(data))
```
"""
struct TileOperation{ContainedFunc, SharedFunc, CombineFunc} <: AbstractTileOperation
    "The function to apply to each contained range."
    contained_func::ContainedFunc
    "The function to apply to each shared range."
    shared_func::SharedFunc
    "The function to combine the results from each tile on shared ranges."
    combine_func::CombineFunc
end

# Constructors

TileOperation(operation::Function) = TileOperation(contained = operation, shared = operation, combine = operation)
TileOperation(; contained, shared = contained, combine) = TileOperation{typeof(contained), typeof(shared), typeof(combine)}(contained, shared, combine)

function (op::TileOperation)(tile::TileState)
    contained_results = op.contained_func.(view.((tile.data,), tile.contained_ranges), tile.contained_metadata)
    shared_results = op.shared_func.(view.((tile.data,), tile.shared_ranges), tile.shared_metadata)
    return (contained_results, shared_results)
end

function combine(op::TileOperation, range, metadata, results, tile_idxs; strategy)
    return op.combine_func(results, tile_idxs, metadata) # TODO: have several levels of this.
end