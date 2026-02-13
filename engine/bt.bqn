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
