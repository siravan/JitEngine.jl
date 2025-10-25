const MEM = RBP
const STATES = R13
const IDX = R12
const PARAMS = RBX
const RET = 0
const TEMP = 1

const PAGE_SIZE = 4096

function load_const(dst, idx)
    label = "_const_$(idx)_"
    vmovsd_xmm_label(dst, label)
end

function load_mem(dst, idx)
    vmovsd_xmm_mem(dst, MEM, idx * 8)
end

function save_mem(src, idx)
    vmovsd_mem_xmm(MEM, idx * 8, src)
end

function load_param(dst, idx)
    vmovsd_xmm_mem(dst, PARAMS, idx * 8)
end

function load_stack(dst, idx)
    vmovsd_xmm_mem(dst, RSP, idx * 8)
end

function save_stack(src, idx)
    vmovsd_mem_xmm(RSP, idx * 8, src)
end

function neg(dst, s1)
    vmovsd_xmm_label(TEMP, "_minus_zero_")
    vxorpd(dst, s1, TEMP)
end

function abs(dst, s1)
    vmovsd_xmm_label(TEMP, "_minus_zero_")
    vandnpd(dst, TEMP, s1);
end

function recip(dst, s1)
    vmovsd_xmm_label(TEMP, "_one_")
    vdivsd(dst, TEMP, s1);
end

function not(dst, s1)
    vmovsd_xmm_label(TEMP, "_all_ones_")
    vxorpd(dst, s1, TEMP)
end

function floor(dst, s1)
    vroundsd(dst, s1, :floor)
end

function round(dst, s1)
    vroundsd(dst, s1, :round)
end

function ceiling(dst, s1)
    vroundsd(dst, s1, :ceiling)
end

function frac(dst, s1)
    floor(TEMP, s1)
    vsubsd(dst, s1, TEMP)
end

function fmov(dst, r1)
    if dst != r1
        vmovapd(dst, r1)
    else
        return true
    end
end

function fmod(dst, s1, s2)
    vdivsd(RET, s1, s2)
    floor(RET, RET)
    vmulsd(RET, RET, s2)
    vsubsd(dst, s1, RET)
end

function square(dst, s1)
    vmulsd(dst, s1, s1)
end

function cube(dst, s1)
    vmulsd(TEMP, s1, s1)
    vmulsd(dst, s1, TEMP)
end

function powi(dst, s1, power)
    if power == 0
        load_const(dst, "_one_")
    elseif power > 0
        t = trailing_zeros(power)
        n = power >> (t + 1)
        s = s1

        vmovapd(dst, s1)

        while n > 0
            vmulsd(TEMP, s, s)
            s = TEMP

            if n & 1 != 0
                vmulsd(dst, dst, TEMP)
            end
            n >>= 1
        end

        for i = 1:t
            vmulsd(dst, dst, dst)
        end
    else
        powi(dst, s1, -power)
        recip(dst, dst)
    end

    return true
end

function select_if(dst, cond, val_true, val_false)
    @assert dst != TEMP
    vandpd(TEMP, cond, val_true)
    vandnpd(dst, cond, val_false)
    vorpd(dst, dst, TEMP)
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
    vzeroupper()

    @static if Sys.iswindows()
        sub_rsp(32)
        call_indirect(label)
        add_rsp(32)
    else
        call_indirect(label)
    end

    return true
end

function save_nonvolatile_regs()
    @static if Sys.iswindows()
        mov_mem_reg(RSP, 0x08, MEM)
        mov_mem_reg(RSP, 0x10, PARAMS)
        # mov_mem_reg(RSP, 0x18, IDX)
        # mov_mem_reg(RSP, 0x20, STATES)
    else
        sub_rsp(32)
        mov_mem_reg(RSP, 0x00, MEM)
        mov_mem_reg(RSP, 0x08, PARAMS)
        # mov_mem_reg(RSP, 0x10, IDX)
        # mov_mem_reg(RSP, 0x18, STATES)
    end
end

function load_nonvolatile_regs()
    @static if Sys.iswindows()
        # mov_reg_mem(STATES, RSP, 0x20)
        # mov_reg_mem(IDX, RSP, 0x18)
        mov_reg_mem(PARAMS, RSP, 0x10)
        mov_reg_mem(MEM, RSP, 0x08)
    else
        # mov_reg_mem(STATES, RSP, 0x18);
        # mov_reg_mem(IDX, RSP, 0x10);
        mov_reg_mem(PARAMS, RSP, 0x08)
        mov_reg_mem(MEM, RSP, 0x00)
        add_rsp(32)
    end
end

function align()
    n = ip()

    while (n & 7) != 1  # 1 because of Julia 1-indexing
        nop()
        n += 1
    end
end

function predefined_consts()
    align()

    set_label("_minus_zero_")
    append_quad(reinterpret(UInt64, -0.0))

    set_label("_one_")
    append_quad(reinterpret(UInt64, 1.0))

    set_label("_all_ones_")
    append_quad(0xffffffffffffffff)
end

# aligns at a multiple of 32 (to cover different ABIs)
function align_stack(n)
    return n + 16 - (n & 15)
end

function frame_size(cap)
    return align_stack(8 * cap + 8) - 8
end

function chkstk(size)
    @static if Sys.iswindows()
        while size > PAGE_SIZE
            sub_rsp(PAGE_SIZE)
            mov_reg_mem(RAX, RSP, 0)
            size -= PAGE_SIZE
        end
    end
    sub_rsp(size)
end

function seal()
    predefined_consts()
    apply_jumps()
end

function prologue(cap)
    save_nonvolatile_regs()

    @static if Sys.iswindows()
        mov(MEM, RCX)
        # mov(STATES, RDX)
        # mov(IDX, R8)
        mov(PARAMS, R9)
    else
        mov(MEM, RDI)
        # mov(STATES, RSI)
        # mov(IDX, RDX)
        mov(PARAMS, RCX)
    end

    chkstk(frame_size(cap))
end

function epilogue(cap)
    add_rsp(frame_size(cap))
    vzeroupper()
    load_nonvolatile_regs()
    ret()
end
