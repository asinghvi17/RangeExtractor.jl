var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"","category":"page"},{"location":"api/","page":"API","title":"API","text":"Modules = [TiledExtractor]","category":"page"},{"location":"api/#TiledExtractor.FixedGridTiling","page":"API","title":"TiledExtractor.FixedGridTiling","text":"FixedGridTiling(chunk_sizes...)\n\nTiles a domain into a fixed grid of chunks. \n\nGeometries that are fully encompassed by a tile are processed in bulk whenever a tile is read.\n\nGeometries that lie on chunk boundaries are added to a separate queue, and whenever a tile is read,  the view on the tile representing the chunk of that geometry that lies within the tile is added to a queue.  These views are combined by a separate worker task, and once all the information on a geometry has been read, it is processed by a second worker task.\n\nHowever, this approach could potentially change.  If we know the statistic is separable and associative (like a histogram with fixed bins, or mean, min, max, etc.), we could simply process the partial geometries in the same task that reads the tile, and recombine at the end.   This would allow us to avoid the (cognitive) overhead of  managing separate channels and worker tasks.  But it would be a bit less efficient and less general over the space of zonal functions.  It would, however, allow massive zonals - so eg \n\n\n\n\n\n","category":"type"},{"location":"api/#TiledExtractor.TileOperation","page":"API","title":"TiledExtractor.TileOperation","text":"TileOperation(; contained, shared)\nTileOperation(operation)\n\nCreate a tile operation that can operate on a TileState and return a tuple of results from the contained and shared ranges.\n\nArguments\n\ncontained: Function to apply to contained (non-overlapping) regions\nshared: Function to apply to shared (overlapping) regions\n\nExamples\n\n# Different functions for contained and shared regions\nop = TileOperation(\n    contained = (data, meta) -> mean(data),\n    shared = (data, meta) -> sum(data)\n)\n\n# Same function for both\nop = TileOperation((data, meta) -> mean(data))\n\n\n\n\n\n","category":"type"},{"location":"api/#TiledExtractor.TileState","page":"API","title":"TiledExtractor.TileState","text":"TileState{N, TileType, RowVecType}\nTileState(tile::TileType, tile_offset::CartesianIndex{N}, contained_rows::AbstractVector, shared_rows::AbstractVector)\n\nA struct that holds all the state that is local to a single tile.\n\nFields\n\ntile: The read data of the tile.\ntile_ranges: The ranges that the tile covers in the parent array\ncontained_ranges: The ranges of the rows that are fully contained in the tile\nshared_ranges: The ranges of the rows that are only partially contained in the tile, i.e shared with other tiles\ncontained_metadata: The rows that are fully contained in the tile\nshared_metadata: The rows that are only partially contained in the tile, i.e shared with other tiles\n\n\n\n\n\n","category":"type"},{"location":"api/#TiledExtractor.TilingStrategy","page":"API","title":"TiledExtractor.TilingStrategy","text":"abstract type TilingStrategy\n\nAbstract type for tiling strategies.  Must hold all necessary information to create a tiling strategy.\n\nAll tiling strategies MUST implement the following methods:\n\nindextype(::Type{<: TilingStrategy}): Return the type of the index used by the tiling strategy.  For example, FixedGridTiling returns CartesianIndex{N}.\nget_tile_indices(tiling, range): Given a range, return the indices of the tiles that the range intersects.\ntile_to_ranges(tiling, index): Given a tile index, return the ranges that the tile covers.\nsplit_ranges_into_tiles(tiling, ranges): Given a set of ranges, return three dictionaries:\nA dictionary mapping tile indices to the indices of the ranges that the tile fully contains (Ints).\nA dictionary mapping tile indices to the indices of the ranges that the tile shares with one or more other ranges (Ints).\nA dictionary mapping the indices of the shared ranges (Ints) to the tile indices that contain them.\n\n\n\n\n\n","category":"type"},{"location":"api/#TiledExtractor._nothing_or_view-Tuple{Any, Any}","page":"API","title":"TiledExtractor._nothing_or_view","text":"_nothing_or_view(x, idx)\n\nReturn view(x, idx) if x is not nothing, otherwise return nothing.\n\nThis is made so that we can have metadata=nothing, and have it still work with broadcast.\n\n\n\n\n\n","category":"method"},{"location":"api/#TiledExtractor.crop_ranges_to_array-Union{Tuple{T}, Tuple{N}, Tuple{AbstractArray{T, N}, NTuple{N, var\"#s2\"} where var\"#s2\"<:AbstractUnitRange}} where {N, T}","page":"API","title":"TiledExtractor.crop_ranges_to_array","text":"crop_ranges_to_array(array, ranges)\n\nCrop the ranges (a Tuple of AbstractUnitRange) to the axes of array.\n\nThis uses intersect internally to crop the ranges.  \n\nReturns a Tuple of AbstractUnitRange, that have been  cropped to the axes of array.\n\n\n\n\n\n","category":"method"},{"location":"api/#TiledExtractor.extract","page":"API","title":"TiledExtractor.extract","text":"extract(array, ranges, metadata=nothing; operation::TileOperation, combine, tiling_scheme::TilingStrategy, threaded = true)\n\nExtract statistics from an array by tiling it into chunks and processing each chunk separately.\n\nThis function splits the input array into tiles according to the provided tiling scheme, and processes each tile independently. For regions that are fully contained within a tile, the operation is applied directly. For regions that span multiple tiles, the partial results are combined using the provided combine function.\n\nArguments\n\nMandatory positional arguments:\n\narray: The input array to process\nranges: A vector of tuples of ranges specifying regions to process\n\nMandatory keyword arguments:\n\noperation::TileOperation: A TileOperation specifying how to process contained and shared regions\ncombine: Function to combine results from shared regions across tiles\ntiling_scheme::TilingStrategy: Strategy for splitting the array into tiles\n\nOptional positional argument:\n\nmetadata=nothing: Optional metadata associated with each range\n\n(this is at the last position right before the keyword arguments)\n\nOptional keyword arguments:\n\nthreaded=Static.True(): Whether to process tiles in parallel\n\nExamples\n\nBasic array operations:\n\nExamples\n\nSimple usage:\n\nusing TiledExtractor\n\n# Create a 2D array\narray = ones(20, 20)\n\n# Define ranges of interest\nranges = [\n    (1:4, 1:4),\n    (9:20, 11:20),\n    (1:15, 11:20),\n    (11:20, 1:10)\n]\n\n# Define a tiling scheme (tiles of size 10x10)\ntiling_scheme = FixedGridTiling{2}(10)\n\n# Define the operation to perform on each tile\nop = TileOperation(\n    (x, meta) -> sum(x),  # For regions fully contained in a tile\n    (x, meta) -> sum(x)   # For regions that span multiple tiles\n)\n\n# Define a combine function for shared regions\ncombine_func = sum\n\n# Extract the results\nresults = extract(array, ranges; operation=op, combine=combine_func, tiling_scheme=tiling_scheme)\n\nprintln(results)  # Outputs the sums over the specified ranges\n\nWith Rasters.jl\n\nNote that this example uses TiledExtractor directly.  In the near future we will integrate with Rasters.jl to allow cleaner syntax.\n\nusing TiledExtractor\nusing Rasters, RasterDataSources\nusing NaturalEarth  # For country geometries\nimport GeoInterface  # For accessing extents of geometries\n\n# Load a raster dataset (e.g., WorldClim minimum temperature for January)\nras = Raster(WorldClim{Climate}, :tmin, month=1)\n\n# Load country polygons from NaturalEarth at 1:10 million scale\nall_countries = naturalearth(\"admin_0_countries\", 10)\n\n# Get the extents of each country geometry\nextents = GeoInterface.extent.(all_countries.geometry)\n\n# Convert extents to index ranges over the raster\nranges = Rasters.dims2indices.((ras,), Touches.(extents))\n\n# Define the tiling scheme (tiles of size 100x100)\ntiling_scheme = FixedGridTiling{2}(100)\n\n# Define the operation to perform on each tile\nop = TileOperation(\n    # For regions fully contained in a tile\n    (x, meta) -> zonal(sum, x; of=meta, boundary=:touches, progress=false, threaded=false),\n    # For regions that span multiple tiles\n    (x, meta) -> zonal(sum, x; of=meta, boundary=:touches, progress=false, threaded=false)\n)\n\n# Define a combine function for shared regions\ncombine_func = sum\n\n# Extract the zonal sums for each country\nresults = extract(ras, ranges, all_countries.geometry; operation=op, combine=combine_func, tiling_scheme=tiling_scheme)\n\n# Compare to a non-tiled approach\nnon_tiled_results = zonal(sum, ras; of=all_countries.geometry, boundary=:touches, progress=false, threaded=false)\n\nresults ≈ non_tiled_results # true\n\n@show results\n\n\n\n\n\n","category":"function"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = TiledExtractor","category":"page"},{"location":"#TiledExtractor","page":"Home","title":"TiledExtractor","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for TiledExtractor.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [TiledExtractor]","category":"page"},{"location":"devdocs/#Developer-Documentation","page":"Developer Documentation","title":"Developer Documentation","text":"","category":"section"},{"location":"devdocs/#Testing","page":"Developer Documentation","title":"Testing","text":"","category":"section"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"This package uses TestItems.jl, a testing framework that allows structuring tests into individual, independent @testitem blocks that can be run independently.","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"TestItems.jl integrates with both VSCode and the command line, making it easy to write and run tests during development.","category":"page"},{"location":"devdocs/#Running-Tests","page":"Developer Documentation","title":"Running Tests","text":"","category":"section"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"To run all tests, simply run Pkg.test(\"TiledExtractor\") from the Julia REPL.","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"To run a subset of tests, you can use TestItemRunner.jl to filter tests.  Here's an example from the TestItems.jl documentation:","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"using TestItemRunner\n@run_package_tests filter=ti->( !(:skipci in ti.tags) && endswith(ti.filename, \"test_foo.jl\") )","category":"page"},{"location":"devdocs/#Adding-New-Tests","page":"Developer Documentation","title":"Adding New Tests","text":"","category":"section"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"Tests can be added to any file in the test directory by creating a new @testitem block. For example:","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"@testitem \"My Test\" tags=[:Demo] begin\n    # Test code here\n    @test 1 + 1 == 2\n    @test 2 + 2 != 5\n\n    using Statistics\n\n    @test mean([1, 2, 3]) == 2\nend","category":"page"},{"location":"devdocs/","page":"Developer Documentation","title":"Developer Documentation","text":"Note that @testitem blocks ought to be self-contained, so all usings should lie within the block.  using Test, TileExtractor is executed by default by TestItems.jl, so you don't need to include it in your test.","category":"page"}]
}