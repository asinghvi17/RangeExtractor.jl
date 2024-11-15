#=
# Extractor API

This file contains the main API for the extractor.  
=#

const _THREADED_DEFAULT = Static.StaticBool(false)

"""
    extract([f], data, ranges, [metadata]; strategy, threaded)


Passing a function `f` is more memory-efficient and faster, since the processing is done immediately as data is extracted, and the result is (usually) a lot smaller than the whole array!
"""
function extract(data::AbstractArray, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::Union{AbstractVector, Nothing} = nothing; strategy = reasonable_strategy(array), threaded = _THREADED_DEFAULT, kwargs...) where N
    return extract(identity, data, ranges, metadata; strategy, threaded, kwargs...)
end

function extract(f, data::AbstractArray, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::Union{AbstractVector, Nothing} = nothing; strategy = reasonable_strategy(array), threaded = _THREADED_DEFAULT, kwargs...) where N
    operator = RecombiningTileOperation(f)
    return extract(operator, data, ranges, metadata; strategy, threaded, kwargs...)
end

function extract(operator::AbstractTileOperation, data::AbstractArray, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::Union{AbstractVector, Nothing} = nothing; strategy = reasonable_strategy(array), threaded = _THREADED_DEFAULT, kwargs...) where N
    # Figure out `eltype(result)` based on `operator` and `data`,
    # and then allocate a result array of that type.
    # TODO: allow missings
    result, _n_skip = allocate_result(operator, data, ranges, metadata, strategy)
    return extract!(operator, result, data, ranges, metadata; strategy, threaded, _n_skip, kwargs...)
end


"""
    extract!([f], dest, data, ranges, [metadata]; strategy, threaded)
"""
function extract!(dest::AbstractVector, data::AbstractArray, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::Union{AbstractVector, Nothing} = nothing; strategy = reasonable_strategy(array), threaded = _THREADED_DEFAULT, _n_skip = 0, kwargs...) where N
    return extract!(identity, dest, data, ranges, metadata; strategy, threaded, _n_skip, kwargs...)
end

function extract!(f, dest::AbstractVector, data::AbstractArray, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::Union{AbstractVector, Nothing} = nothing; strategy = reasonable_strategy(array), threaded = _THREADED_DEFAULT, _n_skip = 0, kwargs...) where N
    operator = RecombiningTileOperation(f)
    return extract!(operator, dest, data, ranges, metadata; strategy, threaded, _n_skip, kwargs...)
end

function extract!(operator::AbstractTileOperation, dest::AbstractVector, data::AbstractArray, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::Union{AbstractVector, Nothing} = nothing; strategy = reasonable_strategy(array), threaded = _THREADED_DEFAULT, _n_skip = 0, kwargs...) where N
    threaded = Static.StaticBool(threaded)
    # The implementations of `_extract!` lie in `extractor/serial.jl` and `extractor/parallel.jl`.
    # More implementations (Dagger, etc) will be added in the future, so we want to support those too!
    return _extract!(threaded, operator, dest, data, ranges, metadata; strategy, _n_skip, kwargs...)
end
