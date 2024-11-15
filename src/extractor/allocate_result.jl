"""
    allocate_result(operator, data, ranges, metadata, strategy)

Allocate a result array for the given extraction operation. 

Returns a tuple of (allocated, n_skip) where `n_skip` is the number of ranges that should be skipped.
"""
function allocate_result(operator, data, ranges, metadata, strategy)
    return Vector{Any}(undef, length(ranges)), 0 
    # TODO: improve
    # improve by:
    # - for the zonal operator, we know the type of the result
    # - for a tileoperator with the eltype of identity, we know
    #   that the result is an array of type `typeof(copy(view(data, [1:1, 1:1])))`
    #   (for example in a 2d array)
end
