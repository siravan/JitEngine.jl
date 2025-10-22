θ(x) = Int(value(x))

rules_gen = [
    @rule load(~dst, mem(~idx)) => Amd.load_mem(θ(~dst), θ(~idx))
    @rule load(~dst, param(~idx)) => Amd.load_param(θ(~dst), θ(~idx))
    @rule load(~dst, stack(~idx)) => Amd.load_stack(θ(~dst), θ(~idx))
    @rule load_const(~dst, ~val, ~idx) => Amd.load_const(θ(~dst), θ(~idx))

    @rule save(mem(~idx), ~src) => Amd.save_mem(θ(~src), θ(~idx))
    @rule save(stack(~idx), ~src) => Amd.save_stack(θ(~src), θ(~idx))

    @rule mov(~dst, ~x) => Amd.fmov(θ(~dst), θ(~x))

    @rule binop(~dst, :plus, ~x, ~y) => Amd.vaddsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :times, ~x, ~y) => Amd.vmulsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :minus, ~x, ~y) => Amd.vsubsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :divide, ~x, ~y) => Amd.vdivsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :lt, ~x, ~y) => Amd.vcmpltsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :leq, ~x, ~y) => Amd.vcmplesd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :gt, ~x, ~y) => Amd.vcmpnlesd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :geq, ~x, ~y) => Amd.vcmpnltsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :eq, ~x, ~y) => Amd.vcmpeqsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :neq, ~x, ~y) => Amd.vcmpneqsd(θ(~dst), θ(~x), θ(~y))

    @rule uniop(~dst, :neg, ~x) => Amd.neg(θ(~dst), θ(~x))
    @rule uniop(~dst, :square, ~x) => Amd.square(θ(~dst), θ(~x))
    @rule uniop(~dst, :cube, ~x) => Amd.cube(θ(~dst), θ(~x))
    @rule uniop(~dst, :sqrt, ~x) => Amd.vsqrtsd(θ(~dst), θ(~x))

    @rule call_func(~op, ~idx) => Amd.call_op(~op)
]

apply_gen(eq) = Chain(rules_gen)(value(eq))

function generate(builder::Builder, mir::MIR)
    Amd.reset()

    cap = builder.count_temps
    Amd.prologue(cap)

    for t in mir.ir
        apply_gen(t)
    end

    Amd.epilogue(cap)

    Amd.align()

    for (idx, val) in enumerate(mir.constants)
        Amd.add_const(idx, val)
    end

    for (f, p) in mir.vt
        Amd.add_func(f, p)
    end

    Amd.seal()

    return Amd.bytes()
end
