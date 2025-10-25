@syms Ω(x, y)

rules_peephole = [
    @rule Ω(load(~x, stack(~idx)), mov(~y, ~x)) => load(~y, stack(~idx))
    @rule Ω(load(~x, mem(~idx)), mov(~y, ~x)) => load(~y, mem(~idx))
    @rule Ω(save(stack(~idx), ~x), load(~y, stack(~idx))) => mov(~y, ~x)
    @rule Ω(mov(~y, ~x), save(stack(~idx), ~y)) => save(stack(~idx), ~x)
    @rule Ω(mov(~y, ~x), save(mem(~idx), ~y)) => save(mem(~idx), ~x)
    @rule Ω(mov(~y, ~x), mov(~z, ~y)) => mov(~z, ~x)
    @rule Ω(mov(~x, ~x), ~y) => ~y
]

function apply_peephole(t0, t1)
    x = Ω(t0, t1)

    for r in rules_peephole
        y = r(x)
        if y != nothing
            return y
        end
    end
    return nothing
end

function peephole!(mir)
    n = length(mir.ir)

    if n < 2
        return
    end

    p = Any[]
    push!(p, mir.ir[1])

    for i = 2:n
        t0 = pop!(p)
        t1 = mir.ir[i]

        t = apply_peephole(t0, t1)

        if t != nothing
            push!(p, t)
        else
            push!(p, t0)
            push!(p, t1)
        end
    end

    mir.ir = p
end
