asm = Assembler(-4, 0)

function reset()
    global asm
    asm = Assembler(-4, 0)
end

const RAX = 0
const RCX = 1
const RDX = 2
const RBX = 3
const RSP = 4
const RBP = 5
const RSI = 6
const RDI = 7
const R8 = 8
const R9 = 9
const R10 = 10
const R11 = 11
const R12 = 12
const R13 = 13
const R14 = 14
const R15 = 15

function modrm_reg(reg, rm)
    append_byte(0xc0 + ((reg & 7) << 3) + (rm & 7))
end

function modrm_sib(reg, base, index, scale)
    append_byte(0x04 + ((reg & 7) << 3)) # R/M = 0b100, MOD = 0b00
    scale = trailing_zeros(scale) << 6
    append_byte((scale | (index & 7) << 3) | (base & 7))
end

function rex(reg, rm)
    b = 0x48 + ((rm & 8) >> 3) + ((reg & 8) >> 1)
    append_byte(b)
end

function rex_index(reg, rm, index)
    b = 0x48 + ((rm & 8) >> 3) + ((index & 8) >> 2) + ((reg & 8) >> 1)
    append_byte(b)
end

function modrm_mem(reg, rm, offset)
    small = -128 <= offset < 128

    if small
        append_byte(0x40 + ((reg & 7) << 3) + (rm & 7))
    else
        append_byte(0x80 + ((reg & 7) << 3) + (rm & 7))
    end

    if rm == RSP
        append_byte(0x24) # SIB byte for RSP
    end

    if small
        append_byte(offset)
    else
        append_word(offset)
    end
end

function vex2pd(reg, vreg)
    # This is the two-byte VEX prefix (VEX2) for packed-double (pd)
    # and 256-bit ymm registers
    r = (~reg & 8) << 4
    vvvv = (~vreg & 0x0f) << 3
    append_byte(0xc5)
    append_byte(r | vvvv | 5)
end

function vex2sd(reg, vreg)
    # This is the two-byte VEX prefix (VEX2) for scalar-double (sd)
    # and 256-bit ymm registers
    r = (~reg & 8) << 4
    vvvv = (~vreg & 0x0f) << 3

    append_byte(0xc5)
    append_byte(r | vvvv | 3)
end

function vex3pd(reg, vreg, rm, index, encoding)
    # This is the three-byte VEX prefix (VEX3) for packed-double (pd)
    # and 256-bit ymm registers
    # fnault encoding is 1
    r = (~reg & 8) << 4
    x = (~index & 8) << 3
    b = (~rm & 8) << 2
    vvvv = (~vreg & 0x0f) << 3

    append_byte(0xc4)
    append_byte(r | x | b | encoding)
    append_byte(vvvv | 5)
end

function vex3sd(reg, vreg, rm, index, encoding)
    # This is the three-byte VEX prefix (VEX3) for scalar-double (sd)
    # and 256-bit ymm registers
    # default encoding is 1
    r = (~reg & 8) << 4
    x = (~index & 8) << 3
    b = (~rm & 8) << 2
    vvvv = (~vreg & 0x0f) << 3

    append_byte(0xc4)
    append_byte(r | x | b | encoding)
    append_byte(vvvv | 3)
end

function vex_sd(reg, vreg, rm, index)
    if rm < 8 && index < 8
        vex2sd(reg, vreg)
    else
        vex3sd(reg, vreg, rm, index, 1)
    end
end

function vex_pd(reg, vreg, rm, index)
    if rm < 8 && index < 8
        vex2pd(reg, vreg)
    else
        vex3pd(reg, vreg, rm, index, 1)
    end
end

function sse_sd(reg, rm)
    append_byte(0xf2) # sd
    rex(reg, rm)
    append_byte(0x0f)
end

function sse_sd_index(reg, rm, index)
    append_byte(0xf2) # sd
    rex_index(reg, rm, index)
    append_byte(0x0f)
end

function sse_pd(reg, rm)
    append_byte(0x66) # pd
    rex(reg, rm)
    append_byte(0x0f)
end

# AVX rules!
function vmovapd(reg, rm)
    vex_pd(reg, 0, rm, 0)
    append_byte(0x28)
    modrm_reg(reg, rm)
end

#******************* scalar double ******************#
function vmovsd_xmm_mem(reg, rm, offset)
    vex_sd(reg, 0, rm, 0)
    append_byte(0x10)
    modrm_mem(reg, rm, offset)
end

function vmovsd_xmm_indexed(reg, base, index, scale)
    vex_sd(reg, 0, base, index)
    append_byte(0x10)
    modrm_sib(reg, base, index, scale)
end

function vmovsd_xmm_label(reg, label)
    vex_sd(reg, 0, 0, 0)
    append_byte(0x10)
    # modr/m byte with MOD=00 and R/M=101 (RIP-relative address)
    append_byte(5 | ((reg & 7) << 3))
    jump(label, 0)
end

function vmovsd_mem_xmm(rm, offset, reg)
    vex_sd(reg, 0, rm, 0)
    append_byte(0x11)
    modrm_mem(reg, rm, offset)
end

function vmovsd_indexed_xmm(base, index, scale, reg)
    vex_sd(reg, 0, base, index)
    append_byte(0x11)
    modrm_sib(reg, base, index, scale)
end

function vaddsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0x58)
    modrm_reg(reg, rm)
end

function vsubsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0x5c)
    modrm_reg(reg, rm)
end

function vmulsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0x59)
    modrm_reg(reg, rm)
end

function vdivsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0x5e)
    modrm_reg(reg, rm)
end

function vsqrtsd(reg, rm)
    vex_sd(reg, 0, rm, 0)
    append_byte(0x51)
    modrm_reg(reg, rm)
end

function vroundsd(reg, rm, mode)
    vex3pd(reg, reg, rm, 0, 3)
    append_byte(0x0b)
    modrm_reg(reg, rm)

    if mode == :round
        append_byte(0)
    elseif mode == :floor
        append_byte(1)
    elseif mode == :ceiling
        append_byte(2)
    elseif mode == :trunc
        append_byte(3)
    end
end

function vcmpeqsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(0)
end

function vcmpltsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(1)
end

function vcmplesd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(2)
end

function vcmpunordsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(3)
end

function vcmpneqsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(4)
end

function vcmpnltsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(5)
end

function vcmpnlesd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(6)
end

function vcmpordsd(reg, vreg, rm)
    vex_sd(reg, vreg, rm, 0)
    append_byte(0xC2)
    modrm_reg(reg, rm)
    append_byte(7)
end

function vucomisd(reg, rm)
    vex_pd(reg, 0, rm, 0)
    append_byte(0x2e)
    modrm_reg(reg, rm)
end

#******************* packed double ******************#
function vbroadcastsd(reg, rm, offset)
    vex3pd(reg, 0, rm, 0, 2)
    append_byte(0x19)
    modrm_mem(reg, rm, offset)
end

function vbroadcastsd_label(reg, label)
    vex3pd(reg, 0, 0, 0, 2)
    append_byte(0x19)
    # modr/m byte with MOD=00 and R/M=101 (RIP-relative address)
    append_byte(5 | ((reg & 7) << 3))
    jump(label, 0)
end

function vmovpd_ymm_mem(reg, rm, offset)
    vex_pd(reg, 0, rm, 0)
    append_byte(0x10)
    modrm_mem(reg, rm, offset)
end

function vmovpd_ymm_indexed(reg, base, index, scale)
    vex_pd(reg, 0, base, index)
    append_byte(0x10)
    modrm_sib(reg, base, index, scale)
end

function vmovpd_ymm_label(reg, label)
    vex_pd(reg, 0, 0, 0)
    append_byte(0x10)
    # modr/m byte with MOD=00 and R/M=101 (RIP-relative address)
    append_byte(5 | ((reg & 7) << 3))
    jump(label, 0)
end

function vmovpd_mem_ymm(rm, offset, reg)
    vex_pd(reg, 0, rm, 0)
    append_byte(0x11)
    modrm_mem(reg, rm, offset)
end

function vmovpd_indexed_ymm(base, index, scale, reg)
    vex_pd(reg, 0, base, index)
    append_byte(0x11)
    modrm_sib(reg, base, index, scale)
end

function vaddpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x58)
    modrm_reg(reg, rm)
end

function vsubpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x5c)
    modrm_reg(reg, rm)
end

function vmulpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x59)
    modrm_reg(reg, rm)
end

function vdivpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x5e)
    modrm_reg(reg, rm)
end

function vsqrtpd(reg, rm)
    vex_pd(reg, 0, rm, 0)
    append_byte(0x51)
    modrm_reg(reg, rm)
end

function vroundpd(reg, rm, mode)
    vex3pd(reg, 0, rm, 0, 3)
    append_byte(0x09)
    modrm_reg(reg, rm)

    if mode == :round
        append_byte(0)
    elseif mode == :floor
        append_byte(1)
    elseif mode == :ceiling
        append_byte(2)
    elseif mode == :trunc
        append_byte(3)
    end
end

function vandpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x54)
    modrm_reg(reg, rm)
end

function vandnpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x55)
    modrm_reg(reg, rm)
end

function vorpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x56)
    modrm_reg(reg, rm)
end

function vxorpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0x57)
    modrm_reg(reg, rm)
end

function vcmpeqpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(0)
end

function vcmpltpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(1)
end

function vcmplepd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(2)
end

function vcmpunordpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(3)
end

function vcmpneqpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(4)
end

function vcmpnltpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(5)
end

function vcmpnlepd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(6)
end

function vcmpordpd(reg, vreg, rm)
    vex_pd(reg, vreg, rm, 0)
    append_byte(0xC2)
    modrm_reg(reg, rm)
    append_byte(7)
end

#******************* SSE scalar double ******************#
function movapd(reg, rm)
    sse_pd(reg, rm)
    append_byte(0x28)
    modrm_reg(reg, rm)
end

function movsd_xmm_mem(reg, rm, offset)
    sse_sd(reg, rm)
    append_byte(0x10)
    modrm_mem(reg, rm, offset)
end

function movsd_xmm_indexed(reg, base, index, scale)
    sse_sd_index(reg, base, index)
    append_byte(0x10)
    modrm_sib(reg, base, index, scale)
end

function movsd_xmm_label(reg, label)
    sse_sd(reg, 0)
    append_byte(0x10)
    # modr/m byte with MOD=00 and R/M=101 (RIP-relative address)
    append_byte(5 | ((reg & 7) << 3))
    jump(label, 0)
end

function movsd_mem_xmm(rm, offset, reg)
    sse_sd(reg, rm)
    append_byte(0x11)
    modrm_mem(reg, rm, offset)
end

function movsd_indexed_xmm(base, index, scale, reg)
    sse_sd_index(reg, base, index)
    append_byte(0x11)
    modrm_sib(reg, base, index, scale)
end

function addsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0x58)
    modrm_reg(reg, rm)
end

function subsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0x5c)
    modrm_reg(reg, rm)
end

function mulsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0x59)
    modrm_reg(reg, rm)
end

function divsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0x5e)
    modrm_reg(reg, rm)
end

function sqrtsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0x51)
    modrm_reg(reg, rm)
end

function roundsd(reg, rm, mode)
    sse_pd(reg, rm)
    append_bytes([0x3a, 0x0b])
    modrm_reg(reg, rm)

    if mode == :round
        append_byte(0)
    elseif mode == :floor
        append_byte(1)
    elseif mode == :ceiling
        append_byte(2)
    elseif mode == :trunc
        append_byte(3)
    end
end

function cmpeqsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(0)
end

function cmpltsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(1)
end

function cmplesd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(2)
end

function cmpunordsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(3)
end

function cmpneqsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(4)
end

function cmpnltsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(5)
end

function cmpnlesd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xc2)
    modrm_reg(reg, rm)
    append_byte(6)
end

function cmpordsd(reg, rm)
    sse_sd(reg, rm)
    append_byte(0xC2)
    modrm_reg(reg, rm)
    append_byte(7)
end

function ucomisd(reg, rm)
    sse_pd(reg, rm)
    append_byte(0x2e)
    modrm_reg(reg, rm)
end

function andpd(reg, rm)
    sse_pd(reg, rm)
    append_byte(0x54)
    modrm_reg(reg, rm)
end

function andnpd(reg, rm)
    sse_pd(reg, rm)
    append_byte(0x55)
    modrm_reg(reg, rm)
end

function orpd(reg, rm)
    sse_pd(reg, rm)
    append_byte(0x56)
    modrm_reg(reg, rm)
end

function xorpd(reg, rm)
    sse_pd(reg, rm)
    append_byte(0x57)
    modrm_reg(reg, rm)
end

#*******************************************#
function vzeroupper()
    append_bytes([0xC5, 0xF8, 0x77])
end

# general registers
function mov(reg, rm)
    rex(reg, rm)
    append_byte(0x8b)
    modrm_reg(reg, rm)
end

function mov_reg_mem(reg, rm, offset)
    rex(reg, rm)
    append_byte(0x8b)
    modrm_mem(reg, rm, offset)
end

function mov_reg_label(reg, label)
    rex(reg, 0)
    append_byte(0x8b)
    # modr/m byte with MOD=00 and R/M=101 (RIP-relative address)
    append_byte(5 | ((reg & 7) << 3))
    jump(label, 0)
end

function mov_mem_reg(rm, offset, reg)
    rex(reg, rm)
    append_byte(0x89)
    modrm_mem(reg, rm, offset)
end

function movabs(rm, imm64)
    rex(0, rm)
    append_byte(0xb8 + (rm & 7))
    append_word(imm64)
    append_word(imm64 >> 32)
end

function call(reg)
    if reg < 8
        append_bytes([0xff, 0xd0 | reg])
    else
        append_bytes([0x41, 0xff, 0xd0 | (reg & 7)])
    end
end

function call_indirect(label)
    append_bytes([0xff, 0x15])
    jump(label, 0)
end

function push(reg)
    if reg < 8
        append_byte(0x50 | reg)
    else
        append_bytes([0x41, 0x50 | (reg & 7)])
    end
end

function pop(reg)
    if reg < 8
        append_byte(0x58 | reg)
    else
        append_bytes([0x41, 0x58 | (reg & 7)])
    end
end

function ret()
    append_byte(0xc3)
end

function add_rsp(imm)
    append_bytes([0x48, 0x81, 0xc4])
    append_word(imm)
end

function sub_rsp(imm)
    append_bytes([0x48, 0x81, 0xec])
    append_word(imm)
end

function or(reg, rm)
    rex(reg, rm)
    append_byte(0x0b)
    modrm_reg(reg, rm)
end

function xor(reg, rm)
    rex(reg, rm)
    append_byte(0x33)
    modrm_reg(reg, rm)
end

function add(reg, rm)
    rex(reg, rm)
    append_byte(0x03)
    modrm_reg(reg, rm)
end

function add_imm(rm, imm)
    rex(0, rm)
    append_byte(0x81)
    modrm_reg(0, rm)
    append_word(imm)
end

function inc(rm)
    rex(0, rm)
    append_byte(0xff)
    modrm_reg(0, rm)
end

function dec(rm)
    rex(0, rm)
    append_byte(0xff)
    modrm_reg(1, rm)
end

function jmp(label)
    append_byte(0xe9)
    jump(label, 0)
end

function jz(label)
    append_bytes([0x0f, 0x84])
    jump(label, 0)
end

function jnz(label)
    append_bytes([0x0f, 0x85])
    jump(label, 0)
end

function jpe(label)
    # jump if parity even is true if vucomisd returns
    # an unordered result
    append_bytes([0x0f, 0x8a])
    jump(label, 0)
end

function nop()
    append_byte(0x90)
end

########################### macros ###########################

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
    xor(dst, s1, TEMP)
end

function abs(dst, s1)
    vmovsd_xmm_label(TEMP, "_minus_zero_")
    andnot(dst, TEMP, s1);
end

function recip(dst, s1)
    vmovsd_xmm_label(TEMP, "_one_")
    divide(dst, TEMP, s1);
end

function not(dst, s1)
    vmovsd_xmm_label(TEMP, "_all_ones_")
    xor(dst, s1, TEMP)
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
    vmovapd(dst, r1)
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
        t = power.trailing_zeros()
        n = power >> (t + 1)
        s = s1

        # nop is required to prevent a bug caused by load/mov peephole optimization
        # nop()

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
