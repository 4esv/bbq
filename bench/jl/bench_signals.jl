#!/usr/bin/env julia
# Signal utilities benchmark — Cross, Fill, Hold, Thresh

const EPS = 1e-10

function load_csv(path)
    lines = readlines(path)
    data = lines[4:end]
    n = length(data)
    close = Vector{Float64}(undef, n)
    for i in 1:n
        parts = split(data[i], ',')
        close[i] = parse(Float64, parts[2])
    end
    close
end

function ma(n, prices)
    cs = cumsum(vcat([0.0], prices))
    (cs[n+1:end] .- cs[1:end-n]) ./ n
end

function shift_right(arr)
    vcat([0.0], arr[1:end-1])
end

function cross(fast, slow)
    Float64.((fast .>= slow) .& (shift_right(fast) .< shift_right(slow)))
end

function cross_down(fast, slow)
    Float64.((fast .<= slow) .& (shift_right(fast) .> shift_right(slow)))
end

function fill_signal(signals)
    out = similar(signals)
    out[1] = signals[1]
    for i in 2:length(signals)
        out[i] = signals[i] != 0 ? signals[i] : out[i-1]
    end
    out
end

function hold(n, positions)
    pos = 0.0
    count = 0
    out = similar(positions)
    for i in 1:length(positions)
        if count > 0
            count -= 1
            out[i] = pos
        elseif positions[i] != pos
            count = positions[i] != 0 ? (n - 1) : 0
            pos = positions[i]
            out[i] = pos
        else
            out[i] = pos
        end
    end
    out
end

function thresh(level, values)
    Float64.((values .> level) .& (shift_right(values) .<= level))
end

function thresh_down(level, values)
    Float64.((values .< level) .& (shift_right(values) .>= level))
end

function wilder(n, arr)
    a = 1.0 / n
    out = similar(arr)
    out[1] = arr[1]
    for i in 2:length(arr)
        out[i] = a * arr[i] + (1 - a) * out[i-1]
    end
    out
end

function rsi(n, c)
    deltas = diff(vcat([c[1]], c))[2:end]
    gains = max.(deltas, 0.0)
    losses = max.(-deltas, 0.0)
    ag = wilder(n, gains)
    al = wilder(n, losses)
    100.0 .- 100.0 ./ (1.0 .+ ag ./ max.(al, EPS))
end

function main()
    csv_path = ARGS[1]
    c = load_csv(csv_path)

    # MA cross
    fast = ma(10, c)
    slow = ma(50, c)
    min_len = min(length(fast), length(slow))
    f = fast[end-min_len+1:end]
    s = slow[end-min_len+1:end]

    cr = cross(f, s)
    cd = cross_down(f, s)
    raw = cr .- cd
    fl = fill_signal(raw)
    hd = hold(5, fl)

    # Threshold from RSI
    r = rsi(14, c)
    a70 = thresh(70.0, r)
    b30 = thresh_down(30.0, r)

    results = [sum(cr), sum(cd), sum(fl), sum(hd), sum(a70), sum(b30)]
    for r in results
        println(repr(r))
    end
end

main()
