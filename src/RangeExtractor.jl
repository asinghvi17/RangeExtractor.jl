module RangeExtractor

using TimerOutputs
const to = TimerOutput()

using DocStringExtensions, ProgressMeter

include("state.jl")
include("utils.jl")

include("operators/abstract.jl")
include("operators/generic.jl")
include("operators/recombining.jl")

include("extractor.jl")

export extract

end
