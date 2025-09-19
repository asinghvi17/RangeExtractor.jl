using CairoMakie, GeoMakie
import GeometryOps as GO, GeoInterface as GI
using Rasters

plotsdir() = joinpath(@__DIR__, "plots")

earth_img = GeoMakie.earth()

earth_ras = DimArray(earth_img |> rotr90, (X(LinRange(-180, 180, size(earth_img, 2)+1)[1:end-1]), Y(LinRange(-90, 90, size(earth_img, 1)+1)[1:end-1])))


fig, ax, plt = heatmap(
    earth_ras; 
    axis = (; 
        aspect = DataAspect(),
        xticks = Makie.WilkinsonTicks(6; k_min = 4),
        yticks = Makie.WilkinsonTicks(6; k_min = 4),
        xlabel = "",
        ylabel = "",
    ),
)
# https://github.com/rafaqz/DimensionalData.jl/issues/929
ax.xlabel = ""
ax.ylabel = ""
fig

legenditems = []
legendlabels = []

push!(legenditems,
    [begin
    x, y = (i.I .- 1) ./ 2
    Makie.PolyElement(;
        polypoints = [Point2f(x, y), Point2f(x+0.5, y), Point2f(x+0.5, y+0.5), Point2f(x, y+0.5), Point2f(x, y)],
        color = cgrad(:terrain)[l/4]
    )
end for (i, l) in zip(CartesianIndices((1:2, 1:2)), CartesianIndices((1:2, 1:2)) |> LinearIndices)]
)
push!(legendlabels, "Dataset")

leg = Legend(fig[2, 1], legenditems, legendlabels; tellheight = true, tellwidth = false)
fig

save(joinpath(plotsdir(), "range_meta_tiling", "1.png"), fig; px_per_unit = 2)

using NaturalEarth
all_countries = NaturalEarth.naturalearth("admin_0_countries", 110)
usa_multipoly = all_countries.geometry[findfirst(==("USA"), all_countries.ADM0_A3)]
usa_poly = GI.getgeom(usa_multipoly, argmax(GO.area.(GI.getgeom(usa_multipoly))))

range = Rasters.dims2indices(earth_ras, Touches(GI.extent(usa_poly)))
ext = GI.extent(earth_ras[range...])
rect = Rect2f(ext.X[1], ext.Y[1], ext.X[2] - ext.X[1], ext.Y[2] - ext.Y[1])

rangeplot = poly!(ax, rect; color = (:white, 0.3), strokecolor = (:gray, 0.9), strokewidth = 1)

push!(legenditems, rangeplot)
push!(legendlabels, "Range")

delete!(leg)
leg = Legend(fig[2, 1], legenditems, legendlabels; tellheight = true, tellwidth = false)

fig

save(joinpath(plotsdir(), "range_meta_tiling", "2.png"), fig; px_per_unit = 2)



usaplot = poly!(ax, usa_poly; color = (:red, 0.3), strokecolor = (:red, 0.5), strokewidth = 1)
push!(legenditems, usaplot)
push!(legendlabels, "Metadata")

delete!(leg)
leg = Legend(fig[2, 1], legenditems, legendlabels; nbanks = 2, orientation = :horizontal, tellheight = true, tellwidth = false)

fig

save(joinpath(plotsdir(), "range_meta_tiling", "3.png"), fig; px_per_unit = 2)

limits!(ax, rect)
save(joinpath(plotsdir(), "range_meta_tiling", "3-1.png"), fig; px_per_unit = 2)

strategy = FixedGridTiling(36, 36)

c, s, _si = RangeExtractor.split_ranges_into_tiles(strategy, [range], [nothing])

tile_ranges = RangeExtractor.tile_to_ranges.((strategy,), keys(s))

range2rect(range) = begin
    ext = GI.extent(earth_ras[(x -> first(x):last(x)+1).(range)...,])
    Rect2f(ext.X[1], ext.Y[1], ext.X[2] - ext.X[1], ext.Y[2] - ext.Y[1])
end

tilepoly = poly!(ax, range2rect.(tile_ranges); color = (:blue, 0.3), strokecolor = (:blue, 0.5), strokewidth = 1)

push!(legenditems, tilepoly)
push!(legendlabels, "Tiles")

delete!(leg)
leg = Legend(fig[2, 1], legenditems, legendlabels; nbanks = 2, orientation = :horizontal, tellheight = true, tellwidth = false)

fig

save(joinpath(plotsdir(), "range_meta_tiling", "4.png"), fig; px_per_unit = 2)

using GADM
ohio = GADM.get("USA", "Ohio"; depth = 0) |> GI.getfeature |> only |> GI.geometry
mass = GADM.get("USA", "Massachusetts"; depth = 0) |> GI.getfeature |> only |> GI.geometry
maine = GADM.get("USA", "Maine"; depth = 0) |> GI.getfeature |> only |> GI.geometry
texas = GADM.get("USA", "Texas"; depth = 0) |> GI.getfeature |> only |> GI.geometry

usaplot.visible[] = false
statesplot = poly!(ax, [texas, mass, maine, ohio]; color = (:red, 0.3), strokecolor = (:red, 0.5), strokewidth = 1)

fig

save(joinpath(plotsdir(), "range_meta_tiling", "5.png"), fig; px_per_unit = 2)

limits!(ax, -180, 180, -90, 90)

fig

save(joinpath(plotsdir(), "range_meta_tiling", "6.png"), fig; px_per_unit = 2)

statesplot.visible[] = false

poly!(ax, GADM.get("USA"; depth = 0) |> GI.getfeature |> only |> GI.geometry; color = (:red, 0.3), strokecolor = (:red, 0.5), strokewidth = 1)

fig

save(joinpath(plotsdir(), "range_meta_tiling", "7.png"), fig; px_per_unit = 2)


