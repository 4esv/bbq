#!/usr/bin/env python3
"""Synthetic OHLCV data generator — Geometric Brownian Motion."""
import sys
import numpy as np
from datetime import datetime, timedelta


def generate(n, seed=42):
    rng = np.random.default_rng(seed)
    S0, mu, sigma, dt = 400.0, 0.08, 0.20, 1 / 252

    # Close prices via GBM
    log_ret = (mu - 0.5 * sigma**2) * dt + sigma * np.sqrt(dt) * rng.standard_normal(n - 1)
    close = np.empty(n)
    close[0] = S0
    close[1:] = S0 * np.exp(np.cumsum(log_ret))

    # Intraday OHLC derived from close
    spread = close * rng.uniform(0.005, 0.02, n)
    high = close + spread * rng.uniform(0.3, 0.9, n)
    low = close - spread * rng.uniform(0.3, 0.9, n)
    open_ = low + (high - low) * rng.uniform(0.1, 0.9, n)
    high = np.maximum(high, np.maximum(close, open_))
    low = np.minimum(low, np.minimum(close, open_))

    # Volume: log-normal, SPY-like range
    vol = rng.lognormal(mean=17, sigma=0.5, size=n).astype(np.int64)

    # Trading-day dates (skip weekends)
    dates, d = [], datetime(2020, 1, 2)
    while len(dates) < n:
        if d.weekday() < 5:
            dates.append(d.strftime("%Y-%m-%d"))
        d += timedelta(days=1)

    return dates, close, high, low, open_, vol


def write_csv(path, dates, close, high, low, open_, vol):
    with open(path, "w") as f:
        f.write("Price,Close,High,Low,Open,Volume\n")
        f.write("Ticker,SYN,SYN,SYN,SYN,SYN\n")
        f.write("Date,,,,,\n")
        for i in range(len(dates)):
            f.write(f"{dates[i]},{close[i]},{high[i]},{low[i]},{open_[i]},{vol[i]}\n")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <rows> <output.csv> [seed]", file=sys.stderr)
        sys.exit(1)
    n = int(sys.argv[1])
    path = sys.argv[2]
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 42
    dates, close, high, low, open_, vol = generate(n, seed)
    write_csv(path, dates, close, high, low, open_, vol)
    print(f"Generated {n} rows -> {path}")
