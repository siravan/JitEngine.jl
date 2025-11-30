mutable struct MIR
    syms::SymbolTable
    fp::Dict{Symbol,Any}
    ir::Vector{Any}
    vt::Vector{Any}
    constants::Vector{Float64}
    count_regs::Int
    used_regs::Vector{Int}

    MIR(syms) = new(syms, func_pointers(), [], [], [], 2, Int[])
end

function Base.push!(mir::MIR, t)
    push!(mir.ir, t)
end

function push_new_reg!(mir::MIR, f)
    r = new_reg(mir)
    push!(mir.ir, f(r))
    return r
end

@syms σ0 σ1 ω

function new_reg(mir::MIR)
    r = mir.count_regs
    mir.count_regs += 1
    sym = Symbol("σ$r")
    v = (@variables $sym)[1]
    return v
end

@syms mov(r, s) call_func(op::Symbol)

function bool_to_real(mir, x)
    one, _ = lower_terminal(mir, 1.0)
    return push_new_reg!(mir, r -> binop(r, :and, x, one)), Real
end

#
# lower functions convert a propagated Builder object into
# an intermediate representation

function lower(builder::Builder)
    mir = MIR(builder.syms)

    add_func(mir, :matmul)
    add_func(mir, :adjoint)

    for eq in builder.eqs
        if eq isa Equation
            if istree(eq.lhs) && operation(eq.lhs) == getindex
                lower_setindex(mir, eq.lhs, lower_real(mir, eq.rhs))
            else
                r = lower_real(mir, eq.rhs)
                push!(mir, save(eq.lhs, r))
            end
        else
            push!(mir, eq)
        end
    end

    return mir
end

function lower_real(mir::MIR, eq)
    eq, t = lower(mir, eq)

    if t == Bool
        eq, t = bool_to_real(mir, eq)
    end

    return eq
end

function lower(mir::MIR, eq)
    eq = value(eq)

    if iscall(eq)
        head = operation(eq)

        if head == uniop
            return lower_uniop(mir, eq)
        elseif head == binop
            return lower_binop(mir, eq)
        elseif head == ternary
            return lower_ternary(mir, eq)
        elseif head == unicall
            return lower_unicall(mir, eq)
        elseif head == bincall
            return lower_bincall(mir, eq)
        elseif head == getindex
            return lower_getindex(mir, eq)
        end
    else
        return lower_terminal(mir, eq)
    end
end

function lower_terminal(mir::MIR, eq)
    if is_number(eq)
        val = Float64(eq)
        idx = findfirst(x -> x == val, mir.constants)

        if idx == nothing
            push!(mir.constants, val)
            idx = length(mir.constants)
        end

        return push_new_reg!(mir, r -> load_const(r, val, idx)), Real
    else
        return push_new_reg!(mir, r -> load(r, eq)), Real
    end
end

function lower_getindex(mir::MIR, eq)
    arr, idx = arguments(eq)

    if isequal(idx, λ)
        return push_new_reg!(mir, r -> load_indexed(r, arr)), Real
    else
        return push_new_reg!(mir, r -> load(r, eq)), Real
    end
end

function lower_setindex(mir::MIR, lhs, rhs)
    arr, idx = arguments(lhs)

    if isequal(idx, λ)
        return push!(mir, save_indexed(arr, rhs))
    else
        error("general indexing not supported")
    end
end

function lower_uniop(mir::MIR, eq)
    _, op, x = arguments(eq)
    x, t = lower(mir, x)

    if t == Bool && op != :not
        x, t = bool_to_real(mir, x)
    end

    return push_new_reg!(mir, r -> uniop(r, op, x)), t
end

function lower_binop(mir::MIR, eq)
    _, op, x, y = arguments(eq)

    if ershov(x) >= ershov(y)
        x, tx = lower(mir, x)
        y, ty = lower(mir, y)
    else
        y, ty = lower(mir, y)
        x, tx = lower(mir, x)
    end

    if tx == Bool && ty == Bool
        if op == :times
            op = :and
        elseif op == :plus
            op = :or
        end
    end

    if tx == Bool && !(ty == Bool && op in [:and, :or])
        x, tx = bool_to_real(mir, x)
    end

    if ty == Bool && !(tx == Bool && op in [:and, :or])
        y, ty = bool_to_real(mir, y)
    end

    if op in [:lt, :leq, :gt, :geq, :eq, :neq]
        t = Bool
    else
        t = tx == Bool && ty == Bool ? Bool : Real
    end

    return push_new_reg!(mir, r -> binop(r, op, x, y)), t
end

function lower_ternary(mir::MIR, eq)
    _, cond, x, y = arguments(eq)

    e1 = ershov(cond)
    e2 = ershov(x)
    e3 = ershov(y)

    if e1 >= e2 && e2 >= e3
        s1, t1 = lower(mir, cond)
        s2, t2 = lower(mir, x)
        s3, t3 = lower(mir, y)
    elseif e1 >= e3 && e3 >= e2
        s1, t1 = lower(mir, cond)
        s3, t3 = lower(mir, y)
        s2, t2 = lower(mir, x)
    elseif e2 >= e1 && e1 >= e3
        s2, t2 = lower(mir, x)
        s1, t1 = lower(mir, cond)
        s3, t3 = lower(mir, y)
    elseif e2 >= e3 && e3 >= e1
        s2, t2 = lower(mir, x)
        s3, t3 = lower(mir, y)
        s1, t1 = lower(mir, cond)
    elseif e3 >= e1 && e1 >= e2
        s3, t3 = lower(mir, y)
        s1, t1 = lower(mir, cond)
        s2, t2 = lower(mir, x)
    else
        s3, t3 = lower(mir, y)
        s2, t2 = lower(mir, x)
        s1, t1 = lower(mir, cond)
    end

    @assert t1 == Bool && t2 == t3

    return push_new_reg!(mir, r -> ternary(r, s1, s2, s3)), t2
end

function lower_unicall(mir::MIR, eq)
    op, x = arguments(eq)
    push!(mir, mov(σ0, lower_real(mir, x)))

    add_func(mir, op)
    push!(mir, call_func(op))
    return push_new_reg!(mir, r -> mov(r, σ0)), Real
end

function lower_bincall(mir::MIR, eq)
    op, x, y = arguments(eq)

    if ershov(x) >= ershov(y)
        push!(mir, mov(σ0, lower_real(mir, x)))
        push!(mir, mov(σ1, lower_real(mir, y)))
    else
        push!(mir, mov(σ1, lower_real(mir, y)))
        push!(mir, mov(σ0, lower_real(mir, x)))
    end

    add_func(mir, op)
    push!(mir, call_func(op))
    return push_new_reg!(mir, r -> mov(r, σ0)), Real
end

function add_func(mir::MIR, op)
    if !(op in first.(mir.vt))
        push!(mir.vt, (op, mir.fp[op]))
    end
end
