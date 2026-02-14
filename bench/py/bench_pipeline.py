#!/usr/bin/env python3
"""Full MA crossover pipeline benchmark."""
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


def fill(signals):
    out = np.empty(len(signals))
    out[0] = signals[0]
    for i in range(1, len(signals)):
        out[i] = signals[i] if signals[i] != 0 else out[i - 1]
    return out


def hold(n, positions):
    pos, count = 0.0, 0
    out = np.empty(len(positions))
    for i in range(len(positions)):
        if count > 0:
            count -= 1
            out[i] = pos
        elif positions[i] != pos:
            count = (n - 1) if positions[i] != 0 else 0
            pos = positions[i]
            out[i] = pos
        else:
            out[i] = pos
    return out


# ── Pandas pipeline ─────────────────────────────────────────


def pipeline_pandas(df):
    c = df["close"]

    # Indicators
    fast = c.rolling(10).mean()
    slow = c.rolling(50).mean()

    # Signals
    raw = (fast > slow).astype(float) - (fast < slow).astype(float)
    raw = raw.dropna().values
    pos = hold(5, fill(raw))

    # Backtest
    ret = c.pct_change().dropna().values
    min_len = min(len(pos), len(ret))
    pos, ret = pos[-min_len:], ret[-min_len:]
    strat = pos * ret
    cost = 0.001 * np.abs(np.diff(pos, prepend=0.0))
    net = strat - cost[: len(strat)]

    # Metrics
    sharpe = np.sqrt(TDY) * np.mean(net) / max(pstd(net), EPS)
    eq = np.cumprod(1 + net)
    mx = np.maximum.accumulate(eq)
    dd = np.min((eq - mx) / mx)
    cagr_val = np.prod(1 + net) ** (TDY / len(net)) - 1

    results = [sharpe, dd, cagr_val, eq.sum()]
    for r in results:
        print(repr(float(r)))


# ── Numpy pipeline ──────────────────────────────────────────


def pipeline_numpy(df):
    c = df["close"].values.astype(np.float64)

    # Indicators (prefix-sum MA)
    cs = np.concatenate([[0], np.cumsum(c)])
    fast = (cs[10:] - cs[:-10]) / 10
    slow = (cs[50:] - cs[:-50]) / 50
    min_len = min(len(fast), len(slow))
    f, s = fast[-min_len:], slow[-min_len:]

    # Signals
    raw = (f > s).astype(np.float64) - (f < s).astype(np.float64)
    pos = hold(5, fill(raw))

    # Backtest
    ret = np.diff(c) / c[:-1]
    min_len2 = min(len(pos), len(ret))
    pos, ret = pos[-min_len2:], ret[-min_len2:]
    strat = pos * ret
    cost = 0.001 * np.abs(np.diff(pos, prepend=0.0))
    net = strat - cost[: len(strat)]

    # Metrics
    sharpe = np.sqrt(TDY) * np.mean(net) / max(pstd(net), EPS)
    eq = np.cumprod(1 + net)
    mx = np.maximum.accumulate(eq)
    dd = np.min((eq - mx) / mx)
    cagr_val = np.prod(1 + net) ** (TDY / len(net)) - 1

    results = [sharpe, dd, cagr_val, eq.sum()]
    for r in results:
        print(repr(float(r)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", help="Path to OHLCV CSV")
    parser.add_argument("--mode", choices=["pandas", "numpy"], default="pandas")
    args = parser.parse_args()
    df = load_csv(args.csv)
    if args.mode == "pandas":
        pipeline_pandas(df)
    else:
        pipeline_numpy(df)
