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
