using CairoMakie

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


p1 = poly!(ax, [Rect2f((22, 22), (06, 06)), Rect2f((81,81), (9,9))]; color = Makie.Cycled(1), alpha = 0.5, label = "Fully contained in tile")
p2 = poly!(ax, Rect2f((62, 42), (6, 10)); color = Makie.Cycled(2), alpha = 0.5, label = "Shared between 2 tiles")
p3 = poly!(ax, Rect2f((22, 62), (40, 10)); color = Makie.Cycled(3), alpha = 0.5, label = "Shared between 8 tiles")

leg = Legend(fig[2, 1], ax; orientation = :horizontal, nbanks = 2)

save(joinpath(@__DIR__, "contained_shared_ranges.svg"), fig)
save(joinpath(@__DIR__, "contained_shared_ranges.png"), fig; px_per_unit = 2)
##############

using RangeExtractor

array = rand(100, 100)
strategy = FixedGridTiling{2}(10)

ranges = [
    (22:28, 22:28),
    (81:90, 81:90),
    (62:68, 42:52),
    (22:62, 62:72)
]

c, s, _si = RangeExtractor.split_ranges_into_tiles(strategy, ranges)


all_tiles = collect(union(keys(c), keys(s)))

all_tiles_ranges = [RangeExtractor.tile_to_ranges(strategy, t) for t in all_tiles]
all_tiles_rects = [Rect2f((first.(r) .- 1), (last.(r) .- first.(r) .+ 1)) for r in all_tiles_ranges]

tiles_plot = poly!(ax, all_tiles_rects; color = fill((:gray, 0.5), length(all_tiles_rects)), alpha = 0.5, label = "All tiles to be loaded")

delete!(leg)
leg = Legend(fig[2, 1], ax; orientation = :horizontal, nbanks = 2)

fig

save(joinpath(@__DIR__, "applicable_tiles.svg"), fig)
save(joinpath(@__DIR__, "applicable_tiles.png"), fig; px_per_unit = 2)

delete!(leg)

_f, _a, _p = poly(Rect2f(Vec2f(0), Vec2f(1)); color = (:forestgreen, 0.5));

plots, labels = Makie.get_labeled_plots(ax; merge = false, unique = false)
labels[end] = "Non-loaded tiles"
push!(plots, _p)
push!(labels, "Loaded tiles")

leg = Legend(fig[2, 1], plots, labels; orientation = :horizontal, nbanks = 2)

record(fig, joinpath(@__DIR__, "tile_filling_serial.mp4"), 0:length(all_tiles_rects); framerate = 4) do i
    tiles_plot.color[] = vcat(fill((:forestgreen, 0.5), i), fill((:gray, 0.5), length(all_tiles_rects) - i))
end
