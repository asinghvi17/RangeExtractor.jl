using GeoDataFrames
using GLMakie, Tyler, Animations, Interpolations, DataInterpolations

using RangeExtractor
using Rasters, ArchGDAL
using NaturalEarth
import GeoInterface as GI, GeometryOps as GO, LibGEOS as LG

function forcexy(geom)
    return GO.apply(GO.GI.PointTrait(), geom) do point
        (GI.x(point), GI.y(point))
    end
end

rgi_path = "/Users/singhvi/Downloads/RGI2000-v7.0-G-global"

if !isfile(joinpath(rgi_path, "RGI2000-v7.0-G-global.gpkg"))
    @info "Collecting all RGI shapefiles into one geopackage, this might take a few minutes..."
    tables = [GeoDataFrames.read(joinpath(f, basename(f) * ".shp")) for f in Iterators.filter(isdir, readdir(rgi_path; join = true))]

    final_table = vcat(tables...) |> forcexy

    GeoDataFrames.write(joinpath(rgi_path, "RGI2000-v7.0-G-global.gpkg"), final_table)
else
    final_table = GeoDataFrames.read(joinpath(rgi_path, "RGI2000-v7.0-G-global.gpkg"))
end


# poly(final_table.geometry |> forcexy)

polytable = Rasters.rasterize(
    sum, final_table; 
    boundary = :touches, 
    fill = 1, 
    missingval = 0, 
    size = (16000, 16000),
    threaded = true,
)

using GeoMakie

f1, a1, bg1 = lines(GeoMakie.coastlines(); color = :gray60, alpha = 0.2)
translate!(bg1, 0, 0, 10)
hm1 = heatmap!(a1, extrema(dims(polytable, X)), extrema(dims(polytable, Y)), Resampler(polytable))
hm1.colormap = :ice
# hm1.alpha = 0.3

import Rasters: Projected, Intervals, Start
available_tiles = Raster(zeros(360, 180); missingval = 0.0, dims = (X(Projected(-180:179; sampling = Intervals(Start()), crs = EPSG(4326))), Y(Projected(-90:89; sampling = Intervals(Start()), crs = EPSG(4326)))))

import RangeExtractor: split_ranges_into_tiles

c, s, _si = split_ranges_into_tiles(FixedGridTiling{2}(1), Rasters.DD.dims2indices.((available_tiles,), Touches.(GI.extent.(final_table.geometry))))

for (idx, vals) in c
    available_tiles[idx] += length(vals)
end

shared_tiles = zero(available_tiles)

for (idx, vals) in s
    shared_tiles[idx] += length(vals)
end

using Extents

high_mtn_asia_geoms = filter(final_table.geometry) do geom
    Extents.intersects(GI.extent(geom), Extents.Extent(X = (69, 78), Y = (32, 37)))
end

f, a, p = heatmap(available_tiles + shared_tiles; colormap = :viridis, alpha = 0.6);
cb = Colorbar(f[1, 2], p; label = "Number of glaciers in tile")
display(GLMakie.Screen(), f)
# now, add the high mountain asia glaciers to the plot
p2 = poly!(high_mtn_asia_geoms; color = :transparent, strokecolor = :red)
p2.strokewidth = 1


using Tyler

m_elev = Tyler.Map(Extent(X = (-180, 180), Y = (-80, 80)); provider=Tyler.ElevationProvider(nothing));
display(GLMakie.Screen(), m_elev.figure)

hma_wmerc = GO.reproject(high_mtn_asia_geoms, EPSG(4326), EPSG(3857))

map_poly_plot = poly!(m_elev.axis, hma_wmerc; color = :transparent, strokecolor = :red)
map_poly_plot.strokewidth = 1