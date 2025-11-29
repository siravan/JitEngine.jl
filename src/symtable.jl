struct Variable
    loc
    shape
end

mutable struct SymbolTable
    vars::Dict{Any,Variable}
    size_mem::Int
    size_param::Int
    size_stack::Int

    SymbolTable() = new(Dict(), 0, 0, 0)
end

next_mem(syms::SymbolTable) = syms.size_mem

function create_variable(name, shape)
    sym = Symbol(name)
    l = length(shape)

    if l == 0
        v = (@variables $sym)[1]
    elseif l == 1
        v = (@variables $sym[1:shape[1]])[1]
    elseif l == 2
        v = (@variables $sym[1:shape[1], 1:shape[2]])[1]
    elseif l == 3
        v = (@variables $sym[1:shape[1], 1:shape[2], 1:shape[3]])[1]
    else
        error("only 1-3 dimensional variables are supported")
    end

    return v
end

function add_mem!(syms::SymbolTable, name::String, shape=())
    return add_mem!(syms, create_variable(name, shape), shape)
end

function add_mem!(syms::SymbolTable, v, shape=())
    syms.vars[v] = Variable(mem(syms.size_mem), shape)
    syms.size_mem += prod(shape)
    return v
end

function add_alias!(syms::SymbolTable, name::String, shape=())
    return add_alias!(syms, create_variable(name, shape), shape)
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
    v = create_variable("θ$n", shape)
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

function rename(syms::SymbolTable, dst, src)
    syms.vars[src] = syms.vars[dst]
end
