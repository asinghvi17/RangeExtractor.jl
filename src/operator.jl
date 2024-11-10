#=
# TileOperation

The [`TileOperation`](@ref) is a type that holds two functions:
- A function that is applied to the contained ranges of a tile
- A function that is applied to the shared ranges of a tile

The results from the contained and shared ranges are then combined to form the final result by the extractor, using its `combine_func`.

A [`TileOperation`](@ref) is callable with a [`TileState`](@ref), and returns a tuple of the results from the contained and shared functions.    

=#
"""
    TileOperation(; contained, shared)
    TileOperation(operation)

Create a tile operation that can operate on a [`TileState`](@ref)
and return a tuple of results from the contained and shared ranges.



# Arguments
- `contained`: Function to apply to contained (non-overlapping) regions
- `shared`: Function to apply to shared (overlapping) regions

# Examples
```julia
# Different functions for contained and shared regions
op = TileOperation(
    contained = (data, meta) -> mean(data),
    shared = (data, meta) -> sum(data)
)

# Same function for both
op = TileOperation((data, meta) -> mean(data))
```
"""
struct TileOperation{C,S}
    contained_func::C
    shared_func::S
end

# Constructor for when the same operation should be used for both
function TileOperation(operation::Function)
    TileOperation(operation, operation)
end

# Keyword constructor for explicit contained/shared functions
function TileOperation(; 
    contained::Function,
    shared::Function=contained
)
    TileOperation(contained, shared)
end


# This function allows us to define dispatches on TileOperations based on the types of the contained functions,
# allowing custom behaviour for different operations.
function (op::TileOperation{ContainedFunc, SharedFunc})(state::TileState{N}) where {N, ContainedFunc, SharedFunc}
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
    if op isa TileOperation && argtypes <: Tuple{<: TileState}
        println(io, """
        No matching method found for TileOperation with functions:
            contained_func::$(typeof(op.contained_func))
            shared_func::$(typeof(op.shared_func))
        
        This likely means there are multiple applicable methods for your operator functions.
        To resolve this, you can define more specific method signatures for your operator functions
        that explicitly call the general case, as shown below:
        
        ```
        (op::TileOperation{$(typeof(op.contained_func)), $(typeof(op.shared_func))})(state::TileState) = invoke(TileOperation{Function, Function}(op.contained_func, op.shared_func), Tuple{TileState}, state)
        ```

        See the Julia documentation on multiple dispatch and `invoke` for more details.
        """)
    end
end
