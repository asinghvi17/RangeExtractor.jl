"""
    RecombiningTileOperation(f)

A tile operation that always passes `f` a fully materialized array over the requested range.

Contained ranges are instantly materialized and evaluated 
when encountered; relevant sections of shared ranges are put 
in the shared channel and set aside.  

When all components of a shared range are read, then 
`f` is called with the fully materialized array.

Here, the combining function is simply an array mosaic.  
There is no difference between shared and contained operations.
"""
struct RecombiningTileOperation{F} <: AbstractTileOperation
    f::F # if this is identity, then nothing happens
end

function (op::RecombiningTileOperation)(state::TileState)
    view_generator = (view(state.tile, range_from_tile_origin(state, r)...) for r in state.contained_ranges)
    contained_results = if isnothing(state.contained_metadata)
        op.f.(view_generator)
    else
        op.f.(view_generator, state.contained_metadata)
    end
    shared_results = [state.tile[relevant_range_from_tile_origin(state, r)...] for r in state.shared_ranges]
    return (contained_results, shared_results)
end

function (op::RecombiningTileOperation)(state::TileState, contained_channel::Channel, shared_channel::Channel)
    view_generator = (view(state.tile, range_from_tile_origin(state, r)...) for r in state.contained_ranges)
    bc_obj = if isnothing(state.contained_metadata)
        Base.Broadcast.broadcasted(op.f, view_generator)
    else
        Base.Broadcast.broadcasted(op.f, view_generator, state.contained_metadata)
    end
    
    for i in axes(bc_obj)
        put!(contained_channel, bc_obj[i])
    end

    # We can't use views here, 
    # because that would persist the tile in memory, 
    # which we don't want.
    # Instead, we materialize a new array from the shared ranges.
    shared_data_generator = (state.tile[relevant_range_from_tile_origin(state, r)...] for r in state.shared_ranges)

    for (i, data) in enumerate(shared_data_generator)
        put!(shared_channel, (state.tile_idx, i) => data)
    end

    return
end

function combine(op::RecombiningTileOperation, data, range, metadata, results, tile_idxs; strategy)
    # Create a zeroed out version of the parent array,
    # viewed at the appropriate indices.
    collected_array = zero(view(data, range...))

    # Populate the array with the results from each tile.
    for (result, tile_idx) in zip(results, tile_idxs)
        current_tile_ranges = tile_to_ranges(strategy, tile_idx)
        ranges_to_assign_to = relevant_range_from_tile_origin(range, current_tile_ranges)

        collected_array[ranges_to_assign_to...] = result
    end
    
    # Return the result of the operation on the collected array.
    if isnothing(metadata)
        return op.f(collected_array)
    else
        return op.f(collected_array, metadata)
    end
end
