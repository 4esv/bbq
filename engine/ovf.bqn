# bbq — BQN Based Quant
# engine/ovf.bqn — anti-overfitting metrics

bt  ← •Import "bt.bqn"
opt ← •Import "opt.bqn"

eps ← bt.eps
tdy ← bt.tdy

# ── Helpers ──────────────────────────────────

# σ_SR = sqrt((1 - γ3×SR + (γ4-1)/4×SR²) / (T-1))
SRSigma ← {
  sr‿sk‿ku‿t ← 𝕩
  v ← ((1 - sk×sr) + ((ku-1)÷4)×sr⋆2) ÷ 1⌈t-1
  √0⌈v
}

# ── DSR (Deflated Sharpe Ratio) ──────────────

# n DSR sr‿skew‿kurt‿T → scalar in [0,1]
DSR ⇐ {
  n ← 𝕨
  sr‿sk‿ku‿t ← 𝕩
  eu ← 0.5772156649
  sr_star ← {n≤1 ? 0 ;
    a ← (1-eu) × opt.PhiInv 1 - 1÷n
    b ← eu × opt.PhiInv 1 - 1÷n × ⋆1
    (a+b) × √1÷1⌈t-1
  }
  sig ← SRSigma sr‿sk‿ku‿t
  opt.Phi (sr - sr_star) ÷ eps⌈sig
}

# ── PSR (Probabilistic Sharpe Ratio) ─────────

# sr_bench PSR sr‿T‿n‿skew‿kurt → scalar in [0,1]
PSR ⇐ {
  sr_bench ← 𝕨
  sr‿t‿n‿sk‿ku ← 𝕩
  sig ← SRSigma sr‿sk‿ku‿t
  opt.Phi (sr - sr_bench) ÷ eps⌈sig
}

# ── MinTRL (Minimum Track Record Length) ─────

# n‿sr MinTRL skew‿kurt → scalar (minimum bars)
MinTRL ⇐ {
  n‿sr ← 𝕨
  sk‿ku ← 𝕩
  z ← opt.PhiInv 1 - 0.05÷n
  1 + ((1 - sk×sr) + ((ku-1)÷4)×sr⋆2) × (z÷eps⌈sr)⋆2
}

# ── PBO (Probability of Backtest Overfitting) ─

# PBO wf_result → scalar in [0,1]
PBO ⇐ {
  folds ← 𝕩.folds
  n ← ≠folds
  { n=0 ? 0 ;
    oos ← {𝕩.test_score}¨ folds
    (+´oos < 0) ÷ n
  }
}

# ── HHI (Return Concentration) ───────────────

# HHI ret → scalar in [0,1]
HHI ⇐ {
  pos ← (𝕩>0)/𝕩
  { 0=(+´pos) ? 0 ;
    w ← pos÷+´pos
    +´w⋆2
  }
}

# ── TrialCorrect (Benjamini-Hochberg FDR) ────

# n‿alpha TrialCorrect pvalues → boolean mask (1=reject H0)
TrialCorrect ⇐ {
  n‿alpha ← 𝕨
  pvals ← 𝕩
  m ← ≠pvals
  order ← ⍋pvals
  sorted ← order⊏pvals
  crit ← (alpha÷m) × 1+↕m
  pass ← sorted ≤ crit
  passing ← /pass
  { 0=≠passing ? 0¨pvals ;
    last_k ← ¯1⊑passing
    reject_idx ← (1+last_k)↑order
    mask ← 0¨pvals
    { mask ↩ 1⌾(𝕩⊸⊑) mask }¨ reject_idx
    mask
  }
}
