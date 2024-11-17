module RangeExtractor

using TimerOutputs
const to = TimerOutput()

using DocStringExtensions, ProgressMeter

include("strategy/abstract.jl")
include("strategy/fixedgrid.jl")
include("strategy/rtree.jl")

include("state.jl")
include("utils.jl")

include("operators/abstract.jl")
include("operators/generic.jl")
include("operators/recombining.jl")
include("operators/sum.jl")

# include("extractor.jl")
include("extractor/extractor.jl")
include("extractor/allocate_result.jl")
include("extractor/serial.jl")
include("extractor/asyncsinglethreaded.jl")
include("extractor/multithreaded.jl")

export extract

end
