using JitEngine
using Symbolics

@variables x

x0 = 0.0001

for i = 1:10
    e = x^2 + x

    for j = 1:i
        e = e^2 + e
    end

    ed = expand_derivatives(Differential(x)(e))
    f = compile_func([x], [ed])

    println(i, '\t', f([x0])[1])
end
