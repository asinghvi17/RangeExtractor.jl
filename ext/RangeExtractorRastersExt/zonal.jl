#=
# Zonal override


=#
import Rasters: zonal
import RangeExtractor: AbstractTileOperation, combine

# A callable struct that calls `zonal` with the provided kwargs.
# kind of like a version of a hypothetical `FixKW` but specific to zonal.
struct ZonalLambda{F}
    f::F
    # zonal options
    boundary::Symbol
    shape::Union{Symbol, Nothing}
    skipmissing::Bool
    bylayer::Bool
end
# this function definition makes the struct "callable"
function (op::ZonalLambda)(data, geometry)
    zonal(op.f, data; of = geometry, boundary = op.boundary, skipmissing = op.skipmissing, shape = op.shape, bylayer = op.bylayer, progress = false, threaded = false)
end

# Now, we override `zonal` iff the user provides a tiling strategy.
function Rasters.zonal(f, data::Union{Rasters.AbstractRaster, Rasters.AbstractRasterStack, Rasters.AbstractRasterSeries}, strategy::TilingStrategy; of = nothing, geometrycolumn = nothing, boundary = :center, shape = nothing, skipmissing = true, bylayer = true, kwargs...)
    # create a callable struct that will call `zonal` with the provided kwargs
    callable = ZonalLambda(f, boundary, shape, skipmissing, bylayer)
    # construct a RecombiningTileOperation
    operation = RecombiningTileOperation(callable)
    zonal(operation, data, strategy; of = of, geometrycolumn = geometrycolumn, boundary = boundary, shape = shape, skipmissing = skipmissing, bylayer = bylayer, kwargs...)
end

# TODO: should this mask before passing data to the operation?
# Currently it doesn't.
function Rasters.zonal(operation::AbstractTileOperation, data::Union{Rasters.AbstractRaster, Rasters.AbstractRasterStack, Rasters.AbstractRasterSeries}, strategy::TilingStrategy; of = nothing, geometrycolumn = nothing, boundary = :center, shape = nothing, skipmissing = true, bylayer = true, kwargs...)
    # now, construct the ranges from the geometries
    geoms = Rasters._get_geometries(of, geometrycolumn)
    extents = Rasters.GeoInterface.extent.(geoms)
    ranges = Rasters.dims2indices.((data,), Rasters.Touches.(extents))

    # call `extract` with the recombining tile operation
    # TODO: call alloc_zonal to get an array, that can be passed to extract!
    # thus making the inner extract loop somewhat type stable.

    result = RangeExtractor.extract(
        operation, 
        data, ranges, geoms; # be sure to pass the geometries as metadata.
        strategy,
        kwargs...
    ) .|> identity

    return result
end