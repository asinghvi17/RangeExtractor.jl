module RangeExtractorRastersExt

using RangeExtractor
using Rasters

function RangeExtractor.similar_blank(array::AbstractRaster)
    # Construct a new array of the same type as `array`,
    # backed by unclean memory.
    new = similar(array)

    # If the array doesn't have a missing value,
    # we can just fill it with zeros.
    fillval = isnothing(Rasters.missingval(array)) ? zero(eltype(array)) : Rasters.missingval(array)
    # Fill the new array with the fill value.   
    fill!(new, fillval)
    return new
end

include("threadsafe_arrays.jl")
include("zonal.jl")

end # module