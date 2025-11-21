module JitEngine

using SymbolicUtils
using SymbolicUtils.Rewriters
using Symbolics
using Symbolics: value, scalarize, is_array_of_symbolics, unwrap
using ModelingToolkit
using PrecompileTools: @setup_workload, @compile_workload

export compile_func, compile_ode, compile_jac, compile_func_vectorized

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
include("symtable.jl")
include("builder.jl")
include("lowering.jl")
include("peephole.jl")
include("codegen.jl")

include("memory.jl")
include("inspector.jl")
include("engine.jl")

@setup_workload begin
    @variables x y t β
    u = [0.0, 1.0]
    du = zeros(2)
    J = zeros(2, 2)
    @compile_workload begin
        f = compile_func([x, y], [x+y, x*y])
        f(2, 3)
        f = compile_func([x, y], [x-y, x/y, x%y])
        f(10, 3)
        f = compile_func((x, y) -> asin(sin(x)) + exp(log(x+y)) + x^y)
        f(0.5, 2)
        f = compile_ode(t, [x, y], [β*y, -β*x]; params = [β])
        f(du, u, [2.0], 0.0)
        f = compile_jac(t, [x, y], [β*y, -β*x]; params = [β])
        f(J, u, [2.0], 0.0)
    end
end

end
