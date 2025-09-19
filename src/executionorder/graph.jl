struct ConnectedComponentsOrder <: AbstractExecutionOrder
end


using Graphs, MetaGraphsNext


_ensure_vertex!(graph, index) = if !haskey(graph, index)
    add_vertex!(graph, index)
end

_ensure_edge_or_add!(graph, index1, index2, default = 0) = if !haskey(graph, index1, index2)
    add_edge!(graph, index1, index2, default)
else
    graph[index1, index2] += default
end

# override the higher level function, because we need to return more information
function ranges_tiles_order(order::ConnectedComponentsOrder, tiling::FixedGridTiling{N}, ranges::AbstractVector{<: NTuple{N, AbstractRange}}) where {N}

    graph = MetaGraph(
        Graphs.SimpleGraph();
        label_type = CartesianIndex{N},
        edge_data_type = Int,
    )
    
    contained_ranges = Dict{CartesianIndex{N}, Vector{Int}}()
    shared_ranges = Dict{CartesianIndex{N}, Vector{Int}}()
    shared_ranges_indices = Dict{Int, CartesianIndices{N, NTuple{N, UnitRange{Int}}}}()
    
    only_contained_tiles = CartesianIndex{N}[]
    
    for (range_idx, range) in enumerate(ranges)
        tile_indices = get_tile_indices(tiling, range)
        # If the range spans multiple tiles, add it to the shared_ranges dictionary
        if any(x -> length(x) > 1, tile_indices)
            current_indices = CartesianIndices(tile_indices)
            shared_ranges_indices[range_idx] = current_indices
            for current_index in current_indices
                vec = get!(() -> Vector{Int}(), shared_ranges, current_index)
                push!(vec, range_idx)
                _ensure_vertex!(graph, current_index)
                for other_index in current_indices
                    other_index == current_index && continue
                    _ensure_vertex!(graph, other_index)
                    _ensure_edge_or_add!(graph, current_index, other_index, 1)
                end
            end
        else
            # If the range spans a single tile, add it to the contained_ranges dictionary
            tile_index = CartesianIndex(only.(tile_indices))
            vec = get!(() -> Vector{Int}(), contained_ranges, tile_index)
            push!(vec, range_idx)
            push!(only_contained_tiles, tile_index)
            # Don't add this to the graph, since we don't care about it.
        end
    end
    
    # Obtain all connected components of the graph
    ccs = connected_components(graph)
    
    # Execute the connected components first...and in some order.
    order = mapreduce(x -> getindex.((graph.vertex_labels,), x), vcat, ccs)
    
    # Execute the contained tiles last.
    append!(order, only_contained_tiles) # lower priority

    return contained_ranges, shared_ranges, shared_ranges_indices, order
end