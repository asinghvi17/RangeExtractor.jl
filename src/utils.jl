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