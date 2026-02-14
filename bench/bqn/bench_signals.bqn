# bench/bqn/bench_signals.bqn — signal utilities benchmark
bt ← •Import "../../engine/bt.bqn"
data ← bt.Validate bt.Load ⊑•args
c ← data.close

# Generate signals from MA cross
fast ← 10 bt.MA c
slow ← 50 bt.MA c
f‿s ← bt.Align fast‿slow

cross   ← f bt.Cross s
crossdn ← f bt.CrossDown s
filled  ← bt.Fill cross - crossdn
held    ← 5 bt.Hold filled

# Threshold signals from RSI
rsi     ← 14 bt.RSI c
above70 ← 70 bt.Thresh rsi
below30 ← 30 bt.ThreshDown rsi

•Out •Repr +´cross
•Out •Repr +´crossdn
•Out •Repr +´filled
•Out •Repr +´held
•Out •Repr +´above70
•Out •Repr +´below30
