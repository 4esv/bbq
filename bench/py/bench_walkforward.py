#!/usr/bin/env python3
"""Walk-forward grid search benchmark."""
import sys
import argparse
import numpy as np
import pandas as pd

EPS = 1e-10
TDY = 252


def load_csv(path):
    df = pd.read_csv(
        path, skiprows=3, header=None,
        names=["date", "close", "high", "low", "open", "volume"],
    )
    return df


def pstd(x):
    return np.sqrt(np.mean((x - np.mean(x)) ** 2))


def sharpe(r):
    return np.sqrt(TDY) * np.mean(r) / max(pstd(r), EPS)


def ma(n, prices):
    cs = np.concatenate([[0], np.cumsum(prices)])
    return (cs[n:] - cs[:-n]) / n


def ma_cross_strategy(params, prices):
    fast_n, slow_n = params
    fast = ma(fast_n, prices)
    slow = ma(slow_n, prices)
    min_len = min(len(fast), len(slow))
    f, s = fast[-min_len:], slow[-min_len:]
    return (f > s).astype(np.float64)


def windows(train_len, test_len, prices):
    n = len(prices)
    nf = 1 + int((n - train_len - test_len) // test_len)
    assert nf > 0, "Not enough data for walk-forward"
    folds = []
    for i in range(nf):
        s = i * test_len
        train_p = prices[s:s + train_len]
        test_p = prices[s + train_len:s + train_len + test_len]
        folds.append((train_p, test_p))
    return folds


def grid_search(grid, folds, cost_rate):
    oos_rets = []

    for train_p, test_p in folds:
        train_ret = np.diff(train_p) / train_p[:-1]
        test_ret = np.diff(test_p) / test_p[:-1]

        # Score all param combos on train
        best_score = -np.inf
        best_idx = 0
        for idx, params in enumerate(grid):
            pos = ma_cross_strategy(params, train_p)
            min_len = min(len(pos), len(train_ret))
            pos_a = pos[-min_len:]
            ret_a = train_ret[-min_len:]
            sr = pos_a * ret_a
            cost = cost_rate * np.abs(np.diff(pos_a, prepend=0.0))
            net = sr - cost[:len(sr)]
            score = sharpe(net)
            if score > best_score:
                best_score = score
                best_idx = idx

        # Evaluate best on test
        best_params = grid[best_idx]
        test_pos = ma_cross_strategy(best_params, test_p)
        min_len = min(len(test_pos), len(test_ret))
        test_pos = test_pos[-min_len:]
        test_ret_a = test_ret[-min_len:]
        test_sr = test_pos * test_ret_a
        test_cost = cost_rate * np.abs(np.diff(test_pos, prepend=0.0))
        test_oos = test_sr - test_cost[:len(test_sr)]
        oos_rets.append(test_oos)

    return np.concatenate(oos_rets)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", help="Path to OHLCV CSV")
    parser.add_argument("--mode", choices=["pandas", "numpy"], default="numpy")
    args = parser.parse_args()
    df = load_csv(args.csv)
    c = df["close"].values.astype(np.float64)

    train_len = 504
    test_len = 126
    cost_rate = 0.001

    # Grid: fast=[5,10,15,20] x slow=[30,40,50,60,70]
    grid = [(f, s) for f in [5, 10, 15, 20] for s in [30, 40, 50, 60, 70]]

    folds = windows(train_len, test_len, c)
    oos = grid_search(grid, folds, cost_rate)

    # Checksums
    eq = np.cumprod(1.0 + oos)
    mx = np.maximum.accumulate(eq)
    print(repr(float(sharpe(oos))))
    print(repr(float(np.min((eq - mx) / mx))))
    print(repr(float(np.prod(1.0 + oos) - 1.0)))
    print(repr(float(np.sum(eq))))


if __name__ == "__main__":
    main()
