# bench/bqn/bench_pipeline.bqn — full MA crossover pipeline
bt ← •Import "../../engine/bt.bqn"
data ← bt.Validate bt.Load ⊑•args
c ← data.close

# Indicators
fast ← 10 bt.MA c
slow ← 50 bt.MA c

# Signals
f‿s ← bt.Align fast‿slow
raw ← (f > s) - (f < s)
pos ← 5 bt.Hold bt.Fill raw

# Backtest
ret ← bt.Ret c
pos‿ret ↩ bt.Align pos‿ret
strat ← pos bt.Run ret
cost ← 0.001 bt.Cost pos
net ← strat - (≠strat)↑cost

# Metrics
•Out •Repr bt.Sharpe net
•Out •Repr bt.MaxDD net
•Out •Repr bt.CAGR net
•Out •Repr +´bt.Equity net
