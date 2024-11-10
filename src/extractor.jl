function _extract(array, ranges, metadata, tiling_scheme, op::TileOperation, combine_func)
# Single-threaded extractor
# Nothing complicated here.

function _extract(::Static.False, array, ranges, metadata, tiling_scheme, op::TileOperation, combine_func)
    # for now, DO NOT CHANNELIZE/MULTITHREAD
    # simply run single threaded so we are confident of the state of the program

    # Split the ranges into their tiles.
    contained_ranges, shared_ranges, shared_ranges_indices = split_ranges_into_tiles(tiling_scheme, ranges)
    contained_range_tiles = collect(keys(contained_ranges))
    shared_range_tiles = collect(keys(shared_ranges))
    shared_only_tiles = setdiff(shared_range_tiles, contained_range_tiles)
    all_relevant_tiles = collect(union(contained_range_tiles, shared_only_tiles))

    
    _EMPTY_INDEX_VECTOR = Int[]

    # For each tile, extract the data and apply the operation.
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

    # For each geometry split across tiles, combine the results from the relevant tiles.
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

    # Combine the results from the contained tiles and the shared tiles.  This is a pre-allocated vector for speed.

    CONTAINED_RESULT_ELTYPE = mapfoldl(eltype, Base.promote_type, first(res) for res in results)
    FINAL_RESULT_ELTYPE = foldl(Base.promote_type, Iterators.map(typeof ∘ last, shared_results), init = CONTAINED_RESULT_ELTYPE)
    ret = Vector{FINAL_RESULT_ELTYPE}(undef, length(ranges))

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


# Multi-threaded extractor
# This gets a bit more complicated, since it (A) keeps track of state and (B) uses channels to send results back to the main thread where they are processed.

function _extract(::Static.True, array, ranges, metadata, tiling_scheme, op::TileOperation, combine_func)

    # Split the ranges into their tiles.
    contained_ranges, shared_ranges, shared_ranges_indices = split_ranges_into_tiles(tiling_scheme, ranges)
    contained_range_tiles = collect(keys(contained_ranges))
    shared_range_tiles = collect(keys(shared_ranges))
    shared_only_tiles = setdiff(shared_range_tiles, contained_range_tiles)
    all_relevant_tiles = collect(union(contained_range_tiles, shared_only_tiles))

    shared_input_channel = Channel{Tuple{indextype(tiling_scheme), Any}}(Inf)
    shared_output_channel = Channel{Tuple{indextype(tiling_scheme), Any}}(Inf)

    
    _EMPTY_INDEX_VECTOR = Int[]

    # For each tile, extract the data and apply the operation.
    result_promises = map(all_relevant_tiles) do tile_idx

        tile_ranges = tile_to_ranges(tiling_scheme, tile_idx)
        tile_ranges = crop_ranges_to_array(array, tile_ranges)

        contained_indices = get(contained_ranges, tile_idx, _EMPTY_INDEX_VECTOR)
        shared_indices = get(shared_ranges, tile_idx, _EMPTY_INDEX_VECTOR)

        contained_ranges = view(ranges, contained_indices)
        shared_ranges = view(ranges, shared_indices)
        
        contained_metadata = _nothing_or_view(metadata, contained_indices)
        shared_metadata = _nothing_or_view(metadata, shared_indices)

        Threads.@spawn begin
            tile = view($array, $tile_ranges...)
            state = TileState(
                tile, 
                $tile_ranges, 
                $contained_indices, 
                $shared_indices, 
                $contained_metadata, 
                $shared_metadata
            )
            contained_results, shared_results = op(state)
        end   
    end

    results = fetch.(result_promises)

    # For each geometry split across tiles, combine the results from the relevant tiles.
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

    # Combine the results from the contained tiles and the shared tiles.  This is a pre-allocated vector for speed.

    CONTAINED_RESULT_ELTYPE = mapfoldl(eltype, Base.promote_type, first(res) for res in results)
    FINAL_RESULT_ELTYPE = foldl(Base.promote_type, Iterators.map(typeof ∘ last, shared_results), init = CONTAINED_RESULT_ELTYPE)
    ret = Vector{FINAL_RESULT_ELTYPE}(undef, length(ranges))

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