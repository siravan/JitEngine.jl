module JitEngine

using SymbolicUtils
using SymbolicUtils.Rewriters
using Symbolics
using Symbolics: value
using ModelingToolkit

export compile_func, compile_ode, compile_jac

module Amd
@static if Sys.ARCH == :x86_64
    include("assembler.jl")
    include("amd/amd.jl")
end
end
using .Amd

module Arm
@static if Sys.ARCH == :aarch64
    include("assembler.jl")
    include("arm/arm.jl")
end
end
using .Arm

@static if Sys.ARCH == :x86_64
    Cpu = Amd

    if Sys.iswindows()
        const CLOBBERED_REGS = 6
    elseif Sys.isunix()
        const CLOBBERED_REGS = 16
    else
        const CLOBBERED_REGS = 16
        @warn "unrecognized os"
    end
elseif Sys.ARCH == :aarch64
    Cpu = Arm
    const CLOBBERED_REGS = 8
else
    const CLOBBERED_REGS = 16
    @warn "unrecognized architecture: $(Sys.ARCH)"
end

const LOGICAL_REGS = 16

include("mathlib.jl")
include("builder.jl")
include("lowering.jl")
include("peephole.jl")
include("codegen.jl")

include("memory.jl")
include("inspector.jl")
include("engine.jl")

end
