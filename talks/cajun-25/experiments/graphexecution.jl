# set up for the animations
# load packages
using RangeExtractor # obviously
using Extents
import GeoFormatTypes as GFT, GeometryOps as GO, 
CoordinateTransformations as CT, GeoInterface as GI,
GeoJSON as GeoJSON # geospatial stuff to plot polygons
import WellKnownGeometry
using CairoMakie # plotting
using LinearAlgebra

plotsdir() = joinpath(@__DIR__, "plots")

function scale_to_extent(geom, dest::Extent)
    source = GI.extent(geom; fallback = true)

    source_widths = (source.X[2] - source.X[1], source.Y[2] - source.Y[1])
    dest_widths = (dest.X[2] - dest.X[1], dest.Y[2] - dest.Y[1])

    scale_factors = dest_widths ./ source_widths

    scaling_matrix = Diagonal(Point2(scale_factors))

    transformation = CT.Translation(dest.X[1], dest.Y[1]) ∘ CT.LinearMap(scaling_matrix) ∘ CT.Translation(-source.X[1], -source.Y[1])

    return GO.transform(transformation, geom)
end

# create a "sample geometry" that we will scale, to make this look cooler
wkt = GFT.WellKnownText(GFT.Geom(), "POLYGON ((0.23046094 0.89454174,0.18937868 0.88546944,0.03707415 0.8430624,0.0 0.6231775,0.0020039678 0.35662937,0.047094166 0.2217722,0.050100207 0.21232414,0.2054109 0.0031871796,0.2154308 0.0,0.25050098 0.0,0.3086173 0.08269501,0.3086173 0.21547413,0.33867735 0.35037994,0.34068137 0.38160324,0.45591182 0.47803116,0.55811626 0.3347473,0.6042084 0.20287132,0.6943888 0.13022995,0.7334669 0.13339424,0.8717436 0.16500854,0.88677365 0.19341278,0.98196393 0.51521015,1.0 0.63854504,0.966934 0.8733654,0.86272556 0.89756393,0.8316634 0.8612509,0.7695392 0.74875736,0.6322647 0.8794184,0.55811626 0.9639225,0.49298602 1.0,0.4088177 0.98197174,0.4008016 0.8582201,0.3797596 0.8096628,0.37575155 0.8005419,0.27755505 0.8096628,0.23046094 0.89454174))")

# This is the source array that we will tile.
array = rand(100, 100)

# This is the tiling strategy that we will use - dividing the array into chunks of 10x10 elements each.
tiling = FixedGridTiling{2}(10)

# These are the ranges that we are concerned with.
ranges = [
    (22:28, 22:28),
    (81:90, 81:90),
    (62:68, 42:52),
    (22:62, 62:72)
]
ranges_rects = [Rect2f((first.(r) .- 1), (last.(r) .- first.(r) .+ 1)) for r in ranges]

# Since this is an example, let's generate some hypothetical geometries that might have spawned these:
extents_per_range = [Extent(X = extrema(r[1]), Y = extrema(r[2])) for r in ranges]
geoms = [scale_to_extent(wkt, e) for e in extents_per_range]

# Now, let's split the ranges into tiles, and extract some information from that.
# `c` is the set of tiles that are fully contained in the range.
# `s` is the set of tiles that are shared between multiple ranges.
# `_si` is the inversion of `s` - for each geometry, which tiles does it need?
c, s, _si = RangeExtractor.split_ranges_into_tiles(strategy, ranges)

all_tiles = collect(union(keys(c), keys(s)))

all_tiles_ranges = [RangeExtractor.tile_to_ranges(strategy, t) for t in all_tiles]
all_tiles_rects = [Rect2f((first.(r) .- 1), (last.(r) .- first.(r) .+ 1)) for r in all_tiles_ranges]

using Graphs, MetaGraphsNext

graph = MetaGraph(
    Graphs.SimpleGraph();
    label_type = CartesianIndex{N},
    edge_data_type = Int,
)

contained_ranges = Dict{CartesianIndex{N}, Vector{Int}}()
shared_ranges = Dict{CartesianIndex{N}, Vector{Int}}()
shared_ranges_indices = Dict{Int, CartesianIndices{N, NTuple{N, UnitRange{Int}}}}()

only_contained_tiles = CartesianIndex{N}[]

for (range_idx, range) in enumerate(ranges)
    tile_indices = get_tile_indices(tiling, range)
    # If the range spans multiple tiles, add it to the shared_ranges dictionary
    if any(x -> length(x) > 1, tile_indices)
        current_indices = CartesianIndices(tile_indices)
        shared_ranges_indices[range_idx] = current_indices
        for current_index in current_indices
            vec = get!(() -> Vector{Int}(), shared_ranges, current_index)
            push!(vec, range_idx)
            _ensure_vertex!(graph, current_index)
            for other_index in current_indices
                other_index == current_index && continue
                _ensure_vertex!(graph, other_index)
                _ensure_edge_or_add!(graph, current_index, other_index, 1)
            end
        end
    else
        # If the range spans a single tile, add it to the contained_ranges dictionary
        tile_index = CartesianIndex(only.(tile_indices))
        vec = get!(() -> Vector{Int}(), contained_ranges, tile_index)
        push!(vec, range_idx)
        push!(only_contained_tiles, tile_index)
        # Don't add this to the graph, since we don't care about it.
    end
end

# Obtain all connected components of the graph
ccs = connected_components(graph)

# Execute the connected components first...and in some order.
order = mapreduce(x -> getindex.((graph.vertex_labels,), x), vcat, ccs)

# Execute the contained tiles last.
append!(order, only_contained_tiles) # lower priority

graphplot(graph; ilabels = getindex.(graph.vertex_labels, 1:nv(graph)))