rules_extract = [
    @rule load(~dst, ~x) => (~dst, ω, ω, ω)
    @rule load_const(~dst, ~x, ~idx) => (~dst, ω, ω, ω)
    @rule load_indexed(~dst, ~x) => (~dst, ω, ω, ω)
    @rule save(~x, ~r1) => (ω, ~r1, ω, ω)
    @rule save_indexed(~x, ~r1) => (ω, ~r1, ω, ω)
    @rule uniop(~dst, ~op, ~r1) => (~dst, ~r1, ω, ω)
    @rule binop(~dst, ~op, ~r1, ~r2) => (~dst, ~r1, ~r2, ω)
    @rule ternary(~dst, ~r1, ~r2, ~r3) => (~dst, ~r1, ~r2, ~r3)
    @rule call_func(~op) => (σ0, ω, ω, ω)
    @rule mov(~dst, ~r1) => (~dst, ~r1, ω, ω)
    @rule set_label(~label) => (ω, ω, ω, ω)
    @rule branch_if(~limit, ~label) => (ω, ω, ω, ω)
    @rule reset_index() => (ω, ω, ω, ω)
    @rule inc_index() => (ω, ω, ω, ω)
    @rule matmul(~dst, ~r1, ~r2, ~shape) => (ω, ω, ω, ω)
    @rule set_adjoint(~dst, ~r1, ~shape) => (ω, ω, ω, ω)
]

apply_extract(eq) = Chain(rules_extract)(value(eq))

function allocate(mir::MIR)
    # registers 0 and 1 have special meanings and
    # are excluded from the pool
    pool = (1 << LOGICAL_REGS - 1) & ~3

    regs = Dict{Any,Int}()
    regs[σ0] = 0
    regs[σ1] = 1
    S = Set([σ0, σ1, ω])

    for t in mir.ir
        dst, r1, r2, r3 = apply_extract(t)

        if !(r1 in S)
            pool |= 1 << regs[r1]
        end

        if !(r2 in S)
            pool |= 1 << regs[r2]
        end

        if !(r3 in S)
            pool |= 1 << regs[r3]
        end

        if dst in S
            continue
        end

        if haskey(regs, dst)
            error("double allocation!")
        end

        if pool == 0
            error("no available free register")
        end

        d = trailing_zeros(pool)
        regs[dst] = d
        pool &= ~(1 << d)
    end

    return regs
end

function substitute_registers!(builder::Builder, mir::MIR)
    regs = allocate(mir)
    subs = Dict(v => y.loc for (v, y) in builder.syms.vars)
    subs = merge(regs, subs)

    ir = []

    for i = 1:length(mir.ir)
        push!(ir, substitute(mir.ir[i], subs))
    end

    mir.ir = ir
    mir.used_regs = unique(values(regs))
end
