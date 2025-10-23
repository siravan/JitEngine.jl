mutable struct Assembler
    buf::Vector{UInt8}
    labels::Dict{String,Int}
    jumps::Vector{Any}
    delta::Int
    shift::Int

    Assembler(delta, shift) =
        new(Vector{UInt8}[], Dict{String,Int}(), Vector{Any}(), delta, shift)
end

function bytes()
    global asm
    return asm.buf
end

function append_byte(b)
    global asm
    push!(asm.buf, b)
end

function append_bytes(bs)
    for b in bs
        append_byte(b)
    end
end

function append_word(u)
    # appends u (uint32) as little-endian
    for i = 1:4
        append_byte(u & 0xff)
        u >>= 8
    end
end

function append_quad(u)
    # appends u (uint32) as little-endian
    for i = 1:8
        append_byte(u & 0xff)
        u >>= 8
    end
end

function ip()
    global asm
    return length(asm.buf) + 1
end

function set_label(label)
    global asm
    @assert !haskey(asm.labels, label)
    asm.labels[label] = ip()
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

        # TODO: we need a better place for this check
        # assembler is supposed to be arch agnostic
        #[cfg(target_arch = "aarch64")]
        #    assert!(
        #        offset >= 0 && offset < (1 << 20),
        #        "the code segment is too large!"
        #    )

        x = (offset << asm.shift) | code

        asm.buf[k] |= (x & 0xff)
        asm.buf[k+1] |= (x >> 8) & 0xff
        asm.buf[k+2] |= (x >> 16) & 0xff
        asm.buf[k+3] |= (x >> 24) & 0xff
    end
end
