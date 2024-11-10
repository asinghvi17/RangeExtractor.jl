using TiledExtractor
using Test

if !haskey(ENV, "RASTERDATASOURES_PATH")
    ENV["RASTERDATASOURES_PATH"] = mktempdir()
end

@testset "TiledExtractor.jl" begin
    @testset "Correctness" include("correctness.jl")
end
