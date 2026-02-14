# bench/bqn/bench_loading.bqn — CSV parse only benchmark
bt ← •Import "../../engine/bt.bqn"
data ← bt.Validate bt.Load ⊑•args

# Checksum to prevent dead-code elimination
•Out •Repr (+´data.close) + (+´data.high) + (+´data.low) + (+´data.open) + (+´data.vol)
