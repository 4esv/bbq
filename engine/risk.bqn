# bbq — BQN Based Quant
# engine/risk.bqn — position sizing and risk controls

bt ← •Import "bt.bqn"
eps ← bt.eps
tdy ← bt.tdy

# ── Position Sizing ──────────────────────────

# target VolTarget sig‿ret → scaled position to achieve target annualized vol
# Uses 21-bar rolling sample std (N-1), annualized by √252
VolTarget ⇐ {
  target ← 𝕨
  sig‿ret ← 𝕩
  n ← 21
  rvol ← {
    w ← ret⊏˜(𝕩-(n-1))+↕n
    m ← (+´w)÷n
    (√(+´(w-m)⋆2)÷((n-1)⌈1)) × √tdy
  }¨ (n-1)+↕((≠ret)-(n-1))
  scaled ← ((n-1)↓sig) × target ÷ rvol⌈eps
  ((n-1)⥊0) ∾ scaled
}

# f KellyFrac ret → scalar: f × mean/var, clipped to [¯1,1]
KellyFrac ⇐ {
  f ← 𝕨
  m ← (+´𝕩)÷≠𝕩
  v ← (+´(𝕩-m)⋆2)÷((≠𝕩)-1)⌈1
  ¯1 ⌈ 1 ⌊ f × m ÷ v⌈eps
}

# n‿f KellySeries sig‿ret → rolling Kelly-scaled position
KellySeries ⇐ {
  n‿f ← 𝕨
  sig‿ret ← 𝕩
  kelly ← {
    𝕩 < n ? 0 ;
    w ← ret⊏˜((𝕩-n)+↕n)
    m ← (+´w)÷n
    v ← (+´(w-m)⋆2)÷((n-1)⌈1)
    ¯1 ⌈ 1 ⌊ f × m ÷ v⌈eps
  }¨ ↕≠ret
  sig × kelly
}

# ── Position Limits ──────────────────────────

# cap MaxPos pos → clip magnitude, preserve sign
MaxPos ⇐ {(×𝕩) × 𝕨 ⌊ |𝕩}

# ── Risk Controls ────────────────────────────

# n‿thresh CircuitBreaker pos‿ret → zero pos for n bars after n-bar loss < thresh
CircuitBreaker ⇐ {
  n‿thresh ← 𝕨
  pos‿ret ← 𝕩
  nbar ← {
    𝕩 < n ? 0 ;
    +´ret⊏˜((𝕩-(n-1))+↕n)
  }¨ ↕≠ret
  fire ← nbar < thresh
  remaining ← 0
  mask ← {
    i ← 𝕩
    { (i⊑fire) ? remaining ↩ n ; @ }
    r ← remaining
    { r > 0 ? remaining ↩ r-1 ; @ }
    r > 0
  }¨ ↕≠ret
  pos × ¬mask
}

# thresh DDControl pos‿ret → zero while drawdown < thresh
DDControl ⇐ {
  thresh ← 𝕨
  pos‿ret ← 𝕩
  eq ← ×`1+ret
  mx ← ⌈`eq
  dd ← (eq-mx)÷mx
  pos × dd ≥ thresh
}

# ── Composition ──────────────────────────────

# arr Scale pos → element-wise multiply
Scale ⇐ ×
