abstract type FuncType end
abstract type Lambdify <: FuncType end
abstract type FastFunc <: FuncType end
abstract type OdeFunc <: FuncType end
abstract type JacFunc <: FuncType end


mutable struct Func{T}
    code::MachineCode
    mem::Vector{Float64}
    params::Vector{Float64}
    count_states::Int
    count_params::Int
    count_obs::Int
    count_diffs::Int
end


function compile_builder(T, builder)
    mir = lower(builder)
    substitute_registers!(builder, mir)
    peephole!(mir)
    asm = generate(builder, mir)

    mem = zeros(builder.count_states + builder.count_obs + builder.count_diffs + 1)
    params = zeros(builder.count_params)

    code = create_executable_memory(asm)

    func = Func{T}(
        code,
        mem,
        params,
        builder.count_states,
        builder.count_params,
        builder.count_obs,
        builder.count_diffs,
    )

    return func
end

###################### compile_* functions ###############################

# function compile_ode(sys::ODESystem; kw...)
#     model = JSON.json(dictify_ode(sys))
#     return compile_model(OdeFunc, model; kw...)
# end

# function compile_ode(sys::System; kw...)
#     model = JSON.json(dictify_ode(sys))
#     return compile_model(OdeFunc, model; kw...)
# end

function compile_ode(t, states, diffs; params = [], kw...)
    builder = build(t, states, [], diffs; params)
    return compile_builder(Lambdify, builder; kw...)

    model = JSON.json(dictify_ode(states, eqs, t; params))
    return compile_model(OdeFunc, model; kw...)
end

function symbolize_ode_func(f::Function, t)
    u = Inspector("u")
    du = Inspector("du")
    p = Inspector("p")

    f(du, u, p, t)

    states, _ = linearize(u)
    _, diffs = linearize(du)
    @assert length(states) == length(eqs)
    params, _ = linearize(p)

    return states, diffs, params
end

function compile_ode(f::Function; kw...)
    @variables t
    states, diffs, params = symbolize_ode_func(f, t)
    return compile_ode(t, states, [], diffs; params, kw...)
end

function compile_jac(t, states, diffs; params = [], kw...)
    n = length(states)
    @assert n == length(eqs)

    J = Num[]
    for eq in eqs
        for x in states
            deq_x = expand_derivatives(Differential(x)(eq))
            push!(J, deq_x)
        end
    end

    builder = build(t, states, J, []; params)
    return compile_builder(Lambdify, builder; kw...)
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
    builder = build(nothing, states, obs, [])
    return compile_builder(Lambdify, builder; kw...)
end

function compile_func(states, obs; params = [], kw...)
    builder = build(nothing, states, obs, []; params)
    return compile_builder(Lambdify, builder; kw...)
end

######################### Calls #############################

function (func::Func{Lambdify})(u::Vector{T}) where {T<:Number}
    func.mem[1:func.count_states] .= u
    call(func.code, func.mem, func.params)
    return func.mem[(func.count_states+2):(func.count_states+func.count_obs+1)]
end

function (func::Func{Lambdify})(u::Vector{T}, p) where {T<:Number}
    func.params .= p
    func.mem[1:func.count_states] .= u
    call(func.code, func.mem, func.params)
    return func.mem[(func.count_states+2):(func.count_states+func.count_obs+1)]
end

function (func::Func{Lambdify})(
    u::Matrix{T},
    p = nothing;
    copy_matrix = true,
) where {T<:Number}
    if p != nothing
        func.params .= p
    end

    if copy_matrix
        states = zeros(size(u, 1), func.count_states)
        states .= u
        states_mat = create_matrix(states)
    else
        states_mat = create_matrix(u)
    end

    obs = zeros(size(u, 1), func.count_obs)
    obs_mat = create_matrix(obs)

    @ccall libpath.execute_matrix(
        func.handle::Ptr{Cvoid},
        states_mat.handle::Ptr{Cvoid},
        obs_mat.handle::Ptr{Cvoid},
    )::Cvoid

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
