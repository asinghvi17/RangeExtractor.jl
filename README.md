# RangeExtractor

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://asinghvi17.github.io/RangeExtractor.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://asinghvi17.github.io/RangeExtractor.jl/dev/)
[![Build Status](https://github.com/asinghvi17/RangeExtractor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/asinghvi17/RangeExtractor.jl/actions/workflows/CI.yml?query=branch%3Amain)

**RangeExtractor.jl** is a package for efficiently extracting and operating on subsets of large (out-of-memory) arrays, and is optimized for use with arrays that have very high load time.

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

# Define regions of interest
ranges = [
    (1:4, 1:4),
    (9:20, 11:20),
    (1:15, 11:20),
    (11:20, 1:10)
]

# Define tiling scheme (10x10 tiles)
tiling_scheme = FixedGridTiling{2}(10)

# Define operation to perform on tiles
op = TileOperation(
    (x, meta) -> sum(x),  # For regions within a tile
    (x, meta) -> sum(x)   # For regions spanning tiles
)

# Extract results
results = extract(array, ranges; 
    operation = op,
    combine = sum,  # How to combine results across tiles
    tiling_scheme = tiling_scheme
)
```

## Key features

- Flexible tiling schemes: define your own tiling scheme that encodes your knowledge of the data.
- Multi-threaded, asynchronous processing: extract data from multiple tiles in parallel, and apply the operation to each tile in parallel.
- Split computations efficiently across tiles
- Completely flexible operations.

## Generic to any Array

```julia
using RangeExtractor
using Rasters, ArchGDAL
using RasterDataSources, NaturalEarth

# Load raster dataset
ras = Raster(WorldClim{Climate}, :tmin, month=1)

# Get country polygons
countries = naturalearth("admin_0_countries", 10)

# Convert extents to index ranges
ranges = Rasters.dims2indices.((ras,), Touches.(extents))

# Define tiling scheme
tiling_scheme = FixedGridTiling{2}(100)

# Define zonal statistics operation
op = TileOperation(
    (x, meta) -> zonal(sum, x; of=meta),
    (x, meta) -> zonal(sum, x; of=meta)
)

# Calculate zonal statistics
results = RangeExtractor.extract(ras, ranges, countries.geometry;
    operation = op,
    combine = sum,
    tiling_scheme = tiling_scheme
)
```

## Similar approaches elsewhere

- `exactextract` in R and Python does something similar, but it is forced to keep all vector statistics materialized in memory.  See https://isciences.github.io/exactextract/performance.html#the-raster-sequential-strategy.

## Acknowledgements

This effort was funded by the NASA MEaSUREs program in contribution to the Inter-mission Time Series of Land Ice Velocity and Elevation (ITS_LIVE) project (https://its-live.jpl.nasa.gov/).

