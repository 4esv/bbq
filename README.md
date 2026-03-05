# bbq

**BQN Based Quant.**

[![CI](https://github.com/4esv/bbq/actions/workflows/ci.yml/badge.svg)](https://github.com/4esv/bbq/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/4esv/bbq)

v2.0

---

## Requirements

- [CBQN](https://github.com/dzaima/CBQN)
- A [data source](#data-sources)

## Overview

bbq is a quantitative finance toolkit in [BQN](https://mlochbaum.github.io/BQN/). 11 modules: indicators, backtesting, walk-forward validation, options pricing, Monte Carlo simulation, risk management, and anti-overfitting diagnostics.

## BQN 101

Micro syntax primer so you can read bbq code:

```
x ← 5                    # define
x ↩ 6                    # reassign
3‿1‿4                    # array (flat)
⟨3, 1‿4⟩                 # nested array
F ← {𝕩+1}               # function (𝕩 = right arg, 𝕨 = left arg)
+´ 1‿2‿3                 # fold: 6
F¨ 1‿2‿3                 # each: apply F to every element
F˘ mat                   # row-wise: apply F to each row
(F G H) x               # train: (F x) G (H x)
```

Evaluation is **right-to-left**: `2×3+1` = `2×(3+1)` = `8`.

Full tutorial: [mlochbaum.github.io/BQN/tutorial](https://mlochbaum.github.io/BQN/tutorial/index.html)

## Quick Start

Install [CBQN](https://github.com/dzaima/CBQN), then:

```bash
make fetch                     # download SPY data (5yr daily)
make run name=ma_cross         # run the example strategy
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

## Data Sources

bbq works with any CSV containing `Date,Open,High,Low,Close,Volume` columns.

**Yahoo Finance** — requires Python 3 + `pip install yfinance`:

```bash
make fetch                    # SPY, 5yr daily
make fetch ticker=AAPL period=10y
```

**Stooq** — free CSV, no API key, no Python:

```bash
curl -o data/SPY.csv "https://stooq.com/q/d/l/?s=spy.us&i=d"
```

**Alpha Vantage** — free API key, no Python:

```bash
curl -o data/SPY.csv "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=SPY&outputsize=full&apikey=YOUR_KEY&datatype=csv"
```

Free tier: 25 requests/day. Get a key at [alphavantage.co](https://www.alphavantage.co/support/#api-key).

## Makefile

```
make new name=X        Create strategy from template
make fetch [ticker=X]  Download market data (default: SPY, 5y)
make run name=X        Run a strategy
make test              Run test suite (129 tests)
make source name=X     Create data source (fetcher + parser)
make clean             Remove data files
```

## Usage

### Writing a Strategy

Every strategy is a BQN script that imports the engine, loads data, computes indicators, generates positions, and prints a report. Positions are arrays of `1` (long), `0` (flat), and `¯1` (short). The engine multiplies positions by returns.

```bqn
bt ← •Import "../engine/bt.bqn"
data ← bt.Validate bt.Load "../data/spy.csv"
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

### Walk-Forward Validation

```bqn
wf ← •Import "../engine/wf.bqn"
data ← wf.Validate wf.Load "../data/spy.csv"
prices ← data.close

MACross ← {
  fast‿slow ← 𝕨
  f‿s ← wf.Align (fast wf.MA 𝕩)‿(slow wf.MA 𝕩)
  f > s
}

grid ← wf.Grid ⟨8‿10‿12, 40‿50‿60⟩
results ← prices MACross wf._WF ⟨500, 100, grid, 0.001, wf.Sharpe⟩
"MA Cross"‿500‿100‿(≠grid) wf.WFReport results
```

### Composed Strategies

Normalize features, compute weighted score, threshold into positions:

```bqn
bt ← •Import "../engine/bt.bqn"
cmp ← •Import "../engine/cmp.bqn"
data ← bt.Validate bt.Load "../data/spy.csv"
c ← data.close

f1 ← ((-≠sma)↑c) - sma←50 bt.MA c   # SMA distance
f2 ← 14 bt.RSI c                       # RSI
upper‿mid‿lower ← 20‿2 bt.BB c
f3 ← (cb-lower)÷(upper-lower)+1e¯10    # BB position (cb←(-≠upper)↑c)

# ENorm: expanding-window z-score (no lookahead)
pos ← 0.5 cmp.Thresh 0.4‿0.3‿0.3 cmp.Score cmp.ENorm¨ f1‿f2‿f3
```

### Portfolio Backtesting

```bqn
weights ← 0.5‿0.3‿0.2
port_ret ← weights bt.PortRun ⟨⟨pos_spy, ret_spy⟩, ⟨pos_qqq, ret_qqq⟩, ⟨pos_gld, ret_gld⟩⟩
port_eq ← bt.PortEquity port_ret
```

### Options Pricing

```bqn
opt ← •Import "../engine/opt.bqn"
# Black-Scholes: S=42, K=40, T=0.5, r=0.1, σ=0.2, call
opt.BS 42‿40‿0.5‿0.1‿0.2‿1     # ≈ 4.76
opt.Delta 42‿40‿0.5‿0.1‿0.2‿1  # ≈ 0.81
opt.IV 4.76‿42‿40‿0.5‿0.1‿1    # ≈ 0.20 (round-trip)
```

### Monte Carlo Simulation

```bqn
mc ← •Import "../engine/mc.bqn"
paths ← mc.Paths 10000‿100‿0.05‿0.2‿1‿252   # 10k GBM paths
price ← 100⊸mc.EuroCall mc._Price paths‿0.05‿1
# Antithetic variance reduction
apaths ← mc.Paths mc._Antithetic 5000‿100‿0.05‿0.2‿1‿252
```

### Risk Management

```bqn
risk ← •Import "../engine/risk.bqn"
scaled ← 0.15 risk.VolTarget sig‿ret            # target 15% annualized vol
kelly ← 20‿0.5 risk.KellySeries sig‿ret         # half-Kelly, 20-bar lookback
safe ← 3‿(¯0.10) risk.CircuitBreaker pos‿ret    # pause after 3-bar loss > 10%
```

### Anti-Overfitting

```bqn
ovf ← •Import "../engine/ovf.bqn"
ovf.DSR 100 sr‿skew‿kurt‿T     # Deflated Sharpe (100 trials)
ovf.PBO wf_result               # Probability of Backtest Overfitting
ovf.HHI ret                     # Return concentration
```

### Execution Realism

```bqn
exec ← •Import "../engine/exec.bqn"
slip ← 0.1‿0.1 exec.Slippage pos‿vol            # Almgren-Chriss impact
capped ← 0.01 exec.FillLimit pos‿vol             # volume-based fill cap
r ← 0.02 exec.StopLoss pos‿data                  # 2% stop-loss
r ← 0.05‿0.10 exec.StopTake pos‿data             # 5% stop, 10% take-profit
```

### Universe Management

```bqn
uni ← •Import "../engine/uni.bqn"
datasets ← bt.LoadMany "../data/spy.csv"‿"../data/qqq.csv"‿"../data/gld.csv"
u ← uni.Universe datasets
scores ← uni.XScore signal_mat     # cross-sectional z-score
weights ← 2 uni.TopN scores        # long top-2, short bottom-2
```

## API Reference

### Data Contract

`Load` returns a namespace: `{dates⇐, close⇐, high⇐, low⇐, open⇐, vol⇐}`. All numeric arrays are flat floats, same length. Any data source that returns this shape works with bbq.

### Indicators

All dyadic: `n Indicator prices` unless noted. Output is shorter than input by the warmup period. EMA returns same length.

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
| `AvgWin` / `AvgLoss` | Mean winning / losing return |
| `Expectancy` | Expected value per trade |
| `Trades` | Position change count |
| `TimeIn` / `Exposure` | Fraction of time in market |
| `Skew` / `Kurt` | Distribution shape |

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

### Options Pricing

| Name | Signature | Description |
|------|-----------|-------------|
| `BS` | `BS S‿K‿T‿r‿σ‿type` | Black-Scholes price (1=call, ¯1=put) |
| `Delta` / `Gamma` / `Theta` / `Vega` / `Rho` | Same args | Greeks |
| `IV` | `IV target‿S‿K‿T‿r‿type` | Implied volatility (Newton-Raphson) |
| `Parity` | `Parity S‿K‿T‿r` | Put-call parity forward |
| `Npdf` / `Phi` / `PhiInv` | Monadic | Normal distribution functions |

### Monte Carlo

| Name | Signature | Description |
|------|-----------|-------------|
| `Paths` | `Paths n‿S₀‿μ‿σ‿T‿steps` | GBM price paths [n, steps] |
| `_Price` | `Payoff _Price paths‿r‿T` | Discounted expected payoff |
| `_Antithetic` | `Paths _Antithetic config` | Antithetic variance reduction |
| `EuroCall` / `EuroPut` | `k F path` | European payoffs |
| `AsianCall` | `k AsianCall path` | Arithmetic average call |
| `BarrierUpOut` | `k‿barrier BarrierUpOut path` | Up-and-out barrier call |

### Rolling Analytics

| Name | Signature | Description |
|------|-----------|-------------|
| `RSharpe` | `n RSharpe ret` | Rolling annualized Sharpe |
| `RVol` | `n RVol ret` | Rolling annualized vol |
| `RMaxDD` | `n RMaxDD ret` | Rolling max drawdown |
| `RBeta` | `n‿bench RBeta ret` | Rolling beta vs benchmark |
| `Alpha` | `bench‿rf Alpha ret` | Jensen's alpha |
| `IR` | `bench IR ret` | Information ratio |
| `Drawdowns` | `Drawdowns ret` | Episode namespace `{start,end,depth,dur}` |
| `UpsideCapture` / `DownsideCapture` | `bench F ret` | Capture ratios |

### Risk Management

| Name | Signature | Description |
|------|-----------|-------------|
| `VolTarget` | `target VolTarget sig‿ret` | Vol-scaled position sizing |
| `KellyFrac` | `frac KellyFrac ret` | Fractional Kelly (clipped ±1) |
| `KellySeries` | `n‿frac KellySeries sig‿ret` | Rolling Kelly positions |
| `MaxPos` | `cap MaxPos pos` | Clip magnitude, preserve sign |
| `CircuitBreaker` | `n‿thresh CircuitBreaker pos‿ret` | Pause on cumulative loss |
| `DDControl` | `thresh DDControl pos‿ret` | Pause on drawdown |

### Anti-Overfitting

| Name | Signature | Description |
|------|-----------|-------------|
| `DSR` | `n DSR SR‿sk‿ku‿T` | Deflated Sharpe Ratio |
| `PSR` | `bench PSR SR‿T‿n‿sk‿ku` | Probabilistic Sharpe Ratio |
| `MinTRL` | `n‿SR MinTRL sk‿ku` | Minimum track record length |
| `PBO` | `PBO wf_result` | Probability of backtest overfitting |
| `HHI` | `HHI ret` | Return concentration (Herfindahl) |
| `TrialCorrect` | `n‿alpha TrialCorrect pvals` | BH multiple-test correction |

### Execution Realism

| Name | Signature | Description |
|------|-----------|-------------|
| `Slippage` | `impact‿decay Slippage pos‿vol` | Almgren-Chriss market impact |
| `FillLimit` | `pct FillLimit pos‿vol` | Volume-based fill cap |
| `StopLoss` | `pct StopLoss pos‿data` | Intrabar stop-loss |
| `TakeProfit` | `pct TakeProfit pos‿data` | Intrabar take-profit |
| `StopTake` | `stop‿tp StopTake pos‿data` | Combined (stop wins on tie) |

### Universe Management

| Name | Signature | Description |
|------|-----------|-------------|
| `Universe` | `Universe namespaces` | Stack aligned OHLCV into matrices |
| `XRank` | `XRank mat` | Cross-sectional rank per row |
| `XScore` | `XScore mat` | Cross-sectional z-score per row |
| `XWeight` | `XWeight mat` | L1-normalize row weights |
| `LongOnly` | `LongOnly mat` | Zero negatives, renormalize |
| `TopN` | `n TopN scores` | Long top-N, short bottom-N |
| `_UniRun` | `Strategy _UniRun universe` | Apply strategy per asset |
| `UniReport` | `name UniReport weights‿uni` | Per-asset + combined report |

## Why BQN

- **Dense, array-oriented** — natural fit for time series and matrix operations
- **Concise** — entire indicator suite in ~25 lines vs 160+ in Python ([benchmarks](#benchmarks))
- **Stable spec** — no breaking changes
- **Fast** — CBQN compiles to native, competitive with numpy at scale
- **Readable once learned** — trains and combinators compose cleanly

More at [mlochbaum.github.io/BQN](https://mlochbaum.github.io/BQN/).

## Benchmarks

CBQN vs Python (pandas/numpy) vs Julia on synthetic GBM data. Median of 10 runs, 3 warmup.

### Indicators (MA, EMA, RSI, ATR, BB, Stoch, OBV, VWAP)

| Rows | BQN | pandas | numpy | Julia |
|------|-----|--------|-------|-------|
| 1,000 | 5ms | 211ms | 211ms | 1,087ms |
| 10,000 | 15ms | 213ms | 219ms | 1,088ms |
| 100,000 | 124ms | 275ms | 345ms | 1,180ms |
| 1,000,000 | 1,453ms | 855ms | 1,556ms | 1,774ms |

### Signals (Cross, Fill, Hold, Thresh)

| Rows | BQN | pandas | numpy | Julia |
|------|-----|--------|-------|-------|
| 1,000 | 5ms | 214ms | 211ms | 760ms |
| 10,000 | 16ms | 239ms | 248ms | 803ms |
| 100,000 | 128ms | 321ms | 332ms | 876ms |
| 1,000,000 | 1,451ms | 1,362ms | 1,383ms | 1,410ms |

### Full Pipeline (indicators → signals → backtest → metrics)

| Rows | BQN | pandas | numpy | Julia |
|------|-----|--------|-------|-------|
| 1,000 | 5ms | 213ms | 213ms | 676ms |
| 10,000 | 15ms | 233ms | 226ms | 708ms |
| 100,000 | 117ms | 289ms | 295ms | 802ms |
| 1,000,000 | 1,385ms | 954ms | 952ms | 1,162ms |

### Walk-Forward Grid Search (20 param combos, 504/126 train/test)

| Rows | BQN | Python | Julia |
|------|-----|--------|-------|
| 10,000 | 26ms | 254ms | 997ms |
| 100,000 | 225ms | 639ms | 1,110ms |

### Code Size

| Benchmark | BQN | Python | Julia |
|-----------|-----|--------|-------|
| indicators | 25 | 162 (6.5x) | 161 (6.4x) |
| signals | 26 | 132 (5.1x) | 118 (4.5x) |
| pipeline | 26 | 129 (5.0x) | 90 (3.5x) |
| loading | 6 | 49 (8.2x) | 48 (8.0x) |

Benchmark source on the `bench` branch.

## Architecture

```
engine/
├── core.bqn    # Shared: data loading, indicators, signal utilities
├── bt.bqn      # Backtesting: simulation, PnL, metrics, portfolio, reporting
├── wf.bqn      # Walk-forward: windowing, grid search, OOS aggregation
├── cmp.bqn     # Composition: normalization, scoring, thresholding
├── opt.bqn     # Options pricing: Black-Scholes, Greeks, IV
├── mc.bqn      # Monte Carlo: GBM paths, pricing, payoffs, antithetic variates
├── roll.bqn    # Rolling analytics: RSharpe, RVol, drawdowns, capture ratios
├── risk.bqn    # Position sizing & risk controls: Kelly, vol target, circuit breaker
├── ovf.bqn     # Anti-overfitting: DSR, PSR, PBO, HHI, trial correction
├── exec.bqn    # Execution realism: slippage, fill limits, stop/take-profit
└── uni.bqn     # Universe management: cross-sectional ops, ranking, multi-asset
```

Dependency chain: `core.bqn ← bt.bqn ← wf.bqn`. Each layer re-exports the one below it. Strategies import `bt.bqn`, walk-forward scripts import `wf.bqn`.

Leaf modules (`opt.bqn`, `mc.bqn`, `roll.bqn`, `risk.bqn`, `ovf.bqn`, `exec.bqn`, `uni.bqn`) import `bt.bqn` or `core.bqn` directly.

## Design

A backtest is a fold. Indicators are array operations. Positions are arrays of 1, 0, and ¯1. The engine multiplies positions by returns.

The architecture has two phases: indicators (pure array ops, SIMD-friendly) and execution (compound-state scan, inherently sequential). Five primitive patterns implement all indicators: windowed reduction, scan accumulation, shifted arrays, element-wise arithmetic, and compound scan.

`_Sim` exists for strategies that need bar-by-bar state (trailing stops, regime filters, Kalman filters). It generates position arrays that feed into the same `Run` pipeline.

Walk-forward validation splits history into rolling train/test windows, optimizes parameters on train, evaluates on test, and stitches out-of-sample segments. The OOS equity curve is the real result.

## Acknowledgements

- [Marshall Lochbaum](https://mlochbaum.github.io/BQN/) — BQN language (ISC license)
- [dzaima](https://github.com/dzaima/CBQN) — CBQN implementation (LGPLv3 / GPLv3 / MPL 2.0)

## License

MIT.
