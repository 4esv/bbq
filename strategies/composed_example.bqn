# Strategy: Composed (SMA/RSI/BB)
# Hypothesis: Fusing multiple normalized signals reduces noise from any single
#   indicator. SMA distance captures trend, RSI captures momentum, Bollinger
#   position captures mean-reversion context.
# Parameters: weights 0.4/0.3/0.3, threshold 0.5

bt ← •Import "../engine/bt.bqn"
cmp ← •Import "../engine/cmp.bqn"

data ← bt.Validate bt.Load "../data/spy.csv"
c ← data.close

# ── Features ─────────────────────────────────
sma ← 50 bt.MA c
f1 ← ((-≠sma)↑c) - sma           # SMA distance

f2 ← 14 bt.RSI c                  # RSI

upper‿mid‿lower ← 20‿2 bt.BB c
cb ← (-≠upper)↑c
f3 ← (cb-lower)÷(upper-lower)+1e¯10  # BB position (0-1)

# ── Compose ──────────────────────────────────
pos ← 0.5 cmp.Thresh 0.4‿0.3‿0.3 cmp.Score cmp.ENorm¨ f1‿f2‿f3

# ── Backtest ─────────────────────────────────
ret ← bt.Ret c
pos‿ret ↩ bt.Align pos‿ret
pos‿ret ↩ (¯1↓pos)‿(1↓ret)  # 1-bar shift: trade on next open
strat ← pos bt.Run ret
bh ← ret

"Composed (SMA/RSI/BB)"‿pos bt.Report strat‿bh
