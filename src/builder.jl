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

@syms plus(x, y) times(x, y) minus(x, y) divide(x, y) power(x, y) rem(x, y)
@syms lt(x, y) leq(x, y) gt(x, y) geq(x, y) eq(x, y) neq(x, y)

rules_rename = [
    @rule +(~~xs) => foldl(plus, ~~xs)
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
@syms unicall(op::Symbol, x) bincall(op::Symbol, x, y) powi(p::Int)::Symbol

rules_codify = [
    @rule plus(~x, ~y) => binop(0, :plus, ~x, ~y)
    @rule times(~x, ~y) => binop(0, :times, ~x, ~y)
    @rule minus(~x, ~y) => binop(0, :minus, ~x, ~y)
    @rule divide(~x, ~y) => binop(0, :divide, ~x, ~y)
    @rule rem(~x, ~y) => binop(0, :rem, ~x, ~y)
    @rule lt(~x, ~y) => binop(0, :lt, ~x, ~y)
    @rule leq(~x, ~y) => binop(0, :leq, ~x, ~y)
    @rule gt(~x, ~y) => binop(0, :gt, ~x, ~y)
    @rule geq(~x, ~y) => binop(0, :geq, ~x, ~y)
    @rule eq(~x, ~y) => binop(0, :eq, ~x, ~y)
    @rule neq(~x, ~y) => binop(0, :neq, ~x, ~y)
    @rule power(ℯ, ~y) => unicall(:exp, ~y)
    @rule power(~x, ~p::is_integer) => uniop(0, powi(~p), ~x)
    @rule power(~x, ~y) => bincall(:power, ~x, ~y)
    @rule neg(~x) => uniop(0, :neg, ~x)
    @rule not(~x) => uniop(0, :not, ~x)
    @rule square(~x) => uniop(0, :square, ~x)
    @rule cube(~x) => uniop(0, :cube, ~x)
    @rule sqrt(~x) => uniop(0, :sqrt, ~x)
    @rule cbrt(~x) => unicall(:cbrt, ~x)
    @rule ifelse(~cond, ~x, ~y) => ternary(0, ~cond, ~x, ~y)
    @rule (~f)(~x) => unicall(Symbol(~f), ~x)
]

function apply_codify(eq)
    return Postwalk(PassThrough(Chain(rules_codify)))(value(eq))
end

############################ Builder #############################

@syms reg(r::Int) load(r, loc) save(loc, r) load_const(r, val::Float64, idx::Int)

mutable struct Builder
    states::Array{Any}
    obs_vars::Array{Any}
    eqs::Array{Any}
    syms::SymbolTable
    count_states::Int
    count_obs::Int
    count_diffs::Int
    count_params::Int
end

new_temp!(builder::Builder) = new_temp!(builder.syms)
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
function build(t, states, obs, diffs; params = [])
    eqs = Any[]
    syms = SymbolTable()

    for (i, state) in enumerate(states)
        if is_array_of_symbolics(state)
            add_alias!(syms, state, size(state))

            for v in scalarize(state)
                add_mem!(syms, v)
            end
        else
            add_mem!(syms, state)
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
        v = add_mem!(syms, diff_nbame(i))
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
    )

    for (lhs, eq) in eqs
        rhs = apply_codify(apply_rewrite(apply_rename(eq)))
        push!(builder.eqs, lhs ~ propagate(builder, rhs))
    end

    return builder
end

################### Propagation ##########################
#
# note that propagation is used in herbiculture sense, measing
# cutting and re-implasting tree branches

function propagate(builder::Builder, eq)
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
