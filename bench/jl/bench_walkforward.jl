#!/usr/bin/env julia
# Walk-forward grid search benchmark

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

function sharpe(r)
    sqrt(TDY) * (sum(r) / length(r)) / max(pstd(r), EPS)
end

function ma(n, prices)
    cs = cumsum(vcat([0.0], prices))
    (cs[n+1:end] .- cs[1:end-n]) ./ n
end

function ma_cross_strategy(params, prices)
    fast_n, slow_n = params
    fast = ma(fast_n, prices)
    slow = ma(slow_n, prices)
    min_len = min(length(fast), length(slow))
    f = fast[end-min_len+1:end]
    s = slow[end-min_len+1:end]
    Float64.(f .> s)
end

function windows(train_len, test_len, prices)
    n = length(prices)
    nf = 1 + floor(Int, (n - train_len - test_len) / test_len)
    nf < 1 && error("Not enough data for walk-forward")
    folds = Vector{Tuple{Vector{Float64}, Vector{Float64}}}(undef, nf)
    for i in 0:nf-1
        s = i * test_len
        train_p = prices[s+1:s+train_len]
        test_p = prices[s+train_len+1:s+train_len+test_len]
        folds[i+1] = (train_p, test_p)
    end
    folds
end

function grid_search(grid, folds, cost_rate)
    oos_rets = Vector{Float64}[]

    for (train_p, test_p) in folds
        train_ret = diff(train_p) ./ train_p[1:end-1]
        test_ret = diff(test_p) ./ test_p[1:end-1]

        # Score all param combos on train
        best_score = -Inf
        best_idx = 1
        for (idx, params) in enumerate(grid)
            pos = ma_cross_strategy(params, train_p)
            pos = pos[end-min(length(pos), length(train_ret))+1:end]
            train_ret_aligned = train_ret[end-length(pos)+1:end]
            sr = pos .* train_ret_aligned
            cost = cost_rate .* abs.(diff(vcat([0.0], pos)))
            net = sr .- cost[1:length(sr)]
            score = sharpe(net)
            if score > best_score
                best_score = score
                best_idx = idx
            end
        end

        # Evaluate best on test
        best_params = grid[best_idx]
        test_pos = ma_cross_strategy(best_params, test_p)
        min_len = min(length(test_pos), length(test_ret))
        test_pos = test_pos[end-min_len+1:end]
        test_ret_aligned = test_ret[end-min_len+1:end]
        test_sr = test_pos .* test_ret_aligned
        test_cost = cost_rate .* abs.(diff(vcat([0.0], test_pos)))
        test_oos = test_sr .- test_cost[1:length(test_sr)]
        push!(oos_rets, test_oos)
    end

    all_oos = vcat(oos_rets...)
    all_oos
end

function main()
    csv_path = ARGS[1]
    c = load_csv(csv_path)

    train_len = 504
    test_len = 126
    cost_rate = 0.001

    # Grid: fast=[5,10,15,20] × slow=[30,40,50,60,70]
    grid = Tuple{Int,Int}[]
    for f in [5, 10, 15, 20]
        for s in [30, 40, 50, 60, 70]
            push!(grid, (f, s))
        end
    end

    folds = windows(train_len, test_len, c)
    oos = grid_search(grid, folds, cost_rate)

    # Checksums
    eq = cumprod(1.0 .+ oos)
    println(repr(sharpe(oos)))
    println(repr(minimum((eq .- accumulate(max, eq)) ./ accumulate(max, eq))))
    println(repr(prod(1.0 .+ oos) - 1.0))
    println(repr(sum(eq)))
end

main()
