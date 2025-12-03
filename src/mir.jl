@syms mem(x::Int) stack(x::Int) param(x::Int)
@syms reg(r::Int) load(r, loc) save(loc, r) load_const(r, val::Float64, idx::Int)

@syms set_label(label::String) branch_if(limit::Int, label::String)
@syms reset_index() inc_index() load_indexed(r, loc::Any) save_indexed(loc::Any, r)
@syms matmul(dst::Any, x::Any, y::Any, shape::Tuple)
@syms set_adjoint(dst::Any, x::Any, shape::Tuple)
@syms set_inv(dst::Any, x::Any, shape::Tuple)

@syms λ::Int
