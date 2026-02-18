#!/usr/bin/env python3
"""Reference implementations for engine/uni.bqn"""
import numpy as np

np.random.seed(42)

# Synthetic universe: 50 bars, 4 assets
nb, na = 50, 4
prices = 100 * np.cumprod(1 + np.random.normal(0.001, 0.01, (nb, na)), axis=0)

print(f"Universe shape: [{nb}, {na}]")
print(f"Prices[0]: {prices[0].round(2)}")
print()

# XRank: per-row ascending rank (0-indexed)
def xrank(mat):
    return np.argsort(np.argsort(mat, axis=1), axis=1)

ranked = xrank(prices)
print(f"XRank row 0: {ranked[0]}")
# Each row is a permutation of 0..na-1
assert all(sorted(ranked[i]) == list(range(na)) for i in range(nb))
print("XRank: all rows are valid permutations")
print()

# XScore: per-row z-score
def xscore(mat):
    m = mat.mean(axis=1, keepdims=True)
    s = mat.std(axis=1, keepdims=True) + 1e-10
    return (mat - m) / s

scored = xscore(prices)
print(f"XScore row 0: {scored[0].round(4)}")
print(f"XScore row sums (should be ~0): {scored.sum(axis=1)[:3].round(10)}")
assert np.allclose(scored.sum(axis=1), 0, atol=1e-10)
print("XScore: all row sums ≈ 0")
print()

# XWeight: per-row absolute normalization
def xweight(mat):
    s = np.abs(mat).sum(axis=1, keepdims=True)
    return mat / np.maximum(s, 1e-10)

weighted = xweight(prices)
print(f"XWeight abs row sums (should be 1): {np.abs(weighted).sum(axis=1)[:3].round(6)}")
assert np.allclose(np.abs(weighted).sum(axis=1), 1)
print("XWeight: all abs row sums = 1")
print()

# LongOnly: clip negatives, renormalize
def longonly(w):
    w = np.maximum(w, 0)
    s = w.sum(axis=1, keepdims=True)
    return np.where(s > 0, w / s, 0)

# Test with mixed sign matrix
mixed = np.array([[1, -2, 3], [-4, 5, -6], [0, 0, 0]], dtype=float)
lo = longonly(mixed)
print(f"LongOnly([1,-2,3]): {lo[0].round(4)}")
print(f"LongOnly([-4,5,-6]): {lo[1].round(4)}")
print(f"LongOnly([0,0,0]): {lo[2].round(4)}")
assert np.all(lo >= 0)
assert np.isclose(lo[0].sum(), 1)
assert np.isclose(lo[1].sum(), 1)
assert np.isclose(lo[2].sum(), 0)
print("LongOnly: all non-negative, row sums correct")
print()

# TopN: long top n, short bottom n
def topn(scores, n):
    result = np.zeros_like(scores)
    for i in range(len(scores)):
        order = np.argsort(scores[i])
        result[i, order[-n:]] = 1 / n
        result[i, order[:n]] = -1 / n
    return result

tn = topn(prices, 1)
print(f"TopN(1) row 0: {tn[0]}")
print(f"TopN row sums (should be 0): {tn.sum(axis=1)[:3].round(10)}")
assert np.allclose(tn.sum(axis=1), 0)
print("TopN: all row sums = 0")
print()

print("All reference values computed successfully.")
