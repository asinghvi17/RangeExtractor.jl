#=
# TileOperator

The [`TileOperator`](@ref) is a type that holds two functions:
- A function that is applied to the contained ranges of a tile
- A function that is applied to the shared ranges of a tile

The results from the contained and shared ranges are then combined to form the final result by the extractor, using its `combine_func`.

A [`TileOperator`](@ref) is callable with a [`TileState`](@ref), and returns a tuple of the results from the contained and shared functions.    

=#

"""
    TileOperator{ContainedFunc, SharedFunc}
    (to::TileOperator)(tile, state::TileState)

A struct that holds the functions to apply to the contained and shared areas of a tile.

It's callable with a tile its state, and returns a tuple of the results from the contained and shared functions.

$(FIELDS)
"""
struct TileOperator{ContainedFunc, SharedFunc}
    """
    The function to apply to the contained areas, returns a single value per array.  
        
    This function MUST take one input, which are: 
        (a) the relevant view of the tile, and
        (b) the metadata contained in the row under consideration.

    The output of this function is a single value, however you define that.
    """
    contained_func::ContainedFunc
    """
    The function to apply to the shared areas, returns a single value per array.  
        
    This function MUST take one input, which are: 
        (a) the relevant materialized array of the data that was requested, and
        (b) the metadata contained in the row under consideration.

    The output of this function is a single value, however you define that.  

    **HOWEVER**, the reason we have split these functions up is so that you can pass a combiner function
    that will combine the results from the contained functions on each tile.

    So, you could stitch rasters together, _or_ you could calculate a rolling minimum or online statistic, to save memory.
    Something like a histogram would also be a good candidate to return from `shared_func`, as long as the bins are guaranteed
    to be the same everywhere so they are additive.
    """
    shared_func::SharedFunc
end

# This function allows us to define dispatches on TileOperators based on the types of the contained functions,
# allowing custom behaviour for different operations.
function (op::TileOperator{ContainedFunc, SharedFunc})(state::TileState{N}) where {N, ContainedFunc, SharedFunc}
    # Note: this function is called within a multithreaded task, so DO NOT multithread within it.

    # First, map over the contained ranges and apply the contained function
    contained_results = broadcast(state.contained_ranges, state.contained_metadata) do range, metadata
        # We need to shift the range by the offset of the tile, so that it is relative to the tile's origin
        range_from_tile_origin = ntuple(N) do i
            range[i] .- first(state.tile_ranges[i]) .+ 1
        end
        tileview = view(state.tile, range_from_tile_origin...)
        return op.contained_func(tileview, metadata)
    end

    # Then, map over the shared ranges and apply the shared function
    shared_results = broadcast(state.shared_ranges, state.shared_metadata) do range, metadata
        relevant_range_from_tile_origin = ntuple(N) do i
            relevant_range = intersect(range[i],state.tile_ranges[i])
            return relevant_range .- first(state.tile_ranges[i]) .+ 1
        end
        tileview = view(state.tile, relevant_range_from_tile_origin...)
        return op.shared_func(tileview, metadata)
    end

    # Return a tuple of the results (combined and shared)
    return (contained_results, shared_results)
end

function _tile_operator_invocation_error_hinter(io, exc, argtypes, kwargs)
    op = exc.f
    if op isa TileOperator && argtypes <: Tuple{<: TileState}
        println(io, """
        No matching method found for TileOperator with functions:
            contained_func::$(typeof(op.contained_func))
            shared_func::$(typeof(op.shared_func))
        
        This likely means there are multiple applicable methods for your operator functions.
        To resolve this, you can define more specific method signatures for your operator functions
        that explicitly call the general case, as shown below:
        
        ```
        (op::TileOperator{$(typeof(op.contained_func)), $(typeof(op.shared_func))})(state::TileState) = invoke(TileOperator{Function, Function}(op.contained_func, op.shared_func), Tuple{TileState}, state)
        ```

        See the Julia documentation on multiple dispatch and `invoke` for more details.
        """)
    end
end
