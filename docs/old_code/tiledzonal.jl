# This file contains the original code that spawned this package, which was 
# a function that performed zonal statistics on tiles of a raster.


using TiledIteration, ChunkSplitters
using GeoInterface, Extents

using CairoMakie

function Makie.convert_arguments(plt::Type{<: Makie.Poly}, extent::Extents.Extent)
    return (Rect2{Float64}(extent.X[1], extent.Y[1], extent.X[2] - extent.X[1], extent.Y[2] - extent.Y[1]),)
end


"""
    abstract type TilingStrategy

Abstract type for tiling strategies.  Must hold all necessary information to create a tiling strategy.
"""
abstract type TilingStrategy end

"""
    FixedGridTiling(chunk_sizes...)

Tiles a domain into a fixed grid of chunks. 

Geometries that are fully encompassed by a tile are processed in bulk whenever a tile is read.

Geometries that lie on chunk boundaries are added to a separate queue, and whenever a tile is read, 
the view on the tile representing the chunk of that geometry that lies within the tile is added to a queue.  These views are combined by a separate worker task,
and once all the information on a geometry has been read, it is processed by a second worker task.

However, this approach could potentially change.  If we know the statistic is separable and associative (like a histogram with fixed bins, or `mean`, `min`, `max`, etc.),
we could simply process the partial geometries in the same task that reads the tile, and recombine at the end.   This would allow us to avoid the (cognitive) overhead of 
managing separate channels and worker tasks.  But it would be a bit less efficient and less general over the space of zonal functions.  It would, however, allow massive zonals - so eg 
"""
struct FixedGridTiling{N} <: TilingStrategy 
    tilesize::NTuple{N, Int}
end

FixedGridTiling{N}(tilesize::Int) where N = FixedGridTiling{N}(ntuple(_ -> tilesize, N))

function get_tile_indices(tiling::FixedGridTiling{N}, raster::Rasters.DD.DimArrayOrStack, geom) where N
    ext = GI.extent(geom)
    native_indices = Rasters.DD.dims2indices(raster, ext)
    tile_indices = ntuple(N) do i
        get_range_of_multiples(native_indices[i], tiling.tilesize[i])
    end
    return tile_indices
end

function tile_to_ranges(tiling::FixedGridTiling{N}, raster::Rasters.DD.DimArrayOrStack, tile_index::CartesianIndex{N}) where N
    ranges_to_request = ntuple(N) do i
        start_idx = (tile_index[i] - 1) * tiling.tilesize[i] + 1
        stop_idx = min(start_idx + tiling.tilesize[i] - 1, size(raster, i))
        return start_idx:stop_idx
    end
    return ranges_to_request
end

function get_range_of_multiples(range, factor)
    start = floor(Int, (first(range) - 1)/factor) + 1 # account for 1 based indexing
    stop = floor(Int, (last(range) - 1)/factor) + 1 # account for 1 based indexing

    if stop < start
        tmp = start
        start = stop
        stop = tmp
    end

    return UnitRange(start, stop)
end


function split_geometries_into_tiles(tiling::FixedGridTiling{N}, raster::Rasters.DD.DimArrayOrStack, geoms; progress = true) where N
    progress && (prog = Progress(length(geoms); desc = "Sorting geometries into tiles"))
    single_tile_geoms = Dict{CartesianIndex{N}, Vector{Int}}()
    multi_tile_geoms = Dict{CartesianIndex{N}, Vector{Int}}()
    multi_tile_geoms_indices = Dict{Int, CartesianIndices{N, Tuple{Vararg{UnitRange{Int}, N}}}}()


    for (geom_idx, geom) in enumerate(geoms)
        tile_indices = get_tile_indices(tiling, raster, geom)
        # If the geometry spans multiple tiles, add it to the multi_tile_geoms dictionary
        if any(x -> length(x) > 1, tile_indices)
            current_indices = CartesianIndices(tile_indices)
            multi_tile_geoms_indices[geom_idx] = current_indices
            for current_index in current_indices
                vec = get!(() -> Vector{Int}(), multi_tile_geoms, current_index)
                push!(vec, geom_idx)
            end
        else
            # If the geometry spans a single tile, add it to the single_tile_geoms dictionary
            vec = get!(() -> Vector{Int}(), single_tile_geoms, CartesianIndex(only.(tile_indices)))
            push!(vec, geom_idx)
        end
        progress && next!(prog)
    end

    return single_tile_geoms, multi_tile_geoms, multi_tile_geoms_indices
end

function zonal_on_tile(f, tile_idx::CartesianIndex, tile::Raster, geoms::Vector, inside_geoms::Vector{Int}, shared_geoms::Vector{Int}, shared_read_channel::Channel{<: Pair{<: Pair{Int, <: CartesianIndex}, <: Raster}}; progressmeter = nothing, zonal_kwargs...)
    # assuming file has been read
    # first, read the extents of the shared geometries, and post them to the main Channel
    for geom_idx in shared_geoms
        put!(shared_read_channel, (geom_idx => tile_idx) => read(crop(tile, to = GI.extent(geoms[geom_idx]), touches = false)))
    end

    # then, process the inside geometries
    result_vec = zonal(f, tile; of = view(geoms, inside_geoms), threaded = false, progress = false, zonal_kwargs...)

    isnothing(progressmeter) || update!(progressmeter, length(inside_geoms))

    return (inside_geoms, result_vec)
end

using DimensionalData, DimensionalData.Lookups
function _get_raw_overlap_ranges(main_raster, sub_raster)
    # WARNING: this function ASSUMES that the rasters are axis aligned and that the sub_raster is a subregion of the main_raster
    # Furthermore this will only work with regular and irregular lookup types
    return map(dims(sub_raster)) do dim
        main_range = lookup(main_raster, dim)
        sub_range = lookup(sub_raster, dim)

        @assert isordered(main_range)
        @assert isordered(sub_range)
        @assert !isexplicit(main_range)
        @assert !isexplicit(sub_range)

        
        first_sub_val = first(sub_range)
        last_sub_val = last(sub_range)

        if length(main_range) == length(sub_range)
            return rebuild(dim, 1:length(sub_range))
        end

        if !isreverse(main_range)
            # first_sub_val -= 2Rasters.maybe_eps(first_sub_val; grow=true)
            # last_sub_val += 2Rasters.maybe_eps(last_sub_val; grow=true)
            
            sub_range_start = searchsortedfirst(val(main_range), first_sub_val)
            sub_range_stop = searchsortedlast(val(main_range), last_sub_val)
        else
            # first_sub_val += 2Rasters.maybe_eps(first_sub_val; grow=true)
            # last_sub_val -= 2Rasters.maybe_eps(last_sub_val; grow=true)
            
            sub_range_start = searchsortedfirst(val(main_range), first_sub_val; rev = true)
            sub_range_stop = searchsortedlast(val(main_range), last_sub_val; rev = true)
        end
        
        sub_range_start = max(1, sub_range_start)
        # sub_range_stop = min(min(length(main_range), length(sub_range)), sub_range_stop)
        
        return rebuild(dim, sub_range_start:sub_range_stop)
    end
end

function shared_geom_raster_collector(tiling::FixedGridTiling{N}, raster, geoms, multi_tile_read_dict::Dict, shared_read_channel::Channel{<: Pair{<: Pair{Int, <: CartesianIndex}, <: Raster}}, shared_zonal_channel::Channel{<: Pair{Int, <: Raster}}) where N

    for item in shared_read_channel
        (geom_idx, tile_idx), sub_raster = item

        geom_raster, written_indices = get!(multi_tile_read_dict, geom_idx) do 
            # create zero raster with the dims of the raster necessary
            (zero(crop(raster, to = GI.extent(geoms[geom_idx]))), CartesianIndex{N}[])
        end
        
        # Assign the loaded values to the existing raster
        # We are already guaranteed axis alignment and the correct ordering
        # since both lhs and rhs are views of the same parent.
        geom_view = view(geom_raster, _get_raw_overlap_ranges(geom_raster, sub_raster)...)

        try
            # WARNING: this will ONLY work if crop is lazy
            geom_view .= parent(sub_raster)
        catch e
            @warn "Error filling raster with sub-raster info"
            overlap_ranges = _get_raw_overlap_ranges(geom_raster, sub_raster)
            @show overlap_ranges size(sub_raster) size(geom_view) size(crop(sub_raster, to = geom_view))
            # show(stderr, e)
            @exfiltrate
            rethrow(e)
        end
        push!(written_indices, tile_idx)

        if issetequal(written_indices, multi_tile_read_dict[geom_idx][2]) # this means that all the necessary indices have been read
            # send the result off to the zonal worker to do processing
            put!(shared_zonal_channel, geom_idx => geom_raster)
            # delete!(multi_tile_read_dict, geom_idx)
        end
    end

    @debug "Shared raster collector finished"
end

function shared_geom_zonal_worker(f, shared_zonal_channel::Channel{<: Pair{Int, <: Raster}}; progressmeter = nothing, zonal_kwargs...)
    shared_results = Dict{Int, Any}()
    for item in shared_zonal_channel
        geom_idx, geom_raster = item
        result = zonal(f, geom_raster; of = geoms[geom_idx], threaded = false, progress = false, zonal_kwargs...)
        shared_results[geom_idx] = result
        !isnothing(progressmeter) && next!(progressmeter)
    end
    @debug "Shared zonal worker finished"
    return shared_results
end

function tiledzonal(f::F, raster, tiling::FixedGridTiling{2}; of = nothing, geometrycolumn = first(GeoInterface.geometrycolumns(of)), zonal_kwargs...) where F
# f = minimum
# raster = dem
# tiling = FixedGridTiling{2}(2915)
# of = glaciers[1:100, :]
# geometrycolumn = first(GeoInterface.geometrycolumns(of))
# zonal_kwargs = (; skipmissing = true)
    # Extract geometries from the input
    geoms = Rasters._get_geometries(of, geometrycolumn)

    # Split the geometries into tiles and extract those geometries that span multiple tiles
    # This returns three dictionaries.  They are structured as (tile_index => [geometry_indices], tile_index => [geometry_indices], geometry_index => [tile_indices] respectively).
    single_tile_geoms, multi_tile_geoms, multi_tile_geoms_indices = split_geometries_into_tiles(tiling, raster, geoms; progress = false)
    multi_tile_read_dict = Dict{Int, Tuple{Raster, Vector{CartesianIndex{2}}}}()

    # Set up channels for the multi-tile geometries
    _ZERO_RASTER_TYPE = typeof(zero(view(raster, X(1:1), Y(1:1))))

    multi_tile_read_channel = Channel{Pair{Pair{Int, CartesianIndex{2}}, _ZERO_RASTER_TYPE}}(Inf) # This channel should be infinitely large, since there's no guarantee we read all the 
    multi_tile_zonal_channel = Channel{Pair{Int, _ZERO_RASTER_TYPE}}(500)


    progressmeter = Progress(length(geoms); desc = "Computing statistics on geometries", showspeed = true)

    # Set up the workers for these channels
    multi_tile_read_worker = Threads.@spawn :default shared_geom_raster_collector($tiling, $raster, $geoms, $multi_tile_read_dict, $multi_tile_read_channel, $multi_tile_zonal_channel)
    multi_tile_zonal_worker = Threads.@spawn :default shared_geom_zonal_worker($f, $multi_tile_zonal_channel; progressmeter, $zonal_kwargs...)

    # Now, set up the task based iteration over the tiled geometries
    tile_keys = collect(keys(single_tile_geoms))
    tile_tasks = map(tile_keys) do key
        # Note: we interpolate everything except the `read` statement, 
        # since that is going to be run on the thread itself...
        Threads.@spawn :default zonal_on_tile(
            $f, 
            $key,
            read(view(raster, $(tile_to_ranges(tiling, raster, key))...)), 
            $geoms, 
            $single_tile_geoms[key], 
            $(get(multi_tile_geoms, key, Int[])), 
            $multi_tile_read_channel; 
            $progressmeter, 
            zonal_kwargs...
        )
    end

    # Fetch the results of the tasks
    @time tile_task_results = fetch.(tile_tasks)

    yield()
    # If there were any tiles that were not loaded (because no geometry was fully encompassed by the tile),
    # we load them here.
    non_loaded_multi_tiles = setdiff(keys(multi_tile_geoms), keys(single_tile_geoms))

    final_multi_tile_tasks = map(collect(non_loaded_multi_tiles)) do tile_idx
        Threads.@spawn :default begin
            tile = read(view($raster, $(tile_to_ranges(tiling, raster, tile_idx))...))
            shared_geoms = $(multi_tile_geoms[tile_idx])
            for geom_idx in shared_geoms
                put!($multi_tile_read_channel, (geom_idx => $tile_idx) => read(view(tile, GI.extent($(geoms)[geom_idx])))) # reading is good since it can free up memory potentially
            end
        end
    end

    wait.(final_multi_tile_tasks)

    close(multi_tile_read_channel)
    wait(multi_tile_read_worker)

    close(multi_tile_zonal_channel)

    multi_tile_geom_results = fetch(multi_tile_zonal_worker)


    return (tile_task_results, multi_tile_geom_results)
end


@time tiledzonal(identity, dem, FixedGridTiling{2}(2915); of = glaciers[1:100, :], skipmissing = true)







struct STRTreeTiling{T} <: TilingStrategy
    nodecapacity::Int
    predicate_function::T
end

function STRTreeTiling(; nodecapacity::Int = 3, memory_limit::Int = 1_000, predicate_function::T = is_extent_suitable) where T
    STRTreeTiling{T}(nodecapacity, predicate_function)
end



# Try a simple example of why the multi-tile geom loading might be failing

ext = Extent(X = (2.5, 7.0), Y = (2.0, 7.0))

using Rasters, RasterDataSources, ArchGDAL
using TiledIteration # easy splitting into tiles

# dem = Raster(WorldClim{Climate}, :tmin, month = 1)
ras = read(view(dem, 1:10, 1:10))

ext = Extent(X=(lookup(ras, X)[2], lookup(ras, X)[7]), Y=(lookup(ras, Y)[7], lookup(ras, Y)[2]))

view(ras, ext)

tile_ranges = collect(TiledIteration.TileIterator(axes(ras), (5, 5)))
ras_tiles = (inds -> ras[inds...]).(tile_ranges)

sub_tiles = read.(view.(ras_tiles, (ext,)))

crop(new_ras, to = sub_tiles[1])


sub_tiles[1] .= 1
sub_tiles[2] .= 2
sub_tiles[3] .= 3
sub_tiles[4] .= 4

new_ras = zero(view(ras, ext))

new_ras[DimSelectors(sub_tiles[1]; selectors = At)] .= sub_tiles[1]
new_ras[DimSelectors(sub_tiles[2]; selectors = At)] .= sub_tiles[2]
new_ras[DimSelectors(sub_tiles[3]; selectors = At)] .= sub_tiles[3]
new_ras[DimSelectors(sub_tiles[4]; selectors = At)] .= sub_tiles[4]

new_ras

crop(new_ras, to = sub_tiles[1])


f