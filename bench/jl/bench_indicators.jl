#!/usr/bin/env julia
# Indicator benchmark — base (raw arrays) vs pkg (RollingFunctions.jl)

const EPS = 1e-10

function load_csv(path)
    lines = readlines(path)
    # Skip 3 header lines (yfinance format)
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
    close, high, low, open_, vol
end

# ── Base implementations (raw Julia arrays) ──────────────

function ma(n, prices)
    cs = cumsum(vcat([0.0], prices))
    (cs[n+1:end] .- cs[1:end-n]) ./ n
end

function ema(n, prices)
    alpha = 2.0 / (1 + n)
    out = similar(prices)
    out[1] = prices[1]
    for i in 2:length(prices)
        out[i] = alpha * prices[i] + (1 - alpha) * out[i-1]
    end
    out
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
    deltas = diff(vcat([c[1]], c))  # prepend c[1] so diff[1] = 0
    deltas = deltas[2:end]          # drop the leading 0
    gains = max.(deltas, 0.0)
    losses = max.(-deltas, 0.0)
    ag = wilder(n, gains)
    al = wilder(n, losses)
    100.0 .- 100.0 ./ (1.0 .+ ag ./ max.(al, EPS))
end

function atr(n, c, h, l)
    # BQN's » fills with 0
    prev_c = vcat([0.0], c[1:end-1])
    tr = max.(h .- l, max.(abs.(h .- prev_c), abs.(l .- prev_c)))
    wilder(n, tr)[2:end]
end

function bb_upper(n, k, c)
    m = ma(n, c)
    # Rolling std (population, ddof=0)
    stds = Vector{Float64}(undef, length(c) - n + 1)
    for i in 1:length(stds)
        win = @view c[i:i+n-1]
        mu = sum(win) / n
        stds[i] = sqrt(sum((win .- mu).^2) / n)
    end
    m .+ k .* stds
end

function stoch_k(n, c, h, l)
    len = length(c) - n + 1
    out = Vector{Float64}(undef, len)
    for i in 1:len
        hi = maximum(@view h[i:i+n-1])
        lo = minimum(@view l[i:i+n-1])
        rng = max(hi - lo, EPS)
        out[i] = 100.0 * (c[i+n-1] - lo) / rng
    end
    out
end

function obv(c, v)
    # BQN's » fills with 0, so first diff = c[1] - 0 = c[1]
    d = diff(vcat([0.0], c))
    cumsum(sign.(d) .* v)
end

function vwap(c, h, l, v)
    tp = (h .+ l .+ c) ./ 3.0
    cumsum(tp .* v) ./ cumsum(v)
end

function indicators_base(c, h, l, v)
    ma20  = ma(20, c)
    ma50  = ma(50, c)
    ema20 = ema(20, c)
    rsi14 = rsi(14, c)
    atr14 = atr(14, c, h, l)
    upper = bb_upper(20, 2.0, c)
    k     = stoch_k(14, c, h, l)
    o     = obv(c, v)
    vw    = vwap(c, h, l, v)

    sums = [sum(ma20), sum(ma50), sum(ema20), sum(rsi14),
            sum(atr14), sum(upper), sum(k), sum(o), sum(vw)]
    for s in sums
        println(repr(s))
    end
end

# ── Pkg implementations (RollingFunctions.jl) ────────────

using RollingFunctions

function indicators_pkg(c, h, l, v)
    ma20  = rollmean(c, 20)
    ma50  = rollmean(c, 50)
    ema20 = ema(20, c)  # still manual — no exact ewm in RollingFunctions
    rsi14 = rsi(14, c)
    atr14 = atr(14, c, h, l)
    upper = bb_upper(20, 2.0, c)
    k     = stoch_k(14, c, h, l)
    o     = obv(c, v)
    vw    = vwap(c, h, l, v)

    sums = [sum(ma20), sum(ma50), sum(ema20), sum(rsi14),
            sum(atr14), sum(upper), sum(k), sum(o), sum(vw)]
    for s in sums
        println(repr(s))
    end
end

# ── Main ─────────────────────────────────────────────────

function main()
    csv_path = ARGS[1]
    mode = length(ARGS) >= 3 && ARGS[2] == "--mode" ? ARGS[3] : "base"

    c, h, l, o, v = load_csv(csv_path)

    if mode == "base"
        indicators_base(c, h, l, v)
    else
        indicators_pkg(c, h, l, v)
    end
end

main()
