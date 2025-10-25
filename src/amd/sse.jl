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