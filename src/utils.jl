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
    return relevant_range(array_axes, ranges)
end



function range_from_tile_origin(tile::TileState, range::NTuple{N, <: AbstractRange}) where N
    return range_from_tile_origin(tile.tile_ranges, range)
end

function range_from_tile_origin(tile_ranges::Tuple{Vararg{<: AbstractUnitRange}}, ranges::NTuple{N, <: AbstractUnitRange}) where N
    return ntuple(N) do i
        return ranges[i] .- first(tile_ranges[i]) .+ 1
    end
end

function relevant_range(tile_ranges::Tuple{Vararg{<: AbstractUnitRange}}, ranges::NTuple{N, <: AbstractUnitRange}) where N
    return ntuple(N) do i
        return intersect(ranges[i], tile_ranges[i])
    end
end

function relevant_range(tile::TileState, range::NTuple{N, <: AbstractRange}) where N
    return relevant_range(tile.tile_ranges, range)
end

function relevant_range_from_tile_origin(tile, range::NTuple{N, <: AbstractRange}) where N
    return range_from_tile_origin(tile, relevant_range(tile, range))
end


"""
    _nothing_or_view(x, idx)

Return `view(x, idx)` if `x` is not nothing, otherwise return nothing.

This is made so that we can have `metadata=nothing`, and have it still work with `broadcast`.
"""
function _nothing_or_view(x, idx)
    isnothing(x) ? nothing : view(x, idx)
end

# ProgressMeter.jl's `update!` implementation sets the counter to the new value.  But I want to add the new value to the current counter.

function _append_progress!(p::ProgressMeter.Progress, new_count; options...)
    ProgressMeter.lock_if_threading(p) do
        p.counter += new_count
        updateProgress!(p; ignore_predictor = false, options...)
    end
end
