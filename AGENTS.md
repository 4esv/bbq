# bbq — BQN Based Quant

v1.0

## Architecture

```
engine/
├── core.bqn    # Shared: constants, data loading, indicators, signal utilities
├── bt.bqn      # Backtesting: simulation, PnL, metrics, portfolio, reporting (imports core)
├── wf.bqn      # Walk-forward: windowing, grid search, OOS aggregation (imports bt)
├── cmp.bqn     # Composition: normalization, scoring, thresholding (imports bt)
├── opt.bqn     # Options pricing: Black-Scholes, Greeks, IV (imports core)
├── mc.bqn      # Monte Carlo: GBM paths, pricing, payoffs, antithetic variates (imports core, opt)
├── roll.bqn    # Rolling analytics: RSharpe, RVol, drawdowns, capture ratios (imports bt)
├── risk.bqn    # Position sizing & risk controls: Kelly, vol target, circuit breaker (imports bt)
├── ovf.bqn     # Anti-overfitting: DSR, PSR, PBO, HHI, trial correction (imports bt, opt)
├── exec.bqn    # Execution realism: slippage, fill limits, stop/take-profit (imports bt)
└── uni.bqn     # Universe management: alignment, cross-sectional ops, ranking (imports bt)
```

Dependency chain: `core.bqn ← bt.bqn ← wf.bqn`

- `bt.bqn` re-exports everything from `core.bqn` — strategies only import `bt.bqn`
- `wf.bqn` re-exports everything from `bt.bqn` — walk-forward scripts import `wf.bqn`
- `cmp.bqn` imports `bt.bqn` internally, does not re-export — composed strategies import both `bt` and `cmp`
- `opt.bqn` imports `core.bqn` for `eps` — strategies import `opt.bqn` directly
- `mc.bqn` imports `core.bqn` and `opt.bqn` — MC scripts import `mc.bqn` directly
- `roll.bqn`, `risk.bqn`, `exec.bqn`, `uni.bqn` import `bt.bqn` directly
- `ovf.bqn` imports `bt.bqn` and `opt.bqn` directly

## API Reference

### core.bqn — Shared Primitives

| Export | Signature | Description |
|--------|-----------|-------------|
| `eps` | constant | `1e¯10` — division guard |
| `tdy` | constant | `252` — trading days/year |
| `Split` | `Split str` | CSV line splitter (internal, exported for bt) |
| `Load` | `Load path` | Load yfinance CSV → `{dates, close, high, low, open, vol}` |
| `LoadMany` | `LoadMany paths` | Load list of CSVs → list of namespaces |
| `Validate` | `Validate data` | Assert OHLCV invariants, passthrough |
| `Align` | `Align arrays` | Trim list of arrays to shortest (from tail) |
| `Wilder` | `n Wilder arr` | Wilder smoothing (exported for bt) |
| `Pstd` | `Pstd arr` | Population std (exported for bt) |
| `MA` | `n MA prices` | Simple moving average |
| `EMA` | `n EMA prices` | Exponential moving average (same length) |
| `WMA` | `n WMA prices` | Weighted moving average |
| `Std` | `n Std prices` | Rolling population std |
| `RSI` | `n RSI prices` | Relative Strength Index (0-100) |
| `MACD` | `fast‿slow‿sig MACD prices` | Returns `macd‿signal‿hist` |
| `ATR` | `n ATR data` | Average True Range (namespace input) |
| `Mom` | `n Mom prices` | Momentum |
| `ROC` | `n ROC prices` | Rate of Change (%) |
| `Stoch` | `n Stoch data` | Stochastic %K/%D (namespace input) |
| `BB` | `n‿k BB prices` | Bollinger Bands: `upper‿mid‿lower` |
| `OBV` | `OBV close‿vol` | On-Balance Volume (monadic) |
| `VWAP` | `VWAP data` | Volume-Weighted Avg Price (monadic, namespace) |
| `AD` | `AD data` | Accumulation/Distribution (monadic, namespace) |
| `RMax` | `n RMax prices` | Rolling maximum |
| `RMin` | `n RMin prices` | Rolling minimum |
| `Cross` | `fast Cross slow` | 1 where fast crosses above slow |
| `CrossDown` | `fast CrossDown slow` | 1 where fast crosses below slow |
| `Mask` | `n Mask arr` | Zero first n elements |
| `Fill` | `Fill signals` | Forward-fill: hold last non-zero |
| `Thresh` | `level Thresh values` | 1 where value crosses above level |
| `ThreshDown` | `level ThreshDown values` | 1 where value crosses below level |
| `Hold` | `n Hold positions` | Min n-bar holding period |

### bt.bqn — Backtesting Engine

Re-exports all of core.bqn, plus:

| Export | Signature | Description |
|--------|-----------|-------------|
| `_Sim` | `Step _Sim init‿obs` | 1-modifier: step function → position scan |
| `Ret` | `Ret prices` | Simple returns (n-1 length) |
| `LogRet` | `LogRet prices` | Log returns (n-1 length) |
| `Run` | `pos Run ret` | Strategy returns (pos × ret) |
| `Cost` | `rate Cost pos` | Transaction cost array |
| `Equity` | `Equity ret` | Equity curve starting at 1 |
| `Sharpe` | `Sharpe ret` | Annualized Sharpe ratio (Rf=0) |
| `Sortino` | `Sortino ret` | Sortino ratio |
| `MaxDD` | `MaxDD ret` | Maximum drawdown (negative) |
| `MaxDDDur` | `MaxDDDur ret` | Longest drawdown in bars |
| `TotalRet` | `TotalRet ret` | Cumulative return |
| `CAGR` | `CAGR ret` | Compound annual growth rate |
| `AnnVol` | `AnnVol ret` | Annualized volatility |
| `Calmar` | `Calmar ret` | CAGR / \|MaxDD\| |
| `WinRate` | `WinRate ret` | Positive-return day fraction |
| `ProfitFactor` | `ProfitFactor ret` | Gross profit / gross loss |
| `AvgWin` | `AvgWin ret` | Mean winning return |
| `AvgLoss` | `AvgLoss ret` | Mean losing return |
| `Expectancy` | `Expectancy ret` | Expected value per trade |
| `Trades` | `Trades pos` | Position change count |
| `TimeIn` | `TimeIn pos` | Fraction of time in market |
| `Exposure` | `Exposure pos` | Alias for TimeIn |
| `Skew` | `Skew ret` | Return distribution skewness |
| `Kurt` | `Kurt ret` | Excess kurtosis |
| `Report` | `name‿pos Report strat‿bh` | Print formatted summary |
| `PortRun` | `weights PortRun assets` | Weighted portfolio returns |
| `PortCost` | `rates PortCost positions` | Combined transaction costs |
| `PortEquity` | `PortEquity ret` | Alias for Equity |
| `PortReport` | `name‿cpos PortReport assets‿cret` | Per-asset + combined report |
| `RunOHLC` | `pos RunOHLC data` | Open-to-open returns with OHLC data |
| `AlignDates` | `AlignDates namespaces` | Align multiple namespaces to common date range |

### wf.bqn — Walk-Forward Validation

Re-exports all of bt.bqn, plus:

| Export | Signature | Description |
|--------|-----------|-------------|
| `Windows` | `train‿test Windows prices` | Rolling train/test splits |
| `Grid` | `Grid ranges` | Cartesian product of param ranges |
| `_WF` | `prices Strategy _WF config` | Walk-forward orchestrator (1-modifier) |
| `WFReport` | `name‿tr‿te‿gs WFReport results` | Print WF summary |

**`_WF` config**: `train‿test‿grid‿cost_rate‿Metric` (list)

**`_WF` returns**: `{folds, oos_ret, oos_eq, summary}` namespace

### cmp.bqn — Composable Signal Layer

Imports bt.bqn internally, does not re-export. Strategies import both `bt` and `cmp`.

| Export | Signature | Description |
|--------|-----------|-------------|
| `Norm` | `Norm arr` | Z-score normalize, full-array (for WF per-fold use) |
| `ENorm` | `ENorm arr` | Expanding-window z-score (no lookahead bias) |
| `Score` | `weights Score features` | Weighted sum with auto-alignment |
| `Thresh` | `level Thresh scores` | Level-based position mapper: 1/0/¯1 |
| `Compose` | `weights‿level Compose features` | Full pipeline: Norm, score, threshold (WF use) |

### opt.bqn — Options Pricing

Imports core.bqn for `eps`. Leaf module — strategies import `opt.bqn` directly.

| Export | Signature | Description |
|--------|-----------|-------------|
| `Npdf` | `Npdf x` | Standard normal PDF |
| `Phi` | `Phi x` | Standard normal CDF (Abramowitz-Stegun) |
| `BS` | `BS S‿K‿T‿r‿σ‿type` | Black-Scholes price (type: 1=call, ¯1=put) |
| `Delta` | `Delta S‿K‿T‿r‿σ‿type` | Option delta |
| `Gamma` | `Gamma S‿K‿T‿r‿σ‿type` | Option gamma |
| `Theta` | `Theta S‿K‿T‿r‿σ‿type` | Option theta |
| `Vega` | `Vega S‿K‿T‿r‿σ‿type` | Option vega |
| `Rho` | `Rho S‿K‿T‿r‿σ‿type` | Option rho |
| `IV` | `IV target‿S‿K‿T‿r‿type` | Implied volatility (Newton-Raphson) |
| `Parity` | `Parity S‿K‿T‿r` | Put-call parity: S - Ke^(-rT) |

### mc.bqn — Monte Carlo Simulation

Imports core.bqn and opt.bqn. Leaf module — MC scripts import `mc.bqn` directly.

| Export | Signature | Description |
|--------|-----------|-------------|
| `Paths` | `Paths n‿S₀‿μ‿σ‿T‿steps` | GBM price paths [n, steps] |
| `_Price` | `Payoff _Price paths‿r‿T` | Discounted expected payoff (1-modifier) |
| `_Antithetic` | `Paths _Antithetic config` | Antithetic variance reduction [2n, steps] |
| `EuroCall` | `k EuroCall path` | European call payoff (terminal) |
| `EuroPut` | `k EuroPut path` | European put payoff (terminal) |
| `AsianCall` | `k AsianCall path` | Arithmetic average call payoff |
| `BarrierUpOut` | `k‿barrier BarrierUpOut path` | Up-and-out barrier call payoff |

### roll.bqn — Rolling Analytics

Imports bt.bqn. Import directly for rolling performance analysis.

| Export | Signature | Description |
|--------|-----------|-------------|
| `RSharpe` | `n RSharpe ret` | Rolling annualized Sharpe |
| `RVol` | `n RVol ret` | Rolling annualized volatility |
| `RMaxDD` | `n RMaxDD ret` | Rolling max drawdown |
| `RBeta` | `n‿bench RBeta ret` | Rolling beta vs benchmark |
| `Alpha` | `bench‿rf Alpha ret` | Jensen's alpha |
| `IR` | `bench IR ret` | Information ratio |
| `Drawdowns` | `Drawdowns ret` | Drawdown episode namespace `{start,end,depth,dur}` |
| `UpsideCapture` | `bench UpsideCapture ret` | Upside capture ratio |
| `DownsideCapture` | `bench DownsideCapture ret` | Downside capture ratio |

### risk.bqn — Position Sizing & Risk Controls

Imports bt.bqn. Import directly for position sizing and risk management.

| Export | Signature | Description |
|--------|-----------|-------------|
| `VolTarget` | `target VolTarget sig‿ret` | Vol-scaled position sizing |
| `KellyFrac` | `frac KellyFrac ret` | Fractional Kelly sizing (clipped to ±1) |
| `KellySeries` | `n‿frac KellySeries sig‿ret` | Rolling Kelly position series |
| `MaxPos` | `cap MaxPos pos` | Clip positions to ±cap |
| `CircuitBreaker` | `n‿thresh CircuitBreaker pos‿ret` | Zero positions on n-bar cumulative loss |
| `DDControl` | `thresh DDControl pos‿ret` | Pause on drawdown, resume on recovery |
| `Scale` | `target Scale pos‿ret` | Alias for VolTarget |

### ovf.bqn — Anti-Overfitting Metrics

Imports bt.bqn and opt.bqn. Import directly for overfitting diagnostics.

| Export | Signature | Description |
|--------|-----------|-------------|
| `DSR` | `n DSR SR‿sk‿ku‿T` | Deflated Sharpe Ratio |
| `PSR` | `bench PSR SR‿T‿n‿sk‿ku` | Probabilistic Sharpe Ratio |
| `MinTRL` | `n‿SR MinTRL sk‿ku` | Minimum track record length |
| `PBO` | `PBO fold_scores` | Probability of backtest overfitting |
| `HHI` | `HHI ret` | Herfindahl-Hirschman concentration |
| `TrialCorrect` | `n‿alpha TrialCorrect pvals` | BH multiple-test correction → boolean array |

### exec.bqn — Execution Realism

Imports bt.bqn. Import directly for realistic execution simulation.

| Export | Signature | Description |
|--------|-----------|-------------|
| `Slippage` | `impact‿decay Slippage pos‿vol` | Market impact cost array |
| `FillLimit` | `pct FillLimit pos‿vol` | Volume-based fill cap |
| `StopLoss` | `pct StopLoss pos‿data` | Intrabar stop-loss → `{pos,ret,triggered}` |
| `TakeProfit` | `pct TakeProfit pos‿data` | Intrabar take-profit |
| `StopTake` | `stop‿tp StopTake pos‿data` | Combined stop/take (stop wins on tie) |

Note: `RunOHLC` re-exported from bt.bqn: `pos RunOHLC data` — open-to-open returns.

### uni.bqn — Universe Management

Imports bt.bqn. Import directly for multi-asset universe strategies.

| Export | Signature | Description |
|--------|-----------|-------------|
| `Universe` | `Universe namespaces` | Stack aligned OHLCV into matrix namespace |
| `XRank` | `XRank mat` | Cross-sectional rank per row (0=lowest) |
| `XScore` | `XScore mat` | Cross-sectional z-score per row |
| `XWeight` | `XWeight mat` | L1-normalize row weights |
| `LongOnly` | `LongOnly mat` | Zero negatives, renormalize |
| `TopN` | `n TopN scores` | Long top-N, short bottom-N, equal weight |
| `_UniRun` | `Strategy _UniRun universe` | Apply strategy to universe matrix |
| `UniReport` | `name UniReport universe‿pos` | Per-asset + combined report |

Note: `LoadMany` added to core.bqn (`LoadMany paths`), `AlignDates` added to bt.bqn (`AlignDates namespaces`).

## BQN Landmines

- **Right-to-left evaluation**: `a-b-c` = `a-(b-c)`. Use `a-(b+c)` or explicit parens.
- **Immediate blocks**: `{expr}` without `𝕩`/`𝕨`/`𝕊` is an immediate block, not a function. This matters for `⎊` (Catch) — the left operand must reference a special name to be a function.
- **No variable redefinition**: use `↩` for reassignment, `←` only for first definition.
- **`•Import` is relative to the .bqn file**, not the caller.
- **Namespace export**: `⇐` exports. `⟨A,B⟩ ⇐ ns` destructures and re-exports.
- **`_Sim` closure mutation**: `state ↩ ...` inside `{...}¨` is the standard BQN pattern for sequential fold with changing state.
- **Array stranding**: `a‿b‿c` creates a flat 3-element list. Use `⟨a, b⟩` for nested lists (e.g., pos‿ret pairs).
- **`⍒` on equal scores**: picks first index (deterministic).
- **`×⊸×` is sign×𝕩, not 𝕨×𝕩**: `⊸` applies left operand monadically to `𝕨`. Use plain `×` for dyadic multiply.
- **Functions can't be dyadic args**: `F G x` is a train, not `G` with `𝕨=F`. Use a 1-modifier (`_Price` not `Price`) to receive functions as operands.
- **`•MonoTime@` needs parens before arithmetic**: `•MonoTime@ - t0` parses as `•MonoTime (@ - t0)`. Write `(•MonoTime@)-t0`.

## Conventions

- Comment tags: `# TODO:`, `# NOTE:`, `# BUG:`, `# FIX:`, `# HACK:`, `# PERF:`, `# WARNING:`
- Headers: `# bbq — BQN Based Quant` / `# engine/file.bqn — description`
- Section dividers: `# ── Name ─────────────────────────────`
- Tests: `tests/verify.bqn`, run with `make test`
- Strategies import `bt.bqn`, walk-forward scripts import `wf.bqn`, composed strategies also import `cmp.bqn`
