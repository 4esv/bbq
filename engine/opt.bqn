# bbq — BQN Based Quant
# engine/opt.bqn — Black-Scholes options pricing

core ← •Import "core.bqn"
eps ← core.eps

# ── Normal Distribution ─────────────────────────

# Standard normal PDF
Npdf ⇐ (÷√2×π)⊸×∘⋆∘(-0.5⊸×∘(⋆⟜2))

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

# ── Student's t Distribution ──────────────────────

# Log Gamma via Lanczos approximation (g=7)
LnGamma ← {
  t ← 𝕩 + 6.5
  s ← 0.99999999999980993 + +´ ⟨676.5203681218851, ¯1259.1392167224028, 771.32342877765313, ¯176.61502916214059, 12.507343278686905, ¯0.13857109526572012, 9.9843695780195716e¯6, 1.5056327351493116e¯7⟩ ÷ 𝕩+↕8
  (0.5 × ⋆⁼ 2×π) + (⋆⁼ s) + ((𝕩-0.5) × ⋆⁼ t) - t
}

# nu Tpdf x → Student's t PDF
Tpdf ⇐ {
  nu ← 𝕨
  lc ← ((LnGamma (nu+1)÷2) - LnGamma nu÷2) - 0.5 × ⋆⁼ nu×π
  ⋆ lc + (-(nu+1)÷2) × ⋆⁼ 1 + (𝕩⋆2)÷nu
}

# Regularized incomplete beta I_x(a,b) via continued fraction
BetaI ← {
  x0‿a0‿b0 ← 𝕩
  swap ← x0 > (a0+1) ÷ a0+b0+2
  x‿a‿b ← {swap ? (1-x0)‿b0‿a0 ; x0‿a0‿b0}
  lnB ← (LnGamma a) + (LnGamma b) - LnGamma a+b
  lnF ← ((a × ⋆⁼ eps⌈x) + (b × ⋆⁼ eps⌈1-x)) - lnB + ⋆⁼ a
  # CF coefficients (200 terms)
  js ← 1+↕200 ⋄ odd ← 2|js
  mo ← (js-1)÷2 ⋄ me ← js÷2
  do ← (-(a+mo) × (a+b+mo) × x) ÷ (a+2×mo) × a+1+2×mo
  de ← (me × (b-me) × x) ÷ (a+(2×me)-1) × a+2×me
  ds ← (odd×do) + (¬odd) × de
  h ← 1.0
  {h ↩ 1 + 𝕩 ÷ {1e¯30>|𝕩 ? 1e¯30 ; 𝕩} h}¨ ⌽ds
  val ← (⋆lnF) ÷ h
  {swap ? 1-val ; val}
}

# nu Tcdf x → Student's t CDF
Tcdf ⇐ {
  t ← 𝕨 ÷ 𝕨 + 𝕩⋆2
  0.5 + (×𝕩) × 0.5 × 1 - BetaI t‿(𝕨÷2)‿0.5
}

# nu TcdfInv p → inverse Student's t CDF (Newton-Raphson)
TcdfInv ⇐ {
  nu ← 𝕨
  p ← 0.0001⌈0.9999⌊𝕩
  x0 ← (PhiInv p) × {nu>4 ? √nu÷nu-2 ; 1}
  Refine ← {𝕩 - ((nu⊸Tcdf 𝕩) - p) ÷ eps⌈nu⊸Tpdf 𝕩}
  Refine⍟10 x0
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
