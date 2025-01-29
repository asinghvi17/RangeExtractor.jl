module RangeExtractorRastersExt

using RangeExtractor
using Rasters

function similar_blank(array::AbstractRaster)
    new = similar(array)
    new.data .= Rasters.missingval(array)
    return new
end

include("threadsafe_arrays.jl")
include("zonal.jl")

end # module