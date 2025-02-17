import GeometryOps as GO
import GeoInterface as GI


# # Get the data
using GeoDataFrames, DataFrames

tab1 = GeoDataFrames.read("/Users/anshul/Downloads/glims_download_45040/glims_polygons.shp")
tab2 = GeoDataFrames.read("/Users/anshul/Downloads/glims_download_74931/glims_polygons.shp")

final_table = filter(:line_type => ==("glac_bound"), vcat(tab1, tab2)) |> GO.forcexy
# The 


using RangeExtractor, FHist

op = TileOperation(;
    contained = fit

)