# bbq — BQN Based Quant
# engine/mc.bqn — Monte Carlo simulation

core ← •Import "core.bqn"
eps ← core.eps

# ── RNG (internal) ─────────────────────────────

# Unif n → n uniform floats in (0,1)
Unif ← {(𝕩 •rand.Range 1000000000) ÷ 1000000000}

# Randn n → n standard normal samples (Box-Muller)
Randn ← {
  half ← ⌈𝕩÷2
  u1 ← eps⌈Unif half
  u2 ← Unif half
  r ← √-2×⋆⁼u1
  a ← 2×π×u2
  𝕩↑(r×•math.Cos a)∾r×•math.Sin a
}

# nu RandChi2 n → n chi-squared(nu) samples
RandChi2 ← {+˝ (𝕨‿𝕩 ⥊ Randn 𝕨×𝕩) ⋆ 2}

# nu RandT n → n Student's t samples
RandT ⇐ {(Randn 𝕩) ÷ √(𝕨 RandChi2 𝕩)÷𝕨}

# ── Path Generation ────────────────────────────

# NOTE: Paths takes μ (real-world drift). For risk-neutral pricing, pass r as μ.
# _Price discounts at r. These are intentionally separate parameters.

# GbmZ n‿s0‿mu‿sig‿t‿steps → drift‿diff‿z‿s0 (shared GBM setup)
GbmZ ← {
  n‿s0‿mu‿sig‿t‿steps ← 𝕩
  dt ← t÷steps
  ⟨(mu - 0.5×sig⋆2) × dt, sig × √dt, n‿steps ⥊ Randn n×steps, s0⟩
}

# Paths n‿S₀‿μ‿σ‿T‿steps → [n, steps] price paths (GBM)
# μ = drift rate (use risk-free rate r for risk-neutral pricing)
Paths ⇐ {
  drift‿diff‿z‿s0 ← GbmZ 𝕩
  s0 × ⋆ +`˘ drift + diff×z
}

# TPaths n‿S₀‿μ‿σ‿T‿steps‿nu → [n, steps] fat-tailed GBM paths
TPaths ⇐ {
  n‿s0‿mu‿sig‿t‿steps‿nu ← 𝕩
  dt ← t÷steps
  sv ← sig × √(nu-2)÷nu                    # variance-matched σ
  drift ← (mu - 0.5×sv⋆2) × dt
  z ← n‿steps ⥊ nu RandT n×steps
  s0 × ⋆ +`˘ drift + (sv×√dt)×z
}

# ── Payoff Helpers ─────────────────────────────

# k EuroCall path → payoff
EuroCall ⇐ 0⊸⌈ -˜⟜(¯1⊸⊑)

# k EuroPut path → payoff
EuroPut ⇐ 0⊸⌈ -⟜(¯1⊸⊑)

# k AsianCall path → payoff (arithmetic average)
AsianCall ⇐ 0⊸⌈ -˜⟜(+´÷≠)

# k‿barrier BarrierUpOut path → payoff (knocked out if any price ≥ barrier)
# NOTE: barrier touch (price = barrier) triggers knockout
BarrierUpOut ⇐ {k‿b←𝕨 ⋄ (∧´𝕩<b) × 0⌈(¯1⊑𝕩)-k}

# ── Pricing ────────────────────────────────────

# Payoff _Price paths‿r‿T → discounted expected payoff
_Price ⇐ {
  paths‿r‿t ← 𝕩
  (⋆-r×t) × (+´÷≠) 𝔽˘ paths
}

# ── Variance Reduction ─────────────────────────

# Paths _Antithetic config → [2n, steps] (antithetic variates)
# NOTE: 𝔽 referenced to make this a 1-modifier (operand unused)
_Antithetic ⇐ {𝔽
  drift‿diff‿z‿s0 ← GbmZ 𝕩
  dz ← diff×z
  (s0 × ⋆ +`˘ drift+dz) ∾ s0 × ⋆ +`˘ drift-dz
}
