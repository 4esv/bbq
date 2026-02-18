#!/usr/bin/env python3
"""Reference verification for exec.bqn"""
import numpy as np

np.random.seed(42)
N = 100
# Synthetic OHLCV
close = 100 * np.cumprod(1 + np.random.normal(0.001, 0.01, N))
open_p = close * (1 + np.random.normal(0, 0.002, N))
high = np.maximum(open_p, close) * (1 + np.abs(np.random.normal(0, 0.005, N)))
low = np.minimum(open_p, close) * (1 - np.abs(np.random.normal(0, 0.005, N)))
vol = 1e6 * (1 + np.abs(np.random.normal(0, 0.3, N)))

# Slippage
pos = np.where(np.random.random(N) > 0.5, 1, 0).astype(float)
delta = np.abs(np.diff(np.concatenate([[0], pos])))
slippage = 0.1 * np.sqrt(delta / (0.1 * vol + 1e-10))
print(f"Slippage sum: {slippage.sum():.6f}")

# FillLimit
capped = np.sign(pos) * np.minimum(np.abs(pos), 0.1 * vol)
print(f"FillLimit max: {capped.max():.6f}")

# RunOHLC
open_ret = (np.diff(open_p)) / open_p[:-1]
strat_ret = pos[:-1] * open_ret
print(f"RunOHLC mean: {strat_ret.mean():.6f}")

# StopLoss reference
def stop_loss(pos, open_p, low, close, pct):
    N = len(pos)
    new_pos = pos.copy()
    bar_ret = (close - open_p) / open_p
    mod_ret = bar_ret.copy()
    triggered = np.zeros(N, dtype=int)
    entry_px = 0.0
    for i in range(N):
        if pos[i] > 0:
            if i == 0 or pos[i-1] == 0:
                entry_px = open_p[i]
            stop_px = entry_px * (1 - pct)
            if low[i] < stop_px:
                new_pos[i] = 0
                triggered[i] = 1
                mod_ret[i] = (stop_px - open_p[i]) / open_p[i]
                entry_px = 0.0
        else:
            entry_px = 0.0
    strat_ret = pos * mod_ret  # original pos for triggered bar contribution
    return new_pos, strat_ret, triggered

np_new, np_ret, np_trig = stop_loss(pos, open_p, low, close, 0.02)
print(f"StopLoss triggered count: {np_trig.sum()}")
print(f"StopLoss mean return: {np_ret.mean():.6f}")
print("All reference values computed successfully.")
