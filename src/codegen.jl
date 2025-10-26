θ(x) = Int(value(x))    # phyiscal register number

rules_gen_amd = [
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
    @rule binop(~dst, :rem, ~x, ~y) => Amd.fmod(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :lt, ~x, ~y) => Amd.vcmpltsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :leq, ~x, ~y) => Amd.vcmplesd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :gt, ~x, ~y) => Amd.vcmpnlesd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :geq, ~x, ~y) => Amd.vcmpnltsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :eq, ~x, ~y) => Amd.vcmpeqsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :neq, ~x, ~y) => Amd.vcmpneqsd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :and, ~x, ~y) => Amd.vandpd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :or, ~x, ~y) => Amd.vorpd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :xor, ~x, ~y) => Amd.vxorpd(θ(~dst), θ(~x), θ(~y))
    @rule uniop(~dst, :neg, ~x) => Amd.neg(θ(~dst), θ(~x))
    @rule uniop(~dst, :not, ~x) => Amd.not(θ(~dst), θ(~x))
    @rule uniop(~dst, :square, ~x) => Amd.square(θ(~dst), θ(~x))
    @rule uniop(~dst, :cube, ~x) => Amd.cube(θ(~dst), θ(~x))
    @rule uniop(~dst, :sqrt, ~x) => Amd.vsqrtsd(θ(~dst), θ(~x))
    @rule uniop(~dst, powi(~p), ~x) => Amd.powi(θ(~dst), θ(~x), ~p)
    @rule ternary(~dst, ~cond, ~x, ~y) =>
        Amd.select_if(θ(~dst), θ(~cond), θ(~x), θ(~y))
    @rule call_func(~op) => Amd.call_op(~op)
]

rules_gen_arm = [
    @rule load(~dst, mem(~idx)) => Arm.load_mem(θ(~dst), θ(~idx))
    @rule load(~dst, param(~idx)) => Arm.load_param(θ(~dst), θ(~idx))
    @rule load(~dst, stack(~idx)) => Arm.load_stack(θ(~dst), θ(~idx))
    @rule load_const(~dst, ~val, ~idx) => Arm.load_const(θ(~dst), θ(~idx))
    @rule save(mem(~idx), ~src) => Arm.save_mem(θ(~src), θ(~idx))
    @rule save(stack(~idx), ~src) => Arm.save_stack(θ(~src), θ(~idx))
    @rule mov(~dst, ~x) => Arm.fmov(θ(~dst), θ(~x))
    @rule binop(~dst, :plus, ~x, ~y) => Arm.fadd(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :times, ~x, ~y) => Arm.fmul(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :minus, ~x, ~y) => Arm.fsub(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :divide, ~x, ~y) => Arm.fdiv(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :rem, ~x, ~y) => Amd.fmod(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :lt, ~x, ~y) => Arm.fcmlt(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :leq, ~x, ~y) => Arm.fcmle(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :gt, ~x, ~y) => Arm.fcmgt(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :geq, ~x, ~y) => Arm.fcmge(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :eq, ~x, ~y) => Arm.fcmeq(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :neq, ~x, ~y) => Arm.fcmne(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :and, ~x, ~y) => Arm.and(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :or, ~x, ~y) => Arm.orr(θ(~dst), θ(~x), θ(~y))
    @rule binop(~dst, :xor, ~x, ~y) => Arm.eor(θ(~dst), θ(~x), θ(~y))
    @rule uniop(~dst, :neg, ~x) => Arm.neg(θ(~dst), θ(~x))
    @rule uniop(~dst, :not, ~x) => Arm.not(θ(~dst), θ(~x))
    @rule uniop(~dst, :square, ~x) => Arm.square(θ(~dst), θ(~x))
    @rule uniop(~dst, :cube, ~x) => Arm.cube(θ(~dst), θ(~x))
    @rule uniop(~dst, :sqrt, ~x) => Arm.fsqrt(θ(~dst), θ(~x))
    @rule uniop(~dst, powi(~p), ~x) => Arm.powi(θ(~dst), θ(~x), ~p)
    @rule ternary(~dst, ~cond, ~x, ~y) =>
        Arm.select_if(θ(~dst), θ(~cond), θ(~x), θ(~y))
    @rule call_func(~op) => Arm.call_op(~op)
]

function apply_gen(x)
    if Sys.ARCH == :x86_64
        rules = rules_gen_amd
    elseif Sys.ARCH == :aarch64
        rules = rules_gen_arm
    end

    for r in rules
        y = r(x)
        if y != nothing
            return y
        end
    end
    error("unrecognized instruction: $x")
end

function generate(builder::Builder, mir::MIR)
    saved = list_registers_to_save(builder, mir)

    Cpu.reset()
    Cpu.prologue(builder.count_temps)

    for (reg, loc) in saved
        apply_gen(save(loc, reg))
    end

    for t in mir.ir
        apply_gen(t)
    end

    for (reg, loc) in saved
        apply_gen(load(reg, loc))
    end

    Cpu.epilogue(builder.count_temps)

    Cpu.align()

    for (idx, val) in enumerate(mir.constants)
        Cpu.add_const(idx, val)
    end

    for (f, p) in mir.vt
        Cpu.add_func(f, p)
    end

    Cpu.seal()

    return Cpu.bytes()
end

function list_registers_to_save(builder::Builder, mir::MIR)
    saved = []

    for i = CLOBBERED_REGS:LOGICAL_REGS
        if i in mir.used_regs
            push!(saved, (i, stack(builder.count_temps)))
            builder.count_temps += 1
        end
    end

    return saved
end
