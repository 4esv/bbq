# bench/bqn/bench_metrics.bqn — metrics benchmark
bt ← •Import "../../engine/bt.bqn"
data ← bt.Validate bt.Load ⊑•args
c ← data.close

# MA cross to get realistic strategy returns
fast ← 10 bt.MA c
slow ← 50 bt.MA c
f‿s ← bt.Align fast‿slow
pos ← f > s
ret ← bt.Ret c
pos‿ret ↩ bt.Align pos‿ret
strat ← pos bt.Run ret

# All 18 metrics
•Out •Repr bt.Sharpe strat
•Out •Repr bt.Sortino strat
•Out •Repr bt.MaxDD strat
•Out •Repr bt.MaxDDDur strat
•Out •Repr bt.TotalRet strat
•Out •Repr bt.CAGR strat
•Out •Repr bt.AnnVol strat
•Out •Repr bt.Calmar strat
•Out •Repr bt.WinRate strat
•Out •Repr bt.ProfitFactor strat
•Out •Repr bt.AvgWin strat
•Out •Repr bt.AvgLoss strat
•Out •Repr bt.Expectancy strat
•Out •Repr bt.Trades pos
•Out •Repr bt.TimeIn pos
•Out •Repr bt.Skew strat
•Out •Repr bt.Kurt strat
•Out •Repr +´ bt.Equity strat
