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
    if base == RBP
        append_byte(0x44 + ((reg & 7) << 3)) # R/M = 0b100, MOD = 0b00
        scale = trailing_zeros(scale) << 6
        append_byte((scale | (index & 7) << 3) | (base & 7))
        append_byte(0)
    else
        append_byte(0x04 + ((reg & 7) << 3)) # R/M = 0b100, MOD = 0b00
        scale = trailing_zeros(scale) << 6
        append_byte((scale | (index & 7) << 3) | (base & 7))
    end
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

############### common instructions (AVX and Vector) ################
#
function vmovapd(reg, rm)
    vex_pd(reg, 0, rm, 0)
    append_byte(0x28)
    modrm_reg(reg, rm)
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

function vzeroupper()
    append_bytes([0xC5, 0xF8, 0x77])
end

#*******************************************#

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

function or_(reg, rm)
    rex(reg, rm)
    append_byte(0x0b)
    modrm_reg(reg, rm)
end

function xor_(reg, rm)
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

function cmp(reg, rm)
    rex(reg, rm)
    append_byte(0x3b)
    modrm_reg(reg, rm)
end

function cmp_imm(rm, imm)
    rex(0, rm)
    append_byte(0x81)
    modrm_reg(7, rm)    # note that the cmp opcode is coded in the R/MMod byte
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

# jump less
function jl(label)
    append_bytes([0x0f, 0x8c])
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

##############################################################

include("avx.jl")
# include("sse.jl")
# include("vector.jl")
include("macros.jl")
