using Tyler, MapTiles, TileProviders
using Colors # for aftercare definition
using DiskArrays
import RangeExtractor # for some utility 
using CairoMakie # diagnostics

struct TileArray{ElType, ProviderType <: TileProviders.AbstractProvider, DownloaderType <: Tyler.AbstractDownloader} <: AbstractDiskArray{ElType, 2}
    provider::ProviderType
    downloader::DownloaderType
    grid::MapTiles.TileGrid
    tilesize::Int
end

TileArray{ElType}(provider::P, downloader::D, grid::MapTiles.TileGrid, tilesize::Int) where {ElType, P <: TileProviders.AbstractProvider, D <: Tyler.AbstractDownloader} = TileArray{ElType, P, D}(provider, downloader, grid, tilesize)

# Utils taken from Zarr.jl
"""
ind2tile(r, bs)

For a given index and blocksize determines which chunks of the Zarray will have to
be accessed.
"""
ind2tile(r::AbstractUnitRange, bs) = fld1(first(r),bs):fld1(last(r),bs)
ind2tile(r::Integer, bs) = fld1(r,bs)

function inds2tilenums(A::TileArray, inds::AbstractUnitRange, dim::Int)
    firsts = first.(A.grid.grid.indices)
    return ind2tile(inds, A.tilesize) .+ firsts[dim] .- 1
end

function tile2inds(A::TileArray, tile::MapTiles.Tile)
    first_x = first(A.grid.grid.indices[1])
    last_y = last(A.grid.grid.indices[2])
    return tile2inds(CartesianIndex(tile.x, tile.y), (first_x, last_y), A.tilesize)
end
# tile2inds(t::MapTiles.Tile, bs) = tile2ind(CartesianIndex(t.x, t.y), bs)
tile2inds(t::CartesianIndex{N}, firsts::NTuple{N, Int}, bs) where N = CartesianIndices(
    (tile2ind_x(t[1], firsts[1], bs), tile2ind_y(t[2], firsts[2], bs))
)
tile2ind_x(t::Int, first, bs) = UnitRange{Int}(((t - first) * bs + 1):((t - first + 1) * bs))
tile2ind_y(t::Int, last, bs) = UnitRange{Int}(((last - t) * bs + 1):((last - t + 1) * bs))

Base.size(a::TileArray) = size(a.grid.grid) .* a.tilesize

DiskArrays.haschunks(a::TileArray) = DiskArrays.Chunked()
function DiskArrays.eachchunk(a::TileArray)
    return DiskArrays.GridChunks(size(a), (first(a.tilesize), last(a.tilesize)); offset = (0, 0))
end

function DiskArrays.readblock!(A::TileArray{ElType, ProviderType, DownloaderType}, aout::AbstractMatrix{<: ElType}, xinds::AbstractUnitRange, yinds::AbstractUnitRange) where {ElType, ProviderType, DownloaderType}

    needed_tiles = MapTiles.Tile.(inds2tilenums(A, xinds, 1), inds2tilenums(A, yinds, 2)', A.grid.z)

    map(needed_tiles) do tile
        # first, fetch tile indices
        tile_data = Tyler.fetch_tile(A.provider, A.downloader, tile)
        # compute the indices of the tile in the larger array
        tile_inds = tile2inds(A, tile)
        # then, fetch the relevant indices
        relevant_out_inds = RangeExtractor.relevant_range_from_tile_origin((xinds, yinds), tile_inds.indices)

        relevant_tile_inds = RangeExtractor.relevant_range_from_tile_origin(tile_inds.indices, (xinds, yinds))

        # debugging code, uncomment if necessary
        # display(image(aftercare(tile_data); axis = (; title = "tile $tile")))
        # @show relevant_out_inds relevant_tile_inds tile_inds

        aout[relevant_out_inds...] = aftercare(tile_data)[relevant_tile_inds...]
    end
end

aftercare(m::AbstractMatrix{<: Colorant}) = rotr90(m)
aftercare(m::AbstractMatrix) = m
aftercare(e::Tyler.ElevationData) = _nan_if_out_of_range.(e.elevation, e.elevation_range...)

function _nan_if_out_of_range(val, min, max)
    min <= val <= max ? val : NaN
end# clamp.(e.elevation, e.elevation_range...)


function DiskArrays.writeblock!(::TileArray, args...)
    # ;)
    error("You can't write to a tile array, since it's a web hosted service!")
end


# test case
# fix Tyler API not fully implemented yet
Tyler.file_ending(::TileProviders.Provider) = ".jpg"
# fix VSCode infinitely calling getindex
function Base.showable(::MIME"image/svg+xml", ::TileArray{<: Colors.Colorant})
    return false
end


using Colors
ta = TileArray{RGB{Colors.FixedPointNumbers.N0f8}}(
    TileProviders.Google(),
    Tyler.PathDownloader(joinpath(@__DIR__, "data")),
    MapTiles.TileGrid(MapTiles.Extents.Extent(X = (-180, 180), Y = (-90, 90)), 2, MapTiles.WGS84()),
    256
)


ta_elev = TileArray{Float32}(
    Tyler.ElevationProvider(nothing),
    Tyler.PathDownloader(joinpath(@__DIR__, "data")),
    MapTiles.TileGrid(MapTiles.Extents.Extent(X = (-180, 180), Y = (-90, 90)), 2, MapTiles.WGS84()),
    256
)

import Rasters
using Rasters: Raster, Projected, X, Y, Intervals, Start

function Raster(provider::Tyler.ElevationProvider, zoom_level::Int, path = mktempdir())
    grid = MapTiles.TileGrid(MapTiles.Extents.Extent(X = (-180, 180), Y = (-90, 90)), zoom_level, MapTiles.WGS84())
    array = TileArray{Float32}(provider, Tyler.PathDownloader(path), grid, 256)

    tile_bounds = MapTiles.Extents.extent(grid, MapTiles.WebMercator())
    range_step_x = 

    x = X(
        Projected(
            LinRange(tile_bounds.X..., size(array, 1)); 
            sampling = Intervals(Start()),
            crs = Rasters.GeoFormatTypes.EPSG(3875),
            mappedcrs = Rasters.GeoFormatTypes.EPSG(4326),
        )
    )

    y = Y(
        Projected(
            LinRange(tile_bounds.Y..., size(array, 2)),
            sampling = Intervals(Start()),
            crs = Rasters.GeoFormatTypes.EPSG(3875),
            mappedcrs = Rasters.GeoFormatTypes.EPSG(4326),
        )
    )

    return Raster(array, (x, y); crs = Rasters.GeoFormatTypes.EPSG(4326), mappedcrs = Rasters.GeoFormatTypes.EPSG(3875), missingval = NaN)
end
