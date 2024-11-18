using Test, TestItems

@testsnippet SimpleArray begin
    # Create a simple test array
    arr = ones(20, 20)
end

@testitem "FixedGridTiling basic properties" setup=[SimpleArray] tags=[:TilingSchemes] begin
    using RangeExtractor: FixedGridTiling, get_tile_indices

    # Test construction
    tiling = FixedGridTiling{2}(10)
    @test tiling.tilesize == (10, 10)

    # Test tile generation
    tiles = CartesianIndices(get_tile_indices(tiling, axes(arr)))
    
    # Should create 4 tiles for 20x20 array with 10x10 tiles
    @test length(tiles) == 4
    
    # Check tile ranges
    expected_ranges = [
        (1:10, 1:10),    # Top left
        (11:20, 1:10),   # Top right  
        (1:10, 11:20),   # Bottom left
        (11:20, 11:20)   # Bottom right
    ]

    computed_ranges = [tile_to_ranges(tiling, tile) for tile in tiles]
    
    @test issetequal(computed_ranges, expected_ranges)
end

@testitem "FixedGridTiling with uneven dimensions" setup=[SimpleArray] tags=[:TilingSchemes] begin
    using RangeExtractor: FixedGridTiling, get_tiles
    
    # Create array with dimensions not divisible by tile size
    uneven_arr = ones(25, 15)
    tiling = FixedGridTiling{2}(10)
    
    tiles = CartesianIndices(get_tile_indices(tiling, axes(uneven_arr)))
    
    # Should create 6 tiles (3 rows x 2 columns)
    @test length(tiles) == 6
    
    expected_ranges = [
        (1:10, 1:10),    # Top left
        (11:20, 1:10),   # Top middle
        (21:25, 1:10),   # Top right
        (1:10, 11:15),   # Bottom left
        (11:20, 11:15),  # Bottom middle
        (21:25, 11:15)   # Bottom right
    ]
    
    computed_ranges = [tile_to_ranges(tiling, tile) for tile in tiles]
    
    @test issetequal(computed_ranges, expected_ranges)
end

@testitem "FixedGridTiling 3D" tags=[:TilingSchemes] begin
    using RangeExtractor: FixedGridTiling, get_tile_indices, tile_to_ranges
    
    # Create 3D array
    arr3d = ones(15, 15, 15)
    tiling = FixedGridTiling{3}(10)
    
    tiles = CartesianIndices(get_tile_indices(tiling, axes(arr3d)))
    
    # Should create 8 tiles (2x2x2)
    @test length(tiles) == 8

    computed_ranges = [RangeExtractor.relevant_range_from_tile_origin(axes(arr3d), tile_to_ranges(tiling, tile)) for tile in tiles]
    
    # Test a few example tiles
    @test (1:10, 1:10, 1:10) in computed_ranges     # First corner
    @test (11:15, 11:15, 11:15) in computed_ranges  # Opposite corner
end
