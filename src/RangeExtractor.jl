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

include("extractor.jl")

export extract

end
