#=
# Utils
=#

"""
    crop_ranges_to_array(array, ranges)

Crop the `ranges` (a Tuple of `AbstractUnitRange`) to the `axes` of `array`.

This uses `intersect` internally to crop the ranges.  

Returns a Tuple of `AbstractUnitRange`, that have been 
cropped to the `axes` of `array`.
"""
function crop_ranges_to_array(array::AbstractArray{T, N}, ranges::NTuple{N, <: AbstractUnitRange}) where {N, T}
    array_axes = axes(array)
    return ntuple(N) do i
        intersect(array_axes[i], ranges[i])
    end
end

"""
    _nothing_or_view(x, idx)

Return `view(x, idx)` if `x` is not nothing, otherwise return nothing.

This is made so that we can have `metadata=nothing`, and have it still work with `broadcast`.
"""
function _nothing_or_view(x, idx)
    isnothing(x) ? nothing : view(x, idx)
end

"""
    module Static

A simple module that defines a type `StaticBool` that can be used to represent a boolean value at compile time.

Implementation taken from GeometryOps.jl and Rasters.jl before it.  Inspired by Static.jl.
"""
module Static
    export True, False, StaticBool
    abstract type StaticBool{value} end
    struct True <: StaticBool{true} end
    struct False <: StaticBool{false} end
    function StaticBool(value::Bool)
        value ? True() : False()
    end
    StaticBool(value::StaticBool) = value
end

using .Static