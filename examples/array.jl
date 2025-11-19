using JitEngine
using Symbolics

@variables X[1:3, 1:3], Y[1:3, 1:3], a

f = compile_func([a, X, Y], [X .^ a * Y])

x = rand(size(X)...)
y = rand(size(Y)...)

@assert(f(2.0, x, y)[1] ≈ (x .^ 2) * y)

println("ok!")
