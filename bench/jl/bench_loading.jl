#!/usr/bin/env julia
# CSV parse benchmark — base (readdlm) vs pkg (CSV.jl)

function loading_base(path)
    lines = readlines(path)
    data = lines[4:end]
    n = length(data)
    close = Vector{Float64}(undef, n)
    high  = Vector{Float64}(undef, n)
    low   = Vector{Float64}(undef, n)
    open_ = Vector{Float64}(undef, n)
    vol   = Vector{Float64}(undef, n)
    for i in 1:n
        parts = split(data[i], ',')
        close[i] = parse(Float64, parts[2])
        high[i]  = parse(Float64, parts[3])
        low[i]   = parse(Float64, parts[4])
        open_[i] = parse(Float64, parts[5])
        vol[i]   = parse(Float64, parts[6])
    end
    # Checksum to prevent dead-code elimination
    println(repr(sum(close) + sum(high) + sum(low) + sum(open_) + sum(vol)))
end

using CSV, DataFrames

function loading_pkg(path)
    df = CSV.read(path, DataFrame; header=3, skipto=4)
    c = df[!, 2]
    h = df[!, 3]
    l = df[!, 4]
    o = df[!, 5]
    v = df[!, 6]
    println(repr(sum(c) + sum(h) + sum(l) + sum(o) + sum(v)))
end

function main()
    csv_path = ARGS[1]
    mode = length(ARGS) >= 3 && ARGS[2] == "--mode" ? ARGS[3] : "base"

    if mode == "base"
        loading_base(csv_path)
    else
        loading_pkg(csv_path)
    end
end

main()
