struct AbstractExecutionOrder end

struct ArbitraryOrder <: AbstractExecutionOrder end

struct PrecomputedOrder{T} <: AbstractExecutionOrder
    order::Vector{T}
end

# return a vector of tile indices
function (order::AbstractExecutionOrder)(contained, shared, shared_inverse)
    error("Not implemented yet for order $order!")
end

function (order::ArbitraryOrder)(contained, shared, shared_inverse)
    return unique(Iterators.flatten(keys.((contained, shared))))
end

function (order::PrecomputedOrder{T})(contained, shared, shared_inverse) where T
    return order.order
end


function ranges_tiles_order(order::AbstractExecutionOrder, strategy::S, ranges::AbstractVector{<: NTuple{N, AbstractRange}}, metadata::MetadataType) where {N, S <: TilingStrategy, MetadataType}
    contained, shared, shared_inverse = split_ranges_into_tiles(strategy, ranges, metadata)
    order_vec = order(contained, shared, shared_inverse)
    return contained, shared, shared_inverse, order_vec
end


