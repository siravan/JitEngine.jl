using JitEngine

using Symbolics
using Plots

const N = 500

@variables a b x y

f = compile_func([a, b, x, y], [a, b, x^2 - y^2 + a, 2 * x * y + b])

X = zeros(N*N, 4)

for i = 1:N
    for j = 1:N
        X[i+(j-1)*N, 1] = j/N*3.0-2.0
        X[i+(j-1)*N, 2] = i/N*3.0-1.5
    end
end

for i = 1:20
    X .= f(X)
end

m = reshape(hypot.(X[:, 3], X[:, 4]), (N, N))

heatmap(m .< 4.0; aspect_ratio = :equal)
