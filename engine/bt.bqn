# bbq — BQN Backtesting for Quant
# engine/bt.bqn — all public API

# ── Data ─────────────────────────────────────

# NOTE: yfinance CSV format: 3 header lines, then Date,Close,High,Low,Open,Volume
Split ← (⊢-˜+`×¬)∘=⟜','⊸⊔

Load ⇐ {
  lines ← •FLines 𝕩
  rows ← Split¨ 3↓lines
  dates ⇐ 0⊸⊑¨ rows
  close ⇐ •ParseFloat¨ 1⊸⊑¨ rows
  high  ⇐ •ParseFloat¨ 2⊸⊑¨ rows
  low   ⇐ •ParseFloat¨ 3⊸⊑¨ rows
  open  ⇐ •ParseFloat¨ 4⊸⊑¨ rows
  vol   ⇐ •ParseFloat¨ 5⊸⊑¨ rows
}

# ── Indicators ───────────────────────────────

# Wilder smoothing (EMA with α=1/n). Used by RSI and ATR.
Wilder ← {a←÷𝕨 ⋄ (⊑𝕩){(a×𝕩)+(1-a)×𝕨}`𝕩}

# n RMax prices — rolling maximum
RMax ⇐ {⌈´˘ 𝕨↕𝕩}

# n RMin prices — rolling minimum
RMin ⇐ {⌊´˘ 𝕨↕𝕩}

# n MA prices — simple moving average, O(n) via prefix-sum
MA ⇐ {
  cs ← 0∾+`𝕩
  ((𝕨↓cs) - ((-𝕨)↓cs)) ÷ 𝕨
}

# n EMA prices — exponential moving average, same length as input
EMA ⇐ {
  a ← 2÷1+𝕨
  (⊑𝕩) {(a×𝕩)+(1-a)×𝕨}` 𝕩
}

# n WMA prices — weighted moving average
WMA ⇐ {
  w ← 1+↕𝕨
  {(+´w×𝕩)÷+´w}˘ 𝕨↕𝕩
}

# n Std prices — rolling population standard deviation
Std ⇐ {
  {m←(+´÷≠)𝕩 ⋄ √(+´(𝕩-m)⋆2)÷≠𝕩}˘ 𝕨↕𝕩
}

# n Mom prices — momentum (price difference)
Mom ⇐ {(𝕨↓𝕩) - ((-𝕨)↓𝕩)}

# n ROC prices — rate of change as percentage
ROC ⇐ {100 × ((𝕨↓𝕩) - ((-𝕨)↓𝕩)) ÷ (-𝕨)↓𝕩}

# n RSI prices — relative strength index (0-100)
RSI ⇐ {
  deltas ← 1↓ 𝕩 - »𝕩
  gains ← 0⌈deltas
  losses ← 0⌈-deltas
  ag ← 𝕨 Wilder gains
  al ← 𝕨 Wilder losses
  100 - 100÷1+ag÷al⌈1e¯10
}

# fast‿slow‿sig MACD prices → macd‿signal‿hist
MACD ⇐ {
  fast‿slow‿sig ← 𝕨
  ml ← (fast EMA 𝕩) - slow EMA 𝕩
  sl ← sig EMA ml
  n ← ≠sl
  ml‿sl‿(ml-sl)
}

# n ATR data — average true range, takes namespace {high,low,close}
ATR ⇐ {
  h ← 𝕩.high ⋄ l ← 𝕩.low ⋄ c ← 𝕩.close
  hl ← h-l
  hc ← |h - »c
  lc ← |l - »c
  tr ← hl⌈hc⌈lc
  1↓ 𝕨 Wilder tr
}

# n Stoch data → k‿d — stochastic oscillator
Stoch ⇐ {
  c ← 𝕩.close ⋄ h ← 𝕩.high ⋄ l ← 𝕩.low
  lo ← 𝕨 RMin l
  hi ← 𝕨 RMax h
  rng ← hi - lo
  # NOTE: align close to window output (drop n-1 warmup bars)
  k ← 100 × (((𝕨-1)↓c)-lo) ÷ rng⌈1e¯10
  d ← 3 MA k
  k‿d
}

# n‿k BB prices → upper‿mid‿lower — Bollinger Bands
BB ⇐ {
  n‿k ← 𝕨
  mid ← n MA 𝕩
  sd ← n Std 𝕩
  (mid+k×sd)‿mid‿(mid-k×sd)
}

# OBV close‿vol — on-balance volume (monadic)
OBV ⇐ {
  c‿v ← 𝕩
  signs ← × -⟜» c
  +` signs × v
}

# VWAP data — volume-weighted average price (monadic, takes namespace)
VWAP ⇐ {
  tp ← (𝕩.high + 𝕩.low + 𝕩.close) ÷ 3
  (+`tp×𝕩.vol) ÷ +`𝕩.vol
}

# AD data — accumulation/distribution line (monadic, takes namespace)
AD ⇐ {
  h←𝕩.high ⋄ l←𝕩.low ⋄ c←𝕩.close ⋄ v←𝕩.vol
  rng ← h-l
  mfm ← ((c-l)-(h-c)) ÷ rng⌈1e¯10
  +` mfm × v
}

# ── Signal Utilities ─────────────────────────

# fast Cross slow — 1 where fast crosses above slow
Cross ⇐ {(𝕨≥𝕩) ∧ (»𝕨)<»𝕩}

# fast CrossDown slow — 1 where fast crosses below slow
CrossDown ⇐ {(𝕨≤𝕩) ∧ (»𝕨)>»𝕩}

# n Mask arr — zero first n elements, same length
Mask ⇐ {(𝕨⥊0)∾𝕨↓𝕩}

# Fill signals — forward-fill: hold last non-zero
Fill ⇐ {(⊑𝕩){𝕩+(𝕩=0)×𝕨}`𝕩}

# level Thresh values — 1 where value crosses above level
Thresh ⇐ {(𝕩>𝕨) ∧ (»𝕩)≤𝕨}

# level ThreshDown values — 1 where value crosses below level
ThreshDown ⇐ {(𝕩<𝕨) ∧ (»𝕩)≥𝕨}

# n Hold positions — min n-bar holding period
Hold ⇐ {
  n ← 𝕨 ⋄ pos ← 0 ⋄ count ← 0
  {
    count>0 ? count-↩1 ⋄ pos;
    𝕩≠pos  ? count↩(𝕩≠0)×n-1 ⋄ pos↩𝕩;
    pos
  }¨ 𝕩
}

# ── Simulation ───────────────────────────────

# Step _Sim init‿obs → positions
# Step: state 𝔽 observation → new_state (first element = position)
_Sim ⇐ {
  init‿obs ← 𝕩
  state ← init
  Fn ← 𝔽
  {
    state ↩ state Fn 𝕩
    ⊑state
  }¨ obs
}

# ── Backtest Core ────────────────────────────

# Ret prices → simple returns (1 shorter than input)
Ret ⇐ {(1↓𝕩-»𝕩) ÷ 1↓»𝕩}

# LogRet prices → log returns (1 shorter than input)
LogRet ⇐ {1↓ ⋆⁼ 𝕩÷»𝕩}

# pos Run ret → strategy returns
Run ⇐ ×

# rate Cost pos → transaction cost array
Cost ⇐ {𝕨 × |-⟜»𝕩}

# Equity ret → equity curve starting at 1
Equity ⇐ {×`1+𝕩}

# ── Metrics ──────────────────────────────────

# Internal: drawdown series from returns
DdSeries ← {
  eq ← ×`1+𝕩
  mx ← ⌈`eq
  (eq-mx)÷mx
}

# Internal: population std
Pstd ← {m←(+´÷≠)𝕩 ⋄ √(+´(𝕩-m)⋆2)÷≠𝕩}

# Annualized Sharpe ratio (Rf=0)
Sharpe ⇐ {(√252) × ((+´÷≠)𝕩) ÷ (Pstd 𝕩)⌈1e¯10}

# Sortino ratio (downside deviation only)
Sortino ⇐ {
  m ← (+´÷≠)𝕩
  dd ← 0⌊𝕩
  ds ← √(+´dd⋆2)÷≠𝕩
  (√252) × m ÷ ds⌈1e¯10
}

# Maximum drawdown (negative number)
MaxDD ⇐ {⌊´ DdSeries 𝕩}

# Longest drawdown duration (bars)
MaxDDDur ⇐ {
  dd ← DdSeries 𝕩
  # Count consecutive bars where dd < 0
  run ← 0 ⋄ best ← 0
  {
    dd ← 𝕩
    dd<0 ? run+↩1 ⋄ best↩best⌈run;
    run↩0
  }¨ dd
  best⌈run
}

# Total cumulative return
TotalRet ⇐ {¯1+(¯1⊑×`1+𝕩)}

# Compound annual growth rate (252 days/yr)
CAGR ⇐ {((¯1⊑×`1+𝕩)⋆252÷≠𝕩)-1}

# Annualized volatility
AnnVol ⇐ {(Pstd 𝕩)×√252}

# Calmar ratio (CAGR / |MaxDD|)
Calmar ⇐ {(CAGR 𝕩) ÷ (|MaxDD 𝕩)⌈1e¯10}

# Win rate (positive days / active days)
WinRate ⇐ {
  active ← 𝕩≠0
  (+´𝕩>0) ÷ (+´active)⌈1
}

# Profit factor (gross profit / gross loss)
ProfitFactor ⇐ {
  (+´(𝕩>0)×𝕩) ÷ (|+´(𝕩<0)×𝕩)⌈1e¯10
}

# Average winning return
AvgWin ⇐ {w←(𝕩>0)/𝕩 ⋄ 0=≠w ? 0; w←(𝕩>0)/𝕩 ⋄ (+´÷≠)w}

# Average losing return (negative number)
AvgLoss ⇐ {l←(𝕩<0)/𝕩 ⋄ 0=≠l ? 0; l←(𝕩<0)/𝕩 ⋄ (+´÷≠)l}

# Expectancy (expected value per trade)
Expectancy ⇐ {
  wr ← WinRate 𝕩
  (wr × AvgWin 𝕩) + (1-wr) × AvgLoss 𝕩
}

# Trades — count position changes (takes positions)
Trades ⇐ {+´(»𝕩)≠𝕩}

# Time in market (takes positions)
TimeIn ⇐ {(+´𝕩≠0)÷≠𝕩}

# Exposure — alias for TimeIn
Exposure ⇐ TimeIn

# Skewness (third standardized moment)
Skew ⇐ {
  m ← (+´÷≠)𝕩
  s ← Pstd 𝕩
  (+´((𝕩-m)÷s⌈1e¯10)⋆3) ÷ ≠𝕩
}

# Excess kurtosis (fourth standardized moment minus 3)
Kurt ⇐ {
  m ← (+´÷≠)𝕩
  s ← Pstd 𝕩
  ¯3 + (+´((𝕩-m)÷s⌈1e¯10)⋆4) ÷ ≠𝕩
}
