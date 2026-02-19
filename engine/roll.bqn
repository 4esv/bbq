# bbq — BQN Based Quant
# engine/roll.bqn — rolling analytics

bt ← •Import "bt.bqn"

# ── Rolling Metrics ──────────────────────────

# n RSharpe ret → rolling n-bar annualized Sharpe (sample std N-1)
RSharpe ⇐ {
  n←𝕨 ⋄ r←𝕩
  samp ← {
    w ← r⊏˜(𝕩-(n-1))+↕n
    m ← (+´w)÷n
    s ← √(+´(w-m)⋆2)÷(n-1)⌈1
    (√bt.tdy) × m ÷ s⌈bt.eps
  }¨ (n-1)+↕((≠r)-(n-1))
  ((n-1)⥊0) ∾ samp
}

# n RVol ret → rolling n-bar annualized vol (sample std N-1)
RVol ⇐ {
  n←𝕨 ⋄ r←𝕩
  samp ← {
    w ← r⊏˜(𝕩-(n-1))+↕n
    m ← (+´w)÷n
    (√((+´(w-m)⋆2)÷(n-1)⌈1)) × √bt.tdy
  }¨ (n-1)+↕((≠r)-(n-1))
  ((n-1)⥊0) ∾ samp
}

# n RMaxDD ret → rolling max drawdown over n-bar window
RMaxDD ⇐ {
  n←𝕨 ⋄ r←𝕩
  dd ← {
    w ← r⊏˜(𝕩-(n-1))+↕n
    eq ← ×`1+w
    mx ← ⌈`eq
    ⌊´(eq-mx)÷mx
  }¨ (n-1)+↕((≠r)-(n-1))
  ((n-1)⥊0) ∾ dd
}

# n‿bench RBeta strat → rolling n-bar beta vs benchmark
RBeta ⇐ {
  n‿bench ← 𝕨
  b‿s ← bt.Align bench‿𝕩
  beta ← {
    ws ← s⊏˜(𝕩-(n-1))+↕n
    wb ← b⊏˜(𝕩-(n-1))+↕n
    ms ← (+´ws)÷n ⋄ mb ← (+´wb)÷n
    cov ← (+´(ws-ms)×(wb-mb))÷(n-1)⌈1
    var ← (+´(wb-mb)⋆2)÷(n-1)⌈1
    cov÷var⌈bt.eps
  }¨ (n-1)+↕((≠s)-(n-1))
  ((n-1)⥊0) ∾ beta
}

# ── Scalar Metrics ───────────────────────────

# bench‿rf Alpha strat → Jensen's alpha (scalar)
Alpha ⇐ {
  bench‿rf ← 𝕨 ⋄ strat ← 𝕩
  b‿s ← bt.Align bench‿strat
  ms ← (+´s)÷≠s ⋄ mb ← (+´b)÷≠b
  cov ← (+´(s-ms)×(b-mb))÷((≠s)-1)⌈1
  var ← (+´(b-mb)⋆2)÷((≠b)-1)⌈1
  beta ← cov÷var⌈bt.eps
  (bt.CAGR s) - rf + beta×(bt.CAGR b)-rf
}

# bench IR strat → information ratio (scalar)
IR ⇐ {
  b‿s ← bt.Align 𝕨‿𝕩
  diff ← s-b
  m ← (+´diff)÷≠diff
  sd ← √(+´(diff-m)⋆2)÷((≠diff)-1)⌈1
  (√bt.tdy) × m ÷ sd⌈bt.eps
}

# bench UpsideCapture strat → upside capture ratio
UpsideCapture ⇐ {
  b‿s ← bt.Align 𝕨‿𝕩
  mask ← b>0
  sb ← +´mask/b
  { sb=0 ? 0 ; (+´mask/s) ÷ sb }
}

# bench DownsideCapture strat → downside capture ratio
DownsideCapture ⇐ {
  b‿s ← bt.Align 𝕨‿𝕩
  mask ← b<0
  sb ← +´mask/b
  { sb=0 ? 0 ; (+´mask/s) ÷ sb }
}

# ── Drawdown Episodes ────────────────────────

# Drawdowns ret → {start, end, depth, dur}
Drawdowns ⇐ {
  eq ← ×`1+𝕩
  mx ← ⌈`eq
  dds ← (eq-mx)÷mx

  in_ep ← 0
  ep_start ← 0
  ep_min_dd ← 0
  episodes ← ⟨⟩

  {
    i ← 𝕩
    d ← i⊑dds
    { in_ep=0 ?
      { d<0 ?
        in_ep ↩ 1
        ep_start ↩ i
        ep_min_dd ↩ d
      ; @ }
    ;
      { d<ep_min_dd ? ep_min_dd ↩ d ; @ }
      { d≥0 ?
        episodes ∾↩ ⟨ep_start‿(i-1)‿ep_min_dd‿(i-ep_start)⟩
        in_ep ↩ 0
      ; @ }
    }
    @
  }¨ ↕≠eq

  # Close open episode at end of series
  { in_ep≠0 ?
    episodes ∾↩ ⟨ep_start‿((≠eq)-1)‿ep_min_dd‿((≠eq)-ep_start)⟩
  ; @ }

  { 0=≠episodes ?
    {start⇐⟨⟩, end⇐⟨⟩, depth⇐⟨⟩, dur⇐⟨⟩}
  ;
    start ⇐ {⊑𝕩}¨ episodes
    end   ⇐ {1⊑𝕩}¨ episodes
    depth ⇐ {2⊑𝕩}¨ episodes
    dur   ⇐ {3⊑𝕩}¨ episodes
  }
}
