# bench/bqn/bench_walkforward.bqn — walk-forward grid search benchmark
wf ← •Import "../../engine/wf.bqn"
data ← wf.Validate wf.Load ⊑•args
c ← data.close

# MA cross strategy: params 𝔽 prices → positions
MACross ← {
  fast‿slow ← 𝕨
  f ← fast wf.MA 𝕩
  s ← slow wf.MA 𝕩
  f‿s ↩ wf.Align f‿s
  f > s
}

# Grid: fast=[5,10,15,20] × slow=[30,40,50,60,70]
grid ← wf.Grid ⟨5‿10‿15‿20, 30‿40‿50‿60‿70⟩

# Config: train=504, test=126, grid, cost=0.001, metric=Sharpe
config ← 504‿126‿grid‿0.001‿wf.Sharpe

results ← c (MACross wf._WF) config

# Checksums
•Out •Repr results.summary.sharpe
•Out •Repr results.summary.maxdd
•Out •Repr results.summary.total_ret
•Out •Repr +´results.oos_eq
