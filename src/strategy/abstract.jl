#=
# Tiling strategies

There are quite a few different strategies to tile a domain.
=#
export TilingStrategy, indextype, materialize_strategy, get_tile_indices, tile_to_ranges, split_ranges_into_tiles

"""
    abstract type TilingStrategy

Abstract type for tiling strategies.  Must hold all necessary information to create a tiling strategy.

All tiling strategies MUST implement the following methods:
- `indextype(::Type{<: TilingStrategy})`: Return the type of the index used by the tiling strategy.  For example, [`FixedGridTiling`](@ref) returns `CartesianIndex{N}`.  `RTreeTiling` might return a single integer, that corresponds to the R-tree node id.
- `get_tile_indices(tiling, range)`: Given a range, return the indices of the tiles that the range intersects.
- `tile_to_ranges(tiling, index)`: Given a tile index, return the ranges that the tile covers.
- `split_ranges_into_tiles(tiling, ranges)`: Given a set of ranges, return three dictionaries:
    - A dictionary mapping tile indices to the indices of the ranges that the tile fully contains (Ints).
    - A dictionary mapping tile indices to the indices of the ranges that the tile shares with one or more other ranges (Ints).
    - A dictionary mapping the indices of the shared ranges (Ints) to the tile indices that contain them.
"""
abstract type TilingStrategy end

indextype(::Type{<: TilingStrategy}) = error("Not implemented for tiling strategy $tiling")
indextype(tiling::TilingStrategy) = indextype(typeof(tiling))

function get_tile_indices(tiling::TilingStrategy, range::NTuple{N, RangeType}) where {N, RangeType <: AbstractUnitRange}
    error("Not implemented for tiling strategy $tiling")
end

function tile_to_ranges(tiling::TilingStrategy, index::CartesianIndex{N2}) where {N2}
    error("Not implemented for tiling strategy $tiling")
end

function split_ranges_into_tiles(tiling::TilingStrategy, ranges::NTuple{N, RangeType}) where {N, RangeType <: AbstractUnitRange}
    error("Not implemented for tiling strategy $tiling")
end
