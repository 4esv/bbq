#!/usr/bin/env python3
"""Indicator benchmark — pandas vs numpy implementations."""
import sys
import argparse
import numpy as np
import pandas as pd

EPS = 1e-10


def load_csv(path):
    """Load yfinance CSV (3 header lines)."""
    df = pd.read_csv(
        path, skiprows=3, header=None,
        names=["date", "close", "high", "low", "open", "volume"],
    )
    return df


# ── Pandas implementations ──────────────────────────────────


def wilder_pd(n, series):
    """Wilder smoothing via ewm (com=n-1, adjust=False)."""
    return series.ewm(com=n - 1, adjust=False).mean()


def indicators_pandas(df):
    c, h, l, v = df["close"], df["high"], df["low"], df["volume"]

    ma20 = c.rolling(20).mean().dropna()
    ma50 = c.rolling(50).mean().dropna()
    ema20 = c.ewm(span=20, adjust=False).mean()

    # RSI
    delta = c.diff()
    gain = delta.clip(lower=0)
    loss = (-delta).clip(lower=0)
    ag = wilder_pd(14, gain)
    al = wilder_pd(14, loss)
    rsi = 100 - 100 / (1 + ag / al.clip(lower=EPS))
    rsi = rsi.iloc[1:]  # drop first NaN row

    # ATR — BQN's » fills with 0 (not first element)
    prev_c = c.shift(1).fillna(0)
    tr = pd.concat(
        [h - l, (h - prev_c).abs(), (l - prev_c).abs()], axis=1
    ).max(axis=1)
    atr = wilder_pd(14, tr).iloc[1:]

    # Bollinger Bands
    mid = c.rolling(20).mean()
    std = c.rolling(20).std(ddof=0)
    upper = (mid + 2 * std).dropna()

    # Stochastic
    lo = l.rolling(14).min()
    hi = h.rolling(14).max()
    rng = (hi - lo).clip(lower=EPS)
    k = (100 * (c - lo) / rng).dropna()

    # OBV — BQN's » fills with 0, so first diff = c[0] - 0 = c[0]
    delta = c.diff()
    delta.iloc[0] = c.iloc[0]
    signs = np.sign(delta)
    obv = (signs * v).cumsum()

    # VWAP
    tp = (h + l + c) / 3
    vwap = (tp * v).cumsum() / v.cumsum()

    sums = [ma20.sum(), ma50.sum(), ema20.sum(), rsi.sum(),
            atr.sum(), upper.sum(), k.sum(), obv.sum(), vwap.sum()]
    for s in sums:
        print(repr(float(s)))


# ── Numpy implementations ───────────────────────────────────


def wilder_np(n, arr):
    """Wilder smoothing — explicit scan matching BQN."""
    a = 1.0 / n
    out = np.empty(len(arr))
    out[0] = arr[0]
    for i in range(1, len(arr)):
        out[i] = a * arr[i] + (1 - a) * out[i - 1]
    return out


def indicators_numpy(df):
    c = df["close"].values.astype(np.float64)
    h = df["high"].values.astype(np.float64)
    l = df["low"].values.astype(np.float64)
    v = df["volume"].values.astype(np.float64)
    n = len(c)

    # MA via prefix-sum
    cs = np.concatenate([[0], np.cumsum(c)])
    ma20 = (cs[20:] - cs[:-20]) / 20
    ma50 = (cs[50:] - cs[:-50]) / 50

    # EMA via scan
    alpha = 2 / (1 + 20)
    ema20 = np.empty(n)
    ema20[0] = c[0]
    for i in range(1, n):
        ema20[i] = alpha * c[i] + (1 - alpha) * ema20[i - 1]

    # RSI via Wilder smoothing
    deltas = np.diff(c, prepend=c[0])[1:]
    gains = np.maximum(deltas, 0)
    losses = np.maximum(-deltas, 0)
    ag = wilder_np(14, gains)
    al = wilder_np(14, losses)
    rsi = 100 - 100 / (1 + ag / np.maximum(al, EPS))

    # ATR via Wilder smoothing — BQN's » fills with 0
    prev_c = np.zeros(n)
    prev_c[1:] = c[:-1]
    tr = np.maximum(h - l, np.maximum(np.abs(h - prev_c), np.abs(l - prev_c)))
    atr = wilder_np(14, tr)[1:]

    # Bollinger Bands
    mid = ma20.copy()
    windows = np.lib.stride_tricks.sliding_window_view(c, 20)
    std = windows.std(axis=1, ddof=0)
    upper = mid + 2 * std

    # Stochastic
    h_win = np.lib.stride_tricks.sliding_window_view(h, 14)
    l_win = np.lib.stride_tricks.sliding_window_view(l, 14)
    hi = h_win.max(axis=1)
    lo = l_win.min(axis=1)
    rng = np.maximum(hi - lo, EPS)
    k = 100 * (c[13:] - lo) / rng

    # OBV — BQN's » fills with 0, so first diff = c[0] - 0 = c[0]
    diff = np.diff(c, prepend=0.0)
    signs = np.sign(diff)
    obv = np.cumsum(signs * v)

    # VWAP
    tp = (h + l + c) / 3
    vwap = np.cumsum(tp * v) / np.cumsum(v)

    sums = [ma20.sum(), ma50.sum(), ema20.sum(), rsi.sum(),
            atr.sum(), upper.sum(), k.sum(), obv.sum(), vwap.sum()]
    for s in sums:
        print(repr(float(s)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", help="Path to OHLCV CSV")
    parser.add_argument("--mode", choices=["pandas", "numpy"], default="pandas")
    args = parser.parse_args()
    df = load_csv(args.csv)
    if args.mode == "pandas":
        indicators_pandas(df)
    else:
        indicators_numpy(df)
