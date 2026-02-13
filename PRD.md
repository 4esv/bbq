# bbq — Product Requirements Document

**BQN Backtesting for Quant.**
A toolkit, not a framework.

---

## 1. Project identity

**Name:** bbq (lowercase, always)
**Tagline:** BQN Backtesting for Quant
**License:** MIT
**Language:** BQN (specifically CBQN)
**Philosophy:** Toolkit, not framework. Composable functions. No magic, no lifecycle hooks, no config files. As simple as possible, no simpler.

The code should be clean, well-named, with just enough comments to explain the non-obvious. If you can read BQN, you can read bbq.

---

## 2. Project structure

```
bbq/
├── engine/
│   └── bt.bqn              # The toolkit. All public API lives here.
├── strategies/
│   └── ma_cross.bqn         # One clean example strategy. Ships with repo.
├── data/
│   ├── fetch.py              # yfinance fetcher (Python)
│   └── .gitkeep              # CSVs are gitignored
├── lab/
│   ├── STRATEGIES.md         # Research journal template (blank)
│   └── scratch.bqn           # REPL playground (tracked, one-line header)
├── README.md
├── LICENSE                   # MIT
├── CONTRIBUTING.md           # See §12
├── Makefile                  # See §11
└── .gitignore                # See §13
```

No other files. No CI configs, no package.json, no Docker. This is a BQN project with one Python helper.

---

## 3. Data layer

### `Load` — CSV parser

```bqn
Load ⇐ {𝕊 path: ...}
# "data/spy.csv" Load → {dates⇐, close⇐, high⇐, low⇐, open⇐, vol⇐}
```

**Input:** Path to a yfinance-format CSV file.

**Output:** A namespace (the data contract):

```bqn
{
  dates ⇐ ⟨"2020-01-02", "2020-01-03", ...⟩   # string array
  close ⇐ ⟨320.71, 321.22, ...⟩                 # float array
  high  ⇐ ⟨321.15, 322.50, ...⟩                 # float array
  low   ⇐ ⟨319.80, 320.00, ...⟩                 # float array
  open  ⇐ ⟨320.00, 321.00, ...⟩                 # float array
  vol   ⇐ ⟨33400000, 28900000, ...⟩             # float array
}
```

**Implementation notes:**

- yfinance CSVs have a multi-index header. The first 3 lines must be skipped (`3↓lines`).
- Parse with BQN's `•FLines` and CSV splitting.
- All numeric arrays must be **flat float arrays** (not nested). This is critical for CBQN's SIMD paths.
- The data namespace IS the interface contract. Any future data source (Alpaca, Binance, another CSV format) just needs to return this same shape.

### `fetch.py` — Data fetcher

Minimal Python script. Downloads SPY (default) or any ticker via yfinance. Saves to `data/{ticker}.csv`.

```bash
python data/fetch.py              # fetches SPY, 5 years daily
python data/fetch.py AAPL 10y     # fetches AAPL, 10 years
```

Keep it under 30 lines. No argparse — just positional args with defaults.

---

## 4. Indicators layer

Every indicator is a pure function: arrays in, array out. No state, no side effects. All dyadic indicators take `n Indicator prices` unless noted otherwise.

**Output is shorter than input** by the warmup period. This is intentional — the `Mask` helper (§6) handles alignment. Do not pad with zeros or NaN. BQN doesn't have NaN in the same way Python does, and padding creates silent bugs.

### Tier 1 — Ship in v0.1

| Name | Signature | Description | Implementation |
|------|-----------|-------------|----------------|
| `MA` | `n MA prices → array` | Simple moving average | Prefix-sum difference: O(n). Compute `cs←+\prices`, then `((n↓cs) - ((-n)↓cs)) ÷ n`. |
| `EMA` | `n EMA prices → array` | Exponential moving average | Scan with α-blend. `α←2÷1+n`. Seed with `⊑prices`. `(⊑𝕩){(α×𝕩)+(1-α)×𝕨}\`𝕩`. Returns **same length** as input (first value = first price). |
| `WMA` | `n WMA prices → array` | Weighted moving average | Windowed weighted sum. Weights `w←1+↕n`, normalized. Apply per window: `{(+´w×𝕩)÷+´w}˘ n↕prices`. |
| `Std` | `n Std prices → array` | Rolling standard deviation | Windowed. `{m←+´÷≠𝕩 ⋄ √+´(𝕩-m)⋆2÷≠𝕩}˘ n↕prices`. Population std (divide by n, not n-1) — standard for financial indicators. |
| `RSI` | `n RSI prices → array` | Relative Strength Index (0–100) | Most complex Tier 1. Steps: (1) `deltas ← 1↓ -⟜»prices`. (2) `gains ← 0⌈deltas`, `losses ← 0⌈-deltas`. (3) Wilder-smooth both. (4) `rs ← avgGain ÷ avgLoss`. (5) `100 - 100÷1+rs`. |
| `MACD` | `fast‿slow‿sig MACD prices → macd‿signal‿hist` | MACD (3 lines) | Three EMAs composed. `macd_line ← (fast EMA prices) - (slow EMA prices)`. `signal_line ← sig EMA macd_line`. `histogram ← macd_line - signal_line`. Standard params: `12‿26‿9`. |
| `ATR` | `n ATR data → array` | Average True Range | Takes data namespace (needs high, low, close). True Range: `tr ← ⌈´˘ ⍉> ⟨h-l, |h-»c|, |l-»c|⟩`. Then Wilder-smooth. |
| `Mom` | `n Mom prices → array` | Momentum (price change) | `(n↓prices) - ((-n)↓prices)`. Trivial shift-and-subtract. |
| `ROC` | `n ROC prices → array` | Rate of Change (%) | `100 × ((n↓prices) - ((-n)↓prices)) ÷ (-n)↓prices`. Mom as percentage. |
| `Stoch` | `n Stoch data → k‿d` | Stochastic %K/%D | Takes data namespace. `%K ← 100 × (c - n RMin l) ÷ (n RMax h) - (n RMin l)`. `%D ← 3 MA k`. Returns 2-element list. Handle division by zero. |
| `BB` | `n‿k BB prices → upper‿mid‿lower` | Bollinger Bands | `mid ← n MA prices`. `std ← n Std prices`. `upper ← mid + k×std`. `lower ← mid - k×std`. Standard params: `20‿2`. |
| `OBV` | `OBV close‿vol → array` | On-Balance Volume | Monadic. `signs ← ×-⟜»close`. `+\`signs × vol`. First element is first volume. |
| `VWAP` | `VWAP data → array` | Volume-Weighted Avg Price | Monadic. Takes data namespace. Typical price `tp ← (+´⊸÷≠) ⍉> ⟨h, l, c⟩` per bar. Then cumulative: `(+\`tp×v) ÷ (+\`v)`. |
| `AD` | `AD data → array` | Accumulation/Distribution | Monadic. Takes data namespace. Money flow multiplier: `mfm ← ((c-l)-(h-c)) ÷ (h-l)`. Money flow volume: `mfv ← mfm × v`. A/D line: `+\`mfv`. Handle `h=l` (zero range → `mfm=0`). |
| `RMax` | `n RMax prices → array` | Rolling maximum | `⌈´˘ n↕prices`. One expression. |
| `RMin` | `n RMin prices → array` | Rolling minimum | `⌊´˘ n↕prices`. One expression. |

That's 17 indicator functions (counting OBV, VWAP, AD as monadic, MACD/BB/Stoch as multi-output).

### Tier 2 — Do not implement, document as "coming soon"

DEMA, TEMA, ADX, Ichimoku, Keltner Channels, CCI, Williams %R, Parabolic SAR. Each composes from Tier 1 primitives.

### Internal helper: Wilder smoothing

RSI and ATR both use Wilder smoothing (identical to EMA with α=1/n). Factor this out as a private helper within `bt.bqn`:

```bqn
# Not exported. Used by RSI and ATR internally.
wilder ← {α←÷𝕨 ⋄ (⊑𝕩){(α×𝕩)+(1-α)×𝕨}`𝕩}
```

---

## 5. Simulation layer

### `_Sim` — Stateful position simulator (1-modifier)

A 1-modifier that turns any step function into a position-generating scan.

```bqn
_Sim ⇐ {
  # 𝔽 = step function: state 𝔽 observation → new_state
  # 𝕩 = init‿observations (2-element list)
  #   init = initial state (list, first element = position)
  #   observations = array of per-bar data
  # Returns: position array (extracted from first element of each state)
  init‿obs ← 𝕩
  ⊑¨ init 𝔽` obs
}
```

**The contract:**

- Your step function is `state 𝔽 observation → new_state`.
- State is a BQN list. The **first element is always the current position** (1, 0, or ¯1).
- `_Sim` runs the scan, then extracts position (element 0) from each intermediate state.

**Why first-element convention:** It's the simplest possible extraction — `⊑` (first) on each state. No magic keys, no namespace overhead, just positional convention. It mirrors how BQN destructuring works: `pos‿rest ← state` naturally puts position first.

### Nesting for complex state

State is a BQN list. Lists nest. This is how complex strategies compose state without any framework support:

```bqn
# Simple: ⟨pos⟩
# Trailing stop: ⟨pos, peak⟩
# Kalman + trailing stop: ⟨pos, peak, ⟨kx, kp⟩⟩
# Kalman + trailing stop + regime: ⟨pos, peak, ⟨kx, kp⟩, ⟨regime, count⟩⟩
```

Each "concern" is a sub-list. The step function destructures on entry:

```bqn
Step ← {
  pos‿peak‿kalman ← 𝕨          # top-level destructure
  kx‿kp ← kalman               # nested destructure
  # ... compute ...
  ⟨newPos, newPeak, kx‿kp⟩     # re-nest on exit
}
```

The scan doesn't inspect state. It passes it opaquely. You destructure what you need, leave the rest nested. BQN lists are dynamically typed; the nesting IS the composition.

### Observations format

The observations argument is what the step function receives as `𝕩` on each bar. For strategies that only need price: pass the price array directly. For multiple series: pre-zip them:

```bqn
# Price only:
Step _Sim ⟨0⟩‿prices

# Multiple series (price, lower band, moving average):
obs ← <˘⍉> price‿lower‿ma    # transpose + box → list of 3-element lists
Step _Sim ⟨0⟩‿obs
```

The `<˘⍉>` idiom: `>` merges arrays into a matrix (one per row), `⍉` transposes so each column is one bar, `<˘` boxes each column into a list. Result: `⟨⟨p₁,l₁,m₁⟩, ⟨p₂,l₂,m₂⟩, ...⟩`.

### What `_Sim` is NOT

It is not an engine. It does not compute returns, apply costs, or shift signals. It is purely a helper for strategies that need bar-by-bar state threading to generate their position array. The position array it returns feeds into the same `Run` pipeline as any array-computed position.

---

## 6. Signal utilities layer

### `Cross` — Crossover detection

```bqn
Cross ⇐ {(𝕨≥𝕩) ∧ (»𝕨)<»𝕩}   # 𝕨 crosses above 𝕩 → boolean array
```

`fast Cross slow` returns 1 on bars where fast crosses above slow. The "was-below AND now-at-or-above" pattern.

### `CrossDown` — Cross under detection

```bqn
CrossDown ⇐ {(𝕨≤𝕩) ∧ (»𝕨)>»𝕩}   # 𝕨 crosses below 𝕩
```

Mirror of `Cross`.

### `Mask` — Warmup zeroing

```bqn
Mask ⇐ {(𝕨⥊0)∾𝕨↓𝕩}   # n Mask array → array with first n elements zeroed
```

Every strategy needs this. Moving averages produce meaningless values during their warmup period. `50 Mask positions` zeros the first 50 elements. Result is the same length as input.

### `Fill` — Forward-fill signals to positions

```bqn
Fill ⇐ {(⊑𝕩){𝕩+(𝕩=0)×𝕨}`𝕩}   # sparse signals → held positions
```

Converts a sparse signal array (mostly zeros with occasional 1 or ¯1) into a held-position array where positions persist until changed. Signal 1 = "go long and stay long." Signal ¯1 = "go short and stay short." Signal 0 = "no change." The forward-fill scan: remember the last non-zero value.

### `Thresh` / `ThreshDown` — Threshold crossing

```bqn
Thresh ⇐ {(𝕩>𝕨) ∧ (»𝕩)≤𝕨}       # value crosses above level
ThreshDown ⇐ {(𝕩<𝕨) ∧ (»𝕩)≥𝕨}   # value crosses below level
```

`30 ThreshDown rsi` returns 1 when RSI drops below 30. `70 Thresh rsi` returns 1 when RSI rises above 70. For indicator-to-signal conversion.

### `Hold` — Minimum holding period (debounce)

```bqn
Hold ⇐ {
  # n Hold positions → positions with min n-bar hold after entry
  # Suppresses exits for n bars after any entry
  0‿0 {
    pos‿count ← 𝕨
    count>0 ? ⟨pos, count-1⟩;   # still in hold period, keep position
    𝕩≠pos ? ⟨𝕩, 𝕨⊑⟨0,𝕨⟩⟩;     # position changed, start hold if entering
    ⟨𝕩, 0⟩                       # no change
  }` 𝕩
  # extract positions from state
}
```

`5 Hold positions` ensures every position is held at least 5 bars. Prevents churn from rapid entry/exit oscillation. Implementation is a scan.

---

## 7. Backtest core layer

### `Ret` — Daily returns

```bqn
Ret ⇐ {1↓ -⟜» ⊸(÷⟜») 𝕩}   # prices → simple returns
# Or equivalently: (1↓𝕩 - ¯1↓𝕩) ÷ ¯1↓𝕩
```

Returns array is one element shorter than prices. This is correct — there's no return on day 1.

### `LogRet` — Log returns

```bqn
LogRet ⇐ {1↓ -⟜» ⊛𝕩}   # prices → log returns
```

Log returns are additive (useful for cumulative computations). Provide both; let the user choose.

### `Run` — Apply positions to returns

```bqn
Run ⇐ {𝕨 × 𝕩}   # positions Run returns → strategy returns
```

Yes, it's multiplication. Naming it matters. `pos Run ret` reads as English and makes the pipeline legible. Position and return arrays must be the same length — the strategy is responsible for alignment (via `Mask` and truncation).

### `Cost` — Transaction cost deduction

```bqn
Cost ⇐ {𝕨 × | -⟜» 𝕩}   # rate Cost positions → cost_array
```

`0.001 Cost positions` computes per-bar transaction costs at 10 bps. Costs are incurred on position changes only: `|-⟜» positions|` gives the absolute change in position (0→1 = cost of 1, 1→¯1 = cost of 2). Multiply by rate.

### `Equity` — Equity curve

```bqn
Equity ⇐ {×` 1+𝕩}   # returns → equity curve (starts at 1)
```

Cumulative product of (1 + returns). Starts at 1 (normalized). This is the most important derived array — it's what you plot, what you compute drawdowns from, what tells you if your strategy works.

---

## 8. Metrics layer

Every metric is a pure function: returns array in, number out. No side effects.

### Core metrics — Ship in v0.1

| Name | Signature | Formula | Notes |
|------|-----------|---------|-------|
| `Sharpe` | `returns → number` | `(√252) × mean(r) ÷ std(r)` | Annualized. 252 trading days. Risk-free rate = 0. |
| `Sortino` | `returns → number` | `(√252) × mean(r) ÷ √mean((0⌊r)²)` | Downside volatility only. |
| `Calmar` | `returns → number` | `CAGR ÷ |MaxDD|` | Return vs. worst-case loss. |
| `MaxDD` | `returns → number` | `⌊´ (eq-mx)÷mx` where `eq←×\`1+r`, `mx←⌈\`eq` | Returns negative (e.g., ¯0.15 = 15% drawdown). Most important risk metric. |
| `MaxDDDur` | `returns → number` | Longest run where `eq < mx` | Returns bar count. |
| `TotalRet` | `returns → number` | `(¯1⊑×\`1+r) - 1` | Cumulative return as decimal (0.45 = 45%). |
| `CAGR` | `returns → number` | `((¯1⊑eq)⋆252÷≠r) - 1` | Compound annual growth rate. 252 days/year. |
| `AnnVol` | `returns → number` | `std(r) × √252` | Annualized volatility. Population std. |
| `WinRate` | `returns → number` | `(+´r>0) ÷ +´r≠0` | Positive days ÷ active days. |
| `ProfitFactor` | `returns → number` | `(+´r×r>0) ÷ |+´r×r<0|` | Gross profit ÷ gross loss. |
| `AvgWin` | `returns → number` | `mean((r>0)/r)` | Mean of positive returns. |
| `AvgLoss` | `returns → number` | `mean((r<0)/r)` | Mean of negative returns (will be negative). |
| `Expectancy` | `returns → number` | `(WinRate × AvgWin) + ((1-WinRate) × AvgLoss)` | Expected value per trade. Positive = edge. |
| `Trades` | `positions → number` | `+´ (»𝕩)≠𝕩` | Count position changes. Takes **positions**, not returns. |
| `TimeIn` | `positions → number` | `(+´𝕩≠0)÷≠𝕩` | Fraction of time in market. Takes **positions**. |
| `Skew` | `returns → number` | Third standardized moment | Negative = crash risk. Positive = fat right tail. |
| `Kurt` | `returns → number` | Fourth standardized moment minus 3 | Excess kurtosis. >0 = fatter tails than normal. |
| `Exposure` | `positions → number` | Same as `TimeIn` | Alias. Same function, two names. |

That's 18 metric functions (17 unique + 1 alias).

### The drawdown series (internal)

Compute the full drawdown series once, derive `MaxDD`, `MaxDDDur`, and (later) recovery factor from it:

```bqn
# Internal: compute drawdown series from returns
ddSeries ← {
  eq ← ×`1+𝕩          # equity curve
  mx ← ⌈`eq           # running max (high-water mark)
  (eq - mx) ÷ mx      # drawdown series (all ≤ 0)
}
```

`MaxDD = ⌊´ ddSeries`. `MaxDDDur` = longest run of negative values in the series.

---

## 9. Reporting layer

### `Report` — One-call summary

```bqn
Report ⇐ {
  # name‿pos Report strat_ret‿bh_ret → prints to stdout
  # name: string label
  # pos: position array (for Trades, TimeIn)
  # strat_ret: strategy returns
  # bh_ret: buy-and-hold returns (benchmark)
}
```

**Output format** (printed to stdout):

```
═══ MA Cross (10/50) ═══
Total:    +23.4%  (B&H: +67.2%)
CAGR:      +4.3%  (B&H: +10.8%)
Sharpe:     0.41  (B&H:   0.72)
Sortino:    0.58  (B&H:   0.94)
MaxDD:    -18.2%  (B&H: -33.7%)
Calmar:     0.24  (B&H:   0.32)
Volatility: 12.1%  (B&H:  18.4%)
Win Rate:  52.3%
Profit Factor: 1.08
Expectancy: +0.02%
Trades:      47
Time In:   68.4%
Skew:      -0.31
Kurtosis:   2.14
───
Verdict: Not worth pursuing
```

**Verdict logic** (hardcoded thresholds):

| Condition | Verdict |
|-----------|---------|
| Sharpe ≥ 1.0 | Worth paper trading |
| Sharpe ≥ 0.5 | Has potential, needs work |
| Sharpe < 0.5 | Not worth pursuing |
| MaxDD < ¯0.40 | Max drawdown > 40%, reconsider (overrides above) |

**Formatting details:**

- Right-align numbers for scanability
- Always show benchmark comparison for return-based metrics
- Show ± signs on percentages
- Use box-drawing characters for structure (`═` for title, `─` for separator)
- The exact format above is a target, not a specification — match the spirit

---

## 10. Strategy file anatomy

### Template structure (generated by `make new`)

```bqn
# Strategy: {name}
# Hypothesis: {TODO: What do you believe about the market?}
# Parameters: {TODO: List tunable values}
# Created: {date}

bt ← •Import "../engine/bt.bqn"
data ← bt.Load "../data/spy.csv"
c ← data.close

# ── Indicators ──────────────────────────────
# TODO: compute your indicators here

# ── Signals / Positions ─────────────────────
# TODO: generate position array (1=long, 0=flat, ¯1=short)
pos ← 0⥊˜≠c  # placeholder: flat

# ── Backtest ────────────────────────────────
warmup ← 0  # TODO: set to max indicator period
pos ← warmup bt.Mask pos
ret ← bt.Ret c
bh ← ret                        # buy-and-hold benchmark
strat ← (warmup↓pos) bt.Run warmup↓ret

"{name}"‿(warmup↓pos) bt.Report strat‿bh
```

Section markers use BQN comment lines with box-drawing for visual structure. The hypothesis field is the most important line in the file — it forces you to articulate *why* this strategy should work BEFORE seeing results.

### Example strategy: `ma_cross.bqn`

Ships with the repo. Complete, runnable, demonstrates the full pattern:

```bqn
# Strategy: MA Cross
# Hypothesis: Short-term trend following — when the fast MA crosses above
#   the slow MA, momentum is shifting upward. Simple, ancient, probably wrong.
# Parameters: fast=10, slow=50

bt ← •Import "../engine/bt.bqn"
data ← bt.Load "../data/spy.csv"
c ← data.close

# ── Indicators ──────────────────────────────
fast ← 10 bt.MA c
slow ← 50 bt.MA c

# ── Signals / Positions ─────────────────────
pos ← 50 bt.Mask fast > slow    # long when fast > slow

# ── Backtest ────────────────────────────────
ret ← bt.Ret c
bh ← ret
strat ← (50↓pos) bt.Run 50↓ret

"MA Cross (10/50)"‿(50↓pos) bt.Report strat‿bh
```

Run with `bqn strategies/ma_cross.bqn`. It prints the full report. That's the whole user experience.

---

## 11. Makefile

```makefile
.PHONY: new fetch run source clean help

define STRATEGY_TEMPLATE
# Strategy: $(name)
# Hypothesis: TODO — What do you believe about the market?
# Parameters: TODO — List tunable values
# Created: $(shell date +%Y-%m-%d)

bt ← •Import "../engine/bt.bqn"
data ← bt.Load "../data/spy.csv"
c ← data.close

# ── Indicators ──────────────────────────────
# TODO: compute your indicators here

# ── Signals / Positions ─────────────────────
# TODO: generate position array (1=long, 0=flat, ¯1=short)
pos ← 0⥊˜≠c  # placeholder: flat

# ── Backtest ────────────────────────────────
warmup ← 0  # TODO: set to max indicator period
pos ← warmup bt.Mask pos
ret ← bt.Ret c
bh ← ret                        # buy-and-hold benchmark
strat ← (warmup↓pos) bt.Run warmup↓ret

"$(name)"‿(warmup↓pos) bt.Report strat‿bh
endef
export STRATEGY_TEMPLATE

# Create a new strategy from template
# Usage: make new name=bollinger
new:
	@test -n "$(name)" || (echo "Usage: make new name=strategy_name" && exit 1)
	@test ! -f strategies/$(name).bqn || (echo "strategies/$(name).bqn already exists" && exit 1)
	@echo "$$STRATEGY_TEMPLATE" > strategies/$(name).bqn
	@echo "Created strategies/$(name).bqn"

# Fetch market data
# Usage: make fetch [ticker=AAPL] [period=5y]
fetch:
	python data/fetch.py $(or $(ticker),SPY) $(or $(period),5y)

# Run a strategy
# Usage: make run name=ma_cross
run:
	@test -n "$(name)" || (echo "Usage: make run name=strategy_name" && exit 1)
	bqn strategies/$(name).bqn

# Create a new data source (fetcher + parser pair)
# Usage: make source name=alpaca
source:
	@test -n "$(name)" || (echo "Usage: make source name=source_name" && exit 1)
	@test ! -f data/$(name)_fetch.py || (echo "data/$(name)_fetch.py already exists" && exit 1)
	@printf '# $(name) data fetcher\n# Downloads market data to data/*.csv\n# Parser: $(name)_load.bqn\n\nimport sys\n\n# TODO: implement fetcher\n# Output: CSV with columns Date,Open,High,Low,Close,Volume\n# Save to: data/{ticker}.csv\n' > data/$(name)_fetch.py
	@printf '# $(name) data parser\n# Reads CSV from $(name)_fetch.py into bbq data contract\n# Fetcher: $(name)_fetch.py\n#\n# Must return: {dates⇐, close⇐, high⇐, low⇐, open⇐, vol⇐}\n# All numeric arrays: flat floats, same length\n\n# TODO: implement parser\n' > data/$(name)_load.bqn
	@echo "Created data/$(name)_fetch.py  — fetcher: download to data/*.csv"
	@echo "Created data/$(name)_load.bqn  — parser: CSV -> {dates,close,high,low,open,vol}"

# Remove downloaded data
clean:
	rm -f data/*.csv

help:
	@echo "bbq — BQN Backtesting for Quant"
	@echo ""
	@echo "  make new name=X      Create strategy from template"
	@echo "  make fetch [ticker=X] Download market data"
	@echo "  make run name=X      Run a strategy"
	@echo "  make source name=X   Create data source (fetcher + parser)"
	@echo "  make clean            Remove data files"
```

**Implementation notes:**
- `make new` uses a `define/endef` block for the template. No separate template file — one fewer file to maintain, no risk of drift.
- `make source` creates both `data/{name}_fetch.py` (Python fetcher stub with output contract) and `data/{name}_load.bqn` (BQN parser stub with namespace contract). Each file has a comment pointing to its counterpart.

---

## 12. CONTRIBUTING.md

The entire file:

```markdown
# Contributing

Please don't.
```

This is not rude — it's honest scope management. If the project grows, this file can grow with it.

---

## 13. .gitignore

```gitignore
# Data
data/*.csv

# OS
.DS_Store
*~
```

---

## 14. README.md

Tone: dry, understated, precise. Every sentence earns its place.

### Structure

```markdown
# bbq

**BQN Backtesting for Quant.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Overview

bbq is a toolkit for backtesting trading strategies in BQN.
It provides indicators, a simulation helper, metrics, and reporting.
You provide the hypothesis; it provides the disappointment.

## Quick Start

[show: fetch data, run ma_cross, see output]

## Usage

### Writing a Strategy

[show: the anatomy of a strategy file, 3 paragraphs max]
[show: pure array strategy pattern — 5 lines]
[show: stateful strategy pattern with _Sim — 10 lines]

### Data Contract

[document the namespace shape]
[one paragraph on adding new data sources]

### Indicators

[table: Name | Signature | one-line description]

### Signal Utilities

[table: Name | Signature | one-line description]

### Simulation

[explain _Sim in 2 paragraphs]
[show the observation-zipping idiom: <˘⍉>]
[show nested state example]

### Metrics

[table: Name | what it tells you]

### Makefile

[list the commands]

## Design

A backtest is a fold.
Indicators are array operations.
Positions are arrays of 1, 0, and ¯1.
The engine multiplies positions by returns.
Everything else is decoration.

[One paragraph on the two-phase architecture]
[One paragraph on scan as state machine]

## License

MIT.
```

**What the README is NOT:**

- A tutorial on BQN
- A tutorial on backtesting
- A tutorial on trading
- Longer than what fits on two screens

---

## 15. Implementation order

Build in this order. Each step should be testable before moving to the next.

1. **Project skeleton** — Directory structure, LICENSE, CONTRIBUTING.md, .gitignore, empty files.
2. **`fetch.py`** — Data fetcher. Test: `python data/fetch.py` produces `data/SPY.csv`.
3. **`bt.bqn` — Load** — CSV parser. Test: `bt.Load "data/spy.csv"` returns namespace with correct array lengths.
4. **`bt.bqn` — Indicators** — MA first, then EMA, Std, ATR, Mom, ROC, RMax, RMin. Then RSI, MACD, Stoch, BB (these compose from earlier ones). Then OBV, VWAP, AD. Test each: known input → expected output.
5. **`bt.bqn` — Signal utilities** — Cross, CrossDown, Mask, Fill, Thresh, ThreshDown, Hold.
6. **`bt.bqn` — `_Sim`** — The modifier. Test with a trivial step function.
7. **`bt.bqn` — Core** — Ret, LogRet, Run, Cost, Equity.
8. **`bt.bqn` — Metrics** — All 18. Test: verify Sharpe of random returns ≈ 0, Sharpe of constant positive returns is high, MaxDD of monotonically increasing equity = 0, etc.
9. **`bt.bqn` — Report** — Formatted output.
10. **`ma_cross.bqn`** — Example strategy. Test: `bqn strategies/ma_cross.bqn` prints a complete report.
11. **Makefile** — All targets.
12. **`lab/`** — STRATEGIES.md template, scratch.bqn with header.
13. **README.md** — Last, because now you know what the API actually looks like.

---

## 16. What NOT to build

- No multi-asset portfolio support
- No position sizing (always 1 = full position)
- No short selling cost modeling
- No intraday / tick data support
- No database storage
- No web UI, no plots, no charts
- No Monte Carlo or walk-forward analysis
- No parameter optimization (the user does sweeps manually)
- No Tier 2/3 indicators (ADX, Ichimoku, Parabolic SAR, etc.)
- No event-driven engine mode
- No tests directory (the example strategy IS the test)
- No CI/CD
- No documentation beyond README

If it's not in this PRD, it doesn't exist yet.

---

## 17. Version

This is v0.1. The version lives only in the README, not in code.

---

## 18. Success criteria

The project is done when:

1. `python data/fetch.py` downloads data
2. `bqn strategies/ma_cross.bqn` prints a full report with 18 metrics
3. `make new name=test` creates a runnable strategy template
4. The README accurately describes what exists

---

A toolkit.
