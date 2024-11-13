struct RecombiningTileOperation{F} <: AbstractTileOperation
    f::F # if this is identity, then nothing happens
end

function (op::RecombiningTileOperation)(state::TileState, contained_channel::Channel, shared_channel::Channel)
    view_generator = (view(state.tile, range_from_tile_origin(state.tile, r)) for r in state.contained_ranges)
    bc_obj = if isnothing(state.contained_metadata)
        Base.Broadcast.broadcasted(op.f, view_generator)
    else
        Base.Broadcast.broadcasted(op.f, view_generator, state.contained_metadata)
    end
    
    for i in axes(bc_obj)
        put!(contained_channel, bc_obj[i])
    end

    shared_data_generator = (state.tile[relevant_range_from_tile_origin(state.tile, r)...] for r in state.shared_ranges)

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

        collected_array[ranges_to_assign_to...] .= result
    end
    
    # Return the result of the operation on the collected array.
    return op.f(collected_array)
end
