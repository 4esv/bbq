# bench/bqn/bench_indicators.bqn — indicator benchmark
bt ← •Import "../../engine/bt.bqn"
data ← bt.Validate bt.Load ⊑•args
c ← data.close

ma20  ← 20 bt.MA c
ma50  ← 50 bt.MA c
ema20 ← 20 bt.EMA c
rsi14 ← 14 bt.RSI c
atr14 ← 14 bt.ATR data
u‿m‿l ← 20‿2 bt.BB c
k‿d   ← 14 bt.Stoch data
obv   ← bt.OBV c‿data.vol
vwap  ← bt.VWAP data

# Checksum (prevent dead-code elimination)
•Out •Repr +´ma20
•Out •Repr +´ma50
•Out •Repr +´ema20
•Out •Repr +´rsi14
•Out •Repr +´atr14
•Out •Repr +´u
•Out •Repr +´k
•Out •Repr +´obv
•Out •Repr +´vwap
