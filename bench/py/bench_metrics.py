#!/usr/bin/env python3
"""Metrics benchmark — all 18 metrics in numpy."""
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


# ── Metric functions ────────────────────────────────────────


def pstd(x):
    return np.sqrt(np.mean((x - np.mean(x)) ** 2))


def sharpe(r):
    return np.sqrt(TDY) * np.mean(r) / max(pstd(r), EPS)


def sortino(r):
    dd = np.minimum(r, 0)
    ds = np.sqrt(np.mean(dd**2))
    return np.sqrt(TDY) * np.mean(r) / max(ds, EPS)


def dd_series(r):
    eq = np.cumprod(1 + r)
    mx = np.maximum.accumulate(eq)
    return (eq - mx) / mx


def maxdd(r):
    return np.min(dd_series(r))


def maxdd_dur(r):
    dd = dd_series(r)
    in_dd = dd < 0
    lengths = np.zeros(len(dd), dtype=int)
    for i in range(len(dd)):
        if in_dd[i]:
            lengths[i] = (lengths[i - 1] if i > 0 else 0) + 1
    return int(np.max(lengths)) if len(lengths) > 0 else 0


def total_ret(r):
    return np.prod(1 + r) - 1


def cagr(r):
    return np.prod(1 + r) ** (TDY / len(r)) - 1


def ann_vol(r):
    return pstd(r) * np.sqrt(TDY)


def calmar(r):
    return cagr(r) / max(abs(maxdd(r)), EPS)


def win_rate(r):
    active = r != 0
    return np.sum(r > 0) / max(np.sum(active), 1)


def profit_factor(r):
    gross_profit = np.sum(r[r > 0])
    gross_loss = abs(np.sum(r[r < 0]))
    return gross_profit / max(gross_loss, EPS)


def avg_win(r):
    w = r[r > 0]
    return np.sum(w) / max(len(w), 1)


def avg_loss(r):
    lo = r[r < 0]
    return np.sum(lo) / max(len(lo), 1)


def expectancy(r):
    wr = win_rate(r)
    return wr * avg_win(r) + (1 - wr) * avg_loss(r)


def trades(pos):
    # BQN's » fills with 0 — first position change from flat counts
    return int(np.sum(np.diff(pos, prepend=0) != 0))


def time_in(pos):
    return np.sum(pos != 0) / len(pos)


def skew(r):
    m, s = np.mean(r), max(pstd(r), EPS)
    return np.mean(((r - m) / s) ** 3)


def kurt(r):
    m, s = np.mean(r), max(pstd(r), EPS)
    return np.mean(((r - m) / s) ** 4) - 3


def equity(r):
    return np.cumprod(1 + r)


# ── Main ────────────────────────────────────────────────────


def run_metrics(df, mode):
    c = df["close"].values.astype(np.float64)
    n = len(c)

    # MA cross strategy (same as BQN bench)
    cs = np.concatenate([[0], np.cumsum(c)])
    fast = (cs[10:] - cs[:-10]) / 10
    slow = (cs[50:] - cs[:-50]) / 50
    min_len = min(len(fast), len(slow))
    fast, slow = fast[-min_len:], slow[-min_len:]
    pos = (fast > slow).astype(np.float64)
    ret = np.diff(c) / c[:-1]
    min_len2 = min(len(pos), len(ret))
    pos, ret = pos[-min_len2:], ret[-min_len2:]
    strat = pos * ret

    results = [
        sharpe(strat), sortino(strat), maxdd(strat),
        maxdd_dur(strat), total_ret(strat), cagr(strat),
        ann_vol(strat), calmar(strat), win_rate(strat),
        profit_factor(strat), avg_win(strat), avg_loss(strat),
        expectancy(strat), trades(pos), time_in(pos),
        skew(strat), kurt(strat), np.sum(equity(strat)),
    ]
    for r in results:
        print(repr(float(r)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", help="Path to OHLCV CSV")
    parser.add_argument("--mode", choices=["pandas", "numpy"], default="numpy")
    args = parser.parse_args()
    df = load_csv(args.csv)
    run_metrics(df, args.mode)
