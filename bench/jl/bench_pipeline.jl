#!/usr/bin/env julia
# Full MA crossover pipeline benchmark

const EPS = 1e-10
const TDY = 252

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

function pstd(x)
    m = sum(x) / length(x)
    sqrt(sum((x .- m).^2) / length(x))
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

function main()
    csv_path = ARGS[1]
    c = load_csv(csv_path)

    # Indicators (prefix-sum MA)
    cs = cumsum(vcat([0.0], c))
    fast = (cs[11:end] .- cs[1:end-10]) ./ 10
    slow = (cs[51:end] .- cs[1:end-50]) ./ 50
    min_len = min(length(fast), length(slow))
    f = fast[end-min_len+1:end]
    s = slow[end-min_len+1:end]

    # Signals
    raw = Float64.(f .> s) .- Float64.(f .< s)
    pos = hold(5, fill_signal(raw))

    # Backtest
    ret = diff(c) ./ c[1:end-1]
    min_len2 = min(length(pos), length(ret))
    pos = pos[end-min_len2+1:end]
    ret = ret[end-min_len2+1:end]
    strat = pos .* ret
    cost = 0.001 .* abs.(diff(vcat([0.0], pos)))
    net = strat .- cost[1:length(strat)]

    # Metrics
    sharpe_val = sqrt(TDY) * (sum(net) / length(net)) / max(pstd(net), EPS)
    eq = cumprod(1.0 .+ net)
    mx = accumulate(max, eq)
    dd = minimum((eq .- mx) ./ mx)
    cagr_val = prod(1.0 .+ net)^(TDY / length(net)) - 1.0

    results = [sharpe_val, dd, cagr_val, sum(eq)]
    for r in results
        println(repr(r))
    end
end

main()
