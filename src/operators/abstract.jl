

"""
    AbstractTileOperation

Abstract type for tile operations, which are callable structs that can operate on a [`TileState`](@ref).

## Interface

All subtypes of `AbstractTileOperation` MUST implement the following interface:

- `(op::AbstractTileOperation)(state::TileState)`: Apply the operation to the given tile state.  Return a tuple of (contained_results, shared_results).  The order of the results **MUST** be the same as the order of the indices in `state.contained_ranges` and `state.shared_ranges`.
- `combine(op::AbstractTileOperation, range, metadata, results, tile_idxs)`: Combine the outputs from the portions of the shared ranges, and return the final result.

Optionally, subtypes can implement the following methods:
- `(op::AbstractTileOperation)(state::TileState, contained_channel, shared_channel)`: Apply the operation to the given tile state, and write output to the specified channels.
  Output to both of the channels must be in the form `(tile_idx, result_idx) => result`, where `tile_idx` is the index of the tile in the `TileState`, and `result_idx` is the index of the result in the `contained_ranges` or `shared_ranges` of the `TileState`.

  This interface is a bit more efficient, since it avoids the overhead of allocating intermediate arrays.  That can be useful to cut down on inference and GC overhead, especially when dealing with many tiles.
- `contained_result_type(::Type{<: AbstractTileOperation}, DataArrayType)`: Return the type of the results from the contained ranges.  Defaults to `Any`.
- `shared_result_type(::Type{<: AbstractTileOperation}, DataArrayType)`: Return the type of the results from the shared ranges.  Defaults to `Any`.
"""
abstract type AbstractTileOperation end

# This is the fallback method for when the tile operation does not provide a specific method for chanelized operations.
function (op::AbstractTileOperation)(state::TileState, contained_channel::Channel, shared_channel::Channel)
    contained_results, shared_results = op(state)
    for (i, result) in enumerate(contained_results)
        put!(contained_channel, (state.tile_idx, i) => result)
    end
    for (i, result) in enumerate(shared_results)
        put!(shared_channel, (state.tile_idx, i) => result)
    end
end

# This is the fallback method for when tile operations are not defined at all - 
# it'll at least error usefully.
function (op::AbstractTileOperation)(state::TileState)
    error("No method found for $(typeof(op)), it may not be implemented.  Please raise a GitHub issue at RangeExtractor.jl if you see this message.")
end


