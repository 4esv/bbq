#!/usr/bin/env python3
"""Reference verification for risk.bqn against numpy"""
import numpy as np

np.random.seed(42)
ret = np.random.normal(0.001, 0.01, 252)
sig = np.ones(252)

# VolTarget reference
def vol_target(sig, ret, target, n=21):
    result = np.zeros(len(ret))
    for i in range(len(ret)):
        if i < n:
            result[i] = sig[i] * target / 1e-10  # eps guard
            continue
        window = ret[i-n:i]
        rvol = np.std(window, ddof=1) * np.sqrt(252)
        result[i] = sig[i] * target / max(rvol, 1e-10)
    return result

# KellyFrac reference
def kelly_frac(ret, f):
    m = np.mean(ret)
    v = np.var(ret, ddof=1)
    return np.clip(f * m / max(v, 1e-10), -1, 1)

# CircuitBreaker reference
def circuit_breaker(pos, ret, n, thresh):
    result = pos.copy()
    remaining = 0
    for i in range(len(ret)):
        if i >= n:
            nbar_ret = np.sum(ret[i-n+1:i+1])
            if nbar_ret < thresh:
                remaining = n
        if remaining > 0:
            result[i] = 0
            remaining -= 1
    return result

# DDControl reference
def dd_control(pos, ret, thresh):
    eq = np.cumprod(1 + ret)
    running_max = np.maximum.accumulate(eq)
    dd = (eq - running_max) / running_max
    mask = dd >= thresh
    return pos * mask

print("=== Reference values (seed=42, n=252) ===")
vt = vol_target(sig, ret, 0.20)
print(f"VolTarget[21] first valid value: {vt[21]:.6f}")
print(f"KellyFrac(f=0.5): {kelly_frac(ret, 0.5):.6f}")

pos = np.ones(252)
cb = circuit_breaker(pos, ret, 20, -0.05)
print(f"CircuitBreaker zeros: {(cb==0).sum()}")

ddc = dd_control(pos, ret, -0.05)
print(f"DDControl zeros: {(ddc==0).sum()}")
print("All reference values computed successfully.")
