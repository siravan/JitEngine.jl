mutable struct Assembler
    buf::Vector{UInt8}
    labels::Dict{String,Int}
    jumps::Vector{Any}
    delta::Int
    shift::Int
    mask::Int

    Assembler(delta, shift, mask=0xffffffff) =
        new(Vector{UInt8}[], Dict{String,Int}(), Vector{Any}(), delta, shift, mask)
end

function bytes()
    global asm
    return asm.buf
end

function append_byte(b)
    global asm
    push!(asm.buf, b)
    return 1
end

function append_bytes(bs)
    for b in bs
        append_byte(b)
    end
    return length(bs)
end

function append_word(u)
    # appends u (uint32) as little-endian
    for i = 1:4
        append_byte(u & 0xff)
        u >>= 8
    end
    return 4
end

function append_quad(u)
    # appends u (uint32) as little-endian
    for i = 1:8
        append_byte(u & 0xff)
        u >>= 8
    end
    return 8
end

function ip()
    global asm
    # + 1 because of Julia 1-indexing
    return length(asm.buf) + 1
end

function set_label(label)
    global asm
    @assert !haskey(asm.labels, label)
    asm.labels[label] = ip()
    return ip()
end

function jump(label, code)
    global asm
    push!(asm.jumps, (label, ip(), code))
    append_word(code)
end

function apply_jumps()
    global asm
    for (label, k, code) in asm.jumps
        target = asm.labels[label]
        offset = target - k + asm.delta
println(offset)
println(asm.mask)
        x = ((offset << asm.shift) & asm.mask) | code
println(x)
        asm.buf[k] |= (x & 0xff)
        asm.buf[k+1] |= (x >> 8) & 0xff
        asm.buf[k+2] |= (x >> 16) & 0xff
        asm.buf[k+3] |= (x >> 24) & 0xff
    end
end
