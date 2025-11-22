abstract type FuncType end
abstract type Lambdify <: FuncType end
abstract type FastFunc <: FuncType end
abstract type OdeFunc <: FuncType end
abstract type JacFunc <: FuncType end
abstract type Vectorized <: FuncType end


mutable struct Func{T}
    code::MachineCode
    mem::Vector{Float64}
    params::Vector{Float64}
    count_states::Int
    count_params::Int
    count_obs::Int
    count_diffs::Int
    mir::Union{MIR,Nothing}
    state_views::Vector{Any}
    obs_views::Vector{Any}
end


function compile_build(T, builder::Builder; keep_ir = :no, peephole = true)
    # lower build into an intermediate representation
    mir = lower(builder)
    saved_mir = nothing

    if keep_ir == :pre
        saved_mir = deepcopy(mir)
    end

    # allocate and substitute registers (logical with 1:1
    # correspondance to physical ones
    substitute_registers!(builder, mir)

    if keep_ir == :post
        saved_mir = deepcopy(mir)
    end

    # perform peephole optimization (optional)
    if peephole
        peephole!(mir)
    end

    # generate machine code
    asm = generate(builder, mir)
    mem = zeros(builder.syms.size_mem)
    params = zeros(builder.syms.size_param)
    code = create_executable_memory(asm)

    state_views = create_views(builder, mem, builder.states)
    obs_views = create_views(builder, mem, builder.obs_vars)

    func = Func{T}(
        code,
        mem,
        params,
        builder.count_states,
        builder.count_params,
        builder.count_obs,
        builder.count_diffs,
        saved_mir,
        state_views,
        obs_views
    )

    return func
end

function create_views(builder::Builder, mem, vars)
    views = []

    for v in vars
        var_info = builder.syms.vars[v]
        shape = var_info.shape
        idx = extract_idx(var_info) + 1

        if prod(shape) == 1
            push!(views, @view mem[idx])
        else
            v = @view mem[idx:idx+prod(shape)-1]
            push!(views, reshape(v, shape))
        end
    end

    return views
end

###################### compile_* functions ###############################

function symbolize_sys(sys)
    iv = ModelingToolkit.get_iv(sys)
    unknowns = ModelingToolkit.unknowns(sys)
    diff_eqs = ModelingToolkit.get_diff_eqs(sys)
    observed = ModelingToolkit.get_observed(sys)
    params = ModelingToolkit.parameters(sys)

    D = Differential(iv)
    @assert all([isequal(D(v), eq.lhs) for (v, eq) in zip(unknowns, diff_eqs)])

    x = Inspector("x")
    states = [x[i] for i in enumerate(unknowns)]
    μ1 = Dict(v => x for (v, x) in zip(unknowns, states))

    y = Inspector("y")
    vars = [y[i] for i in enumerate(observed)]
    μ2 = Dict(eq.lhs => y for (eq, y) in zip(observed, vars))

    μ = union(μ1, μ2)

    diffs = [substitute(eq.rhs, μ) for eq in diff_eqs]
    obs = [substitute(eq.lhs, μ) ~ substitute(eq.rhs, μ) for eq in observed]

    return iv, states, obs, diffs, params
end

function compile_sys(sys; kw...)
    iv, states, obs, diffs, params = symbolize_sys(sys)
    builder = build(iv, states, obs, diffs; params, kw...)
    return compile_build(OdeFunc, builder; kw...)
end

compile_ode(sys::ODESystem; kw...) = compile_sys(sys; kw...)
compile_ode(sys::System; kw...) = compile_sys(sys; kw...)

function compile_ode(t, states, diffs; params = [], kw...)
    builder = build(t, states, [], diffs; params)
    return compile_build(OdeFunc, builder; kw...)
end

function symbolize_ode_func(f::Function, t)
    u = Inspector("u")
    du = Inspector("du")
    p = Inspector("p")

    f(du, u, p, t)

    states, _ = linearize(u)
    _, diffs = linearize(du)
    @assert length(states) == length(diffs)
    params, _ = linearize(p)

    return states, diffs, params
end

function compile_ode(f::Function; kw...)
    @variables t
    states, diffs, params = symbolize_ode_func(f, t)
    return compile_ode(t, states, diffs; params, kw...)
end

function compile_jac(t, states, diffs; params = [], kw...)
    n = length(states)
    @assert n == length(diffs)

    J = Num[]
    for eq in diffs
        for x in states
            deq_x = expand_derivatives(Differential(x)(eq))
            push!(J, deq_x)
        end
    end

    builder = build(t, states, J, []; params)
    return compile_build(JacFunc, builder; kw...)
end

function compile_jac(f::Function; kw...)
    @variables t
    states, diffs, params = symbolize_ode_func(f, t)
    return compile_jac(t, states, diffs; params, kw...)
end

function symbolize_func(f::Function)
    F = methods(f)[1]
    v = Inspector("v")
    states = [v[i] for i = 1:(F.nargs-1)]
    obs = f(states...)
    return states, obs
end

function compile_func(f::Function; kw...)
    states, obs = symbolize_func(f)
    builder = build(nothing, states, [obs], [])
    return compile_build(FastFunc, builder; kw...)
end

function compile_func(states, obs; params = [], kw...)
    if any(Symbolics.is_array_of_symbolics, states)
        return compile_func_vectorized(states, obs; params = [], kw...)
    else
        builder = build(nothing, states, obs, []; params)
        return compile_build(Lambdify, builder; kw...)
    end
end

function compile_func_vectorized(states, obs; params = [], kw...)
    builder = build(nothing, states, obs, []; params)
    return compile_build(Vectorized, builder; kw...)
end

######################### Calls #############################

function (func::Func{Lambdify})(args...)
    if length(args) > func.count_states
        func.params .= args[(func.count_states+1):end]
    end

    func.mem[1:func.count_states] .= args[1:func.count_states]
    call(func.code, func.mem, func.params)
    return func.mem[(func.count_states+2):(func.count_states+func.count_obs+1)]
end

function (func::Func{Vectorized})(args...)
    for (v, val) in zip(func.state_views, args)
        if length(v) == 1
            v[1] = val
        else
            v .= val
        end
    end

    call(func.code, func.mem, func.params)

    res = []

    for v in func.obs_views
        if length(v) == 1
            push!(res, v[1])
        else
            push!(res, copy(v))
        end
    end

    return res
end

# function (func::Func{Lambdify})(args...; p) where {T<:Number}
#     func.params .= p
#     func.mem[1:func.count_states] .= args
#     call(func.code, func.mem, func.params)
#     return func.mem[(func.count_states+2):(func.count_states+func.count_obs+1)]
# end

function (func::Func{Lambdify})(
    u::Matrix{T},
    p = nothing;
    copy_matrix = true,
) where {T<:Number}
    if p != nothing
        func.params .= p
    end

    @assert size(u, 2) == func.count_states

    n = size(u, 1)
    obs = zeros(n, func.count_obs)

    for i = 1:n
        @inbounds func.mem[1:func.count_states] .= u[i, :]
        call(func.code, func.mem, func.params)
        @inbounds obs[i, :] .=
            func.mem[(func.count_states+2):(func.count_states+func.count_obs+1)]
    end

    return obs
end

function (func::Func{FastFunc})(args...)
    @assert func.count_obs == 1
    func.mem[1:func.count_states] .= args
    call(func.code, func.mem, func.params)
    return func.mem[func.count_states+2]
end

function (f::Func{OdeFunc})(du, u, p, t)
    f.mem[1:f.count_states] .= u
    f.params .= p
    f.mem[f.count_states+1] = t
    call(f.code, f.mem, f.params)
    du .= f.mem[(f.count_states+f.count_obs+2):(f.count_states+f.count_obs+f.count_diffs+1)]
end

function (f::Func{JacFunc})(J, u, p, t)
    f.mem[1:f.count_states] .= u
    f.params .= p
    f.mem[f.count_states+1] = t
    call(f.code, f.mem, f.params)
    n = f.count_states
    J .= reshape(f.mem[(n+2):(n+1+n*n)], (n, n))
end
