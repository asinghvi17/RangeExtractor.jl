# RangeExtractor

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://asinghvi17.github.io/RangeExtractor.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://asinghvi17.github.io/RangeExtractor.jl/dev/)
[![Build Status](https://github.com/asinghvi17/RangeExtractor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/asinghvi17/RangeExtractor.jl/actions/workflows/CI.yml?query=branch%3Amain)

**RangeExtractor.jl** is a package for efficiently extracting and operating on subsets of large (out-of-memory) arrays, and is optimized for use with arrays that have very high load time.

<img src="https://github.com/user-attachments/assets/468c8d99-407f-427a-a4d0-94fd232b86d7" height=400/>


## Installation

```julia
using Pkg
Pkg.add("RangeExtractor")

using RangeExtractor
```

## Quick Start
```julia
using RangeExtractor

# Create sample array
array = ones(20, 20)

# Define regions of interest, as ranges of indices.
# RangeExtractor only accepts tuples of unit ranges.
ranges = [
    (1:4, 1:4),
    (9:20, 11:20),
    (1:15, 11:20),
    (11:20, 1:10)
]

# Define tiling scheme (10x10 tiles)
tiling_strategy = FixedGridTiling{2}(10)

# Extract results, by invoking `extract` with:
# - a function that takes an array and returns some value.
# - a `do` block, which is a convenient way to provide an anonymous function.
# - a `TileOperation`, which is a more flexible way to provide an operation.
# here, we use a `do` block to sum the values in each range.
results = extract(array, ranges; strategy = tiling_strategy) do A
    sum(A)
end
```

## Key features

- Multi-threaded, asynchronous processing: extract data from multiple tiles in parallel, and apply the operation to each tile in parallel.
- Split computations efficiently across tiles, choose whether to materialize the whole range requested or reduce sections by some intermediate product.
- Flexible tiling schemes: define your own tiling scheme that encodes your knowledge of the data.
- Completely flexible operations.

RangeExtractor.jl also integrates with Rasters.jl, so you can call `Rasters.zonal(f, raster, strategy; of = geoms, ...)` to use RangeExtractor to accelerate your zonal computations.

## Generic to any Array

RangeExtractor.jl is designed to be generic to any array type, as long as it supports AbstractArray-like indexing.  

Here's an example of using RangeExtractor.jl to calculate zonal statistics on a raster dataset, using a custom operation.  This is faster single-threaded than Rasters.jl is multithreaded, since it can split computation a

```julia
using RangeExtractor
using Rasters, ArchGDAL
using RasterDataSources, NaturalEarth
import GeoInterface as GI

# Load raster dataset
ras = Raster(WorldClim{Climate}, :tmin, month=1)

# Get country polygons
countries = naturalearth("admin_0_countries", 10)

# Convert extents to index ranges
ranges = Rasters.dims2indices.((ras,), Rasters.Touches.(GI.extent.(countries.geometry)))

# Define tiling scheme
strategy = FixedGridTiling{2}(100)

# Define zonal statistics operation.  
# Here, we use a `TileOperation` to define a fully custom operation.
# - `contained` is applied to each range that is fully contained within a tile,
#   and returns the final result for that range.
# - `shared` is applied to each range that is partially contained or shared with another tile,
#   and returns some intermediate result that is stored.
# - `combine` is applied to the results of all the `shared` operations for a range,
#   and returns the final result for that range.
op = TileOperation(
    contained = (x, meta) -> zonal(sum, x; of=meta),
    shared = (x, meta) -> zonal(sum, x; of=meta),
    combine = (results, args...) -> sum(results)
)

# Calculate zonal statistics
results = RangeExtractor.extract(
    op,                  # the operation to perform
    ras,                 # the raster to extract from
    ranges,              # the ranges to extract
    countries.geometry;  # the "metadata" - in this case, the polygons to calculate zonal statistics over
    strategy = strategy  # the tiling strategy to use
)
```

## Similar approaches elsewhere

- `exactextract` in R and Python has a somewhat similar strategy for operating on large, out-of-memory rasters, but it is forced to keep all vector statistics materialized in memory.  See https://isciences.github.io/exactextract/performance.html#the-raster-sequential-strategy.  It does not support multithreading, or flexible user-defined operations.

## Acknowledgements

This effort was funded by the NASA MEaSUREs program in contribution to the Inter-mission Time Series of Land Ice Velocity and Elevation (ITS_LIVE) project (https://its-live.jpl.nasa.gov/).

