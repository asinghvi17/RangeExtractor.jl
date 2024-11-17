using Test, TestItems

@testsnippet SimpleArray begin
    # Create a simple test array
    arr = ones(20, 20)
end

@testitem "FixedGridTiling basic properties" setup=[SimpleArray] tags=[:TilingSchemes] begin
    using RangeExtractor: FixedGridTiling, get_tiles

    # Test construction
    tiling = FixedGridTiling{2}(10)
    @test tiling.tile_size == 10

    # Test tile generation
    tiles = get_tiles(arr, tiling)
    
    # Should create 4 tiles for 20x20 array with 10x10 tiles
    @test length(tiles) == 4
    
    # Check tile ranges
    expected_ranges = [
        (1:10, 1:10),    # Top left
        (11:20, 1:10),   # Top right  
        (1:10, 11:20),   # Bottom left
        (11:20, 11:20)   # Bottom right
    ]
    
    @test Set(tiles) == Set(expected_ranges)
end

@testitem "FixedGridTiling with uneven dimensions" setup=[SimpleArray] tags=[:TilingSchemes] begin
    using RangeExtractor: FixedGridTiling, get_tiles
    
    # Create array with dimensions not divisible by tile size
    uneven_arr = ones(25, 15)
    tiling = FixedGridTiling{2}(10)
    
    tiles = get_tiles(uneven_arr, tiling)
    
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
    
    @test Set(tiles) == Set(expected_ranges)
end

@testitem "FixedGridTiling 3D" tags=[:TilingSchemes] begin
    using RangeExtractor: FixedGridTiling, get_tiles
    
    # Create 3D array
    arr3d = ones(15, 15, 15)
    tiling = FixedGridTiling{3}(10)
    
    tiles = get_tiles(arr3d, tiling)
    
    # Should create 8 tiles (2x2x2)
    @test length(tiles) == 8
    
    # Test a few example tiles
    @test (1:10, 1:10, 1:10) in tiles     # First corner
    @test (11:15, 11:15, 11:15) in tiles  # Opposite corner
end
