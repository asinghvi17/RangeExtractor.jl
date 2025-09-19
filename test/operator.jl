using Test, TestItems 

@testsnippet IncreasingReshapedArray begin
    # Create a simple test array
    arr = reshape(1:100, 10, 10)
end

@testitem "Basic operation" setup=[IncreasingReshapedArray] tags=[:TileOperation] begin
    using Statistics
    using RangeExtractor: TileState, TileOperation
    
    # arr is defined in the IncreasingReshapedArray snippet as reshape(1:100, 10, 10)
    state = TileState(
        arr,
        (1:10, 1:10),
        [(1:5, 1:5)], # Contained ranges
        [(4:7, 4:7)], # Shared ranges
        [nothing],    # Contained metadata
        [nothing]     # Shared metadata
    )
    
    # Test operation that sums elements
    op = TileOperation(; 
        contained = (data, _) -> sum(data), 
        shared = (data, _) -> sum(data),
        combine = (x, useless...) -> sum(x))
    contained_results, shared_results = op(state)
    
    @test length(contained_results) == 1
    @test length(shared_results) == 1
    @test contained_results[1] == sum(arr[1:5, 1:5])
    @test shared_results[1] == sum(arr[4:7, 4:7])
end

@testitem "Different contained/shared functions" setup=[IncreasingReshapedArray] tags=[:TileOperation] begin
    using Statistics
    using RangeExtractor: TileState, TileOperation
    
    # arr is defined in the IncreasingReshapedArray snippet as reshape(1:100, 10, 10)
    state = TileState(
        arr,
        (1:10, 1:10),
        [(2:4, 2:4)],  # Contained ranges
        [(3:6, 3:6)],  # Shared ranges
        [nothing],     # Contained metadata
        [nothing]      # Shared metadata
    )
    
    op = TileOperation(
        contained = (data, _) -> mean(data),
        shared = (data, _) -> maximum(data),
        combine = vcat
    )
    
    contained_results, shared_results = op(state)
    
    @test length(contained_results) == 1
    @test length(shared_results) == 1
    @test contained_results[1] ≈ mean(arr[2:4, 2:4])
    @test shared_results[1] == maximum(arr[3:6, 3:6])
end

@testitem "Multiple ranges" setup=[IncreasingReshapedArray] tags=[:TileOperation] begin
    using Statistics
    using RangeExtractor: TileState, TileOperation
    
    # arr is defined in the IncreasingReshapedArray snippet as reshape(1:100, 10, 10)
    state = TileState(
        arr,
        (1:10, 1:10),
        [(1:3, 1:3), (5:7, 5:7)],      # Two contained ranges
        [(2:4, 2:4), (6:8, 6:8)],      # Two shared ranges
        [nothing, nothing],             # Contained metadata
        [nothing, nothing]              # Shared metadata
    )
    
    op = TileOperation(; contained = (data, _) -> sum(data), combine = vcat)
    contained_results, shared_results = op(state)
    
    @test length(contained_results) == 2
    @test length(shared_results) == 2
    @test contained_results[1] == sum(arr[1:3, 1:3])
    @test contained_results[2] == sum(arr[5:7, 5:7])
    @test shared_results[1] == sum(arr[2:4, 2:4])
    @test shared_results[2] == sum(arr[6:8, 6:8])
end

@testitem "Operation with metadata" setup=[IncreasingReshapedArray] tags=[:TileOperation] begin
    using Statistics
    using RangeExtractor: TileState, TileOperation
    
    # arr is defined in the IncreasingReshapedArray snippet as reshape(1:100, 10, 10)
    metadata = [2, 3]  # Multiplication factors
    state = TileState(
        arr,
        (1:10, 1:10),
        [(1:3, 1:3)],      # Contained range
        [(4:6, 4:6)],      # Shared range
        [2],               # Contained metadata
        [3]                # Shared metadata
    )
    
    op = TileOperation(; contained = (data, meta) -> sum(data) * meta, combine = vcat)
    contained_results, shared_results = op(state)
    
    @test contained_results[1] == sum(arr[1:3, 1:3]) * 2
    @test shared_results[1] == sum(arr[4:6, 4:6]) * 3
end
