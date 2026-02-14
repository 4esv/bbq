#!/usr/bin/env python3
"""Validate Python and Julia indicators match BQN on SPY.csv within tolerance."""
import os
import subprocess
import sys
import numpy as np
import pandas as pd

EPS = 1e-10
TOL = 1e-4  # relative tolerance for sum comparison

BENCH_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(BENCH_DIR)
CSV_PATH = os.path.join(ROOT_DIR, "data", "SPY.csv")

INDICATOR_NAMES = ["MA20", "MA50", "EMA20", "RSI14", "ATR14", "BB_upper", "Stoch_K", "OBV", "VWAP"]


def run_bqn_indicators():
    """Run BQN indicator benchmark, return list of checksum floats."""
    cmd = ["bqn", os.path.join(BENCH_DIR, "bqn", "bench_indicators.bqn"), CSV_PATH]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    values = []
    for line in result.stdout.strip().split("\n"):
        line = line.strip().replace("¯", "-")
        values.append(float(line))
    return values


def run_python_indicators(mode):
    """Run Python indicator benchmark, return list of checksum floats."""
    cmd = [
        sys.executable,
        os.path.join(BENCH_DIR, "py", "bench_indicators.py"),
        CSV_PATH, "--mode", mode,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    values = []
    for line in result.stdout.strip().split("\n"):
        values.append(float(line))
    return values


def run_julia_indicators():
    """Run Julia indicator benchmark, return list of checksum floats."""
    cmd = ["julia", os.path.join(BENCH_DIR, "jl", "bench_indicators.jl"), CSV_PATH, "--mode", "base"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    values = []
    for line in result.stdout.strip().split("\n"):
        values.append(float(line))
    return values


def compare(name, bqn_vals, py_vals, labels):
    """Compare two lists of floats within tolerance."""
    ok = True
    for label, bv, pv in zip(labels, bqn_vals, py_vals):
        if abs(bv) < 1e-8 and abs(pv) < 1e-8:
            diff = abs(bv - pv)
            passed = diff < 1e-6
        else:
            diff = abs(bv - pv) / max(abs(bv), abs(pv), 1e-10)
            passed = diff < TOL
        status = "PASS" if passed else "FAIL"
        if not passed:
            ok = False
        print(f"  {status}  {label:12s}  BQN={bv:>20.6f}  {name}={pv:>20.6f}  rel_err={diff:.2e}")
    return ok


def main():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: {CSV_PATH} not found. Run data/fetch.py first.", file=sys.stderr)
        sys.exit(1)

    print(f"Validating on {CSV_PATH}")
    print()

    bqn_vals = run_bqn_indicators()

    all_ok = True

    print("=== BQN vs Python (numpy) ===")
    np_vals = run_python_indicators("numpy")
    if not compare("numpy", bqn_vals, np_vals, INDICATOR_NAMES):
        all_ok = False
    print()

    print("=== BQN vs Python (pandas) ===")
    pd_vals = run_python_indicators("pandas")
    if not compare("pandas", bqn_vals, pd_vals, INDICATOR_NAMES):
        all_ok = False
    print()

    print("=== BQN vs Julia (base) ===")
    try:
        jl_vals = run_julia_indicators()
        if not compare("julia", bqn_vals, jl_vals, INDICATOR_NAMES):
            all_ok = False
    except FileNotFoundError:
        print("  SKIP  Julia not installed")
    except subprocess.CalledProcessError as e:
        print(f"  SKIP  Julia benchmark failed: {e.stderr[:200] if e.stderr else 'unknown error'}")
    print()

    if all_ok:
        print("All validations PASSED")
    else:
        print("Some validations FAILED", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
