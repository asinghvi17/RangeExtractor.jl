#=
# TileOperation

The [`TileOperation`](@ref) is a type that holds two functions:
- A function that is applied to the contained ranges of a tile
- A function that is applied to the shared ranges of a tile

The results from the contained and shared ranges are then combined to form the final result by the extractor, using its `combine_func`.

A [`TileOperation`](@ref) is callable with a [`TileState`](@ref), and returns a tuple of the results from the contained and shared functions.    

=#

export TileOperation

"""
    AbstractTileOperation

Abstract type for tile operations, which are callable structs that can operate on a [`TileState`](@ref).

## Interface

All subtypes of `AbstractTileOperation` MUST implement the following interface:

- `(op::AbstractTileOperation)(state::TileState)`: Apply the operation to the given tile state.  Return a tuple of (contained_results, shared_results).  The order of the results **MUST** be the same as the order of the indices in `state.contained_ranges` and `state.shared_ranges`.

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

function (op::AbstractTileOperation)(state::TileState)
    error("No method found for AbstractTileOperation $(typeof(op)), it may not be implemented.")
end

"""
    TileOperation(; contained, shared)
    TileOperation(operation)

Create a tile operation that can operate on a [`TileState`](@ref)
and return a tuple of results from the contained and shared ranges.

It calls the `contained` function on each contained range, and the `shared` function on each shared range.

Functions are called with the signature `func(data, metadata)`, where `data` is a view of the tile data on the current range, and `metadata` is the metadata for that range.

If constructed with a single function, that function is used for both contained and shared operations.

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
struct TileOperation{ContainedFunc, SharedFunc, CombineFunc} <: AbstractTileOperation
    "The function to apply to each contained range."
    contained_func::ContainedFunc
    "The function to apply to each shared range."
    shared_func::SharedFunc
    "The function to combine the results from each tile on shared ranges."
    combine_func::CombineFunc
end

struct TypedTileOperation{C, S, CombineFunc, ContainedType, SharedType} <: AbstractTileOperation
    contained_func::C
    shared_func::S
    combine_func::CombineFunc
end

"""
    RecombiningTileOperation(func)

Creates a tile operation that always passes `func` the 
"""
struct RecombiningTileOperation{F} <: AbstractRecombiningTileOperation
    func::Func
end


function TypedTileOperation(op::TileOperation{C, S}, data_array::ArrayType, metadata::MetaType) where {C, S, ArrayType, MetaType}
    single_meta = isnothing(metadata) ? nothing : metadata[begin]
    contained_return_type = Base.return_types(op.contained_func, Tuple{ArrayType, typeof(single_meta)})
    shared_return_type = Base.return_types(op.shared_func, Tuple{ArrayType, typeof(single_meta)})
    return TypedTileOperation{C, S, foldl(Base.promote_type, contained_return_type), foldl(Base.promote_type, shared_return_type)}(op.contained_func, op.shared_func)
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


# This function allows us to define dispatches on TileOperations based on the types of the contained functions,
# allowing custom behaviour for different operations.
function (op::TypedTileOperation{ContainedFunc, SharedFunc, ContainedReturnType, SharedReturnType})(state::TileState{N}) where {N, ContainedFunc, SharedFunc, ContainedReturnType, SharedReturnType}
    # Note: this function is called within a multithreaded task, so DO NOT multithread within it.

    # First, map over the contained ranges and apply the contained function
    contained_results = Vector{ContainedReturnType}(undef, length(state.contained_ranges))
    for (i, (range, metadata)) in enumerate(zip(state.contained_ranges, isnothing(state.contained_metadata) ? Iterators.repeated(nothing) : state.contained_metadata))
        # We need to shift the range by the offset of the tile, so that it is relative to the tile's origin
        range_from_tile_origin = ntuple(N) do ri
            range[ri] .- first(state.tile_ranges[ri]) .+ 1
        end
        tileview = view(state.tile, range_from_tile_origin...)
        contained_results[i] = op.contained_func(tileview, metadata)
    end

    # Then, map over the shared ranges and apply the shared function
    shared_results = Vector{SharedReturnType}(undef, length(state.shared_ranges))
    for (i, (range, metadata)) in enumerate(zip(state.shared_ranges, isnothing(state.shared_metadata) ? Iterators.repeated(nothing) : state.shared_metadata))
        relevant_range_from_tile_origin = ntuple(N) do i
            relevant_range = intersect(range[i],state.tile_ranges[i])
            relevant_range .- first(state.tile_ranges[i]) .+ 1
        end
        tileview = view(state.tile, relevant_range_from_tile_origin...)
        shared_results[i] = op.shared_func(tileview, metadata)
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



struct SumOperator <: AbstractTileOperation{typeof(sum), typeof(sum)}
end

function (::SumOperator)(state::TileState{N}) where N

    # First, map over the contained ranges and apply the contained function
    contained_results = broadcast(state.contained_ranges, state.contained_metadata) do range, metadata
        # We need to shift the range by the offset of the tile, so that it is relative to the tile's origin
        range_from_tile_origin = ntuple(N) do i
            range[i] .- first(state.tile_ranges[i]) .+ 1
        end
        tileview = view(state.tile, range_from_tile_origin...)
        return sum(tileview)
    end

    # Then, map over the shared ranges and apply the shared function
    shared_results = broadcast(state.shared_ranges, state.shared_metadata) do range, metadata
        relevant_range_from_tile_origin = ntuple(N) do i
            relevant_range = intersect(range[i],state.tile_ranges[i])
            return relevant_range .- first(state.tile_ranges[i]) .+ 1
        end
        tileview = view(state.tile, relevant_range_from_tile_origin...)
        return sum(tileview)
    end

    # Return a tuple of the results (combined and shared)
    return (contained_results, shared_results)
end