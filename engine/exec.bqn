# bbq — BQN Based Quant
# engine/exec.bqn — execution realism: slippage, stops, limits

bt ← •Import "bt.bqn"

# ── Slippage ───────────────────────────────────

# rate‿adv_frac Slippage pos‿vol → cost array
# Almgren-Chriss sqrt model: cost = rate × √(|Δpos| / (adv_frac × vol))
Slippage ⇐ {
  rate‿adv_frac ← 𝕨
  pos‿vol ← 𝕩
  delta ← |-⟜»pos
  rate × √delta ÷ (adv_frac × vol)⌈bt.eps
}

# ── Fill Limit ─────────────────────────────────

# adv_frac FillLimit pos‿vol → position clipped to adv_frac × vol
FillLimit ⇐ {
  adv_frac ← 𝕨
  pos‿vol ← 𝕩
  cap ← adv_frac × vol
  (×pos) × cap ⌊ |pos
}

# ── Scale ──────────────────────────────────────

# arr Scale pos → arr × pos
Scale ⇐ ×

# ── Stop Loss ──────────────────────────────────

# NOTE: StopLoss, TakeProfit, StopTake use explicit blocks — per-bar
# state mutation (entry price tracking) requires sequential ¨ with ↩.

# pct StopLoss pos‿data → {pos, ret, triggered}
# Long exit if low[i] < entry_price × (1-pct); fill at stop price
# entry_price = open of bar when entering position
StopLoss ⇐ {
  pct ← 𝕨
  pos‿data ← 𝕩
  n ← ≠pos
  o ← data.open ⋄ l ← data.low ⋄ c ← data.close

  bar_ret ← (c-o) ÷ o⌈bt.eps

  out_pos ← +pos
  out_ret ← +bar_ret
  out_trig ← 0¨pos
  entry_px ← 0.0

  {
    i ← 𝕩
    p ← i⊑pos
    { p > 0 ?
      { (i=0) ∨ (0 = (i-1)⊑pos) ? entry_px ↩ i⊑o ; @ }
      stop_px ← entry_px × 1-pct
      { (i⊑l) < stop_px ?
        out_pos  ↩ 0 ⌾ (i⊸⊑) out_pos
        out_trig ↩ 1 ⌾ (i⊸⊑) out_trig
        sr ← (stop_px - i⊑o) ÷ (i⊑o)⌈bt.eps
        out_ret  ↩ sr ⌾ (i⊸⊑) out_ret
        entry_px ↩ 0.0
      ; @ }
    ;
      entry_px ↩ 0.0
    }
    @
  }¨ ↕n

  # NOTE: use original pos for ret so triggered bar contributes stop_ret
  sret ← pos×out_ret
  {pos⇐out_pos, ret⇐sret, triggered⇐out_trig}
}

# ── Take Profit ────────────────────────────────

# pct TakeProfit pos‿data → {pos, ret, triggered}
# Long exit if high[i] > entry_price × (1+pct); fill at target price
TakeProfit ⇐ {
  pct ← 𝕨
  pos‿data ← 𝕩
  n ← ≠pos
  o ← data.open ⋄ h ← data.high ⋄ c ← data.close

  bar_ret ← (c-o) ÷ o⌈bt.eps

  out_pos ← +pos
  out_ret ← +bar_ret
  out_trig ← 0¨pos
  entry_px ← 0.0

  {
    i ← 𝕩
    p ← i⊑pos
    { p > 0 ?
      { (i=0) ∨ (0 = (i-1)⊑pos) ? entry_px ↩ i⊑o ; @ }
      tp_px ← entry_px × 1+pct
      { (i⊑h) > tp_px ?
        out_pos  ↩ 0 ⌾ (i⊸⊑) out_pos
        out_trig ↩ 1 ⌾ (i⊸⊑) out_trig
        tr ← (tp_px - i⊑o) ÷ (i⊑o)⌈bt.eps
        out_ret  ↩ tr ⌾ (i⊸⊑) out_ret
        entry_px ↩ 0.0
      ; @ }
    ;
      entry_px ↩ 0.0
    }
    @
  }¨ ↕n

  sret ← pos×out_ret
  {pos⇐out_pos, ret⇐sret, triggered⇐out_trig}
}

# ── Stop + Take Profit ────────────────────────

# sl‿tp StopTake pos‿data → {pos, ret, triggered}
# Combined stop loss and take profit. Stop wins on same-bar conflict.
# triggered encoding: 0=none, 1=stop, 2=tp, 3=both (stop wins)
StopTake ⇐ {
  sl‿tp ← 𝕨
  pos‿data ← 𝕩
  n ← ≠pos
  o ← data.open ⋄ h ← data.high ⋄ l ← data.low ⋄ c ← data.close

  bar_ret ← (c-o) ÷ o⌈bt.eps

  out_pos ← +pos
  out_ret ← +bar_ret
  out_trig ← 0¨pos
  entry_px ← 0.0

  {
    i ← 𝕩
    p ← i⊑pos
    { p > 0 ?
      { (i=0) ∨ (0 = (i-1)⊑pos) ? entry_px ↩ i⊑o ; @ }
      stop_px ← entry_px × 1-sl
      tp_px   ← entry_px × 1+tp
      sl_hit ← (i⊑l) < stop_px
      tp_hit ← (i⊑h) > tp_px
      { sl_hit ∨ tp_hit ?
        fill_px ← { sl_hit ? stop_px ; tp_px }
        out_pos  ↩ 0 ⌾ (i⊸⊑) out_pos
        out_trig ↩ (sl_hit + 2×tp_hit) ⌾ (i⊸⊑) out_trig
        fr ← (fill_px - i⊑o) ÷ (i⊑o)⌈bt.eps
        out_ret  ↩ fr ⌾ (i⊸⊑) out_ret
        entry_px ↩ 0.0
      ; @ }
    ;
      entry_px ↩ 0.0
    }
    @
  }¨ ↕n

  sret ← pos×out_ret
  {pos⇐out_pos, ret⇐sret, triggered⇐out_trig}
}
