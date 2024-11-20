using Shapefile, ZipFile, GeoDataFrames, DataFrames

import GeometryOps as GO

include("tilearray.jl")

rgi_path = "/Users/singhvi/Downloads/RGI2000-v7.0-G-global/RGI2000-v7.0-G-17_southern_andes/RGI2000-v7.0-G-17_southern_andes.shp"

rgi_df = GeoDataFrames.read(rgi_path)

poly(rgi_df.geometry[1] |> forcexy)

r1 = Rasters.Raster(Tyler.ElevationProvider(nothing), 10)

rgi_webmerc = GO.reproject(rgi_df, EPSG(4326), EPSG(3857)) |> forcexy

r1[Touches(GI.extent(rgi_webmerc.geometry[4242]))][:,:] #|> heatmap


using NaturalEarth
all_countries = NaturalEarth.naturalearth("admin_0_countries", 10)

r1 = Rasters.Raster(TileProviders.Esri(:WorldImagery), 6)

zonal(mean, r1, FixedGridTiling{2}(256); of = all_countries |> x -> GO.reproject(x, EPSG(4326), EPSG(3857)) |> forcexy)