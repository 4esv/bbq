# bbq — BQN Based Quant
# engine/opt.bqn — Black-Scholes options pricing

core ← •Import "core.bqn"
eps ← core.eps

# ── Normal Distribution ─────────────────────────

# Standard normal PDF
Npdf ⇐ {(÷√2×π) × ⋆-0.5×𝕩⋆2}

# Standard normal CDF (Abramowitz-Stegun approximation)
Phi ⇐ {
  neg ← 𝕩 < 0
  ax ← |𝕩
  t ← ÷ 1 + 0.2316419×ax
  # Horner: t×(a1 + t×(a2 + t×(a3 + t×(a4 + t×a5))))
  poly ← t × 0.319381530 + t × ¯0.356563782 + t × 1.781477937 + t × ¯1.821255978 + t × 1.330274429
  pos ← 1 - poly × Npdf ax
  # Branchless: neg selects 1-pos, else pos
  ((¬neg) × pos) + neg × (1-pos)
}

# PhiInv p → inverse standard normal CDF (Newton-Raphson + rational initial guess)
PhiInv ⇐ {
  p ← 0.0001⌈0.9999⌊𝕩
  t ← √-2×⋆⁼(p⌊1-p)
  num ← 2.515517 + 0.802853×t + 0.010328×t⋆2
  den ← 1 + 1.432788×t + 0.189269×t⋆2 + 0.001308×t⋆3
  x0 ← t - num÷den
  x0 ↩ {p<0.5 ? -x0 ; x0}
  Refine ← {𝕩 - ((Phi 𝕩)-p) ÷ eps⌈Npdf 𝕩}
  Refine⍟5 x0
}

# ── Helpers ──────────────────────────────────────

# d1, d2, σ√T (internal)
D12 ← {
  s‿k‿tt‿r‿v ← 𝕩
  st ← v × √tt
  d1 ← ((⋆⁼s÷k) + (r + 0.5×v⋆2) × tt) ÷ eps⌈st
  d2 ← d1 - st
  d1‿d2‿st
}

# ── Pricing ──────────────────────────────────────

# BS S‿K‿T‿r‿σ‿type → price (type: 1=call, ¯1=put)
BS ⇐ {
  s‿k‿tt‿r‿v‿ty ← 𝕩
  d1‿d2‿st ← D12 s‿k‿tt‿r‿v
  df ← ⋆-r×tt
  (ty×s×Phi ty×d1) - ty×k×df×Phi ty×d2
}

# ── Greeks ───────────────────────────────────────

Delta ⇐ {
  s‿k‿tt‿r‿v‿ty ← 𝕩
  d1‿d2‿st ← D12 s‿k‿tt‿r‿v
  (Phi d1) + (ty-1)÷2
}

Gamma ⇐ {
  s‿k‿tt‿r‿v‿ty ← 𝕩
  d1‿d2‿st ← D12 s‿k‿tt‿r‿v
  (Npdf d1) ÷ (s × eps⌈st)
}

Theta ⇐ {
  s‿k‿tt‿r‿v‿ty ← 𝕩
  d1‿d2‿st ← D12 s‿k‿tt‿r‿v
  df ← ⋆-r×tt
  t1 ← (s × (Npdf d1) × v) ÷ eps⌈2×√tt
  t2 ← ty × r × k × df × Phi ty×d2
  (-t1) - t2
}

Vega ⇐ {
  s‿k‿tt‿r‿v‿ty ← 𝕩
  d1‿d2‿st ← D12 s‿k‿tt‿r‿v
  s × (Npdf d1) × √tt
}

Rho ⇐ {
  s‿k‿tt‿r‿v‿ty ← 𝕩
  d1‿d2‿st ← D12 s‿k‿tt‿r‿v
  df ← ⋆-r×tt
  ty × k × tt × df × Phi ty×d2
}

# ── Implied Volatility ──────────────────────────

# IV target‿S‿K‿T‿r‿type → σ (Newton-Raphson)
IV ⇐ {
  target‿s‿k‿tt‿r‿ty ← 𝕩
  Step ← {
    sig ← 0.001⌈10⌊𝕩
    price ← BS s‿k‿tt‿r‿sig‿ty
    vega ← Vega s‿k‿tt‿r‿sig‿ty
    0.001⌈10⌊ sig - (price-target) ÷ eps⌈vega
  }
  Step⍟100 0.5
}

# ── Parity ───────────────────────────────────────

# Parity S‿K‿T‿r → S - Ke^(-rT) (put-call parity forward)
Parity ⇐ {
  s‿k‿tt‿r ← 𝕩
  s - k × ⋆-r×tt
}
