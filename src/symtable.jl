@syms mem(x::Int) stack(x::Int) param(x::Int)

struct Variable
    loc
    shape
end

mutable struct SymbolTable
    vars::Dict{Any, Variable}
    size_mem::Int
    size_param::Int
    size_stack::Int

    SymbolTable() = new(Dict(), 0, 0, 0)
end

next_mem(syms::SymbolTable) = syms.size_mem

function add_mem!(syms::SymbolTable, name::String, shape=())
    sym = Symbol(name)
    v = (@variables $sym)[1]
    return add_mem!(syms, v)
end

function add_mem!(syms::SymbolTable, v, shape=())
    v = value(v)
    syms.vars[v] = Variable(mem(syms.size_mem), shape)
    syms.size_mem += prod(shape)
    return v
end

function add_alias!(syms::SymbolTable, name::String, shape=())
    sym = Symbol(name)
    v = (@variables $sym)[1]
    return add_alias!(syms, v, shape)
end

function add_alias!(syms::SymbolTable, v, shape=())
    v = value(v)
    syms.vars[v] = Variable(mem(syms.size_mem), shape)
    return v
end

function add_param!(syms::SymbolTable, v, shape=())
    v = value(v)
    syms.vars[v] = Variable(param(syms.size_param), shape)
    syms.size_param += prod(shape)
    return v
end

function new_temp!(syms::SymbolTable, shape=())
    n = syms.size_stack
    sym = Symbol("θ$n")
    v = (@variables $sym)[1]
    syms.vars[v] = Variable(stack(n), shape)
    syms.size_stack += prod(shape)
    return v
end

idx_rules = [
    @rule mem(~idx) => ~idx
    @rule stack(~idx) => ~idx
    @rule param(~idx) => ~idx
]

function extract_idx(v::Variable)
    for r in idx_rules
        idx = r(v.loc)
        if idx != nothing
            return idx
        end
    end
    nothing
end
