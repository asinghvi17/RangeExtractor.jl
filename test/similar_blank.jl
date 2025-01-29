using Test, TestItems

@testitem "similar_blank for regular arrays" tags=[:Utils] begin
    using RangeExtractor: similar_blank
    # Test with regular Array
    arr = rand(10, 10)
    blank = similar_blank(arr)
    @test size(blank) == size(arr)
    @test eltype(blank) == eltype(arr)
    @test all(iszero, blank)
end

@testitem "similar_blank for different types" tags=[:Utils] begin
    using RangeExtractor: similar_blank
    # Test with different types
    arr_int = ones(Int, 5, 5)
    blank_int = similar_blank(arr_int)
    @test size(blank_int) == size(arr_int)
    @test eltype(blank_int) == Int
    @test all(iszero, blank_int)
end

@testitem "similar_blank for 3D arrays" tags=[:Utils] begin
    using RangeExtractor: similar_blank
    # Test with 3D array
    arr_3d = rand(4, 4, 4)
    blank_3d = similar_blank(arr_3d)
    @test size(blank_3d) == size(arr_3d)
    @test eltype(blank_3d) == eltype(arr_3d)
    @test all(iszero, blank_3d)
end

@testitem "similar_blank for Rasters, no missing" tags=[:Utils, :Rasters] begin
    using RangeExtractor: similar_blank
    using Rasters

    # Test with Raster without missing values
    data = rand(10, 10)
    raster = Raster(data, (X, Y))
    blank_raster = similar_blank(raster)
    @test size(blank_raster) == size(raster)
    @test eltype(blank_raster) == eltype(raster)
    @test all(iszero, blank_raster)
end

@testitem "similar_blank for Rasters, with missing" tags=[:Utils, :Rasters] begin
    using RangeExtractor: similar_blank
    using Rasters

    # Test with Raster with missing values
    data_missing = Array{Union{Float64, Missing}}(undef, 5, 5)
    fill!(data_missing, missing)
    raster_missing = Raster(data_missing, (X, Y))
    blank_raster_missing = similar_blank(raster_missing)
    @test size(blank_raster_missing) == size(raster_missing)
    @test eltype(blank_raster_missing) == eltype(raster_missing)
    @test all(ismissing, blank_raster_missing)
end
