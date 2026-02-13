# Strategy: MA Cross
# Hypothesis: Short-term trend following — when the fast MA crosses above
#   the slow MA, momentum is shifting upward. Simple, ancient, probably wrong.
# Parameters: fast=10, slow=50

bt ← •Import "../engine/bt.bqn"
data ← bt.Load "../data/spy.csv"
c ← data.close

# ── Indicators ──────────────────────────────
fast ← 10 bt.MA c
slow ← 50 bt.MA c

# ── Signals / Positions ─────────────────────
# NOTE: align MAs — trim fast to match slow length
f ← (≠slow)↑fast
pos ← f > slow

# ── Backtest ────────────────────────────────
ret ← bt.Ret c
# Align returns to position array (drop warmup bars from ret)
w ← (≠ret) - ≠pos
strat ← pos bt.Run w↓ret
bh ← w↓ret

"MA Cross (10/50)"‿pos bt.Report strat‿bh
