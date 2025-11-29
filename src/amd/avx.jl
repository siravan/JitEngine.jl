function vmovsd_xmm_mem(reg, rm, offset)
    vex_sd(reg, 0, rm, 0)
    append_byte(0x10)
    modrm_mem(reg, rm, offset)
end

function vmovsd_xmm_indexed(reg, base, index, scale)
    @assert scale in [1, 2, 4, 8]
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
    @assert scale in [1, 2, 4, 8]
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
