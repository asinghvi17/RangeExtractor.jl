

function range_from_tile_origin(tile::TileState, range::NTuple{N, AbstractRange}) where N
    return range_from_tile_origin(tile.tile_ranges, range)
end

function range_from_tile_origin(tile_ranges::NTuple{N, <: AbstractUnitRange}, ranges::NTuple{N, <: AbstractUnitRange}) where N
    return ntuple(N) do i
        return ranges[i] .- first(tile_ranges[i]) .+ 1
    end
end

function relevant_range(tile_ranges::NTuple{N, <: AbstractUnitRange}, ranges::NTuple{N, <: AbstractUnitRange}) where N
    return ntuple(N) do i
        return intersect(ranges[i], tile_ranges[i])
    end
end

function relevant_range(tile::TileState, range::NTuple{N, AbstractRange}) where N
    return relevant_range(tile.tile_ranges, range)
end

function relevant_range_from_tile_origin(tile, range::NTuple{N, AbstractRange}) where N
    return range_from_tile_origin(tile, relevant_range(tile, range))
end
