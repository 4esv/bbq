#!/usr/bin/env python3
"""Reference verification for roll.bqn against pandas/numpy"""
import numpy as np
import pandas as pd

np.random.seed(42)
ret = np.random.normal(0.001, 0.01, 252)
bench = np.random.normal(0.0008, 0.012, 252)

# RSharpe
def r_sharpe(ret, n):
    r = pd.Series(ret)
    return (r.rolling(n).mean() / r.rolling(n).std(ddof=1) * np.sqrt(252)).values

# RVol
def r_vol(ret, n):
    r = pd.Series(ret)
    return (r.rolling(n).std(ddof=1) * np.sqrt(252)).values

# RBeta
def r_beta(strat, bench, n):
    s = pd.Series(strat)
    b = pd.Series(bench)
    cov = s.rolling(n).cov(b)
    var = b.rolling(n).var(ddof=1)
    return (cov / var).values

# Alpha
def alpha_fn(strat, bench, rf):
    cov = np.cov(strat, bench, ddof=1)[0, 1]
    var = np.var(bench, ddof=1)
    beta = cov / var
    def cagr(r): return (np.prod(1 + r)) ** (252 / len(r)) - 1
    return cagr(strat) - rf - beta * (cagr(bench) - rf)

# IR
def ir_fn(strat, bench):
    diff = strat - bench
    return np.mean(diff) / np.std(diff, ddof=1) * np.sqrt(252)

# UpsideCapture
def upside_capture(strat, bench):
    mask = bench > 0
    return strat[mask].sum() / bench[mask].sum()

# DownsideCapture
def downside_capture(strat, bench):
    mask = bench < 0
    return strat[mask].sum() / bench[mask].sum()

# Print reference values for comparison
n = 20
print("=== Reference values (seed=42, n=252) ===")
print(f"RSharpe[n={n}] first valid: {r_sharpe(ret, n)[n-1]:.6f}")
print(f"RVol[n={n}] first valid: {r_vol(ret, n)[n-1]:.6f}")
print(f"RBeta[n={n}] first valid: {r_beta(ret, bench, n)[n-1]:.6f}")
print(f"Alpha(rf=0): {alpha_fn(ret, bench, 0):.6f}")
print(f"IR: {ir_fn(ret, bench):.6f}")
print(f"UpsideCapture: {upside_capture(ret, bench):.6f}")
print(f"DownsideCapture: {downside_capture(ret, bench):.6f}")
print("All reference values computed successfully.")
