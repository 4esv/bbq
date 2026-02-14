# bbq

**BQN Based Quant.**

[![CI](https://github.com/4esv/bbq/actions/workflows/ci.yml/badge.svg)](https://github.com/4esv/bbq/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

v0.3

---

## Overview

bbq is a toolkit for quantitative strategy development in BQN.
It provides indicators, simulation, metrics, portfolio backtesting, and walk-forward validation.
Bring your own strategies, describe them in a few lines and watch them go.

## Architecture

```
engine/
├── core.bqn    # Shared: data loading, indicators, signal utilities
├── bt.bqn      # Backtesting: simulation, PnL, metrics, portfolio, reporting
├── wf.bqn      # Walk-forward: windowing, grid search, OOS aggregation
└── cmp.bqn     # Composition: normalization, scoring, thresholding
```

`core.bqn ← bt.bqn ← wf.bqn`. Each layer re-exports the one below it. Strategies import `bt.bqn`, walk-forward scripts import `wf.bqn`.

`cmp.bqn` imports `bt.bqn` internally but does not re-export it. Composed strategies import both `bt` and `cmp`.

## Quick Start

```bash
make fetch                        # download SPY data (5yr daily)
bqn strategies/ma_cross.bqn      # run the example strategy
```

Output:

```
═══ MA Cross (10/50) ═══
Total:          +42.2%      (B&H: +74.2%)
CAGR:           +7.6%       (B&H: +12.3%)
Sharpe:         0.66        (B&H: 0.76)
...
───
Verdict: Has potential, needs work
```

## Usage

### Writing a Strategy

Every strategy is a BQN script that imports the engine, loads data, computes indicators, generates positions, and prints a report.
Positions are arrays of `1` (long), `0` (flat), and `¯1` (short). The engine multiplies positions by returns. This is the core concept.

Pure array pattern (no bar-by-bar state):

```bqn
bt ← •Import "../engine/bt.bqn"
data ← bt.Load "../data/spy.csv"
c ← data.close
fast ← 10 bt.MA c
slow ← 50 bt.MA c
pos ← (≠slow)↑fast > slow
```

Stateful pattern with `_Sim` (bar-by-bar state threading):

```bqn
Step ← {
  pos‿peak ← 𝕨
  price‿lower ← 𝕩
  npos ← {pos=0 ? price<lower ; pos}
  ⟨npos, npos⊑⟨peak, peak⌈price⟩⟩
}
pos ← Step bt._Sim ⟨0,0⟩‿obs
```

### Portfolio Backtesting

Run multiple assets with weighted allocation:

```bqn
bt ← •Import "../engine/bt.bqn"
# assets: list of ⟨positions, returns⟩ pairs
weights ← 0.5‿0.3‿0.2
port_ret ← weights bt.PortRun ⟨⟨pos_spy, ret_spy⟩, ⟨pos_qqq, ret_qqq⟩, ⟨pos_gld, ret_gld⟩⟩
port_eq ← bt.PortEquity port_ret
```

### Walk-Forward Validation

Test parameter robustness across rolling windows:

```bqn
wf ← •Import "../engine/wf.bqn"
data ← wf.Validate wf.Load "../data/spy.csv"
prices ← data.close

# Strategy function: params 𝔽 prices → positions
MACross ← {
  fast‿slow ← 𝕨
  f‿s ← wf.Align (fast wf.MA 𝕩)‿(slow wf.MA 𝕩)
  f > s
}

grid ← wf.Grid ⟨8‿10‿12, 40‿50‿60⟩
config ← ⟨500, 100, grid, 0.001, wf.Sharpe⟩

results ← prices MACross wf._WF config
"MA Cross"‿500‿100‿(≠grid) wf.WFReport results
```

### Composed Strategies

Multiple indicators can be fused into a single position signal: normalize each feature, compute a weighted score, and threshold into positions.

```bqn
bt ← •Import "../engine/bt.bqn"
cmp ← •Import "../engine/cmp.bqn"

data ← bt.Validate bt.Load "../data/spy.csv"
c ← data.close

# Build features (different lengths are fine — Score auto-aligns)
sma ← 50 bt.MA c
f1 ← ((-≠sma)↑c) - sma             # SMA distance
f2 ← 14 bt.RSI c                    # RSI
upper‿mid‿lower ← 20‿2 bt.BB c
cb ← (-≠upper)↑c
f3 ← (cb-lower)÷(upper-lower)+1e¯10 # BB position

# ENorm: expanding-window z-score (no lookahead bias for standalone backtests)
# Compose with Norm is for WF per-fold use where the full array is the training set
pos ← 0.5 cmp.Thresh 0.4‿0.3‿0.3 cmp.Score cmp.ENorm¨ f1‿f2‿f3
```

`ENorm¨` z-scores each feature using only past data, `Score` aligns to the shortest and computes a weighted sum, `Thresh` maps to 1 (above level), ¯1 (below negative level), or 0 (between). Use `Compose` (which calls `Norm`) in walk-forward folds where the full array is the training set.

### Composition

| Name | Signature | Description |
|------|-----------|-------------|
| `Norm` | `Norm arr` | Z-score normalize, full-array (for WF per-fold use) |
| `ENorm` | `ENorm arr` | Expanding-window z-score (no lookahead bias) |
| `Score` | `weights Score features` | Weighted sum with auto-alignment |
| `Thresh` | `level Thresh scores` | Level-based position mapper: 1/0/¯1 |
| `Compose` | `weights‿level Compose features` | Full pipeline: Norm, score, threshold (WF use) |

### Data Contract

`Load` returns a namespace: `{dates⇐, close⇐, high⇐, low⇐, open⇐, vol⇐}`. All numeric arrays are flat floats, same length.
Any data source that returns this shape works with bbq. Use `make source name=X` to scaffold a new fetcher/parser pair.

### Indicators

All dyadic: `n Indicator prices` unless noted. Output is shorter than input by the warmup period (no padding). EMA returns same length as input.

| Name | Signature | Description |
|------|-----------|-------------|
| `MA` | `n MA prices` | Simple moving average (O(n) prefix-sum) |
| `EMA` | `n EMA prices` | Exponential moving average |
| `WMA` | `n WMA prices` | Weighted moving average |
| `Std` | `n Std prices` | Rolling population std |
| `RSI` | `n RSI prices` | Relative Strength Index (0-100) |
| `MACD` | `fast‿slow‿sig MACD prices` | Returns `macd‿signal‿histogram` |
| `ATR` | `n ATR data` | Average True Range (takes namespace) |
| `Mom` | `n Mom prices` | Momentum |
| `ROC` | `n ROC prices` | Rate of Change (%) |
| `Stoch` | `n Stoch data` | Stochastic %K/%D (takes namespace) |
| `BB` | `n‿k BB prices` | Bollinger Bands: `upper‿mid‿lower` |
| `OBV` | `OBV close‿vol` | On-Balance Volume (monadic) |
| `VWAP` | `VWAP data` | Volume-Weighted Avg Price (monadic) |
| `AD` | `AD data` | Accumulation/Distribution (monadic) |
| `RMax` | `n RMax prices` | Rolling maximum |
| `RMin` | `n RMin prices` | Rolling minimum |

### Signal Utilities

| Name | Signature | Description |
|------|-----------|-------------|
| `Cross` | `fast Cross slow` | 1 where fast crosses above slow |
| `CrossDown` | `fast CrossDown slow` | 1 where fast crosses below slow |
| `Mask` | `n Mask arr` | Zero first n elements |
| `Fill` | `Fill signals` | Forward-fill: hold last non-zero |
| `Thresh` | `level Thresh values` | 1 where value crosses above level |
| `ThreshDown` | `level ThreshDown values` | 1 where value crosses below level |
| `Hold` | `n Hold positions` | Min n-bar holding period |

### Simulation

`_Sim` is a 1-modifier that turns a step function into a position-generating scan.
Your step function receives state (left) and an observation (right), returns new state.
First element of state is always the position.

For multiple series per bar, zip them: `obs ← <˘⍉> price‿lower‿ma`. Each observation becomes a list `⟨pᵢ, lᵢ, mᵢ⟩`.
Nested state composes naturally: `⟨pos, peak, ⟨kx, kp⟩⟩`.

### Metrics

All take returns, return a number. Trades/TimeIn/Exposure take positions.

| Name | What it tells you |
|------|-------------------|
| `Sharpe` | Risk-adjusted return (annualized, Rf=0) |
| `Sortino` | Like Sharpe, penalizes downside only |
| `Calmar` | CAGR relative to worst drawdown |
| `MaxDD` | Worst peak-to-trough loss (negative) |
| `MaxDDDur` | Longest drawdown in bars |
| `TotalRet` | Cumulative return as decimal |
| `CAGR` | Compound annual growth rate |
| `AnnVol` | Annualized volatility |
| `WinRate` | Fraction of positive-return days |
| `ProfitFactor` | Gross profit / gross loss |
| `AvgWin` | Mean winning return |
| `AvgLoss` | Mean losing return |
| `Expectancy` | Expected value per trade |
| `Trades` | Position change count |
| `TimeIn` | Fraction of time in market |
| `Exposure` | Alias for TimeIn |
| `Skew` | Return distribution asymmetry |
| `Kurt` | Tail fatness (excess kurtosis) |

### Portfolio

| Name | Signature | Description |
|------|-----------|-------------|
| `PortRun` | `weights PortRun assets` | Weighted multi-asset returns |
| `PortCost` | `rates PortCost positions` | Combined transaction costs |
| `PortEquity` | `PortEquity ret` | Equity curve (alias) |
| `PortReport` | `name‿cpos PortReport assets‿cret` | Per-asset + combined report |

### Walk-Forward

| Name | Signature | Description |
|------|-----------|-------------|
| `Windows` | `train‿test Windows prices` | Rolling train/test splits |
| `Grid` | `Grid ranges` | Cartesian product of param ranges |
| `_WF` | `prices Strategy _WF config` | Walk-forward orchestrator |
| `WFReport` | `name‿tr‿te‿gs WFReport results` | Print WF summary |

### Makefile

```
make new name=X        Create strategy from template
make fetch [ticker=X]  Download market data (default: SPY, 5y)
make run name=X        Run a strategy
make test              Run test suite
make source name=X     Create data source (fetcher + parser)
make clean             Remove data files
make setup             Install pre-commit hook
```

## Design

A backtest is a fold. Indicators are array operations. Positions are arrays of 1, 0, and ¯1. The engine multiplies positions by returns.

The architecture has two phases: indicators (pure array ops, embarrassingly parallel, SIMD-friendly) and execution (compound-state scan, inherently sequential).
Five primitive patterns implement all indicators: windowed reduction, scan accumulation, shifted arrays, element-wise arithmetic, and compound scan.

`_Sim` exists for strategies that need bar-by-bar state (trailing stops, regime filters, Kalman filters). It's not an engine, it only generates position arrays.
Those arrays feed into the same `Run` pipeline as any array-computed position.

Walk-forward validation splits history into rolling train/test windows, optimizes parameters on train, evaluates on test, and stitches out-of-sample segments. The OOS equity curve is the real result.

## License

MIT.
