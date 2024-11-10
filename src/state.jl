#=
# TileState

This struct holds all the state that is relevant to a single tile.

It is the input to the [`TileOperator`](@ref), and is used to apply the operator to the tile.
=#

"""
    TileState{N, TileType, RowVecType}
    TileState(tile::TileType, tile_offset::CartesianIndex{N}, contained_rows::AbstractVector, shared_rows::AbstractVector)

A struct that holds all the state that is local to a single tile.

## Fields
$(FIELDS)
"""
struct TileState{N, TileType, RangeType <: AbstractUnitRange, RowVecType}
    "The read data of the tile."
    tile::TileType
    "The ranges that the tile covers in the parent array"
    tile_ranges::NTuple{N, <: RangeType}
    "The ranges of the rows that are fully contained in the tile"
    contained_ranges::AbstractVector{<: NTuple{N, <: RangeType}}
    "The ranges of the rows that are only partially contained in the tile, i.e shared with other tiles"
    shared_ranges::AbstractVector{<: NTuple{N, <: RangeType}}
    "The rows that are fully contained in the tile"
    contained_metadata::RowVecType
    "The rows that are only partially contained in the tile, i.e shared with other tiles"
    shared_metadata::RowVecType
end
