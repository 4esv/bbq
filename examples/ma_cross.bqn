# Strategy: MA Cross
# Hypothesis: Short-term trend following — when the fast MA crosses above
#   the slow MA, momentum is shifting upward. Simple, ancient, probably wrong.
# Parameters: fast=10, slow=50

bt ← •Import "../engine/bt.bqn"
data ← bt.Validate bt.Load "../data/spy.csv"
c ← data.close

# ── Indicators ──────────────────────────────
fast ← 10 bt.MA c
slow ← 50 bt.MA c

# ── Signals / Positions ─────────────────────
f‿s ← bt.Align fast‿slow
pos ← f > s

# ── Backtest ────────────────────────────────
ret ← bt.Ret c
pos‿ret ↩ bt.Align pos‿ret
pos‿ret ↩ (¯1↓pos)‿(1↓ret)  # 1-bar shift: trade on next open
strat ← (pos bt.Run ret) - 0.001 bt.Cost pos
bh ← ret

"MA Cross (10/50)"‿pos bt.Report strat‿bh
