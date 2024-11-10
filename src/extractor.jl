function _extract(array, ranges, metadata, tiling_scheme, op::TileOperator, combine_func)
    # for now, DO NOT CHANNELIZE/MULTITHREAD
    # simply run single threaded so we are confident of the state of the program

    contained_ranges, shared_ranges, shared_ranges_indices = split_ranges_into_tiles(tiling_scheme, ranges)
    contained_range_tiles = collect(keys(contained_ranges))
    shared_range_tiles = collect(keys(shared_ranges))
    shared_only_tiles = setdiff(shared_range_tiles, contained_range_tiles)
    all_relevant_tiles = collect(union(contained_range_tiles, shared_only_tiles))


    _nothing_or_view(x, idx) = isnothing(x) ? nothing : view(x, idx)

    _EMPTY_INDEX_VECTOR = Int[]
    results = map(all_relevant_tiles) do tile_idx
        tile_ranges = tile_to_ranges(tiling_scheme, tile_idx)
        tile_ranges = crop_ranges_to_array(array, tile_ranges)
        tile = view(array, tile_ranges...)
        state = TileState(
            tile, 
            tile_ranges, 
            view(ranges, get(contained_ranges, tile_idx, _EMPTY_INDEX_VECTOR)), 
            view(ranges, get(shared_ranges, tile_idx, _EMPTY_INDEX_VECTOR)), 
            _nothing_or_view(metadata, get(contained_ranges, tile_idx, _EMPTY_INDEX_VECTOR)), 
            _nothing_or_view(metadata, get(shared_ranges, tile_idx, _EMPTY_INDEX_VECTOR))
        )
        contained_results, shared_results = op(state)        
    end

    shared_results = []

    for geom_idx in keys(shared_ranges_indices)
        relevant_results = [
            begin
                relevant_tile_index_in_array = findfirst(==(tile_idx), all_relevant_tiles)
                relevant_geom_index_in_tile = findfirst(==(geom_idx), shared_ranges[tile_idx])
                results[relevant_tile_index_in_array][2][relevant_geom_index_in_tile]
            end for tile_idx in shared_ranges_indices[geom_idx]
        ]
        push!(
            shared_results,
            geom_idx => combine_func(relevant_results)
        )
    end

    ret = Vector{mapfoldl(eltype, Base.promote_type, first(res) for res in results)}(undef, length(ranges))

    # Unwrap the results that were contained in a single tile first
    for (tile_idx, res) in zip(contained_range_tiles, view(results, 1:length(contained_range_tiles)))
        contained_results, __shared_results = res
        ret[contained_ranges[tile_idx]] .= contained_results
    end

    # Then, unwrap the shared results
    for (geom_idx, res) in shared_results
        ret[geom_idx] = res
    end

    return ret
end