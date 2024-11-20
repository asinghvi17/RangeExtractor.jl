var documenterSearchIndex = {"docs":
[{"location":"tilingstrategy/#Tiling-Strategies","page":"Tiling Strategies","title":"Tiling Strategies","text":"","category":"section"},{"location":"tilingstrategy/","page":"Tiling Strategies","title":"Tiling Strategies","text":"RangeExtractor allows you to configure how the extract function handles tiling by passing a tiling strategy.  A tiling strategy must:","category":"page"},{"location":"tilingstrategy/","page":"Tiling Strategies","title":"Tiling Strategies","text":"subtype AbstractTilingStrategy","category":"page"},{"location":"tilingstrategy/","page":"Tiling Strategies","title":"Tiling Strategies","text":"A tiling strategy splits the input ranges into tiles.  The simplest strategy is to use a fixed grid.  But you can also use an R-tree formulation via SpatialIndexing.jl.","category":"page"},{"location":"tilingstrategy/#Tile-visiting-strategies","page":"Tiling Strategies","title":"Tile visiting strategies","text":"","category":"section"},{"location":"tilingstrategy/","page":"Tiling Strategies","title":"Tiling Strategies","text":"In general, you may want to minimize or maximize the number of I/O overlaps.  So you can visit tiles in a specific order.  You could, for example, use Graphs.jl to find which tiles connect to each other, or are connected via shared ranges, and iterate over them so as to minimize the amount of time that intermediate data for those shared ranges is held in memory.","category":"page"},{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"","category":"page"},{"location":"api/","page":"API","title":"API","text":"Modules = [RangeExtractor]","category":"page"},{"location":"api/#RangeExtractor.AbstractTileOperation","page":"API","title":"RangeExtractor.AbstractTileOperation","text":"AbstractTileOperation\n\nAbstract type for tile operations, which are callable structs that can operate on a TileState.\n\nInterface\n\nAll subtypes of AbstractTileOperation MUST implement the following interface:\n\n(op::AbstractTileOperation)(state::TileState): Apply the operation to the given tile state.  Return a tuple of (containedresults, sharedresults).  The order of the results MUST be the same as the order of the indices in state.contained_ranges and state.shared_ranges.\ncombine(op::AbstractTileOperation, range, metadata, results, tile_idxs): Combine the outputs from the portions of the shared ranges, and return the final result.\n\nOptionally, subtypes can implement the following methods:\n\n(op::AbstractTileOperation)(state::TileState, contained_channel, shared_channel): Apply the operation to the given tile state, and write output to the specified channels. Output to both of the channels must be in the form (tile_idx, result_idx) => result, where tile_idx is the index of the tile in the TileState, and result_idx is the index of the result in the contained_ranges or shared_ranges of the TileState.\nThis interface is a bit more efficient, since it avoids the overhead of allocating intermediate arrays.  That can be useful to cut down on inference and GC overhead, especially when dealing with many tiles.\ncontained_result_type(::Type{<: AbstractTileOperation}, DataArrayType): Return the type of the results from the contained ranges.  Defaults to Any.\nshared_result_type(::Type{<: AbstractTileOperation}, DataArrayType): Return the type of the results from the shared ranges.  Defaults to Any.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.AsyncSingleThreaded","page":"API","title":"RangeExtractor.AsyncSingleThreaded","text":"AsyncSingleThreaded(; ntasks = 0)\n\nAsynchronous execution, but only using a single thread.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.Dagger","page":"API","title":"RangeExtractor.Dagger","text":"Dagger()\n\nDagger execution, using Dagger.jl's distributed execution.  Runs asynchronously.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.FixedGridTiling","page":"API","title":"RangeExtractor.FixedGridTiling","text":"FixedGridTiling(chunk_sizes...)\n\nTiles a domain into a fixed grid of chunks. \n\nGeometries that are fully encompassed by a tile are processed in bulk whenever a tile is read.\n\nGeometries that lie on chunk boundaries are added to a separate queue, and whenever a tile is read,  the view on the tile representing the chunk of that geometry that lies within the tile is added to a queue.  These views are combined by a separate worker task, and once all the information on a geometry has been read, it is processed by a second worker task.\n\nHowever, this approach could potentially change.  If we know the statistic is separable and associative (like a histogram with fixed bins, or mean, min, max, etc.), we could simply process the partial geometries in the same task that reads the tile, and recombine at the end.   This would allow us to avoid the (cognitive) overhead of  managing separate channels and worker tasks.  But it would be a bit less efficient and less general over the space of zonal functions.  It would, however, allow massive zonals - so eg \n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.Multithreaded","page":"API","title":"RangeExtractor.Multithreaded","text":"Multithreaded()\n\nMultithreaded execution, using all available threads.  Runs asynchronously.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.RecombiningTileOperation","page":"API","title":"RangeExtractor.RecombiningTileOperation","text":"RecombiningTileOperation(f)\n\nA tile operation that always passes f a fully materialized array over the requested range.\n\nContained ranges are instantly materialized and evaluated  when encountered; relevant sections of shared ranges are put  in the shared channel and set aside.  \n\nWhen all components of a shared range are read, then  f is called with the fully materialized array.\n\nHere, the combining function is simply an array mosaic.   There is no difference between shared and contained operations.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.Serial","page":"API","title":"RangeExtractor.Serial","text":"Serial()\n\nSerial execution, no asynchronicity at all.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.SumTileOperation","page":"API","title":"RangeExtractor.SumTileOperation","text":"SumTileOperation()\n\nAn operator that sums the values in each range.  \n\nThis can freely change the order of summation,  so results may not be floating-point accurate every time.  But they will be approximately accurate.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.TileOperation","page":"API","title":"RangeExtractor.TileOperation","text":"TileOperation(; contained, shared, combine)\nTileOperation(operation)\n\nCreate a tile operation that can operate on a TileState and return a tuple of results from the contained and shared ranges.\n\nIt calls the contained function on each contained range, and the shared function on each shared range.\n\ncontained and shared are called with the signature func(data, metadata), where data is a view of the tile data on the current range, and metadata is the metadata for that range.\n\ncombine is called with the signature combine(shared_results, shared_tile_idxs, metadata), where shared_results is an array of results from the shared function, shared_tile_idxs is an array of the tile indices that the shared results came from, and metadata is the metadata for that range.\n\nIf constructed with a single function, that function is used for both contained and shared operations.\n\nArguments\n\ncontained: Function to apply to contained (non-overlapping) regions\nshared: Function to apply to shared (overlapping) regions\n\nExamples\n\n# Different functions for contained and shared regions\nop = TileOperation(\n    contained = (data, meta) -> sum(data),\n    shared = (data, meta) -> sum(data),\n    combine = (x, _u, _w) -> sum(x)\n)\n\n# Same function for all three\nop = TileOperation((data, meta) -> mean(data))\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.TileState","page":"API","title":"RangeExtractor.TileState","text":"TileState{N, TileType, RowVecType}\nTileState(tile::TileType, tile_offset::CartesianIndex{N}, contained_rows::AbstractVector, shared_rows::AbstractVector)\n\nA struct that holds all the state that is local to a single tile.\n\nFields\n\ntile: The in-memory data of the tile.\ntile_ranges: The ranges that the tile covers in the parent array\ncontained_ranges: The ranges of the rows that are fully contained in the tile\nshared_ranges: The ranges of the rows that are only partially contained in the tile, i.e shared with other tiles\ncontained_metadata: The rows that are fully contained in the tile\nshared_metadata: The rows that are only partially contained in the tile, i.e shared with other tiles\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor.TilingStrategy","page":"API","title":"RangeExtractor.TilingStrategy","text":"abstract type TilingStrategy\n\nAbstract type for tiling strategies.  Must hold all necessary information to create a tiling strategy.\n\nAll tiling strategies MUST implement the following methods:\n\nindextype(::Type{<: TilingStrategy}): Return the type of the index used by the tiling strategy.  For example, FixedGridTiling returns CartesianIndex{N}.  RTreeTiling might return a single integer, that corresponds to the R-tree node id.\nget_tile_indices(tiling, range): Given a range, return the indices of the tiles that the range intersects.\ntile_to_ranges(tiling, index): Given a tile index, return the ranges that the tile covers.\nsplit_ranges_into_tiles(tiling, ranges): Given a set of ranges, return three dictionaries:\nA dictionary mapping tile indices to the indices of the ranges that the tile fully contains (Ints).\nA dictionary mapping tile indices to the indices of the ranges that the tile shares with one or more other ranges (Ints).\nA dictionary mapping the indices of the shared ranges (Ints) to the tile indices that contain them.\n\n\n\n\n\n","category":"type"},{"location":"api/#RangeExtractor._nothing_or_view-Tuple{Any, Any}","page":"API","title":"RangeExtractor._nothing_or_view","text":"_nothing_or_view(x, idx)\n\nReturn view(x, idx) if x is not nothing, otherwise return nothing.\n\nThis is made so that we can have metadata=nothing, and have it still work with broadcast.\n\n\n\n\n\n","category":"method"},{"location":"api/#RangeExtractor.allocate_result-NTuple{5, Any}","page":"API","title":"RangeExtractor.allocate_result","text":"allocate_result(operator, data, ranges, metadata, strategy)\n\nAllocate a result array for the given extraction operation. \n\nReturns a tuple of (allocated, nskip) where `nskip` is the number of ranges that should be skipped.\n\n\n\n\n\n","category":"method"},{"location":"api/#RangeExtractor.crop_ranges_to_array-Union{Tuple{T}, Tuple{N}, Tuple{AbstractArray{T, N}, NTuple{N, var\"#s19\"} where var\"#s19\"<:AbstractUnitRange}} where {N, T}","page":"API","title":"RangeExtractor.crop_ranges_to_array","text":"crop_ranges_to_array(array, ranges)\n\nCrop the ranges (a Tuple of AbstractUnitRange) to the axes of array.\n\nThis uses intersect internally to crop the ranges.  \n\nReturns a Tuple of AbstractUnitRange, that have been  cropped to the axes of array.\n\n\n\n\n\n","category":"method"},{"location":"api/#RangeExtractor.extract!-Union{Tuple{N}, Tuple{AbstractVector, AbstractArray, AbstractVector{<:NTuple{N, AbstractRange}}}, Tuple{AbstractVector, AbstractArray, AbstractVector{<:NTuple{N, AbstractRange}}, Union{Nothing, AbstractVector}}} where N","page":"API","title":"RangeExtractor.extract!","text":"extract!([f], dest, data, ranges, [metadata]; strategy, threaded)\n\n\n\n\n\n","category":"method"},{"location":"api/#RangeExtractor.extract-Union{Tuple{N}, Tuple{AbstractArray, AbstractVector{<:NTuple{N, AbstractRange}}}, Tuple{AbstractArray, AbstractVector{<:NTuple{N, AbstractRange}}, Union{Nothing, AbstractVector}}} where N","page":"API","title":"RangeExtractor.extract","text":"extract([f], data, ranges, [metadata]; strategy, threaded)\n\nPassing a function f is more memory-efficient and faster, since the processing is done immediately as data is extracted, and the result is (usually) a lot smaller than the whole array!\n\n\n\n\n\n","category":"method"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = RangeExtractor","category":"page"},{"location":"#RangeExtractor","page":"Home","title":"RangeExtractor","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for RangeExtractor.","category":"page"},{"location":"","page":"Home","title":"Home","text":"RangeExtractor is designed to efficiently process large arrays by splitting them into manageable tiles and performing operations on each tile independently. This approach is particularly useful when working with arrays that are too large to fit in memory, and for arrays where I/O is a bottleneck (e.g. S3 or cloud hosted arrays).","category":"page"},{"location":"#What's-happening?","page":"Home","title":"What's happening?","text":"","category":"section"},{"location":"#Inputs","page":"Home","title":"Inputs","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The user provides us three pieces of data: ","category":"page"},{"location":"","page":"Home","title":"Home","text":"data: the array in question, that we want to extract ranges from.\nranges: the ranges to extract from said array, as a vector of tuples of AbstractUnitRanges.\nmetadata: associated metadata for each element in ranges.","category":"page"},{"location":"","page":"Home","title":"Home","text":"and an operation, operation::AbstractTileOperation, which defines what to do with the data once you have it.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The user also provides some configuration structs:","category":"page"},{"location":"","page":"Home","title":"Home","text":"TilingStrategy: determines how to divide the array into tiles.  \nThis can be simple, naive, grid-based tiling (FixedGridTiling).\nCan also be tiled by a spatial index like an STR-tree or R-tree.\nTileOperation: defines how to process the data in each tile.  \nThere are two potential ways a range can interact with a tile: \nEither it is fully contained within the tile (contained), \nor it overlaps with the tile and also other tiles (shared).\nThe TileOperation determines how the data from each tile is combined to form the final result.\nThe most generic operation, TileOperation, allows maximal flexibility but can be slow on the compiler.   We provide specialized TileOperations like RecombiningTileOperation, which materializes each requested range into memory before applying the function.\nUsers are also free to implement their own tile operations, so long as they implement the AbstractTileOperation interface.","category":"page"},{"location":"","page":"Home","title":"Home","text":"In future, we plan to add tile iteration schemes, so that users can minimize memory or IO usage by defining a specific order to iterate over tiles.  This might involve graph algorithms or other strategies.","category":"page"},{"location":"#Processing","page":"Home","title":"Processing","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"First, we bin the ranges into tiles generated by the TilingStrategy.  This results in three dictionaries:","category":"page"},{"location":"","page":"Home","title":"Home","text":"contained_ranges: Tile → Ranges fully inside it.  Maps tile indices to indices in the ranges vector, that are fully contained within that tile, \nshared_ranges: Tile → Ranges that overlap it.  Maps tile indices to indices in the ranges vector, that overlap with that tile and also other tiles.\nshared_ranges_indices: Range → Tiles it overlaps with.  Maps indices in the ranges vector to the tile indices that they overlap with.  This is essentially the inverse mapping of shared_ranges.","category":"page"},{"location":"","page":"Home","title":"Home","text":"For each tile that has data that we want, we then read it into memory, and construct a TileState object.  This contains the tile data and index, the contained and shared ranges, and views of the metadata for those ranges.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Then, we apply the given TileOperation to that state.  This puts the data into a Channel, which we then drain by a supporting asynchronous task.  While Julia is waiting on IO, that can process the data so CPU power is maximally utilized.","category":"page"},{"location":"#Outputs","page":"Home","title":"Outputs","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Finally, we combine the results from each tile into a final result vector, and return it.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Shared tile results are usually eagerly combined to reduce memory strain.  All results are written to the vector in the correct fashion.","category":"page"},{"location":"","page":"Home","title":"Home","text":"tip: Tip\nFor a concrete example, refer to the README!","category":"page"},{"location":"devdocs/#Developer-Documentation","page":"Developer Documentation","title":"Developer Documentation","text":"","category":"section"},{"location":"devdocs/#Testing","page":"Developer Documentation","title":"Testing","text":"","category":"section"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"This package uses TestItems.jl, a testing framework that allows structuring tests into individual, independent @testitem blocks that can be run independently.","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"TestItems.jl integrates with both VSCode and the command line, making it easy to write and run tests during development.","category":"page"},{"location":"devdocs/#Running-Tests","page":"Developer Documentation","title":"Running Tests","text":"","category":"section"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"To run all tests, simply run Pkg.test(\"RangeExtractor\") from the Julia REPL.","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"To run a subset of tests, you can use TestItemRunner.jl to filter tests.  Here's an example from the TestItems.jl documentation:","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"using TestItemRunner\n@run_package_tests filter=ti->( !(:skipci in ti.tags) && endswith(ti.filename, \"test_foo.jl\") )","category":"page"},{"location":"devdocs/#Adding-New-Tests","page":"Developer Documentation","title":"Adding New Tests","text":"","category":"section"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"Tests can be added to any file in the test directory by creating a new @testitem block. For example:","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"@testitem \"My Test\" tags=[:Demo] begin\n    # Test code here\n    @test 1 + 1 == 2\n    @test 2 + 2 != 5\n\n    using Statistics\n\n    @test mean([1, 2, 3]) == 2\nend","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"Note that @testitem blocks ought to be self-contained, so all usings should lie within the block.  using Test, TileExtractor is executed by default by TestItems.jl, so you don't need to include it in your test.","category":"page"},{"location":"operations/#Operations","page":"Operations","title":"Operations","text":"","category":"section"},{"location":"operations/","page":"Operations","title":"Operations","text":"RangeExtractor allows you to configure what the extract function does by passing operators.  An operator must:","category":"page"},{"location":"operations/","page":"Operations","title":"Operations","text":"subtype AbstractTileOperator\nbe callable, and take a single argument that is a TileState\nreturn or do something with the tile state","category":"page"},{"location":"operations/","page":"Operations","title":"Operations","text":"This also ties in to the concept of contained and shared ranges.  Ranges that are fully contained within a tile are simply operated on and returned.  However, for ranges that are split between multiple tiles, there are a few options.","category":"page"},{"location":"operations/","page":"Operations","title":"Operations","text":"The simplest option is to store the subsections relevant to each range, combine them when all relevant tiles have been read, and then operate on the combined result.  This is the most flexible option, but it is very memory intensive.  Plus, if you're using extract to operate on a range that is larger than memory, you're out of luck.","category":"page"},{"location":"operations/","page":"Operations","title":"Operations","text":"Another option is to compute some intermediate value.  For example - if you are interested in the sum of all values within the range, you could sum up the values from each tile, and return the result.  This could be done in a AdditiveTileOperator that uses the same function to operate on each tile as well as to combine.","category":"page"},{"location":"operations/","page":"Operations","title":"Operations","text":"You can also write a specific operator for your use case, for example if you want to use Rasters.zonal, but need specific metadata handling and argument order, or keyword argument passthrough, you could create a ZonalTileOperator that holds all relevant state and can call Rasters.zonal with the correct arguments.","category":"page"}]
}
