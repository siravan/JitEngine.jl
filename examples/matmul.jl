using JitEngine
using Symbolics

const N = 5

@variables X[1:N,1:N]

f = compile_func([X], [exp.(sin.(X') * inv(sin.(X')))])

A = rand(size(X)...)

println(f(A)[1])
