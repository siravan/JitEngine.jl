# is_number(x) returns true if x is a concrete numerical type
is_number(x::T) where {T<:Integer} = true
is_number(x::T) where {T<:Float32} = true
is_number(x::T) where {T<:Float64} = true
is_number(x::T) where {T<:Complex} = true
is_number(x::T) where {T<:Rational} = true
is_number(x::T) where {T<:Irrational} = true
is_number(x) = false

is_proper(x) = is_number(x) && !isnan(x) && !isinf(x)
is_integer(x) = is_number(x) && round(x) == x

###################### Rename Operators #######################

@syms plus(x, y) times(x::Any, y::Any) minus(x, y) divide(x, y) power(x, y) rem(x, y)
@syms lt(x, y) leq(x, y) gt(x, y) geq(x, y) eq(x, y) neq(x, y)
@syms matmul(x::Any, y::Any)

is_matrix(xs) = any(x -> size(x) != (), xs)


rules_rename = [
    @rule +(~~xs) => foldl(plus, ~~xs)
    @rule *(~~xs::is_matrix) => foldl(matmul, ~~xs)
    @rule *(~~xs) => foldl(times, ~~xs)
    @rule ~x - ~y => minus(~x, ~y)
    @rule ~x / ~y => divide(~x, ~y)
    @rule ^(~x, ~y) => power(~x, ~y)
    @rule %(~x, ~y) => rem(~x, ~y)
    @rule ~x > ~y => gt(~x, ~y)
    @rule ~x >= ~y => geq(~x, ~y)
    @rule ~x < ~y => lt(~x, ~y)
    @rule ~x <= ~y => leq(~x, ~y)
    @rule ~x == ~y => eq(~x, ~y)
    @rule ~x != ~y => neq(~x, ~y)
]

apply_rename(eq) = Postwalk(PassThrough(Chain(rules_rename)))(value(eq))

################### Rewrite Operators #######################

@syms neg(x) square(x) cube(x) sqrt(x) cbrt(x) not(x)

function approximately(val::Number)
    return x -> value(x) isa Real ? value(x) ≈ val : false
end

rules_rewrite = [
    @rule times(~x, -1.0) => neg(~x)
    @rule times(-1.0, ~x) => neg(~x)
    @rule plus(neg(~x), neg(~y)) => neg(plus(~x, ~y))
    @rule plus(~x, neg(~y)) => minus(~x, ~y)
    @rule plus(neg(~x), ~y) => minus(~y, ~x)
    @rule power(~x, 2) => square(~x)
    @rule power(~x, 3) => cube(~x)
    @rule power(~x, 4) => square(square(~x))
    @rule power(~x, -1) => divide(1.0, ~x)
    @rule power(~x, -2) => divide(1.0, square(~x))
    @rule power(~x, -3) => divide(1.0, cube(~x))
    @rule power(~x, 0.5) => sqrt(~x)
    @rule power(~x, ~p::approximately(1/3)) => cbrt(~x)
    @rule power(~x, -0.5) => divide(1.0, sqrt(~x))
    @rule power(~x, ~p::approximately(-1/3)) => divide(1.0, cbrt(~x))
    @rule !(~x) => not(~x)
]


apply_rewrite(eq) = Postwalk(PassThrough(Chain(rules_rewrite)))(value(eq))

############# High-level Intermediate Representation #########

# the meaning of e in uniop and binop depends on the compilation pass.
# In the early stages, it is the ershov numner
# When IR is emitted, it is the destination
@syms uniop(e, op::Symbol, x) binop(e, op::Symbol, x, y) ternary(e, cond, x, y)
@syms unicall(op::Symbol, x::Any) bincall(op::Symbol, x::Any, y::Any) powi(p::Int)::Symbol
@syms unicast(op::Symbol, x::Any) bincast(op::Symbol, x::Any, y::Any)
@syms reducer(f::Any, op::Symbol, x::Any)

# @syms arrayop(output_idx::Any, expr::Any, reduce::Any, shape::Any)

unref(ref::Symbolics.Ref) = ref.x
unref(ref) = ref

is_arrayop(x) = x isa Symbolics.ArrayOp

function try_arrayop(x)
    if is_arrayop(x)
        op = unwrap(x)
        return arrayop(op.output_idx, unref(op.expr), op.reduce, op.shape)
    else
        return x
    end
end

rules_codify = [
    @rule plus(~x, ~y) => binop(0, :plus, rewrite(~x), rewrite(~y))
    @rule times(~x, ~y) => binop(0, :times, rewrite(~x), rewrite(~y))
    @rule minus(~x, ~y) => binop(0, :minus, rewrite(~x), rewrite(~y))
    @rule divide(~x, ~y) => binop(0, :divide, rewrite(~x), rewrite(~y))
    @rule rem(~x, ~y) => binop(0, :rem, rewrite(~x), rewrite(~y))
    @rule lt(~x, ~y) => binop(0, :lt, rewrite(~x), rewrite(~y))
    @rule leq(~x, ~y) => binop(0, :leq, rewrite(~x), rewrite(~y))
    @rule gt(~x, ~y) => binop(0, :gt, rewrite(~x), rewrite(~y))
    @rule geq(~x, ~y) => binop(0, :geq, rewrite(~x), rewrite(~y))
    @rule eq(~x, ~y) => binop(0, :eq, rewrite(~x), rewrite(~y))
    @rule neq(~x, ~y) => binop(0, :neq, rewrite(~x), rewrite(~y))
    @rule power(ℯ, ~y) => unicall(:exp, rewrite(~y))
    @rule power(~x, ~p::is_integer) => uniop(0, powi(~p), rewrite(~x))
    @rule power(~x, ~y) => bincall(:power, rewrite(~x), rewrite(~y))
    @rule neg(~x) => uniop(0, :neg, rewrite(~x))
    @rule not(~x) => uniop(0, :not, rewrite(~x))
    @rule square(~x) => uniop(0, :square, rewrite(~x))
    @rule cube(~x) => uniop(0, :cube, rewrite(~x))
    @rule sqrt(~x) => uniop(0, :sqrt, rewrite(~x))
    @rule cbrt(~x) => unicall(:cbrt, rewrite(~x))

    @rule broadcast(~op, ~x) => unicast(Symbol(~op), rewrite(~x))
    @rule broadcast(~op, ~x, ~y) => bincast(Symbol(~op), rewrite(~x), rewrite(~y))
    @rule Symbolics._mapreduce(~f, ~op, ~x, ~a, ~b) => reducer(~f, Symbol(~op), rewrite(~x))

    @rule ifelse(~cond, ~x, ~y) => ternary(0, ~cond, rewrite(~x), rewrite(~y))
    @rule (~f)(~x) => unicall(Symbol(~f), rewrite(~x))
]

function apply_codify(eq)
    return Postwalk(Chain(rules_codify))(value(eq))
end

# rewrite(eq) = apply_codify(apply_rewrite(apply_rename(eq)))

function rewrite(eq)
    x = apply_rewrite(apply_rename(eq))

    for r in rules_codify
        y = r(x)
        if y != nothing
            return y
        end
    end

    if is_arrayop(x)
        error("naked ArrayOp is not supported!")
    else
        return x
    end
end


############################ Builder #############################

mutable struct Builder
    states::Array{Any}
    obs_vars::Array{Any}
    eqs::Array{Any}
    syms::SymbolTable
    count_states::Int
    count_obs::Int
    count_diffs::Int
    count_params::Int
    count_loops::Int
end

new_temp!(builder::Builder, shape=()) = new_temp!(builder.syms, shape)

state_name(i) = "σ$(i-1)"
obs_name(i) = "Ψ$(i-1)"
diff_name(i) = "δ$(i-1)"

# Builder is a constructor and the main entry point to the JIT compiler.
#
# Inputs:
#   t:  the independent variable or nothing
#   states: the list of state variables
#   obs: the list of algebraic equations (only the RHS). It can be empty.
#   diffs: the list of differential equations, each one corresponding to
#       a single state variable. It can be empty.
#   params: (optional)
#
function build(t, states, obs, diffs; params = [], unroll=true)
    eqs = Any[]
    syms = SymbolTable()

    for (i, state) in enumerate(states)
        if is_array_of_symbolics(state) && unroll
            add_alias!(syms, state, size(state))

            for v in scalarize(state)
                add_mem!(syms, v)
            end
        else
            add_mem!(syms, state, size(state))
        end
    end

    if t == nothing
        add_mem!(syms, "Ψ_")
    else
        add_mem!(syms, t)
    end

    obs_vars = []

    for (i, eq) in enumerate(obs)
        if eq isa Equation
            push!(obs_vars, eq.lhs)
            add_mem!(syms, eq.lhs)
            push!(eqs, (eq.lhs, eq.rhs))
        elseif !unroll
            v = add_mem!(syms, obs_name(i), size(eq))
            push!(obs_vars, v)
            push!(eqs, (v, eq))
        else
            eq = scalarize(eq)

            if eq isa AbstractArray
                v = add_alias!(syms, obs_name(i), size(eq))
                push!(obs_vars, v)

                for (j, q) in enumerate(scalarize(eq))
                    v = add_mem!(syms, "$(obs_name(i)),$(j-1)")
                    push!(eqs, (v, q))
                end
            else
                v = add_mem!(syms, obs_name(i))
                push!(obs_vars, v)
                push!(eqs, (v, eq))
            end
        end
    end

    @assert isempty(diffs) || length(diffs) == length(states)

    for (i, eq) in enumerate(diffs)
        v = add_mem!(syms, diff_name(i))
        push!(eqs, (v, eq))
    end

    for v in params
        add_param!(syms, v)
    end

    builder = Builder(
        states,
        obs_vars,
        [],
        syms,
        length(states),
        length(obs),
        length(diffs),
        length(params),
        0
    )

    for (lhs, eq) in eqs
        rhs = rewrite(eq)
        println(lhs, " = ", rhs)
        if size(lhs) == ()
            push!(builder.eqs, lhs ~ propagate(builder, rhs))
        else
            rename(builder.syms, lhs, propagate(builder, rhs))
        end
    end

    return builder
end

################### Propagation ##########################
#
# note that propagation is used in herbiculture sense, measing
# cutting and re-implasting tree branches

function propagate(builder::Builder, eq)
    eq = unref(eq)

    if iscall(eq)
        head = operation(eq)

        if head == uniop
            return propagate_uniop(builder, eq)
        elseif head == binop
            return propagate_binop(builder, eq)
        elseif head == ternary
            return propagate_ternary(builder, eq)
        elseif head == unicall
            return propagate_unicall(builder, eq)
        elseif head == bincall
            return propagate_bincall(builder, eq)
        elseif head == unicast
            return propagate_unicast(builder, eq)
        elseif head == bincast
            return propagate_bincast(builder, eq)
        elseif head == matmul
            return propagate_matmul(builder, eq)
        elseif head == reducer
            return propagate_reduce(builder, eq)
        elseif head == getindex
            return eq
        else
            error("unreachable section")
        end
    else
        return eq
    end
end

function propagate_uniop(builder::Builder, eq)
    e, op, x = arguments(eq)
    x = propagate(builder, x)
    e = ershov(x)
    return uniop(e, op, x)
end

function propagate_binop(builder::Builder, eq)
    e, op, x, y = arguments(eq)
    x = propagate(builder, x)
    y = propagate(builder, y)
    e = calc_ershov(x, y)
    u = binop(e, op, x, y)

    if e < (LOGICAL_REGS - 2)
        return u
    else
        # we need to break the tree and introduce a new
        # temporary variable here to ensure register
        # allocation algorithm does not run out of registers.
        # This is part of the Sethi–Ullman algorithm.
        t = new_temp!(builder)
        push!(builder.eqs, t ~ u)
        return t
    end
end

function propagate_ternary(builder::Builder, eq)
    e, cond, x, y = arguments(eq)
    cond = propagate(builder, cond)
    x = propagate(builder, x)
    y = propagate(builder, y)
    e = calc_ershov(cond, x, y)
    u = ternary(e, cond, x, y)

    if e < (LOGICAL_REGS - 2)
        return u
    else
        # see comment in propagate_unicall
        t = new_temp!(builder)
        push!(builder.eqs, t ~ u)
        return t
    end
end

# unicall and bincall always create a new temporary variable
# in the stack because remote calls do not preserve callee-saved
# registers
function propagate_unicall(builder::Builder, eq)
    op, x = arguments(eq)
    x = propagate(builder, x)
    t = new_temp!(builder)
    push!(builder.eqs, t ~ unicall(op, x))
    return t
end

function propagate_bincall(builder::Builder, eq)
    op, x, y = arguments(eq)
    x = propagate(builder, x)
    y = propagate(builder, y)
    t = new_temp!(builder)
    push!(builder.eqs, t ~ bincall(op, x, y))
    return t
end

function propagate_unicast(builder::Builder, eq)
    label = ".L$(builder.count_loops)"
    builder.count_loops += 1

    op, x = arguments(eq)
    arr_x = propagate(builder, x)

    push!(builder.eqs, reset_index())
    push!(builder.eqs, set_label(label))

    expr = eval(:($op($arr_x[λ])))
    y = propagate(builder, rewrite(expr))

    arr_t = new_temp!(builder, size(arr_x))
    push!(builder.eqs, arr_t[λ] ~ y)

    push!(builder.eqs, inc_index())
    push!(builder.eqs, branch_if(prod(size(arr_x)), label))
    return arr_t
end

function broadcast_size(x1, x2)
    s1 = size(x1)
    s2 = size(x2)

    if s1 == ()
        return s2
    elseif s2 == ()
        return s1
    elseif s1 == s2
        return s1
    else
        error("broadcast error!")
    end
end

function propagate_bincast(builder::Builder, eq)
    label = ".L$(builder.count_loops)"
    builder.count_loops += 1

    op, x, y = arguments(eq)

    arr_x = propagate(builder, unref(x))
    arr_y = propagate(builder, unref(y))
    shape = broadcast_size(arr_x, arr_y)

    push!(builder.eqs, reset_index())
    push!(builder.eqs, set_label(label))

    tx = size(arr_x) == () ? arr_x : arr_x[λ]
    ty = size(arr_y) == () ? arr_y : arr_y[λ]

    expr = eval(:($op($tx, $ty)))
    y = propagate(builder, rewrite(expr))
    arr_t = new_temp!(builder, shape)
    push!(builder.eqs, arr_t[λ] ~ y)

    push!(builder.eqs, inc_index())
    push!(builder.eqs, branch_if(prod(shape), label))

    return arr_t
end

function propagate_matmul(builder::Builder, eq)
    x, y = arguments(eq)
    x = propagate(builder, x)
    y = propagate(builder, y)
    t = new_temp!(builder, size(x * y))
    push!(builder.eqs, loop(t, matmul(x, y)))
    return t
end

function propagate_reduce(builder::Builder, eq)
    label = ".L$(builder.count_loops)"
    builder.count_loops += 1

    f, op, x = arguments(eq)
    @assert f == identity
    arr_x = propagate(builder, x)
    shape = size(arr_x)

    push!(builder.eqs, reset_index())

    t = new_temp!(builder, ())
    push!(builder.eqs, t ~ arr_x[λ])

    n = prod(shape)
    if n > 1
        push!(builder.eqs, set_label(label))
        push!(builder.eqs, inc_index())
        expr = eval(:($op($t, $arr_x[λ])))
        y = propagate(builder, rewrite(expr))
        push!(builder.eqs, t ~ y)
        push!(builder.eqs, branch_if(n-1, label))
    end

    return t
end

######################### Utils ###########################

function ershov(x)
    x = value(x)

    if iscall(x) && (operation(x) == uniop || operation(x) == binop)
        return first(arguments(x))
    else
        return 1
    end
end

function calc_ershov(x1, x2)
    e1 = ershov(x1)
    e2 = ershov(x2)
    return e1 == e2 ? e1 + 1 : max(e1, e2)
end

calc_ershov(x1, x2, x3) = calc_ershov(calc_ershov(x1, x2), x3)
