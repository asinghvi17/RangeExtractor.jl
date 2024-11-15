#=
# Tiling schemes


=#

export FixedGridTiling



"""
    FixedGridTiling(chunk_sizes...)

Tiles a domain into a fixed grid of chunks. 

Geometries that are fully encompassed by a tile are processed in bulk whenever a tile is read.

Geometries that lie on chunk boundaries are added to a separate queue, and whenever a tile is read, 
the view on the tile representing the chunk of that geometry that lies within the tile is added to a queue.  These views are combined by a separate worker task,
and once all the information on a geometry has been read, it is processed by a second worker task.

However, this approach could potentially change.  If we know the statistic is separable and associative (like a histogram with fixed bins, or `mean`, `min`, `max`, etc.),
we could simply process the partial geometries in the same task that reads the tile, and recombine at the end.   This would allow us to avoid the (cognitive) overhead of 
managing separate channels and worker tasks.  But it would be a bit less efficient and less general over the space of zonal functions.  It would, however, allow massive zonals - so eg 
"""
struct FixedGridTiling{N} <: TilingStrategy 
    tilesize::NTuple{N, Int}
end

FixedGridTiling{N}(tilesize::Int) where N = FixedGridTiling{N}(ntuple(_ -> tilesize, N))

indextype(::Type{FixedGridTiling{N}}) where N = CartesianIndex{N}

function _get_range_of_multiples(range, factor)
    start = floor(Int, (first(range) - 1)/factor) + 1 # account for 1 based indexing
    stop = floor(Int, (last(range) - 1)/factor) + 1 # account for 1 based indexing

    if stop < start
        tmp = start
        start = stop
        stop = tmp
    end

    return UnitRange(start, stop)
end

function get_tile_indices(tiling::FixedGridTiling{N}, ranges::NTuple{N, RangeType}) where {N, RangeType <: AbstractUnitRange}
    tile_indices = ntuple(N) do i
        _get_range_of_multiples(ranges[i], tiling.tilesize[i])
    end
    return tile_indices
end

function tile_to_ranges(tiling::FixedGridTiling{N}, index::CartesianIndex{N2}) where {N, N2}
    return ntuple(N) do i
        start_idx = (index[i] - 1) * tiling.tilesize[i] + 1
        stop_idx = start_idx + tiling.tilesize[i] - 1
        return start_idx:stop_idx
    end
end

function split_ranges_into_tiles(tiling::FixedGridTiling{N}, ranges::AbstractVector{<: NTuple{N, RangeType}}) where {N, RangeType <: AbstractUnitRange}
    contained_ranges = Dict{CartesianIndex{N}, Vector{Int}}()
    shared_ranges = Dict{CartesianIndex{N}, Vector{Int}}()
    shared_ranges_indices = Dict{Int, CartesianIndices{N, NTuple{N, UnitRange{Int}}}}()

    for (range_idx, range) in enumerate(ranges)
        tile_indices = get_tile_indices(tiling, range)
        # If the range spans multiple tiles, add it to the shared_ranges dictionary
        if any(x -> length(x) > 1, tile_indices)
            current_indices = CartesianIndices(tile_indices)
            shared_ranges_indices[range_idx] = current_indices
            for current_index in current_indices
                vec = get!(() -> Vector{Int}(), shared_ranges, current_index)
                push!(vec, range_idx)
            end
        else
            # If the range spans a single tile, add it to the contained_ranges dictionary
            vec = get!(() -> Vector{Int}(), contained_ranges, CartesianIndex(only.(tile_indices)))
            push!(vec, range_idx)
        end
    end

    return contained_ranges, shared_ranges, shared_ranges_indices
end