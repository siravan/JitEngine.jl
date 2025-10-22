module JitEngine

using SymbolicUtils
using SymbolicUtils.Rewriters
using Symbolics
using Symbolics: value

module Amd
include("assembler.jl")
include("amd.jl")
end

using .Amd

const COUNT_SCRATCH = 14
const SPILL_AREA = 16

include("code.jl")
include("builder.jl")
include("lowering.jl")
include("codegen.jl")

include("memory.jl")
include("inspector.jl")
include("engine.jl")

function generate_func(states, obs; params=nothing)
    builder = build(states, obs; params)
    mir = lower(builder)
    substitute_registers!(builder, mir)
    code = generate(builder, mir)
    return code
end

end
