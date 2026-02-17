# bbq — BQN Based Quant
# examples/mc_convergence.bqn — Monte Carlo vs Black-Scholes convergence demo

mc ← •Import "../engine/mc.bqn"
opt ← •Import "../engine/opt.bqn"

# ── Formatting (local) ───────────────────────

# Rd4 — round to 4 decimal places
Rd4 ← {
  v ← ⌊0.5+10000×|𝕩
  d ← ¯4↑"0000"∾•Fmt 10000|v
  ((𝕩<0)/"-") ∾ (•Fmt ⌊v÷10000) ∾ "." ∾ d
}

# LPad — left-pad string to width (right-align)
LPad ← {((𝕨-≠𝕩)⥊' ')∾𝕩}

# ── Convergence Test ─────────────────────────

s0 ← 100
k ← 100
r ← 0.05
sig ← 0.20
t ← 1
steps ← 252

bsPrice ← opt.BS s0‿k‿t‿r‿sig‿1

•Out "Monte Carlo vs Black-Scholes Convergence"
•Out "S₀=100  K=100  r=0.05  σ=0.20  T=1  steps=252"
•Out "BS analytical: " ∾ Rd4 bsPrice
•Out ""
•Out "  Paths │   MC Price │   BS Price │     Error │    Secs"
•Out "────────┼────────────┼────────────┼───────────┼────────"

{
  n ← 𝕩
  t0 ← •MonoTime@
  paths ← mc.Paths n‿s0‿r‿sig‿t‿steps
  mcPrice ← k⊸mc.EuroCall mc._Price paths‿r‿t
  elapsed ← (•MonoTime@)-t0
  err ← mcPrice - bsPrice
  row ← (8 LPad •Fmt n) ∾ " │ " ∾ (10 LPad Rd4 mcPrice) ∾ " │ " ∾ (10 LPad Rd4 bsPrice) ∾ " │ " ∾ (9 LPad Rd4 err) ∾ " │ " ∾ (7 LPad Rd4 elapsed)
  •Out row
}¨ 1000‿5000‿10000‿50000‿100000
