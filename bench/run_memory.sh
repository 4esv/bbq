#!/usr/bin/env bash
# bench/run_memory.sh — measure peak RSS for all 3 runtimes at 1M rows
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$BENCH_DIR/results/data"
CSV="$DATA_DIR/syn_1000000.csv"
RESULTS="$BENCH_DIR/results/memory.txt"

if [ ! -f "$CSV" ]; then
    echo "ERROR: $CSV not found. Run 'bash bench/run.sh' first to generate data."
    exit 1
fi

echo "=== Peak RSS Measurement (1M rows, indicators) ===" | tee "$RESULTS"
echo "" | tee -a "$RESULTS"

measure() {
    local name="$1"
    shift
    # macOS /usr/bin/time -l reports "maximum resident set size" in bytes
    echo -n "$name: " | tee -a "$RESULTS"
    local output
    output=$(/usr/bin/time -l "$@" 2>&1 1>/dev/null)
    local rss
    rss=$(echo "$output" | grep "maximum resident set size" | awk '{print $1}')
    local rss_mb
    rss_mb=$(echo "scale=1; $rss / 1048576" | bc)
    echo "${rss_mb} MB (${rss} bytes)" | tee -a "$RESULTS"
}

measure "BQN" bqn "$BENCH_DIR/bqn/bench_indicators.bqn" "$CSV"
measure "Python (numpy)" python3 "$BENCH_DIR/py/bench_indicators.py" "$CSV" --mode numpy
measure "Python (pandas)" python3 "$BENCH_DIR/py/bench_indicators.py" "$CSV" --mode pandas
measure "Julia (base)" julia "$BENCH_DIR/jl/bench_indicators.jl" "$CSV" --mode base

echo "" | tee -a "$RESULTS"
echo "Results written to $RESULTS"
