rules_peephole = [
    @rule load(~x, stack(~idx)) + mov(~y, ~x) => load(~y, stack(~idx))
    @rule load(~x, mem(~idx)) + mov(~y, ~x) => load(~y, mem(~idx))
    @rule save(stack(~idx), ~x) + load(~y, stack(~idx)) => mov(~y, ~x)
    @rule mov(~y, ~x) + save(stack(~idx), ~y) => save(stack(~idx), ~x)
    @rule mov(~y, ~x) + mov(~z, ~y)  => mov(~z, ~x)
]

apply_peephole(t0, t1) = Chain(rules_peephole)(t0 + t1)

function peephole!(mir)
    n = length(mir.ir)
    p = Any[]
    push!(p, mir.ir[1])

    for i = 2:n
        t0 = pop!(p)
        t1 = mir.ir[i]

        t = apply_peephole(t0, t1)

        if operation(value(t)) != +
            push!(p, t)
        else
            push!(p, t0)
            push!(p, t1)
        end
    end

    mir.ir = p
end
