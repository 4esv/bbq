# bbq

**BQN Backtesting for Quant.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Get Started

Requires [CBQN](https://github.com/dzaima/CBQN) and Python 3 + `pip install yfinance`.

```bash
make fetch                        # download SPY data (5yr daily)
bqn strategies/ma_cross.bqn      # run the example strategy
make new name=my_idea             # scaffold your own
```

```
═══ MA Cross (10/50) ═══
Total:          +42.2%      (B&H: +74.2%)
CAGR:           +7.6%       (B&H: +12.3%)
Sharpe:         0.66        (B&H: 0.76)
...
───
Verdict: Has potential, needs work
```

## Makefile

```
make new name=X        Create strategy from template
make fetch [ticker=X]  Download market data (default: SPY, 5y)
make run name=X        Run a strategy
make source name=X     Create data source (fetcher + parser)
make clean             Remove data files
```

## Writing a Strategy

Positions are arrays of `1` (long), `0` (flat), `¯1` (short). The engine multiplies positions by returns.

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

For multiple series per bar, zip them: `obs ← <˘⍉> price‿lower‿ma`.

### Running the Backtest

```bqn
ret ← bt.Ret c                    # returns from prices
warmup ← (≠c) - ≠pos              # auto-align
strat ← pos bt.Run warmup↓ret     # strategy returns
bh ← warmup↓ret                   # buy-and-hold benchmark
"My Strategy"‿pos bt.Report strat‿bh
```

`Ret` computes returns. `Run` multiplies positions by returns. `Report` prints everything. `Cost` and `Equity` are there if you need them.

## Data Contract

`Load` returns a namespace: `{dates⇐, close⇐, high⇐, low⇐, open⇐, vol⇐}`. All numeric arrays are flat floats, same length. Any source that returns this shape works. Use `make source name=X` to scaffold a new fetcher/parser pair.

## API Reference

### Indicators

All dyadic: `n Indicator prices` unless noted. Output is shorter than input by the warmup period (no padding). EMA returns same length.

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

`_Sim` is a 1-modifier that turns a step function into a position-generating scan. Your step function receives state (left) and an observation (right), returns new state. First element of state is always the position.

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

## Design

Two phases: indicators (pure array ops, SIMD-friendly) and execution (compound-state scan, sequential). Five primitive patterns implement all indicators: windowed reduction, scan accumulation, shifted arrays, element-wise arithmetic, and compound scan.

`_Sim` exists for strategies that need bar-by-bar state (trailing stops, regime filters, Kalman filters). It generates position arrays that feed into the same `Run` pipeline as any array-computed position.

## License

MIT.
