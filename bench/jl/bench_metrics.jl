#!/usr/bin/env julia
# Metrics benchmark — all 18 metrics in Julia

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

function ma(n, prices)
    cs = cumsum(vcat([0.0], prices))
    (cs[n+1:end] .- cs[1:end-n]) ./ n
end

function pstd(x)
    m = sum(x) / length(x)
    sqrt(sum((x .- m).^2) / length(x))
end

function sharpe(r)
    sqrt(TDY) * (sum(r) / length(r)) / max(pstd(r), EPS)
end

function sortino(r)
    m = sum(r) / length(r)
    dd = min.(r, 0.0)
    ds = sqrt(sum(dd.^2) / length(r))
    sqrt(TDY) * m / max(ds, EPS)
end

function dd_series(r)
    eq = cumprod(1.0 .+ r)
    mx = accumulate(max, eq)
    (eq .- mx) ./ mx
end

function maxdd(r)
    minimum(dd_series(r))
end

function maxdd_dur(r)
    dd = dd_series(r)
    in_dd = dd .< 0
    lengths = zeros(Int, length(dd))
    for i in 1:length(dd)
        if in_dd[i]
            lengths[i] = (i > 1 ? lengths[i-1] : 0) + 1
        end
    end
    maximum(lengths; init=0)
end

function total_ret(r)
    prod(1.0 .+ r) - 1.0
end

function cagr(r)
    prod(1.0 .+ r)^(TDY / length(r)) - 1.0
end

function ann_vol(r)
    pstd(r) * sqrt(TDY)
end

function calmar(r)
    cagr(r) / max(abs(maxdd(r)), EPS)
end

function win_rate(r)
    active = r .!= 0
    sum(r .> 0) / max(sum(active), 1)
end

function profit_factor(r)
    gross_profit = sum(r[r .> 0])
    gross_loss = abs(sum(r[r .< 0]))
    gross_profit / max(gross_loss, EPS)
end

function avg_win(r)
    w = r[r .> 0]
    sum(w) / max(length(w), 1)
end

function avg_loss(r)
    lo = r[r .< 0]
    sum(lo) / max(length(lo), 1)
end

function expectancy(r)
    wr = win_rate(r)
    wr * avg_win(r) + (1 - wr) * avg_loss(r)
end

function trades(pos)
    sum(diff(vcat([0.0], pos)) .!= 0)
end

function time_in(pos)
    sum(pos .!= 0) / length(pos)
end

function skew(r)
    m = sum(r) / length(r)
    s = max(pstd(r), EPS)
    sum(((r .- m) ./ s).^3) / length(r)
end

function kurt(r)
    m = sum(r) / length(r)
    s = max(pstd(r), EPS)
    sum(((r .- m) ./ s).^4) / length(r) - 3
end

function equity(r)
    cumprod(1.0 .+ r)
end

function main()
    csv_path = ARGS[1]
    c = load_csv(csv_path)
    n = length(c)

    # MA cross strategy (same as BQN/Python bench)
    cs = cumsum(vcat([0.0], c))
    fast = (cs[11:end] .- cs[1:end-10]) ./ 10
    slow = (cs[51:end] .- cs[1:end-50]) ./ 50
    min_len = min(length(fast), length(slow))
    fast = fast[end-min_len+1:end]
    slow = slow[end-min_len+1:end]
    pos = Float64.(fast .> slow)
    ret = diff(c) ./ c[1:end-1]
    min_len2 = min(length(pos), length(ret))
    pos = pos[end-min_len2+1:end]
    ret = ret[end-min_len2+1:end]
    strat = pos .* ret

    results = [
        sharpe(strat), sortino(strat), maxdd(strat),
        Float64(maxdd_dur(strat)), total_ret(strat), cagr(strat),
        ann_vol(strat), calmar(strat), win_rate(strat),
        profit_factor(strat), avg_win(strat), avg_loss(strat),
        expectancy(strat), Float64(trades(pos)), time_in(pos),
        skew(strat), kurt(strat), sum(equity(strat)),
    ]
    for r in results
        println(repr(r))
    end
end

main()
