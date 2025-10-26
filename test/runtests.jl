using Test

using Symbolics
using JitEngine
using DifferentialEquations

@variables x y t

@testset "compile_func" begin
    f = compile_func([], [1.0])
    @test f(Float64[]) == [1.0]

    f = compile_func([x, y], [x+y, x*y])
    @test f([2, 3]) == [5.0, 6.0]

    f = compile_func([x], [-x, x^2, x^3, x^4, sqrt(x^2), sqrt(x) / x^0.5])
    @test f([4]) == [-4, 16, 64, 256, 4, 1]

    f = compile_func([x, y], [x > y, x < y, x >= y, x <= y, x == y, x != y])
    @test f([11, 5]) == [1, 0, 1, 0, 0, 1]
    @test f([5, 5]) == [0, 0, 1, 1, 1, 0]

    f = compile_func([x, y, t], [(x > y) + (y > t) == !(!(x > y) * !(y > t))])
    @test f([1, 2, 3]) == [1]
    @test f([1, 3, 2]) == [1]
    @test f([2, 1, 3]) == [1]
    @test f([2, 3, 1]) == [1]
    @test f([3, 1, 2]) == [1]
    @test f([3, 2, 1]) == [1]

    f = compile_func(x -> asin(sin(x)) * acos(cos(x)) * atan(tan(x)) / x^3)
    @test f(0.5) ≈ 1.0

    f = compile_func(x -> acsc(csc(x)) * asec(sec(x)) * acot(cot(x)) / x^3)
    @test f(0.5) ≈ 1.0

    f = compile_func(x -> asinh(sinh(x)) * acosh(cosh(x)) * atanh(tanh(x)) / x^3)
    @test f(0.5) ≈ 1.0

    f = compile_func(x -> acsch(csch(x)) * asech(sech(x)) * acoth(coth(x)) / x^3)
    @test f(0.5) ≈ 1.0

    f = compile_func(x -> exp(log(x)) * exp2(log2(x)) * exp10(log10(x)) / x^3)
    @test f(0.5) ≈ 1.0

    f = compile_func(x -> sum(x^i / factorial(i) for i = 0:15))
    @test f(2.0) ≈ exp(2.0)

    f = compile_func(x -> sum((-1)^i * x^(2*i+1) / factorial(big(2*i+1)) for i = 0:10))
    @test f(0.5) ≈ sin(0.5)

    f = compile_func([x, y, t], [x^(y+1), t % x])
    @test f([5, 2, 44]) == [125.0, 4.0]

    f = compile_func([x, y], [ifelse((x > y) * (x < 4), x^2, y^2)])
    @test f([2, 3]) == [9]
    @test f([3, 1]) == [9]
    @test f([5, 3]) == [9]
end

@testset "compile_ode" begin

    f = compile_ode(t, [x, y], [y, -x])
    prob = ODEProblem(f, [0.0, 1.0], (0.0, 2*pi), Float64[])
    sol = solve(prob)
    @test all(abs.(sol[1, :] .- sin.(sol.t)) .< 0.0001)  # sol[1,:] should be sin(sol.t)
end
