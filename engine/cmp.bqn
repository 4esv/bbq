# bbq — BQN Based Quant
# engine/cmp.bqn — composable signal layer

bt ← •Import "bt.bqn"
eps ← bt.eps

# ── Normalization ──────────────────────────────

# Norm arr — z-score normalize, full-array (for WF per-fold use)
Norm ⇐ {d←𝕩-(+´÷≠)𝕩 ⋄ d÷eps⌈√(+´d⋆2)÷≠𝕩}

# ENorm arr — expanding-window z-score (no lookahead bias)
ENorm ⇐ {
  n←1+↕≠𝕩 ⋄ cm←(+`𝕩)÷n
  sd←√0⌈((+`𝕩⋆2)÷n)-cm⋆2
  (𝕩-cm)÷eps⌈sd
}

# ── Scoring ────────────────────────────────────

# weights Score features — weighted sum, features auto-aligned to shortest length
Score ⇐ {f←bt.Align 𝕩 ⋄ 𝕨+˝∘×>f}

# ── Thresholding ───────────────────────────────

# level Thresh scores — position mapper: 1/0/¯1
Thresh ⇐ >˜ - ⊢<-∘⊣

# ── Composition ────────────────────────────────

# weights‿level Compose features — normalize, score, threshold
# WARNING: uses full-array Norm (lookahead). For live use, replace with ENorm¨
Compose ⇐ {w‿l←𝕨 ⋄ l Thresh w Score Norm¨𝕩}
