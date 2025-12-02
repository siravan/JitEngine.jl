asm = Assembler(0, 3)

function reset()
    global asm
    asm = Assembler(0, 3)
end

include("asm.jl")

const ZERO = 31

const MEM = 19
const PARAMS = 20
const INDEX = 21

const RET = 0
const TEMP = 1
const SCRATCH1 = 9
const SCRATCH2 = 10

function load_immediate(dst, imm::Int64)
    movz(dst, imm & 0xffff)

    if imm >= 2^16
        movk_lsl16(dst, (imm >> 16) & 0xffff)
    end

    if idx >= 2^32
        movk_lsl32(dst, (imm >> 32) & 0xffff)
    end

    if idx >= 2^48
        movk_lsl48(dst, (imm >> 48) & 0xffff)
    end
end

function load_d_from_mem(d, base, idx::Int64)
    @assert idx >= 0

    if idx < 2^12
        ldr_d_offset(d, base, 8 * idx)
    elseif idx < 2^16
        movz(SCRATCH1, idx)
        ldr_d(d, base, SCRATCH1)
    elseif idx < 2^32
        movz(SCRATCH1, idx & 0xffff)
        movk_lsl16(SCRATCH1, idx >> 16)
        ldr_d(d, base, SCRATCH1)
    else
        error("index out of range")
    end
    return true
end

function save_d_to_mem(d, base, idx::Int64)
    @assert idx >= 0

    if idx < 2^12
        str_d_offset(d, base, 8 * idx)
    elseif idx < 2^16
        movz(SCRATCH1, idx)
        str_d(d, base, SCRATCH1)
    elseif idx < 2^32
        movz(SCRATCH1, idx & 0xffff)
        movk_lsl16(SCRATCH1, idx >> 16)
        str_d(d, base, SCRATCH1)
    else
        error("index out of range")
    end
end

function load_x_from_mem(r, base, idx::Int64)
    @assert r != SCRATCH1 && idx >= 0

    if idx < 2^12
        ldr_x_offset(r, base, 8 * idx)
    elseif idx < 2^16
        movz(SCRATCH1, idx)
        ldr_x(r, base, SCRATCH1)
    elseif idx < 2^32
        movz(SCRATCH1, idx & 0xffff)
        movk_lsl16(SCRATCH1, idx >> 16)
        ldr_x(r, base, SCRATCH1)
    else
        error("index out of range")
    end
end

function sub_stack(size)
    sub_x_imm(:sp, :sp, size & 0x0fff)
    if size >> 12 != 0
        sub_x_imm(:sp, :sp, size >> 12, true)
    end
end

function add_stack(size)
    if size >> 12 != 0
        add_x_imm(:sp, :sp, size >> 12, true)
    end
    add_x_imm(:sp, :sp, size & 0x0fff)
end

function load_const(dst, idx)
    label = "_const_$(idx)_"
    ldr_d_label(dst, label)
end

function load_mem(dst, idx)
    load_d_from_mem(dst, MEM, idx)
end

function save_mem(dst, idx)
    save_d_to_mem(dst, MEM, idx)
end

function save_mem_result(idx)
    save_mem(RET, idx)
end

function load_param(dst, idx)
    load_d_from_mem(dst, PARAMS, idx)
end

function load_stack(dst, idx)
    load_d_from_mem(dst, :sp, idx)
end

function save_stack(dst, idx)
    save_d_to_mem(dst, :sp, idx)
end

function neg(dst, s1)
    fneg(dst, s1)
end

function fcmne(dst, s1, s2)
    fcmeq(dst, s1, s2)
    not(dst, dst)
end

function abs(dst, s1)
    fabs(dst, s1)
end

function recip(dst, s1)
    fmov_const(TEMP, 1.0)
    fdiv(dst, TEMP, s1)
end

function floor(dst, s1)
    frintm(dst, s1)
end

function round(dst, s1)
    frinti(dst, s1)
end

function ceiling(dst, s1)
    frintp(dst, s1)
end

function frac(dst, s1)
    floor(TEMP, s1)
    fsub(dst, s1, TEMP)
end

function fmod(dst, s1, s2)
    fdiv(RET, s1, s2)
    floor(RET, RET)
    fmul(RET, RET, s2)
    fsub(dst, s1, RET)
end

function square(dst, s1)
    fmul(dst, s1, s1)
end

function cube(dst, s1)
    fmul(TEMP, s1, s1)
    fmul(dst, s1, TEMP)
end

function powi(dst, s1, power)
    if power == 0
        fmov_const(dst, 1.0)
    elseif power > 0
        t = trailing_zeros(power)
        n = power >> (t + 1)
        s = s1

        fmov(dst, s1)

        while n > 0
            fmul(TEMP, s, s)
            s = TEMP

            if n & 1 != 0
                fmul(dst, dst, TEMP)
            end
            n >>= 1
        end

        for i = 1:t
            fmul(dst, dst, dst)
        end
    else
        powi(dst, s1, -power)
        recip(dst, dst)
    end

    return true
end

function select_if(dst, cond, val_true, val_false)
    if dst != cond
        fmov(dst, cond)
    end
    bsl(dst, val_true, val_false)
end

function add_const(idx, val)
    label = "_const_$(idx)_"
    set_label(label)
    append_quad(reinterpret(UInt64, val))
end

function add_func(f, p)
    label = "_func_$(f)_"
    set_label(label)
    append_quad(UInt64(p))
end

function call_op(op)
    label = "_func_$(op)_"
    ldr_x_label(0, label)
    blr(0)
end

function align() end

function predefined_consts() end

# aligns at a multiple of 32 (to cover different ABIs)
function align_stack(n)
    return n + 16 - (n & 15)
end

function frame_size(cap)
    return align_stack(8 * cap + 8) - 8
end

function seal()
    predefined_consts()
    apply_jumps()
end

function prologue(cap)
    sub_x_imm(:sp, :sp, 32)
    str_x(:lr, :sp, 0)
    str_x(MEM, :sp, 8)
    str_x(PARAMS, :sp, 16)
    str_x(INDEX, :sp, 24)

    mov(MEM, 0)
    mov(PARAMS, 3)

    stack_size = align_stack(8 * cap)
    sub_stack(stack_size)
end

function epilogue(cap)
    stack_size = align_stack(8 * cap)
    add_stack(stack_size)

    ldr_x(INDEX, :sp, 24)
    ldr_x(PARAMS, :sp, 16)
    ldr_x(MEM, :sp, 8)
    ldr_x(:lr, :sp, 0)

    add_x_imm(:sp, :sp, 32)
    ret()
end

###################### Array Ops ###########################

function scratch(idx)
    add_x_imm(SCRATCH2, INDEX, idx & 0x0fff, false)
    if idx >= 2^12
        add_x_imm(SCRATCH2, SCRATCH2, idx >> 12, true)
    end
    return SCRATCH2
end

function load_mem_indexed(dst, idx)
    s = scratch(idx)
    ldr_d(dst, MEM, s)
end

function save_mem_indexed(src, idx)
    s = scratch(idx)
    str_d(src, MEM, s)
end

function load_stack_indexed(dst, idx)
    s = scratch(idx)
    ldr_d(dst, :sp, s)
end

function save_stack_indexed(src, idx)
    s = scratch(idx)
    str_d(src, :sp, s)
end

function reset_index()
    add_x_imm(INDEX, ZERO, 0)
end

function inc_index()
    add_x_imm(INDEX, INDEX, 1)
end

function branch_if(limit, label)
    load_immediate(SCRATCH2, limit)
    cmp_x(INDEX, SCRATCH2)
    b_le(label)
end

function matmul(dst, x, y, shape)
    m, n, l = shape

    load_immediate(0, dst)
    add_x(0, MEM, 0, true)

    load_immediate(1, x)
    add_x(1, MEM, 1, true)

    load_immediate(2, y)
    add_x(2, MEM, 2, true)

    load_immediate(3, m)
    load_immediate(4, n)
    load_immediate(5, l)

    call_op(:matmul)

    return shape
end

function adjoint(dst, x, shape)
    m, n = shape

    load_immediate(0, dst)
    add_x(0, MEM, 0, true)

    load_immediate(1, x)
    add_x(1, MEM, 1, true)

    load_immediate(2, m)
    load_immediate(3, n)

    call_op(:adjoint)

    return shape
end
