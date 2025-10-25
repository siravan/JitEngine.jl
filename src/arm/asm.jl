function reg(s::Symbol)
    if s == :sp
        return 31
    elseif s == :lr
        return 30
    elseif s == :zr || s == :xzr
        return 31
    else
        error("unrecognized register name")
    end
end

reg(x::T) where T <: Integer = x

function rd!(x)
    x = reg(x)
    @assert x < 32
    return x
end

function rn!(x)
    x = reg(x)
    @assert x < 32
    return x << 5
end

function rd2!(x)
    x = reg(x)
    @assert x < 32
    return x << 10
end

function ra!(x)
    x = reg(x)
    @assert x < 32
    return x << 10
end

function rm!(x)
    x = reg(x)
    @assert x < 32
    x << 16
end

function imm!(x)
    @assert x < 4096
    return x << 10
end

function imm16!(x)
    @assert x < 65536
    return x << 5
end

function ofs!(x)
    @assert (x & 7 == 0) && (x < 32768)
    return x << 7
end

function of7!(x)
    @assert (x & 7 == 0) && (x <= 504)
    return x << 12
end

# main rules

# fmov d(rd), d(rn)
fmov(rd, rn) = append_word(0x1e604000 | rd!(rd) | rn!(rn))

# mov x(rd), x(rm)
mov(rd, rm) = append_word(0xaa0003e0 | rd!(rd) | rm!(rm))

# movz x(rd), #imm16
movz(rd, imm16) = append_word(0xd2800000 | rd!(rd) | imm16!(imm16))

# single register load/store instructions
# ldr d(rd), [x(rn), #ofs]
# # ldr d(rd), [x(rn), x(rm), lsl #3]
function ldr_d(rd, rn, ofs, lsl=false)
    if lsl
        w = 0xfc607800 | rd!(rd) | rn!(rn) | rm!(rm)
    else
        w = 0xfd400000 | rd!(rd) | rn!(rn) | ofs!(ofs)
    end
    append_word(w)
end

# ldr x(rd), [x(rn), #ofs]
ldr_x(rd, rn, ofs) = append_word(0xf9400000 | rd!(rd) | rn!(rn) | ofs!(ofs))

# ldr x(rd), [x(rn), x(rm), lsl #3]
ldr_x(rd, rn, rm, lsl) = append_word(0xf8607800 | rd!(rd) | rn!(rn) | rm!(rm))

# ldr d(rd), label
ldr_d_label(rd, label) = jump(label, 0x5c000000 | rd!(rd))

# ldr x(rd), label
ldr_x_label(rd, label) = jump(label, 0x58000000 | rd!(rd))

# str d(rd), [x(rn), #ofs:expr]
# str d(rd), [x(rn), x(rm), lsl #3]
function str_d(rd, rn, ofs, lsl=false)
    if lsl
        w = 0xfc207800 | rd!(rd) | rn!(rn) | rm!(rm)
    else
        w = 0xfd000000 | rd!(rd) | rn!(rn) | ofs!(ofs)
    end
    append_word(w)
end

# str x(rd), [x(rn), #ofs]
str_x(rd, rn, ofs) = append_word(0xf9000000 | rd!(rd) | rn!(rn) | ofs!(ofs))

# paired-registers load/store instructions
# ldp d(rd), d(rd2), [x(rn), #of7]
ldp_d(rd, rd2, rn, of7) = append_word(0x6d400000 | rd!(rd) | rd2!(rd2) | rn!(rn) | of7!(of7))

# ldp x(rd), x(rd2), [x(rn), #of7]
ldp_x(rd, rd2, rn, of7) = append_word(0xa9400000 | rd!(rd) | rd2!(rd2) | rn!(rn) | of7!(of7))

# stp d(rd), d(rd2), [x(rn), #of7]
stp_d(rd, rd2, rn, of7) = append_word(0x6d000000 | rd!(rd) | rd2!(rd2) | rn!(rn) | of7!(of7))

# stp x(rd), x(rd2), [x(rn), #$of7:expr]
stp_x(rd, rd2, rn, of7) = append_word(0xa9000000 | rd!(rd) | rd2!(rd2) | rn!(rn) | of7!(of7))

# x-registers immediate ops
#
# add x(rd), x(rn), #imm
# add x(rd), x(rn), #imm, lsl #12
function add_x_imm(rd, rn, imm, lsl=false)
    if lsl
        w = 0x91400000 | rd!(rd) | rn!(rn) | imm!(imm)
    else
        w = 0x91000000 | rd!(rd) | rn!(rn) | imm!(imm)
    end
    append_word(w)
end

# sub x(rd), x(rn), #imm
# sub x(rd), x(rn), #imm, lsl #12
function sub_x_imm(rd, rn, imm, lsl=false)
    if lsl
        w = 0xd1400000 | rd!(rd) | rn!(rn) | imm!(imm)
    else
        w = 0xd1000000 | rd!(rd) | rn!(rn) | imm!(imm)
    end
    append_word(w)
end

# floating point ops

fadd(rd, rn, rm) = append_word(0x1e602800 | rd!(rd) | rn!(rn) | rm!(rm))
fsub(rd, rn, rm) = append_word(0x1e603800 | rd!(rd) | rn!(rn) | rm!(rm))
fmul(rd, rn, rm) = append_word(0x1e600800 | rd!(rd) | rn!(rn) | rm!(rm))
fdiv(rd, rn, rm) = append_word(0x1e601800 | rd!(rd) | rn!(rn) | rm!(rm))
fsqrt(rd, rn) = append_word(0x1e61c000 | rd!(rd) | rn!(rn))
fneg(rd, rn) = append_word(0x1e614000 | rd!(rd) | rn!(rn))
fabs(rd, rn) = append_word(0x1e60c000 | rd!(rd) | rn!(rn))

# rd := rm * rn + ra
fmadd(rd, rn, rm, ra) = append_word(0x1f400000 | rd!(rd) | rn!(rn) | rm!(rm) | ra!(ra))

# rd := -rm * rn + ra
fmsub(rd, rn, rm, ra) = append_word(0x1f408000 | rd!(rd) | rn!(rn) | rm!(rm) | ra!(ra))

# rd := -(rm * rn + ra)
fnmadd(rd, rn, rm, ra) = append_word(0x1f600000 | rd!(rd) | rn!(rn) | rm!(rm) | ra!(ra))

# rd := -(rm * rn - ra)
fnmsub(rd, rn, rm, ra) = append_word(0x1f608000 | rd!(rd) | rn!(rn) | rm!(rm) | ra!(ra))

# round double to integral (double-coded integer)
frinti(rd, rn) = append_word(0x1e67c000 | rd!(rd) | rn!(rn))

# floor (round toward minus inf) double to integral (double-coded integer)
frintm(rd, rn) = append_word(0x1e654000 | rd!(rd) | rn!(rn))

# ceiling (round toward positive inf) double to integral (double-coded integer)
frintp(rd, rn) = append_word(0x1e64c000 | rd!(rd) | rn!(rn))

#  trunc (round toward zero) double to integral (double-coded integer)
frintz(rd, rn) = append_word(0x1e65c000 | rd!(rd) | rn!(rn))

# logical ops
and(rd, rn, rm) = append_word(0x0e201c00 | rd!(rd) | rn!(rn) | rm!(rm))
orr(rd, rn, rm) = append_word(0x0ea01c00 | rd!(rd) | rn!(rn) | rm!(rm))
eor(rd, rn, rm) = append_word(0x2e201c00 | rd!(rd) | rn!(rn) | rm!(rm))
bit(rd, rn, rm) = append_word(0x2ea01c00 | rd!(rd) | rn!(rn) | rm!(rm))
bif(rd, rn, rm) = append_word(0x2ee01c00 | rd!(rd) | rn!(rn) | rm!(rm))
bsl(rd, rn, rm) = append_word(0x2e601c00 | rd!(rd) | rn!(rn) | rm!(rm))
not(rd, rn) = append_word(0x2e205800 | rd!(rd) | rn!(rn))

# comparison
fcmeq(rd, rn, rm) = append_word(0x5e60e400 | rd!(rd) | rn!(rn) | rm!(rm))
# note that rm and rn are exchanged for fcmlt and fcmle
fcmlt(rd, rm, rn) = append_word(0x7ee0e400 | rd!(rd) | rn!(rn) | rm!(rm))
fcmle(rd, rm, rn) = append_word(0x7e60e400 | rd!(rd) | rn!(rn) | rm!(rm))

fcmgt(rd, rn, rm) = append_word(0x7ee0e400 | rd!(rd) | rn!(rn) | rm!(rm))
fcmge(rd, rn, rm) = append_word(0x7e60e400 | rd!(rd) | rn!(rn) | rm!(rm))

# compare rn with 0.0 and set the flags (NZCV)
fcmp_zero(rn) = append_word(0x1e602008 | rn!(rn))

# misc
b_eq(label) = jump(label, 0x54000000)
b_ne(label) = jump(label, 0x54000001)
b_lt(label) = jump(label, 0x5400000B)
b_le(label) = jump(label, 0x5400000D)
b_gt(label) = jump(label, 0x5400000C)
b_ge(label) = jump(label, 0x5400000A)

tst(rn, rm) = append_word(0xea00001f | rn!(rn) | rm!(rm))

blr(rn) = append_word(0xd63f0000 | rn!(rn))
ret() = append_word(0xd65f03c0)

function fmov_const(rd, val)
    if val == 0.0
        w = 0x9e6703e0 | rd!(rd)
    elseif val == 1.0
        w = 0x1e6e1000 | rd!(rd)
    elseif val == -1.0
        w = 0x1e7e1000 | rd!(rd)
    else
        error("undefined constant: $val")
    end
    append_word(w)
end
