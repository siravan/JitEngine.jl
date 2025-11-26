@syms mem(x::Int) stack(x::Int) param(x::Int)
@syms reg(r::Int) load(r, loc) save(loc, r) load_const(r, val::Float64, idx::Int)

@syms set_label(label::String) branch_if(limit::Int, label::String)
@syms reset_index() inc_index() load_indexed(r, arr::Array) save_indexed(arr::Array, r)
@syms loop(lhs::Any, rhs::Any)

@syms λ::Int
