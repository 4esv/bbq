# bbq — BQN Based Quant
# engine/core.bqn — shared primitives

# ── Constants ────────────────────────────────

eps ⇐ 1e¯10  # division guard
tdy ⇐ 252    # trading days/year

# ── Data ─────────────────────────────────────

# NOTE: yfinance CSV format: 3 header lines, then Date,Close,High,Low,Open,Volume
Split ⇐ (⊢-˜+`×¬)∘=⟜','⊸⊔

Load ⇐ {
  lines ← •FLines 𝕩
  rows ← Split¨ 3↓lines
  ! ∧´6≤≠¨rows
  dates ⇐ 0⊸⊑¨ rows
  close ⇐ •ParseFloat¨ 1⊸⊑¨ rows
  high  ⇐ •ParseFloat¨ 2⊸⊑¨ rows
  low   ⇐ •ParseFloat¨ 3⊸⊑¨ rows
  open  ⇐ •ParseFloat¨ 4⊸⊑¨ rows
  vol   ⇐ •ParseFloat¨ 5⊸⊑¨ rows
}

# 𝕨: 1 = strict/equity (default), 0 = futures (allows negative prices)
Validate ⇐ {
  𝕊 𝕩: 1 𝕊 𝕩;
  s ← 𝕨 ⋄ d ← 𝕩
  ! 0<≠d.close
  n ← ≠d.close
  ! n=≠d.high
  ! n=≠d.low
  ! n=≠d.open
  ! n=≠d.vol
  # NOTE: NaN≠NaN in IEEE 754, Inf detected via comparison
  ! ∧´(d.close=d.close)∧¬∞=|d.close
  ! ∧´(d.high=d.high)∧¬∞=|d.high
  ! ∧´(d.low=d.low)∧¬∞=|d.low
  ! ∧´(d.open=d.open)∧¬∞=|d.open
  ! ∧´d.vol≥0
  { s ?
    ! ∧´d.close>0 ⋄ ! ∧´d.high>0 ⋄ ! ∧´d.low>0 ⋄ ! ∧´d.open>0
  ; @}
  ! ∧´d.high≥d.low
  ! ∧´d.high≥d.close
  ! ∧´d.high≥d.open
  ! ∧´d.low≤d.close
  ! ∧´d.low≤d.open
  d
}

Align ⇐ {m←⌊´≠¨𝕩 ⋄ (-m)↑¨𝕩}

# ── Helpers ──────────────────────────────────

# Wilder smoothing (EMA with α=1/n). Used by RSI and ATR.
Wilder ⇐ {a←÷𝕨 ⋄ (⊑𝕩){(a×𝕩)+(1-a)×𝕨}`𝕩}

# Population std (used by Sharpe, AnnVol, Skew, Kurt)
Pstd ⇐ {m←(+´÷≠)𝕩 ⋄ √(+´(𝕩-m)⋆2)÷≠𝕩}

# ── Indicators ───────────────────────────────

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

# n Std prices — rolling population standard deviation, O(n) via prefix-sum
Std ⇐ {
  s1 ← 0∾+`𝕩
  s2 ← 0∾+`𝕩⋆2
  n ← 𝕨
  m ← ((n↓s1) - ((-n)↓s1)) ÷ n
  v ← ((n↓s2) - ((-n)↓s2)) ÷ n
  √ 0⌈ v - m⋆2
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
  # FIX: constant prices → both ag and al near zero → return 50 (neutral)
  flat ← (ag<eps) ∧ al<eps
  (50×flat) + (¬flat) × 100 - 100÷1+ag÷al⌈eps
}

# fast‿slow‿sig MACD prices → macd‿signal‿hist
MACD ⇐ {
  fast‿slow‿sig ← 𝕨
  ml ← (fast EMA 𝕩) - slow EMA 𝕩
  sl ← sig EMA ml
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
  k ← 100 × (((𝕨-1)↓c)-lo) ÷ rng⌈eps
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
  # FIX: zero bar 0 — » fills with 0, making sign(close[0]-0) always positive
  +` (0∾1↓signs) × v
}

# VWAP data — volume-weighted average price (monadic, takes namespace)
VWAP ⇐ {
  tp ← (𝕩.high + 𝕩.low + 𝕩.close) ÷ 3
  (+`tp×𝕩.vol) ÷ (+`𝕩.vol)⌈eps
}

# AD data — accumulation/distribution line (monadic, takes namespace)
AD ⇐ {
  h←𝕩.high ⋄ l←𝕩.low ⋄ c←𝕩.close ⋄ v←𝕩.vol
  rng ← h-l
  mfm ← ((c-l)-(h-c)) ÷ rng⌈eps
  +` mfm × v
}

# ── Signal Utilities ─────────────────────────

# fast Cross slow — 1 where fast crosses above slow
# NOTE: bar 0 is always 0 — » fills with 0, so (0<0) is false
Cross ⇐ {(𝕨≥𝕩) ∧ (»𝕨)<»𝕩}

# fast CrossDown slow — 1 where fast crosses below slow
# NOTE: bar 0 is always 0 — » fills with 0, so (0>0) is false
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
