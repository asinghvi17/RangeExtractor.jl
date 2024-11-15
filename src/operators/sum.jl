"""
    SumTileOperation()

An operator that sums the values in each range.  

This can freely change the order of summation, 
so results may not be floating-point accurate every time. 
But they will be approximately accurate.
"""
struct SumTileOperation <: AbstractTileOperation end

function (op::SumTileOperation)(state::TileState)
    contained_results = sum.(view.((state.tile,), state.contained_ranges))
    relevant_shared_ranges = relevant_range_from_tile_origin.((state,), state.shared_ranges)
    shared_results = sum.(view.((state.tile,), relevant_shared_ranges))
    return (contained_results, shared_results)
end

function combine(op::SumTileOperation, results, useless...; strategy)
    return sum(results)
end
