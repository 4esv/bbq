#!/usr/bin/env python3
"""Signal utilities benchmark — Cross, Fill, Hold, Thresh."""
import sys
import argparse
import numpy as np
import pandas as pd

EPS = 1e-10


def load_csv(path):
    df = pd.read_csv(
        path, skiprows=3, header=None,
        names=["date", "close", "high", "low", "open", "volume"],
    )
    return df


# ── Signal functions ────────────────────────────────────────


def shift_right(arr):
    """BQN » — shift right, fill with 0."""
    out = np.empty_like(arr)
    out[0] = 0
    out[1:] = arr[:-1]
    return out


def cross(fast, slow):
    """1 where fast crosses above slow."""
    return ((fast >= slow) & (shift_right(fast) < shift_right(slow))).astype(np.float64)


def cross_down(fast, slow):
    """1 where fast crosses below slow."""
    return ((fast <= slow) & (shift_right(fast) > shift_right(slow))).astype(np.float64)


def fill(signals):
    """Forward-fill: hold last non-zero."""
    out = np.empty(len(signals))
    out[0] = signals[0]
    for i in range(1, len(signals)):
        out[i] = signals[i] if signals[i] != 0 else out[i - 1]
    return out


def hold(n, positions):
    """Min n-bar holding period."""
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


def thresh(level, values):
    """1 where value crosses above level."""
    return ((values > level) & (shift_right(values) <= level)).astype(np.float64)


def thresh_down(level, values):
    """1 where value crosses below level."""
    return ((values < level) & (shift_right(values) >= level)).astype(np.float64)


# ── Numpy RSI for thresh tests ──────────────────────────────


def wilder_np(n, arr):
    a = 1.0 / n
    out = np.empty(len(arr))
    out[0] = arr[0]
    for i in range(1, len(arr)):
        out[i] = a * arr[i] + (1 - a) * out[i - 1]
    return out


def rsi_np(n, c):
    deltas = np.diff(c, prepend=c[0])[1:]
    gains = np.maximum(deltas, 0)
    losses = np.maximum(-deltas, 0)
    ag = wilder_np(n, gains)
    al = wilder_np(n, losses)
    return 100 - 100 / (1 + ag / np.maximum(al, EPS))


# ── Main ────────────────────────────────────────────────────


def run_signals(df, mode):
    c = df["close"].values.astype(np.float64)

    # MA cross
    cs = np.concatenate([[0], np.cumsum(c)])
    fast = (cs[10:] - cs[:-10]) / 10
    slow = (cs[50:] - cs[:-50]) / 50
    min_len = min(len(fast), len(slow))
    f, s = fast[-min_len:], slow[-min_len:]

    cr = cross(f, s)
    cd = cross_down(f, s)
    raw = cr - cd
    fl = fill(raw)
    hd = hold(5, fl)

    # Threshold from RSI
    rsi = rsi_np(14, c)
    a70 = thresh(70, rsi)
    b30 = thresh_down(30, rsi)

    results = [cr.sum(), cd.sum(), fl.sum(), hd.sum(), a70.sum(), b30.sum()]
    for r in results:
        print(repr(float(r)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", help="Path to OHLCV CSV")
    parser.add_argument("--mode", choices=["pandas", "numpy"], default="numpy")
    args = parser.parse_args()
    df = load_csv(args.csv)
    run_signals(df, args.mode)
