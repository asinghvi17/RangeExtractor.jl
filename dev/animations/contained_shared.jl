# set up for the animations
# load packages
using RangeExtractor # obviously
using Extents
import GeoFormatTypes as GFT, GeometryOps as GO, 
CoordinateTransformations as CT, GeoInterface as GI,
GeoJSON as GeoJSON # geospatial stuff to plot polygons
using CairoMakie # plotting
using LinearAlgebra

function scale_to_extent(geom, dest::Extent)
    source = GI.extent(geom)

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
strategy = FixedGridTiling{2}(10)

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



fig = Figure(; size = (600, 650))
ax = Axis(fig[1, 1])
xlims!(ax, 0, 100)
ylims!(ax, 0, 100)

ax.title = "Contained and shared ranges"
ax.subtitle = "Grid lines are tile boundaries\nRectangles are ranges"

ax.xticks[] = (0:10:90, string.(1:10))
ax.yticks[] = (0:10:90, string.(1:10))


ax.xgridcolor[] = :black
ax.ygridcolor[] = :black

ax.aspect[] = DataAspect()

g1 = poly!(ax, [geoms[1], geoms[2]]; color = Makie.Cycled(1), alpha = 0.5, label = "Fully contained in tile")
g2 = poly!(ax, geoms[3]; color = Makie.Cycled(2), alpha = 0.5, label = "Shared between 2 tiles")
g3 = poly!(ax, geoms[4]; color = Makie.Cycled(3), alpha = 0.5, label = "Shared between 8 tiles")

leg = Legend(fig[2, 1], ax; orientation = :horizontal, nbanks = 2)

save(joinpath(@__DIR__, "initial_geometries.svg"), fig)
save(joinpath(@__DIR__, "initial_geometries.png"), fig; px_per_unit = 2)

p1 = poly!(ax, [ranges_rects[1], ranges_rects[2]]; color = Makie.Cycled(1), alpha = 0.4)
p2 = poly!(ax, ranges_rects[3]; color = Makie.Cycled(2), alpha = 0.4)
p3 = poly!(ax, ranges_rects[4]; color = Makie.Cycled(3), alpha = 0.4)


save(joinpath(@__DIR__, "contained_shared_ranges.svg"), fig)
save(joinpath(@__DIR__, "contained_shared_ranges.png"), fig; px_per_unit = 2)
##############

tiles_plot = poly!(ax, all_tiles_rects; color = fill((:gray, 0.5), length(all_tiles_rects)), alpha = 0.5, label = "All tiles to be loaded")

delete!(leg)
leg = Legend(fig[2, 1], ax; orientation = :horizontal, nbanks = 3)

fig

save(joinpath(@__DIR__, "applicable_tiles.svg"), fig)
save(joinpath(@__DIR__, "applicable_tiles.png"), fig; px_per_unit = 2)

delete!(leg)

_f, _a, _p = poly(Rect2f(Vec2f(0), Vec2f(1)); color = (:forestgreen, 0.5));

plots, labels = Makie.get_labeled_plots(ax; merge = false, unique = false)
labels[end] = "Non-loaded tiles"
push!(plots, _p)
push!(labels, "Loaded tiles")

leg = Legend(fig[2, 1], plots, labels; orientation = :horizontal, nbanks = 3)

record(fig, joinpath(@__DIR__, "tile_filling_serial.mp4"), 0:length(all_tiles_rects); framerate = 4) do i
    tiles_plot.color[] = vcat(fill((:forestgreen, 0.5), i), fill((:gray, 0.5), length(all_tiles_rects) - i))
end

resize!(fig.scene, (400, 500))

record(fig, joinpath(@__DIR__, "tile_filling_serial_for_README.gif"), 0:length(all_tiles_rects); framerate = 4, px_per_unit = 2) do i
    tiles_plot.color[] = vcat(fill((:forestgreen, 0.5), i), fill((:gray, 0.5), length(all_tiles_rects) - i))
end


# draw geometries on the tiles
# MakieDraw segfaults, we might need to re-write it to be a bit less annoying

# for now, I used mapshaper to create geojson
