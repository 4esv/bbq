# bbq — BQN Based Quant
# engine/uni.bqn — universe management: multi-asset cross-sectional analysis

bt ← •Import "bt.bqn"

eps ← 1e¯10

# ── Universe Construction ─────────────────────

# Universe datasets → matrix namespace {close, high, low, open, vol, n_assets, n_bars}
# datasets: list of aligned OHLCV namespaces (from LoadMany or AlignDates)
# close etc. are [n_bars, n_assets] rank-2 arrays (each column = one asset)
Universe ⇐ {
  ns ← 𝕩
  na ← ≠ns
  nb ← ≠(⊑ns).close
  close    ⇐ ⍉ > {𝕩.close}¨ ns
  high     ⇐ ⍉ > {𝕩.high}¨ ns
  low      ⇐ ⍉ > {𝕩.low}¨ ns
  open     ⇐ ⍉ > {𝕩.open}¨ ns
  vol      ⇐ ⍉ > {𝕩.vol}¨ ns
  n_assets ⇐ na
  n_bars   ⇐ nb
}

# ── Cross-Sectional ──────────────────────────

# XRank mat → rank matrix (per row, ascending, 0-indexed)
XRank ⇐ {⍋⍋𝕩}˘

# XScore mat → z-score matrix (per row: subtract row mean, divide by row std)
# NOTE: BQN leading-axis broadcast: [nb,na] - [nb] subtracts per-row
XScore ⇐ {
  na ← ¯1⊑≢𝕩
  row_m ← (+˝˘𝕩) ÷ na
  centered ← 𝕩 - row_m
  row_v ← (+˝˘centered⋆2) ÷ na
  row_s ← √row_v⌈eps
  centered ÷ row_s
}

# XWeight mat → weight matrix (per row: value / sum(|row|))
XWeight ⇐ {
  abs_sums ← +˝˘|𝕩
  𝕩 ÷ abs_sums⌈eps
}

# LongOnly weights → zero negatives, renormalize per row
LongOnly ⇐ {
  w ← 0⌈𝕩
  row_sums ← +˝˘w
  denom ← row_sums + row_sums=0
  w ÷ denom
}

# n TopN scores → weight matrix: +1/n for top n, -1/n for bottom n
TopN ⇐ {
  n ← 𝕨
  {
    row ← 𝕩
    na ← ≠row
    ranked ← ⍋⍋row
    long_mask  ← ranked ≥ na-n
    short_mask ← ranked < n
    (long_mask÷n) - short_mask÷n
  }˘ 𝕩
}

# ── Strategy Execution ────────────────────────

# Strat _UniRun universe → position matrix [n_bars, n_assets]
# Strat: prices (1-D) → positions (1-D), applied per asset column
_UniRun ⇐ {
  Strat ← 𝔽 ⋄ uni ← 𝕩
  na ← uni.n_assets
  pos_cols ← {Strat 𝕩⊑˘uni.close}¨ ↕na
  ⍉ > pos_cols
}

# ── Reporting ─────────────────────────────────

# name UniReport weights‿uni → print universe performance summary
UniReport ⇐ {
  name ← 𝕨
  weights‿uni ← 𝕩
  na ← uni.n_assets
  nb ← uni.n_bars

  •Out "═══ Universe: " ∾ name ∾ " ═══"
  •Out "Assets: " ∾ (•Fmt na) ∾ "  Bars: " ∾ •Fmt nb
  •Out ""

  # Per-asset returns
  asset_ret ← {bt.Ret 𝕩⊑˘uni.close}¨ ↕na

  # Per-asset report
  {
    j ← 𝕩 ⋄ r ← j⊑asset_ret
    •Out "  Asset " ∾ (5 bt.Pad •Fmt j) ∾ "  Sharpe: " ∾ (bt.Rd bt.Sharpe r) ∾ "  MaxDD: " ∾ bt.Pct bt.MaxDD r
  }¨ ↕na

  # Portfolio returns: (1↓weights) × ret_mat, summed per bar
  ret_mat ← ⍉ > asset_ret
  port_ret ← +˝˘ (1↓weights) × ret_mat

  •Out ""
  •Out "Portfolio:"
  •Out "  Sharpe:  " ∾ bt.Rd bt.Sharpe port_ret
  •Out "  MaxDD:   " ∾ bt.Pct bt.MaxDD port_ret
  •Out "  Total:   " ∾ bt.Pct bt.TotalRet port_ret
}
