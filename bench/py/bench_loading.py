#!/usr/bin/env python3
"""CSV parse only benchmark — pandas vs numpy (manual)."""
import sys
import argparse
import numpy as np
import pandas as pd


def loading_pandas(path):
    """Load via pd.read_csv."""
    df = pd.read_csv(
        path, skiprows=3, header=None,
        names=["date", "close", "high", "low", "open", "volume"],
    )
    checksum = (df["close"].sum() + df["high"].sum() + df["low"].sum()
                + df["open"].sum() + df["volume"].sum())
    print(repr(float(checksum)))


def loading_numpy(path):
    """Load via manual line parsing (matches BQN approach)."""
    with open(path) as f:
        lines = f.readlines()[3:]  # skip 3 header lines
    n = len(lines)
    close = np.empty(n)
    high = np.empty(n)
    low = np.empty(n)
    open_ = np.empty(n)
    vol = np.empty(n)
    for i, line in enumerate(lines):
        parts = line.strip().split(",")
        close[i] = float(parts[1])
        high[i] = float(parts[2])
        low[i] = float(parts[3])
        open_[i] = float(parts[4])
        vol[i] = float(parts[5])
    checksum = close.sum() + high.sum() + low.sum() + open_.sum() + vol.sum()
    print(repr(float(checksum)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", help="Path to OHLCV CSV")
    parser.add_argument("--mode", choices=["pandas", "numpy"], default="pandas")
    args = parser.parse_args()
    if args.mode == "pandas":
        loading_pandas(args.csv)
    else:
        loading_numpy(args.csv)
