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