using JitEngine

using Symbolics
using Plots

const N = 500

@variables a[1:N,1:N], b[1:N,1:N], x[1:N,1:N], y[1:N,1:N]

f = compile_func([a, b, x, y], [x .* x - y .* y + a, 2 * (x .* y) + b])

A = zeros(N, N)
B = zeros(N, N)
X = zeros(N, N)
Y = zeros(N, N)

for i = 1:N
    for j = 1:N
        A[i, j] = j/N * 3.0 - 2.0
        B[i, j] = i/N * 3.0 - 1.5
    end
end

for i = 1:20
    R = f(A, B, X, Y)
    X .= R[1]
    Y .= R[2]
end

m = hypot.(X, Y)

heatmap(m .< 4.0; aspect_ratio = :equal)
