
function _extract!(threaded::Static.True, operator::AbstractTileOperation, dest::AbstractVector, array::AbstractArray, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::Union{AbstractVector, Nothing} = nothing; strategy, progress = true, kwargs...) where N


function reintegrate_shared_results!()

    assembled_results = Dict{GeomIndexType, Vector{Pair{TileIndexType, SharedOutputType}}}()

    for ((geom_idx, tile_idx), result) in shared_results_channel
        if haskey(assembled_results, geom_idx)
            push!(assembled_results[geom_idx], (tile_idx => result))
        else
            assembled_results[geom_idx] = [(tile_idx => result)]
        end

        # Check if the assembled results so far have all required elements for recombination
        if issetequal((first(res) for res in assembled_results[geom_idx]), shared_ranges_indices[geom_idx])
            
        end
    end

end


    if progress
        prog = Progress(length(ranges); desc = "Extracting...")
    end

    # for now, DO NOT CHANNELIZE/MULTITHREAD
    # simply run single threaded so we are confident of the state of the program
    @timeit to "preprocessing" begin
    # Split the ranges into their tiles.
    contained_ranges, shared_ranges, shared_ranges_indices = split_ranges_into_tiles(strategy, ranges)
    contained_range_tiles = collect(keys(contained_ranges))
    shared_range_tiles = collect(keys(shared_ranges))
    shared_only_tiles = setdiff(shared_range_tiles, contained_range_tiles)
    all_relevant_tiles = collect(union(contained_range_tiles, shared_only_tiles))
    end
    @debug "Using $(length(all_relevant_tiles)) tiles with $(length(ranges)) ranges."


    _EMPTY_INDEX_VECTOR = Int[]

    each_tile_contained_indices = get.((contained_ranges,), all_relevant_tiles, (_EMPTY_INDEX_VECTOR,))
    each_tile_shared_indices = get.((shared_ranges,), all_relevant_tiles, (_EMPTY_INDEX_VECTOR,))
    each_tile_contained_metadata = _nothing_or_view.((metadata,), each_tile_contained_indices)
    each_tile_shared_metadata = _nothing_or_view.((metadata,), each_tile_shared_indices)

    # result_vec = _allocate_do_first_tile()

    @debug "Processing $(length(all_relevant_tiles)) tiles."
    # For each tile, extract the data and apply the operation.
    @timeit to "processing tiles" result_tasks = map(all_relevant_tiles, each_tile_contained_indices, each_tile_shared_indices, each_tile_contained_metadata, each_tile_shared_metadata) do tile_idx, tile_contained_indices, tile_shared_indices, tile_contained_metadata, tile_shared_metadata

        raw_tile_ranges = tile_to_ranges(strategy, tile_idx)
        tile_ranges = crop_ranges_to_array(array, raw_tile_ranges)
        contained_ranges_view = view(ranges, get(contained_ranges, tile_idx, _EMPTY_INDEX_VECTOR))
        shared_ranges_view = view(ranges, get(shared_ranges, tile_idx, _EMPTY_INDEX_VECTOR))
        contained_metadata_view = _nothing_or_view(metadata, get(contained_ranges, tile_idx, _EMPTY_INDEX_VECTOR))
        shared_metadata_view = _nothing_or_view(metadata, get(shared_ranges, tile_idx, _EMPTY_INDEX_VECTOR))
        # @debug "Processing tile $tile_idx."
        Threads.@spawn begin
            @timeit to "reading tile into memory" begin
                @debug "Reading tile $tile_idx into memory."
                tile = array[tile_ranges...]
            end
            @timeit to "constructing state" begin
            state = TileState(
                tile, 
                tile_ranges, 
                contained_ranges_view,
                shared_ranges_view,
                contained_metadata_view,
                shared_metadata_view
            )
            end
            # @debug "Operating on tile $tile_idx."
            @timeit to "operating on tile" begin
                contained_results, shared_results = operator(state)  
            end
            progress && update!(prog, length(contained_results))
            contained_results, shared_results
        end
    end

    results = fetch.(result_tasks)

    @debug "Combining shared geometries."
    @timeit to "combining shared geometries" Threads.@threads :greedy for geom_idx in keys(shared_ranges_indices)
        geom_metadata = isnothing(metadata) ? nothing : metadata[geom_idx]
        relevant_tile_idxs = shared_ranges_indices[geom_idx]
        relevant_results = [
            begin
                relevant_tile_index_in_array = findfirst(==(tile_idx), all_relevant_tiles)
                relevant_geom_index_in_tile_results = findfirst(==(geom_idx), shared_ranges[tile_idx])
                results[relevant_tile_index_in_array][2][relevant_geom_index_in_tile_results]
            end for tile_idx in relevant_tile_idxs
        ]
        final_result_for_shared_range = combine(operator, array, ranges[geom_idx], geom_metadata, relevant_results, relevant_tile_idxs; strategy)
        dest[geom_idx] = final_result_for_shared_range
        progress && next!(prog)
    end

    @debug "Combining results to a single vector."

    # Unwrap the results that were contained in a single tile first
    @timeit to "unwrapping contained results" for (tile_idx, res) in zip(contained_range_tiles, view(results, 1:length(contained_range_tiles)))
        contained_results, __shared_results = res
        dest[contained_ranges[tile_idx]] .= contained_results
    end

    return dest
end