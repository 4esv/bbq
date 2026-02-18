#!/usr/bin/env python3
"""Reference verification for ovf.bqn"""
import numpy as np
from scipy import stats

# PhiInv round-trip
for p in [0.05, 0.1, 0.3, 0.5, 0.7, 0.9, 0.95]:
    x = stats.norm.ppf(p)
    p_back = stats.norm.cdf(x)
    assert abs(p_back - p) < 1e-6, f"Round-trip failed for p={p}"
print("PhiInv round-trip: OK")

# DSR
def sr_sigma(sr, skew, kurt, T):
    v = (1 - skew*sr + (kurt-1)/4 * sr**2) / max(T-1, 1)
    return np.sqrt(max(0, v))

def dsr(sr, skew, kurt, T, n):
    eu = 0.5772156649
    if n <= 1:
        sr_star = 0
    else:
        sr_star = ((1-eu)*stats.norm.ppf(1-1/n) + eu*stats.norm.ppf(1-1/(n*np.e))) * np.sqrt(1/max(T-1, 1))
    sig = sr_sigma(sr, skew, kurt, T)
    return stats.norm.cdf((sr - sr_star) / max(sig, 1e-10))

print(f"DSR (high SR, n=1, T=1000):   {dsr(3.0, 0.0, 0.0, 1000, 1):.6f}")
print(f"DSR (SR=0.3, n=100, T=252):   {dsr(0.3, 0.0, 0.0, 252, 100):.6f}")
print(f"DSR (SR=0.1, n=1000, T=252):  {dsr(0.1, 0.0, 0.0, 252, 1000):.6f}")

# PSR
def psr(sr, sr_bench, T, skew, kurt):
    sig = sr_sigma(sr, skew, kurt, T)
    return stats.norm.cdf((sr - sr_bench) / max(sig, 1e-10))

print(f"PSR (SR=1.0 vs bench=0, T=252): {psr(1.0, 0.0, 252, 0.0, 0.0):.6f}")
print(f"PSR (SR=0.3 vs bench=0, T=50):  {psr(0.3, 0.0, 50, 0.0, 0.0):.6f}")

# MinTRL
def mintrl(n, sr, skew, kurt):
    z = stats.norm.ppf(1 - 0.05/n)
    return 1 + (1 - skew*sr + (kurt-1)/4*sr**2) * (z/max(sr, 1e-10))**2

print(f"MinTRL (n=1, SR=1.0, normal):  {mintrl(1, 1.0, 0.0, 0.0):.4f}")

# HHI
ret = np.array([0.01, -0.02, 0.03, 0.01, 0.0])
pos_ret = ret[ret > 0]
hhi = np.sum((pos_ret / pos_ret.sum())**2)
print(f"HHI (mixed returns): {hhi:.4f}")

ret1 = np.array([0.01, -0.01, -0.01, -0.01])
pos1 = ret1[ret1 > 0]
print(f"HHI (single positive): {np.sum((pos1/pos1.sum())**2):.4f}")

ret3 = np.array([0.01, 0.01, 0.01])
pos3 = ret3[ret3 > 0]
print(f"HHI (three equal): {np.sum((pos3/pos3.sum())**2):.4f}")

# TrialCorrect (BH)
pvals = np.array([0.001, 0.01, 0.05, 0.1, 0.3])
m = len(pvals)
alpha = 0.05
order = np.argsort(pvals)
sorted_p = pvals[order]
crit = (alpha/m) * np.arange(1, m+1)
passing = np.where(sorted_p <= crit)[0]
if len(passing):
    last_k = passing[-1]
    reject = np.zeros(m, dtype=int)
    reject[order[:last_k+1]] = 1
else:
    reject = np.zeros(m, dtype=int)
print(f"TrialCorrect reject mask: {reject}")

print("\nAll reference values computed successfully.")
