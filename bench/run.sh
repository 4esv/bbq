#!/usr/bin/env bash
# bench/run.sh — orchestrator: validate → gen data → hyperfine → report
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$BENCH_DIR")"
RESULTS_DIR="$BENCH_DIR/results"
DATA_DIR="$BENCH_DIR/results/data"
REPORT="$RESULTS_DIR/report.md"

SIZES=(1000 10000 100000 1000000)
WF_SIZES=(10000 100000)
WARMUP=3
RUNS=10

mkdir -p "$RESULTS_DIR" "$DATA_DIR"

# ── Step 1: Validate ────────────────────────────────────────

echo "=== Validation ==="
python3 "$BENCH_DIR/validate.py"
echo ""

# ── Step 2: Generate synthetic data ─────────────────────────

echo "=== Generating synthetic data ==="
for size in "${SIZES[@]}"; do
    csv="$DATA_DIR/syn_${size}.csv"
    if [ ! -f "$csv" ]; then
        python3 "$BENCH_DIR/gen_data.py" "$size" "$csv" 42
    else
        echo "Exists: $csv"
    fi
done
echo ""

# ── Step 3: Benchmarks ─────────────────────────────────────

run_bench_nopkg() {
    local name="$1"
    local bqn_script="$2"
    local py_script="$3"
    local jl_script="$4"
    local csv="$5"
    local size="$6"
    local json="$RESULTS_DIR/${name}_${size}.json"

    echo "--- $name @ $size rows ---"
    hyperfine \
        --warmup "$WARMUP" \
        --runs "$RUNS" \
        --export-json "$json" \
        --command-name "bqn" \
        "bqn $bqn_script $csv" \
        --command-name "python-pandas" \
        "python3 $py_script $csv --mode pandas" \
        --command-name "python-numpy" \
        "python3 $py_script $csv --mode numpy" \
        --command-name "julia" \
        "julia $jl_script $csv"
}

run_bench_loading() {
    local csv="$1"
    local size="$2"
    local json="$RESULTS_DIR/loading_${size}.json"

    echo "--- loading @ $size rows ---"
    hyperfine \
        --warmup "$WARMUP" \
        --runs "$RUNS" \
        --export-json "$json" \
        --command-name "bqn" \
        "bqn $BENCH_DIR/bqn/bench_loading.bqn $csv" \
        --command-name "python-pandas" \
        "python3 $BENCH_DIR/py/bench_loading.py $csv --mode pandas" \
        --command-name "python-numpy" \
        "python3 $BENCH_DIR/py/bench_loading.py $csv --mode numpy" \
        --command-name "julia-base" \
        "julia $BENCH_DIR/jl/bench_loading.jl $csv --mode base" \
        --command-name "julia-csv" \
        "julia $BENCH_DIR/jl/bench_loading.jl $csv --mode pkg"
}

run_bench_walkforward() {
    local csv="$1"
    local size="$2"
    local json="$RESULTS_DIR/walkforward_${size}.json"

    echo "--- walkforward @ $size rows ---"
    hyperfine \
        --warmup "$WARMUP" \
        --runs "$RUNS" \
        --export-json "$json" \
        --command-name "bqn" \
        "bqn $BENCH_DIR/bqn/bench_walkforward.bqn $csv" \
        --command-name "python" \
        "python3 $BENCH_DIR/py/bench_walkforward.py $csv" \
        --command-name "julia" \
        "julia $BENCH_DIR/jl/bench_walkforward.jl $csv"
}

echo "=== Running benchmarks ==="

# Indicators — Julia has base and pkg modes
for size in "${SIZES[@]}"; do
    csv="$DATA_DIR/syn_${size}.csv"
    json="$RESULTS_DIR/indicators_${size}.json"

    echo "--- indicators @ $size rows ---"
    hyperfine \
        --warmup "$WARMUP" \
        --runs "$RUNS" \
        --export-json "$json" \
        --command-name "bqn" \
        "bqn $BENCH_DIR/bqn/bench_indicators.bqn $csv" \
        --command-name "python-pandas" \
        "python3 $BENCH_DIR/py/bench_indicators.py $csv --mode pandas" \
        --command-name "python-numpy" \
        "python3 $BENCH_DIR/py/bench_indicators.py $csv --mode numpy" \
        --command-name "julia-base" \
        "julia $BENCH_DIR/jl/bench_indicators.jl $csv --mode base" \
        --command-name "julia-pkg" \
        "julia $BENCH_DIR/jl/bench_indicators.jl $csv --mode pkg"
done

# Metrics, Signals, Pipeline — Julia has one mode
for size in "${SIZES[@]}"; do
    csv="$DATA_DIR/syn_${size}.csv"

    run_bench_nopkg "metrics" \
        "$BENCH_DIR/bqn/bench_metrics.bqn" \
        "$BENCH_DIR/py/bench_metrics.py" \
        "$BENCH_DIR/jl/bench_metrics.jl" \
        "$csv" "$size"

    run_bench_nopkg "signals" \
        "$BENCH_DIR/bqn/bench_signals.bqn" \
        "$BENCH_DIR/py/bench_signals.py" \
        "$BENCH_DIR/jl/bench_signals.jl" \
        "$csv" "$size"

    run_bench_nopkg "pipeline" \
        "$BENCH_DIR/bqn/bench_pipeline.bqn" \
        "$BENCH_DIR/py/bench_pipeline.py" \
        "$BENCH_DIR/jl/bench_pipeline.jl" \
        "$csv" "$size"
done

# Loading
for size in "${SIZES[@]}"; do
    csv="$DATA_DIR/syn_${size}.csv"
    run_bench_loading "$csv" "$size"
done

# Walk-forward (only 10K and 100K — needs enough data for folds)
for size in "${WF_SIZES[@]}"; do
    csv="$DATA_DIR/syn_${size}.csv"
    run_bench_walkforward "$csv" "$size"
done
echo ""

# ── Step 4: Generate report ─────────────────────────────────

echo "=== Generating report ==="
python3 - "$RESULTS_DIR" "$REPORT" "$BENCH_DIR" <<'PYEOF'
import json, sys, os

results_dir = sys.argv[1]
report_path = sys.argv[2]
bench_dir = sys.argv[3]

sizes = [1000, 10000, 100000, 1000000]
wf_sizes = [10000, 100000]

lines = []
lines.append("# CBQN vs Python vs Julia Benchmark Results\n")
lines.append(f"Warmup: 3 | Runs: 10 | Data: GBM synthetic (seed=42)\n")

def read_bench(name, size):
    json_path = os.path.join(results_dir, f"{name}_{size}.json")
    if not os.path.exists(json_path):
        return None
    with open(json_path) as f:
        return json.load(f)

def fmt_ms(median, stddev):
    return f"{median:>7.1f} ± {stddev:>5.1f}"

def fmt_ratio(a, b):
    if b > 0:
        return f"{a/b:.2f}x"
    return "-"

# ── Indicators (5 runners) ────────────────────────────────

benchmarks_5 = ["indicators"]
for bench in benchmarks_5:
    lines.append(f"\n## {bench.title()}\n")
    lines.append("| Rows | BQN (ms) | pandas (ms) | numpy (ms) | Julia-base (ms) | Julia-pkg (ms) | BQN/pandas | BQN/numpy | BQN/jl-base |")
    lines.append("|------|----------|-------------|------------|-----------------|----------------|------------|-----------|-------------|")

    for size in sizes:
        data = read_bench(bench, size)
        if not data:
            lines.append(f"| {size:,} | - | - | - | - | - | - | - | - |")
            continue

        times = {}
        for result in data["results"]:
            name = result["command"]
            median = result["median"] * 1000
            stddev = result.get("stddev", 0) * 1000
            times[name] = (median, stddev)

        bqn = times.get("bqn", (0, 0))
        pd_t = times.get("python-pandas", (0, 0))
        np_t = times.get("python-numpy", (0, 0))
        jb = times.get("julia-base", (0, 0))
        jp = times.get("julia-pkg", (0, 0))

        lines.append(
            f"| {size:>7,} "
            f"| {fmt_ms(*bqn)} "
            f"| {fmt_ms(*pd_t)} "
            f"| {fmt_ms(*np_t)} "
            f"| {fmt_ms(*jb)} "
            f"| {fmt_ms(*jp)} "
            f"| {fmt_ratio(bqn[0], pd_t[0]):>10s} "
            f"| {fmt_ratio(bqn[0], np_t[0]):>9s} "
            f"| {fmt_ratio(bqn[0], jb[0]):>11s} |"
        )

# ── Metrics, Signals, Pipeline (4 runners) ───────────────

benchmarks_4 = ["metrics", "signals", "pipeline"]
for bench in benchmarks_4:
    lines.append(f"\n## {bench.title()}\n")
    lines.append("| Rows | BQN (ms) | pandas (ms) | numpy (ms) | Julia (ms) | BQN/pandas | BQN/numpy | BQN/julia |")
    lines.append("|------|----------|-------------|------------|------------|------------|-----------|-----------|")

    for size in sizes:
        data = read_bench(bench, size)
        if not data:
            lines.append(f"| {size:,} | - | - | - | - | - | - | - |")
            continue

        times = {}
        for result in data["results"]:
            name = result["command"]
            median = result["median"] * 1000
            stddev = result.get("stddev", 0) * 1000
            times[name] = (median, stddev)

        bqn = times.get("bqn", (0, 0))
        pd_t = times.get("python-pandas", (0, 0))
        np_t = times.get("python-numpy", (0, 0))
        jl = times.get("julia", (0, 0))

        lines.append(
            f"| {size:>7,} "
            f"| {fmt_ms(*bqn)} "
            f"| {fmt_ms(*pd_t)} "
            f"| {fmt_ms(*np_t)} "
            f"| {fmt_ms(*jl)} "
            f"| {fmt_ratio(bqn[0], pd_t[0]):>10s} "
            f"| {fmt_ratio(bqn[0], np_t[0]):>9s} "
            f"| {fmt_ratio(bqn[0], jl[0]):>9s} |"
        )

# ── Loading (5 runners) ──────────────────────────────────

lines.append(f"\n## Loading (CSV Parse)\n")
lines.append("| Rows | BQN (ms) | pandas (ms) | numpy (ms) | Julia-base (ms) | Julia-csv (ms) | BQN/pandas | BQN/jl-csv |")
lines.append("|------|----------|-------------|------------|-----------------|----------------|------------|------------|")

for size in sizes:
    data = read_bench("loading", size)
    if not data:
        lines.append(f"| {size:,} | - | - | - | - | - | - | - |")
        continue

    times = {}
    for result in data["results"]:
        name = result["command"]
        median = result["median"] * 1000
        stddev = result.get("stddev", 0) * 1000
        times[name] = (median, stddev)

    bqn = times.get("bqn", (0, 0))
    pd_t = times.get("python-pandas", (0, 0))
    np_t = times.get("python-numpy", (0, 0))
    jb = times.get("julia-base", (0, 0))
    jc = times.get("julia-csv", (0, 0))

    lines.append(
        f"| {size:>7,} "
        f"| {fmt_ms(*bqn)} "
        f"| {fmt_ms(*pd_t)} "
        f"| {fmt_ms(*np_t)} "
        f"| {fmt_ms(*jb)} "
        f"| {fmt_ms(*jc)} "
        f"| {fmt_ratio(bqn[0], pd_t[0]):>10s} "
        f"| {fmt_ratio(bqn[0], jc[0]):>10s} |"
    )

# ── Walk-Forward (3 runners) ─────────────────────────────

lines.append(f"\n## Walk-Forward Optimization\n")
lines.append("| Rows | BQN (ms) | Python (ms) | Julia (ms) | BQN/Python | BQN/Julia |")
lines.append("|------|----------|-------------|------------|------------|-----------|")

for size in wf_sizes:
    data = read_bench("walkforward", size)
    if not data:
        lines.append(f"| {size:,} | - | - | - | - | - |")
        continue

    times = {}
    for result in data["results"]:
        name = result["command"]
        median = result["median"] * 1000
        stddev = result.get("stddev", 0) * 1000
        times[name] = (median, stddev)

    bqn = times.get("bqn", (0, 0))
    py = times.get("python", (0, 0))
    jl = times.get("julia", (0, 0))

    lines.append(
        f"| {size:>7,} "
        f"| {fmt_ms(*bqn)} "
        f"| {fmt_ms(*py)} "
        f"| {fmt_ms(*jl)} "
        f"| {fmt_ratio(bqn[0], py[0]):>10s} "
        f"| {fmt_ratio(bqn[0], jl[0]):>9s} |"
    )

# ── Code line counts ─────────────────────────────────────

all_benchmarks = ["indicators", "metrics", "signals", "pipeline", "loading", "walkforward"]
lines.append("\n## Code Size (lines)\n")
lines.append("| File | BQN | Python | Julia |")
lines.append("|------|-----|--------|-------|")

for bench in all_benchmarks:
    bqn_file = os.path.join(bench_dir, "bqn", f"bench_{bench}.bqn")
    py_file = os.path.join(bench_dir, "py", f"bench_{bench}.py")
    jl_file = os.path.join(bench_dir, "jl", f"bench_{bench}.jl")
    bqn_lines = len(open(bqn_file).readlines()) if os.path.exists(bqn_file) else 0
    py_lines = len(open(py_file).readlines()) if os.path.exists(py_file) else 0
    jl_lines = len(open(jl_file).readlines()) if os.path.exists(jl_file) else 0
    py_ratio = f"{py_lines/bqn_lines:.1f}x" if bqn_lines > 0 else "-"
    jl_ratio = f"{jl_lines/bqn_lines:.1f}x" if bqn_lines > 0 else "-"
    lines.append(f"| {bench} | {bqn_lines} | {py_lines} ({py_ratio}) | {jl_lines} ({jl_ratio}) |")

lines.append("\n*Ratio < 1.0 = BQN faster. Generated by bench/run.sh*\n")

with open(report_path, "w") as f:
    f.write("\n".join(lines))

print(f"Report written to {report_path}")
PYEOF

echo ""
echo "Done. Results in $RESULTS_DIR/"
echo "Report: $REPORT"
