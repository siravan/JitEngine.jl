@syms mem(x::Int) stack(x::Int) param(x::Int)

struct Variable
    loc
    shape::Tuple{Int}
end

mutable struct SymbolTable
    vars::Dict{Any, Variable}
    size_mem::Int
    size_param::Int
    size_stack::Int

    SymbolTable() = new(Dict(), 0, 0, 0)
end

next_mem(syms::SymbolTable) = syms.size_mem

function add_mem!(syms::SymbolTable, name::String)
    sym = Symbol(name)
    v = (@variables $sym)[1]
    return add_mem!(syms, v)
end

function add_mem!(syms::SymbolTable, v)
    if is_array_of_symbolics(v)
        syms.vars[v] = Variable(mem(syms.size_mem), size(v))
        for u in scalarize(v)
            add_mem!(syms, u)
        end
    else
        v = value(v)
        syms.vars[v] = Variable(mem(syms.size_mem), (1,))
        syms.size_mem += 1
    end
    return v
end

function add_param!(syms::SymbolTable, v)
    v = value(v)
    syms.vars[v] = Variable(param(syms.size_param), (1,))
    syms.size_param += 1
    return v
end

function new_temp!(syms::SymbolTable)
    n = syms.size_stack
    sym = Symbol("θ$n")
    v = (@variables $sym)[1]
    syms.vars[v] = Variable(stack(n), (1,))
    syms.size_stack += 1
    return v
end
