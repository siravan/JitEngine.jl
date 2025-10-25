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
    mir::Union{MIR, Nothing}
end


function compile_builder(T, builder; keep_ir=:no, peephole=true)
    # lower builder into an intermediate representation
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
        saved_mir,
    )

    return func
end

###################### compile_* functions ###############################

function compile_sys(sys; kw...)
    builder = Builder(
        ModelingToolkit.get_iv(sys),
        ModelingToolkit.unknowns(sys),
        ModelingToolkit.observed(sys),
        ModelingToolkit.get_diff_eqs(sys);
        params = ModelingToolkit.parameters(sys),
        kw...
    )
    return compile_builder(OdeFunc, builder; kw...)
end

compile_ode(sys::ODESystem; kw...) = compile_sys(sys; kw...)
compile_ode(sys::System; kw...) = compile_sys(sys; kw...)

function compile_ode(t, states, diffs; params = [], kw...)
    builder = Builder(t, states, [], diffs; params)
    return compile_builder(OdeFunc, builder; kw...)
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

    builder = Builder(t, states, J, []; params)
    return compile_builder(JacFunc, builder; kw...)
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
    builder = Builder(nothing, states, [obs], [])
    return compile_builder(FastFunc, builder; kw...)
end

function compile_func(states, obs; params = [], kw...)
    builder = Builder(nothing, states, obs, []; params)
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

    @assert size(u, 2) == func.count_states

    n = size(u, 1)
    obs = zeros(n, func.count_obs)

    for i = 1:n
        @inbounds func.mem[1:func.count_states] .= u[i, :]
        call(func.code, func.mem, func.params)
        @inbounds obs[i, :] .= func.mem[(func.count_states+2):(func.count_states+func.count_obs+1)]
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
