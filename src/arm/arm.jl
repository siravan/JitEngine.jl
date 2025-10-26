asm = Assembler(0, 3)

function reset()
    global asm
    asm = Assembler(0, 3)
end

include("asm.jl")

const MEM = 19      # first arg = mem if direct mode, otherwise null
const STATES = 21   #second arg = states+obs if indirect mode, otherwise null
const IDX = 22      #third arg = index if indirect mode
const PARAMS = 20   #fourth arg = params
const RET = 0
const TEMP = 1
const SCRATCH1 = 9
const SCRATCH2 = 10


function load_d_from_mem(d, base, idx)
    if idx < 4096
        ldr_d(d, base, 8 * idx)
    else
        movz(SCRATCH1, idx)
        ldr_d(d, base, SCRATCH1, true)
    end
    return true
end

function save_d_to_mem(d, base, idx)
    if idx < 4096
        str_d(d, base, 8 * idx)
    else
        movz(SCRATCH1, idx)
        str_d(d, base, SCRATCH1, true)
    end
end

function load_x_from_mem(r, base, idx)
    @assert r != SCRATCH1

    if idx < 4096
        ldr_x(r, base, 8 * idx)
    else
        movz(SCRATCH1, idx)
        ldr_x(r, base, SCRATCH1, true)
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
    sub_x_imm(:sp, :sp, 48)
    str_x(:lr, :sp, 0)
    str_x(MEM, :sp, 8)
    str_x(PARAMS, :sp, 16)
    # str_x(STATES, :sp, 24)
    # str_x(IDX, :sp, 32)

    mov(MEM, 0)
    # mov(STATES, 1)
    # mov(IDX, 2)
    mov(PARAMS, 3)

    stack_size = align_stack(8 * cap)
    sub_stack(stack_size)
end

function epilogue(cap)
    stack_size = align_stack(8 * cap)
    add_stack(stack_size)

    # ldr_x(IDX, :sp, 32)
    # ldr_x(STATES, :sp, 24)
    ldr_x(PARAMS, :sp, 16)
    ldr_x(MEM, :sp, 8)
    ldr_x(:lr, :sp, 0)

    add_x_imm(:sp, :sp, 48)
    ret()
end
