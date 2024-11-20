using GLMakie, Tyler, Animations, Interpolations, DataInterpolations

using RangeExtractor
using Rasters, ArchGDAL
using NaturalEarth
import GeoInterface as GI, GeometryOps as GO, LibGEOS as LG

fig = Figure(size = (1600, 900))

ax = Axis(fig[1, 1]; aspect = DataAspect())

ax.title = "Glaciers around the world"

