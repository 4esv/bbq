# bbq — BQN Based Quant — test suite
# tests/verify.bqn

bt ← •Import "../engine/bt.bqn"

# ── Helpers ──────────────────────────────────

# Assert arrays approximately equal (tolerance 1e-6)
Ae ← {! ∧´ 1e¯6 > | (⥊𝕨)-(⥊𝕩)}

# Assert scalar approximately equal
As ← {! 1e¯6 > |𝕨-𝕩}

pass ← 0

•Out "Running bbq test suite..."
•Out ""

# ══ Data ═════════════════════════════════════

# ── Load ─────────────────────────────────────

data ← bt.Load "../tests/fixture.csv"
! 5 = ≠data.close
! 5 = ≠data.high
! 5 = ≠data.low
! 5 = ≠data.open
! 5 = ≠data.vol
! 5 = ≠data.dates
100‿102‿101‿105‿103 Ae data.close
105‿107‿104‿108‿106 Ae data.high
95‿99‿98‿100‿97 Ae data.low
98‿100‿102‿101‿105 Ae data.open
1e6‿1.2e6‿9e5‿1.5e6‿1.1e6 Ae data.vol

pass +↩ 1 ⋄ •Out "  PASS  Load"

# ── Validate ─────────────────────────────────

d ← bt.Validate data
! 5 = ≠d.close

# Should fail on empty data
! 1 = ({bt.Validate 𝕩 ⋄ 0}⎊{1}) {
  dates⇐⟨⟩ ⋄ close⇐⟨⟩ ⋄ high⇐⟨⟩ ⋄ low⇐⟨⟩ ⋄ open⇐⟨⟩ ⋄ vol⇐⟨⟩
}

# Should fail on negative prices in strict (default) mode
! 1 = ({bt.Validate 𝕩 ⋄ 0}⎊{1}) {
  dates⇐⟨"a"⟩ ⋄ close⇐⟨¯1⟩ ⋄ high⇐⟨5⟩ ⋄ low⇐⟨1⟩ ⋄ open⇐⟨3⟩ ⋄ vol⇐⟨100⟩
}

# Should fail on negative prices in explicit strict mode
! 1 = ({1 bt.Validate 𝕩 ⋄ 0}⎊{1}) {
  dates⇐⟨"a"⟩ ⋄ close⇐⟨¯1⟩ ⋄ high⇐⟨5⟩ ⋄ low⇐⟨1⟩ ⋄ open⇐⟨3⟩ ⋄ vol⇐⟨100⟩
}

# Futures mode: should accept negative prices
fd ← 0 bt.Validate {
  dates⇐⟨"a"⟩ ⋄ close⇐⟨¯37.63⟩ ⋄ high⇐⟨¯30⟩ ⋄ low⇐⟨¯40⟩ ⋄ open⇐⟨¯35⟩ ⋄ vol⇐⟨100⟩
}
! 1 = ≠fd.close

# Futures mode: should still enforce OHLC relationships
! 1 = ({0 bt.Validate 𝕩 ⋄ 0}⎊{1}) {
  dates⇐⟨"a"⟩ ⋄ close⇐⟨¯37⟩ ⋄ high⇐⟨¯50⟩ ⋄ low⇐⟨¯30⟩ ⋄ open⇐⟨¯35⟩ ⋄ vol⇐⟨100⟩
}

# Should fail on OHLC violation (high < low)
! 1 = ({bt.Validate 𝕩 ⋄ 0}⎊{1}) {
  dates⇐⟨"a"⟩ ⋄ close⇐⟨3⟩ ⋄ high⇐⟨1⟩ ⋄ low⇐⟨5⟩ ⋄ open⇐⟨3⟩ ⋄ vol⇐⟨100⟩
}

# Should fail on open outside high/low range
! 1 = ({bt.Validate 𝕩 ⋄ 0}⎊{1}) {
  dates⇐⟨"a"⟩ ⋄ close⇐⟨3⟩ ⋄ high⇐⟨5⟩ ⋄ low⇐⟨1⟩ ⋄ open⇐⟨10⟩ ⋄ vol⇐⟨100⟩
}

# Should fail on length mismatch
! 1 = ({bt.Validate 𝕩 ⋄ 0}⎊{1}) {
  dates⇐"a"‿"b" ⋄ close⇐100‿102 ⋄ high⇐⟨105⟩ ⋄ low⇐95‿99 ⋄ open⇐98‿100 ⋄ vol⇐1000‿2000
}

pass +↩ 1 ⋄ •Out "  PASS  Validate"

# ── Align ────────────────────────────────────

r ← bt.Align ⟨1‿2‿3‿4‿5, 3‿4‿5⟩
3‿4‿5 Ae 0⊑r
3‿4‿5 Ae 1⊑r

r ↩ bt.Align ⟨10‿20, 1‿2‿3‿4⟩
10‿20 Ae 0⊑r
3‿4 Ae 1⊑r

# Three arrays
r ↩ bt.Align ⟨1‿2‿3, 1‿2‿3‿4, 1‿2‿3‿4‿5⟩
! 3 = ≠ 0⊑r
! 3 = ≠ 1⊑r
! 3 = ≠ 2⊑r

# Equal-length arrays pass through unchanged
r ↩ bt.Align ⟨1‿2‿3, 4‿5‿6⟩
1‿2‿3 Ae 0⊑r
4‿5‿6 Ae 1⊑r

pass +↩ 1 ⋄ •Out "  PASS  Align"

# ══ Indicators ═══════════════════════════════

x ← 1‿3‿2‿5‿4
c ← data.close  # 100‿102‿101‿105‿103

# ── MA ───────────────────────────────────────

101‿101.5‿103‿104 Ae 2 bt.MA c
2‿2.5‿3.5‿4.5 Ae 2 bt.MA x
! 3 = ≠ 3 bt.MA x

pass +↩ 1 ⋄ •Out "  PASS  MA"

# ── EMA ──────────────────────────────────────

ema ← 2 bt.EMA x
! 5 = ≠ema
(⊑x) As ⊑ema
# EMA converges toward recent values
! (¯1⊑ema) > 2

pass +↩ 1 ⋄ •Out "  PASS  EMA"

# ── WMA ──────────────────────────────────────

(7÷3)‿(7÷3)‿4‿(13÷3) Ae 2 bt.WMA x
! 4 = ≠ 2 bt.WMA x

pass +↩ 1 ⋄ •Out "  PASS  WMA"

# ── RMax ─────────────────────────────────────

3‿3‿5‿5 Ae 2 bt.RMax x
! 4 = ≠ 2 bt.RMax x

pass +↩ 1 ⋄ •Out "  PASS  RMax"

# ── RMin ─────────────────────────────────────

1‿2‿2‿4 Ae 2 bt.RMin x
! 4 = ≠ 2 bt.RMin x

pass +↩ 1 ⋄ •Out "  PASS  RMin"

# ── Std ──────────────────────────────────────

1‿0.5‿1.5‿0.5 Ae 2 bt.Std x
! 4 = ≠ 2 bt.Std x

pass +↩ 1 ⋄ •Out "  PASS  Std"

# ── Mom ──────────────────────────────────────

2‿¯1‿3‿¯1 Ae 1 bt.Mom x
1‿2‿2 Ae 2 bt.Mom x

pass +↩ 1 ⋄ •Out "  PASS  Mom"

# ── ROC ──────────────────────────────────────

200‿(100×¯1÷3)‿150‿¯20 Ae 1 bt.ROC x
! 4 = ≠ 1 bt.ROC x

pass +↩ 1 ⋄ •Out "  PASS  ROC"

# ── RSI ──────────────────────────────────────

rsi ← 14 bt.RSI c
! ∧´ (rsi≥0) ∧ rsi≤100
# Strictly rising prices → RSI high
rsi_up ← 3 bt.RSI 1‿2‿3‿4‿5‿6‿7‿8
! ∧´ (2↓rsi_up) > 50

pass +↩ 1 ⋄ •Out "  PASS  RSI"

# ── MACD ─────────────────────────────────────

ml‿sl‿hist ← 2‿3‿2 bt.MACD c
! (≠ml) = ≠c
! (≠sl) = ≠c
! (≠hist) = ≠c
(ml-sl) Ae hist

pass +↩ 1 ⋄ •Out "  PASS  MACD"

# ── ATR ──────────────────────────────────────

atr ← 2 bt.ATR data
! (¯1+≠c) = ≠atr
! ∧´ atr > 0

pass +↩ 1 ⋄ •Out "  PASS  ATR"

# ── Stoch ────────────────────────────────────

k‿kd ← 2 bt.Stoch data
! ∧´ (k≥0) ∧ k≤100

pass +↩ 1 ⋄ •Out "  PASS  Stoch"

# ── BB ───────────────────────────────────────

u‿m‿l ← 2‿1 bt.BB x
! ∧´ u ≥ m
! ∧´ m ≥ l
2‿2.5‿3.5‿4.5 Ae m
! 4 = ≠u

pass +↩ 1 ⋄ •Out "  PASS  BB"

# ── OBV ──────────────────────────────────────

obv ← bt.OBV c‿data.vol
! (≠c) = ≠obv
# First bar has no prior close, so OBV starts at 0
0 As ⊑obv

pass +↩ 1 ⋄ •Out "  PASS  OBV"

# ── VWAP ─────────────────────────────────────

vwap ← bt.VWAP data
! (≠c) = ≠vwap
# VWAP is a weighted average of typical price, bounded by cumulative extremes
! ∧´ vwap > 0

pass +↩ 1 ⋄ •Out "  PASS  VWAP"

# ── AD ───────────────────────────────────────

ad ← bt.AD data
! (≠c) = ≠ad

pass +↩ 1 ⋄ •Out "  PASS  AD"

# ══ Signal Utilities ═════════════════════════

# ── Cross ────────────────────────────────────

0‿0‿1‿0 Ae (1‿0‿1‿1) bt.Cross (0‿1‿0‿0)

pass +↩ 1 ⋄ •Out "  PASS  Cross"

# ── CrossDown ────────────────────────────────

0‿1‿0‿0 Ae (1‿0‿1‿1) bt.CrossDown (0‿1‿0‿0)

pass +↩ 1 ⋄ •Out "  PASS  CrossDown"

# ── Mask ─────────────────────────────────────

0‿0‿3‿4‿5 Ae 2 bt.Mask 1‿2‿3‿4‿5
! 5 = ≠ 2 bt.Mask 1‿2‿3‿4‿5

pass +↩ 1 ⋄ •Out "  PASS  Mask"

# ── Fill ─────────────────────────────────────

0‿1‿1‿1‿¯1‿¯1 Ae bt.Fill 0‿1‿0‿0‿¯1‿0
# Starting with non-zero
3‿3‿2‿2 Ae bt.Fill 3‿0‿2‿0

pass +↩ 1 ⋄ •Out "  PASS  Fill"

# ── Thresh ───────────────────────────────────

0‿0‿1‿0‿0 Ae 30 bt.Thresh 25‿28‿35‿32‿29

pass +↩ 1 ⋄ •Out "  PASS  Thresh"

# ── ThreshDown ───────────────────────────────

0‿0‿1‿0‿0 Ae 30 bt.ThreshDown 35‿32‿25‿28‿31

pass +↩ 1 ⋄ •Out "  PASS  ThreshDown"

# ── Hold ─────────────────────────────────────

0‿1‿1‿1‿0‿¯1 Ae 3 bt.Hold 0‿1‿0‿0‿0‿¯1
# No holding needed when already in position
1‿1‿1 Ae 2 bt.Hold 1‿1‿1

pass +↩ 1 ⋄ •Out "  PASS  Hold"

# ══ Simulation ═══════════════════════════════

# ── _Sim ─────────────────────────────────────

# Echo step: position = observation
result ← {⟨𝕩⟩} bt._Sim ⟨0⟩‿(1‿0‿1‿¯1‿0)
1‿0‿1‿¯1‿0 Ae result

# Accumulator step: state = ⟨sum, count⟩, position = running sum
result2 ← {⟨(⊑𝕨)+𝕩, (1⊑𝕨)+1⟩} bt._Sim ⟨0,0⟩‿(1‿2‿3)
1‿3‿6 Ae result2

pass +↩ 1 ⋄ •Out "  PASS  _Sim"

# ══ Backtest Core ════════════════════════════

# ── Ret ──────────────────────────────────────

ret ← bt.Ret c
! 4 = ≠ret
(0.02) As ⊑ret
# Second return: (101-102)/102
(¯1÷102) As 1⊑ret

pass +↩ 1 ⋄ •Out "  PASS  Ret"

# ── LogRet ───────────────────────────────────

lr ← bt.LogRet c
! 4 = ≠lr
# LogRet ≈ Ret for small returns
! ∧´ 0.001 > |lr - ret

pass +↩ 1 ⋄ •Out "  PASS  LogRet"

# ── Run ──────────────────────────────────────

sr ← 1‿0‿1‿¯1 bt.Run 0.02‿¯0.01‿0.03‿¯0.02
0.02‿0‿0.03‿0.02 Ae sr

pass +↩ 1 ⋄ •Out "  PASS  Run"

# ── Cost ─────────────────────────────────────

costs ← 0.001 bt.Cost 0‿1‿1‿0‿¯1
0‿0.001‿0‿0.001‿0.001 Ae costs

pass +↩ 1 ⋄ •Out "  PASS  Cost"

# ── Equity ───────────────────────────────────

eq ← bt.Equity 0.1‿¯0.05‿0.02
! 3 = ≠eq
1.1 As ⊑eq
(1.1×0.95) As 1⊑eq
(1.1×0.95×1.02) As 2⊑eq

pass +↩ 1 ⋄ •Out "  PASS  Equity"

# ══ Metrics ══════════════════════════════════

# Test returns for metrics
mr ← 0.02‿¯0.01‿0.03‿¯0.02‿0.01

# ── TotalRet ─────────────────────────────────

tr ← bt.TotalRet mr
eq_final ← ¯1⊑bt.Equity mr
(eq_final - 1) As tr

pass +↩ 1 ⋄ •Out "  PASS  TotalRet"

# ── CAGR ─────────────────────────────────────

cagr ← bt.CAGR mr
! cagr > 0  # net positive returns → positive CAGR

pass +↩ 1 ⋄ •Out "  PASS  CAGR"

# ── AnnVol ───────────────────────────────────

vol ← bt.AnnVol mr
! vol > 0

pass +↩ 1 ⋄ •Out "  PASS  AnnVol"

# ── Sharpe ───────────────────────────────────

sh ← bt.Sharpe mr
! sh > 0  # positive mean returns → positive Sharpe
# Zero returns → zero Sharpe
0 As bt.Sharpe 0‿0‿0‿0

pass +↩ 1 ⋄ •Out "  PASS  Sharpe"

# ── Sortino ──────────────────────────────────

so ← bt.Sortino mr
! so > 0
# Sortino ≥ Sharpe when there's downside
! so ≥ sh

pass +↩ 1 ⋄ •Out "  PASS  Sortino"

# ── MaxDD ────────────────────────────────────

dd ← bt.MaxDD mr
! dd ≤ 0  # drawdown is non-positive
# All positive returns → zero drawdown
0 As bt.MaxDD 0.01‿0.02‿0.03

pass +↩ 1 ⋄ •Out "  PASS  MaxDD"

# ── MaxDDDur ─────────────────────────────────

dur ← bt.MaxDDDur mr
! dur ≥ 0
# All positive returns → zero duration
0 As bt.MaxDDDur 0.01‿0.02‿0.03
# Single drawdown bar
1 As bt.MaxDDDur 0.1‿¯0.05‿0.1

pass +↩ 1 ⋄ •Out "  PASS  MaxDDDur"

# ── Calmar ───────────────────────────────────

cal ← bt.Calmar mr
! cal > 0

pass +↩ 1 ⋄ •Out "  PASS  Calmar"

# ── WinRate ──────────────────────────────────

wr ← bt.WinRate mr
(3÷5) As wr  # 3 positive out of 5

pass +↩ 1 ⋄ •Out "  PASS  WinRate"

# ── ProfitFactor ─────────────────────────────

pf ← bt.ProfitFactor mr
# gross profit = 0.02+0.03+0.01 = 0.06, gross loss = 0.01+0.02 = 0.03
(0.06÷0.03) As pf

pass +↩ 1 ⋄ •Out "  PASS  ProfitFactor"

# ── AvgWin ───────────────────────────────────

aw ← bt.AvgWin mr
((0.02+0.03+0.01)÷3) As aw

pass +↩ 1 ⋄ •Out "  PASS  AvgWin"

# ── AvgLoss ──────────────────────────────────

al ← bt.AvgLoss mr
((¯0.01+¯0.02)÷2) As al

pass +↩ 1 ⋄ •Out "  PASS  AvgLoss"

# ── Expectancy ───────────────────────────────

ex ← bt.Expectancy mr
# mean of non-zero returns: (0.02-0.01+0.03-0.02+0.01)/5 = 0.006
0.006 As ex

pass +↩ 1 ⋄ •Out "  PASS  Expectancy"

# ── Trades ───────────────────────────────────

pos_t ← 0‿1‿1‿0‿¯1
3 As bt.Trades pos_t

pass +↩ 1 ⋄ •Out "  PASS  Trades"

# ── TimeIn / Exposure ────────────────────────

(3÷5) As bt.TimeIn pos_t
(bt.TimeIn pos_t) As bt.Exposure pos_t

pass +↩ 1 ⋄ •Out "  PASS  TimeIn/Exposure"

# ── Skew ─────────────────────────────────────

# Symmetric distribution → skew = 0
0 As bt.Skew 1‿2‿3‿4‿5

pass +↩ 1 ⋄ •Out "  PASS  Skew"

# ── Kurt ─────────────────────────────────────

# Uniform-like → negative excess kurtosis
kurt ← bt.Kurt 1‿2‿3‿4‿5
¯1.3 As kurt

pass +↩ 1 ⋄ •Out "  PASS  Kurt"

# ══ Portfolio ═══════════════════════════════

# ── PortRun ────────────────────────────────

# 2 assets, equal weights, known returns
pr ← 0.5‿0.5 bt.PortRun ⟨⟨1‿1‿1‿1, 0.02‿¯0.01‿0.03‿¯0.02⟩, ⟨1‿1‿1‿1, 0.01‿0.02‿¯0.01‿0.04⟩⟩
# Expected: 0.5×0.02+0.5×0.01, 0.5×(¯0.01)+0.5×0.02, ...
0.015‿0.005‿0.01‿0.01 Ae pr

pass +↩ 1 ⋄ •Out "  PASS  PortRun"

# ── PortRun weights assertion ──────────────

! 1 = ({𝕩 bt.PortRun ⟨⟨1‿1, 0.01‿0.02⟩, ⟨1‿1, 0.03‿0.04⟩⟩ ⋄ 0}⎊{1}) 0.3‿0.3

pass +↩ 1 ⋄ •Out "  PASS  PortRun weight assertion"

# ── PortCost ───────────────────────────────

pc ← 0.001‿0.002 bt.PortCost ⟨0‿1‿1‿0, 0‿0‿1‿¯1⟩
# Asset 0: 0.001×|0,1,0,1| = 0,0.001,0,0.001
# Asset 1: 0.002×|0,0,1,2| = 0,0,0.002,0.004
# Combined: 0, 0.001, 0.002, 0.005
0‿0.001‿0.002‿0.005 Ae pc

pass +↩ 1 ⋄ •Out "  PASS  PortCost"

# ── PortEquity ─────────────────────────────

peq ← bt.PortEquity 0.1‿¯0.05‿0.02
eq_ref ← bt.Equity 0.1‿¯0.05‿0.02
peq Ae eq_ref

pass +↩ 1 ⋄ •Out "  PASS  PortEquity"

# ══ Walk-Forward ════════════════════════════

wf ← •Import "../engine/wf.bqn"

# ── Windows ────────────────────────────────

# 10 bars, train=4, test=2 → 3 folds
wins ← 4‿2 wf.Windows ↕10
! 3 = ≠wins

# Fold 0: train=[0..3], test=[4..5]
0‿1‿2‿3 Ae ⊑⊑wins
4‿5 Ae 1⊑⊑wins

# Fold 1: train=[2..5], test=[6..7]
2‿3‿4‿5 Ae ⊑1⊑wins
6‿7 Ae 1⊑1⊑wins

# Fold 2: train=[4..7], test=[8..9]
4‿5‿6‿7 Ae ⊑2⊑wins
8‿9 Ae 1⊑2⊑wins

pass +↩ 1 ⋄ •Out "  PASS  Windows"

# ── Grid ───────────────────────────────────

# 2 ranges → 9 combos
g ← wf.Grid ⟨10‿20‿30, 40‿50‿60⟩
! 9 = ≠g
# First tuple
10‿40 Ae ⊑g
# Last tuple
30‿60 Ae ¯1⊑g

pass +↩ 1 ⋄ •Out "  PASS  Grid (2 ranges)"

# Single range
g1 ← wf.Grid ⟨1‿2‿3⟩
! 3 = ≠g1
⟨1⟩ Ae ⊑g1
⟨3⟩ Ae ¯1⊑g1

pass +↩ 1 ⋄ •Out "  PASS  Grid (1 range)"

# Three ranges
g3 ← wf.Grid ⟨1‿2, 3‿4, 5‿6⟩
! 8 = ≠g3
1‿3‿5 Ae ⊑g3
2‿4‿6 Ae ¯1⊑g3

pass +↩ 1 ⋄ •Out "  PASS  Grid (3 ranges)"

# ── _WF ────────────────────────────────────

# Trivial always-long strategy on synthetic data
# 20 bars of steadily rising prices
synth ← 100+↕20

# Strategy: ignore params, go long always
AlwaysLong ← {𝕨 ⋄ (≠𝕩)⥊1}

wf_result ← synth AlwaysLong wf._WF ⟨6, 2, ⟨⟨1⟩⟩, 0, wf.Sharpe⟩

# Verify fold count: 20 bars, train=6, test=2 → nf = 1+⌊(20-6-2)÷2 = 1+6 = 7
! 7 = ≠wf_result.folds

# OOS return length: 7 folds × (2-1) = 7 test returns (Ret shortens by 1)
! 7 = ≠wf_result.oos_ret

# Equity curve same length as OOS returns
! (≠wf_result.oos_ret) = ≠wf_result.oos_eq

# Summary metrics are finite
! ¬ ∞ = |wf_result.summary.sharpe
! ¬ ∞ = |wf_result.summary.maxdd

pass +↩ 1 ⋄ •Out "  PASS  _WF"

# Look-ahead bias detection: momentum on oscillating data
# With look-ahead, strategy sees each return's sign before trading → all positive OOS
# Without look-ahead, directional reversals produce negative OOS returns
MomStrat ← {𝕨 ⋄ 1⌈¯1⌊ ×𝕩-»𝕩}
synth_la ← 100‿102‿99‿104‿97‿101‿98‿103‿100‿105‿96‿102‿99‿104‿97‿101‿98‿103‿100‿105
wf_la ← synth_la MomStrat wf._WF ⟨6, 3, ⟨⟨1⟩⟩, 0, wf.Sharpe⟩
! ∨´ wf_la.oos_ret < 0
pass +↩ 1 ⋄ •Out "  PASS  _WF no look-ahead bias"

# ══ Composition ═══════════════════════════════

cmp ← •Import "../engine/cmp.bqn"

# ── Norm ────────────────────────────────────

n ← cmp.Norm 2‿4‿6‿8‿10
# d=¯4‿¯2‿0‿2‿4, std=√8
(¯4‿¯2‿0‿2‿4 ÷ √8) Ae n

pass +↩ 1 ⋄ •Out "  PASS  Norm"

# ── ENorm ──────────────────────────────────

en ← cmp.ENorm 2‿4‿6‿8‿10
# No lookahead: bar 0 has std=0 → result 0
0 As ⊑en
# Each bar uses only past data, so values differ from full-array Norm
! 5 = ≠en

pass +↩ 1 ⋄ •Out "  PASS  ENorm"

# ── Score ───────────────────────────────────

sc ← 0.6‿0.4 cmp.Score ⟨1‿2‿3, 4‿5‿6⟩
2.2‿3.2‿4.2 Ae sc

pass +↩ 1 ⋄ •Out "  PASS  Score"

# ── Thresh (cmp) ────────────────────────────

1‿0‿¯1‿0‿1 Ae 0.5 cmp.Thresh 1‿0.3‿¯0.8‿0‿0.6

pass +↩ 1 ⋄ •Out "  PASS  Thresh (cmp)"

# ── Compose ─────────────────────────────────

cpos ← ⟨0.5‿0.5, 0.3⟩ cmp.Compose ⟨1‿2‿3, 4‿5‿6⟩
! 3 = ≠cpos
! ∧´ cpos∊1‿0‿¯1

pass +↩ 1 ⋄ •Out "  PASS  Compose"

# ── Score auto-alignment ───────────────────

sc2 ← 0.5‿0.5 cmp.Score ⟨1‿2‿3‿4‿5, 10‿20‿30⟩
! 3 = ≠sc2

pass +↩ 1 ⋄ •Out "  PASS  Score auto-alignment"

# ── Compose single-feature ─────────────────

csf ← 2‿4‿6‿8‿10
(0.5 cmp.Thresh cmp.Norm csf) Ae ⟨1⟩‿0.5 cmp.Compose ⟨csf⟩

pass +↩ 1 ⋄ •Out "  PASS  Compose single-feature"

# ══ Edge Cases ═════════════════════════════════

# ── Single element ─────────────────────────────

⟨42⟩ Ae 1 bt.MA ⟨42⟩
! 0 = ≠ 2 bt.MA ⟨42⟩
⟨42⟩ Ae 3 bt.EMA ⟨42⟩
! 0 = ≠ 2 bt.Std ⟨42⟩
! 0 = ≠ 1 bt.Mom ⟨42⟩
! 0 = ≠ 1 bt.ROC ⟨42⟩

pass +↩ 1 ⋄ •Out "  PASS  Edge: single element"

# ── Constant prices ────────────────────────────

cc ← 50‿50‿50‿50‿50
50‿50‿50‿50 Ae 2 bt.MA cc
50‿50‿50‿50‿50 Ae 2 bt.EMA cc
0‿0‿0‿0 Ae 2 bt.Std cc
0‿0‿0‿0 Ae 1 bt.Mom cc
0‿0‿0‿0 Ae 1 bt.ROC cc

pass +↩ 1 ⋄ •Out "  PASS  Edge: constant prices"

# ── Large price swings ─────────────────────────

big ← 0.01‿10000‿0.01‿10000‿0.01
eq_big ← bt.Equity bt.Ret big
! ∧´ eq_big > 0
! ∧´ ¬ ∞ = |eq_big

pass +↩ 1 ⋄ •Out "  PASS  Edge: large swings"

# ── Zero volume ────────────────────────────────

zv ← {dates⇐"a"‿"b"‿"c", close⇐100‿102‿101, high⇐105‿107‿104, low⇐95‿99‿98, open⇐98‿100‿102, vol⇐0‿0‿0}
0‿0‿0 Ae bt.OBV zv.close‿zv.vol
vwap_zv ← bt.VWAP zv
! 3 = ≠vwap_zv
! ∧´ ¬ ∞ = |vwap_zv

pass +↩ 1 ⋄ •Out "  PASS  Edge: zero volume"

# ── All-long / all-short / all-flat ────────────

er ← 0.02‿¯0.01‿0.03‿¯0.02
0.02‿¯0.01‿0.03‿¯0.02 Ae (4⥊1) bt.Run er
¯0.02‿0.01‿¯0.03‿0.02 Ae (4⥊¯1) bt.Run er
0‿0‿0‿0 Ae (4⥊0) bt.Run er

pass +↩ 1 ⋄ •Out "  PASS  Edge: all-long/short/flat"

# ── Single trade ───────────────────────────────

0‿0.05‿0 Ae (0‿1‿0) bt.Run 0.02‿0.05‿¯0.02
2 As bt.Trades 0‿1‿0

pass +↩ 1 ⋄ •Out "  PASS  Edge: single trade"

# ══ Property Tests ═════════════════════════════

# Random OHLCV generator: sorts 4 random values per bar to get valid low≤open≤close≤high
GenOHLCV ← {
  r ← 1 + (4×𝕩) •rand.Range 100
  s ← ⍉ ∧˘ (𝕩‿4) ⥊ r
  low←0⊏s ⋄ open←1⊏s ⋄ close←2⊏s ⋄ high←3⊏s
  vol ← 1 + 𝕩 •rand.Range 10000
  dates ← •Fmt¨ ↕𝕩
  {dates⇐dates, close⇐close, high⇐high, low⇐low, open⇐open, vol⇐vol}
}

# ── MA/EMA/WMA bounded ────────────────────────

{
  d ← GenOHLCV 50 ⋄ c ← d.close
  lo ← ⌊´c ⋄ hi ← ⌈´c
  ma ← 5 bt.MA c ⋄ ! ∧´ (ma≥lo) ∧ ma≤hi
  ema ← 5 bt.EMA c ⋄ ! ∧´ (ema≥lo) ∧ ema≤hi
  wma ← 5 bt.WMA c ⋄ ! ∧´ (wma≥lo) ∧ wma≤hi
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: MA/EMA/WMA bounded"

# ── RSI/Stoch/BB ranges ──────────────────────

{
  d ← GenOHLCV 50
  rsi ← 14 bt.RSI d.close
  ! ∧´ (rsi≥0) ∧ rsi≤100
  k‿kd ← 5 bt.Stoch d
  ! ∧´ (k≥0) ∧ k≤100
  u‿m‿l ← 10‿2 bt.BB d.close
  ! ∧´ u ≥ m
  ! ∧´ m ≥ l
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: RSI/Stoch/BB ranges"

# ── Metrics ranges ───────────────────────────

{
  d ← GenOHLCV 50
  r ← bt.Ret d.close
  dd ← bt.MaxDD r
  ! dd ≤ 0
  ! dd ≥ ¯1
  wr ← bt.WinRate r
  ! wr ≥ 0
  ! wr ≤ 1
  ((¯1⊑bt.Equity r) - 1) As bt.TotalRet r
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: MaxDD/WinRate/TotalRet"

# ── Cross/CrossDown boolean ───────────────────

{
  d ← GenOHLCV 50 ⋄ c ← d.close
  f‿s ← bt.Align (5 bt.MA c)‿(10 bt.MA c)
  ! ∧´ (f bt.Cross s) ∊ 0‿1
  ! ∧´ (f bt.CrossDown s) ∊ 0‿1
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: Cross/CrossDown boolean"

# ── Indicator output lengths ──────────────────

{
  d ← GenOHLCV 50 ⋄ c ← d.close ⋄ n ← ≠c
  ! (n-4) = ≠ 5 bt.MA c
  ! n = ≠ 5 bt.EMA c
  ! (n-4) = ≠ 5 bt.WMA c
  ! (n-4) = ≠ 5 bt.Std c
  ! (n-1) = ≠ 1 bt.Mom c
  ! (n-1) = ≠ 1 bt.ROC c
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: indicator lengths"

# ── Cost non-negative ─────────────────────────

{
  pos ← (50 •rand.Range 3) - 1
  costs ← 0.001 bt.Cost pos
  ! ∧´ costs ≥ 0
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: Cost non-negative"

# ── Equity positive ──────────────────────────

{
  d ← GenOHLCV 50
  r ← bt.Ret d.close
  eq ← bt.Equity r
  ! ∧´ eq > 0
  (1+⊑r) As ⊑eq
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: Equity positive"

# ── Mask zeroes prefix ───────────────────────

{
  n ← 1 + •rand.Range 9
  arr ← 1 + 20 •rand.Range 100
  m ← n bt.Mask arr
  ! ∧´ 0 = n↑m
  ! 20 = ≠m
  0
}¨ ↕10

pass +↩ 1 ⋄ •Out "  PASS  Prop: Mask zeroes prefix"

# ══ Options Pricing ═══════════════════════════

opt ← •Import "../engine/opt.bqn"

# ── Npdf ─────────────────────────────────────

# Npdf(0) ≈ 1/√(2π) ≈ 0.398942
(0.398942) As opt.Npdf 0
# Symmetry: Npdf(x) = Npdf(-x)
(opt.Npdf 1.5) As opt.Npdf ¯1.5
# Array compat
! 3 = ≠ opt.Npdf 0‿1‿2

pass +↩ 1 ⋄ •Out "  PASS  Npdf"

# ── Phi ──────────────────────────────────────

# Known values
0.5 As opt.Phi 0
(0.841345) As opt.Phi 1
(0.158655) As opt.Phi ¯1
(0.977250) As opt.Phi 2
# Symmetry: Phi(x) + Phi(-x) = 1
1 As (opt.Phi 1.5) + opt.Phi ¯1.5
# Array compat
! 4 = ≠ opt.Phi 0‿1‿¯1‿2

pass +↩ 1 ⋄ •Out "  PASS  Phi"

# ── BS ───────────────────────────────────────

# Hull ch13: S=42, K=40, T=0.5, r=0.1, σ=0.2
# Call ≈ 4.76, Put ≈ 0.81
bsc ← opt.BS 42‿40‿0.5‿0.1‿0.2‿1
! 0.01 > |bsc - 4.76
bsp ← opt.BS 42‿40‿0.5‿0.1‿0.2‿¯1
! 0.01 > |bsp - 0.81

# Monotonicity: call price decreases with higher strikes
c35 ← opt.BS 42‿35‿0.5‿0.1‿0.2‿1
c45 ← opt.BS 42‿45‿0.5‿0.1‿0.2‿1
c50 ← opt.BS 42‿50‿0.5‿0.1‿0.2‿1
! c35 > c45
! c45 > c50

pass +↩ 1 ⋄ •Out "  PASS  BS"

# ── Parity ───────────────────────────────────

# Put-call parity: call - put = S - Ke^(-rT)
par ← opt.Parity 42‿40‿0.5‿0.1
(bsc - bsp) As par

pass +↩ 1 ⋄ •Out "  PASS  Parity"

# ── Delta ────────────────────────────────────

dc ← opt.Delta 42‿40‿0.5‿0.1‿0.2‿1
dp ← opt.Delta 42‿40‿0.5‿0.1‿0.2‿¯1
# Call delta ∈ [0,1], put delta ∈ [-1,0]
! (dc≥0) ∧ dc≤1
! (dp≥¯1) ∧ dp≤0
# Call delta - put delta = 1
1 As dc - dp

pass +↩ 1 ⋄ •Out "  PASS  Delta"

# ── Gamma ────────────────────────────────────

gc ← opt.Gamma 42‿40‿0.5‿0.1‿0.2‿1
gp ← opt.Gamma 42‿40‿0.5‿0.1‿0.2‿¯1
# Same for call/put, positive
gc As gp
! gc > 0

pass +↩ 1 ⋄ •Out "  PASS  Gamma"

# ── Vega ─────────────────────────────────────

vc ← opt.Vega 42‿40‿0.5‿0.1‿0.2‿1
vp ← opt.Vega 42‿40‿0.5‿0.1‿0.2‿¯1
# Same for call/put, positive
vc As vp
! vc > 0

pass +↩ 1 ⋄ •Out "  PASS  Vega"

# ── Theta ────────────────────────────────────

tc ← opt.Theta 42‿40‿0.5‿0.1‿0.2‿1
tp ← opt.Theta 42‿40‿0.5‿0.1‿0.2‿¯1
# Time decay: theta is negative for long options
! tc < 0

pass +↩ 1 ⋄ •Out "  PASS  Theta"

# ── Rho ──────────────────────────────────────

rc ← opt.Rho 42‿40‿0.5‿0.1‿0.2‿1
rp ← opt.Rho 42‿40‿0.5‿0.1‿0.2‿¯1
# Call rho > 0, put rho < 0
! rc > 0
! rp < 0

pass +↩ 1 ⋄ •Out "  PASS  Rho"

# ── IV ───────────────────────────────────────

# Round-trip: price → IV → price across 6 scenarios
{
  s‿k‿tt‿r‿v‿ty ← 𝕩
  price ← opt.BS 𝕩
  iv ← opt.IV price‿s‿k‿tt‿r‿ty
  reprice ← opt.BS s‿k‿tt‿r‿iv‿ty
  ! 1e¯4 > |price - reprice
  0
}¨ ⟨
  42‿40‿0.5‿0.1‿0.2‿1     # ITM call, low vol
, 42‿45‿0.5‿0.1‿0.2‿¯1    # ITM put, low vol
, 42‿50‿0.5‿0.1‿0.4‿1     # OTM call, high vol
, 42‿35‿0.5‿0.1‿0.4‿¯1    # OTM put, high vol
, 42‿42‿0.5‿0.1‿0.3‿1     # ATM call
, 42‿42‿0.5‿0.1‿0.3‿¯1    # ATM put
⟩

pass +↩ 1 ⋄ •Out "  PASS  IV"

# ══ Monte Carlo ═══════════════════════════════

mc ← •Import "../engine/mc.bqn"

# ── Paths ──────────────────────────────────

paths ← mc.Paths 100‿100‿0.05‿0.2‿1‿252
! 100 = ⊑ ≢paths                  # 100 paths
! 252 = 1⊑ ≢paths                 # 252 steps
! ∧´ ∧˝ paths > 0                 # GBM paths always positive

pass +↩ 1 ⋄ •Out "  PASS  MC Paths"

# ── _Antithetic ──────────────────────────────

apaths ← mc.Paths mc._Antithetic 50‿100‿0.05‿0.2‿1‿252
! 100 = ⊑ ≢apaths                 # 2×50 = 100 paths
! 252 = 1⊑ ≢apaths
! ∧´ ∧˝ apaths > 0

pass +↩ 1 ⋄ •Out "  PASS  MC _Antithetic"

# ── Payoffs ──────────────────────────────────

# EuroCall: max(S_T - K, 0)
! 0 = 100 mc.EuroCall 90‿95‿80     # OTM: S_T=80 < K=100
! 10 = 100 mc.EuroCall 90‿95‿110   # ITM: 110-100 = 10

# EuroPut: max(K - S_T, 0)
! 20 = 100 mc.EuroPut 90‿95‿80     # ITM: 100-80 = 20
! 0 = 100 mc.EuroPut 90‿95‿110     # OTM: S_T=110 > K=100

# AsianCall: max(avg - K, 0)
! 0 = 100 mc.AsianCall 90‿110‿80   # avg=93.33 < 100
! (110 mc.AsianCall 100‿120‿130) > 0

# BarrierUpOut: knocked out if any price >= barrier
! 0 = 100‿120 mc.BarrierUpOut 90‿130‿110   # breached: 130 >= 120
! (100‿120 mc.BarrierUpOut 90‿110‿115) > 0  # not breached, ITM

pass +↩ 1 ⋄ •Out "  PASS  MC Payoffs"

# ── _Price convergence ───────────────────────

# MC European call should converge to BS within tolerance
{
  s0←100 ⋄ k←100 ⋄ r←0.05 ⋄ sig←0.2 ⋄ t←1
  bsPrice ← opt.BS s0‿k‿t‿r‿sig‿1
  paths ← mc.Paths 50000‿s0‿r‿sig‿t‿252
  mcPrice ← k⊸mc.EuroCall mc._Price paths‿r‿t
  ! 0.5 > |mcPrice - bsPrice
  0
}

pass +↩ 1 ⋄ •Out "  PASS  MC _Price convergence"

# ══ Risk ═════════════════════════════════════

risk ← •Import "../engine/risk.bqn"

# ── VolTarget ────────────────────────────────

# Result has same length as input signal
{
  ret ← 0.01‿0.02‿¯0.01‿0.005‿¯0.005‿0.015‿¯0.008‿0.003‿0.01‿¯0.02‿0.005‿0.008‿¯0.003‿0.012‿¯0.007‿0.001‿0.009‿¯0.004‿0.006‿0.002‿0.011‿¯0.003‿0.007‿0.002‿0.01
  sig ← (≠ret) ⥊ 1
  vt ← 0.20 risk.VolTarget sig‿ret
  ! (≠vt) = ≠sig
  # First n-1 bars are 0 (warmup, no vol estimate yet)
  ! ∧´ 0 = 20↑vt
  ! (20⊑vt) > 0
  # After warmup, values are finite and positive (sig=1, target>0)
  ! ∧´ (21↓vt) > 0
  ! ∧´ ¬ ∞ = |vt
  0
}

pass +↩ 1 ⋄ •Out "  PASS  VolTarget"

# ── KellyFrac: zero-mean → 0, negative-mean → negative ──

{
  ret ← ⟨0,0,0,0,0⟩
  k ← 0.5 risk.KellyFrac ret
  ! 0 = k

  ret2 ← ¯0.01‿¯0.01‿¯0.01‿¯0.01‿¯0.01
  k2 ← 0.5 risk.KellyFrac ret2
  ! k2 < 0
  0
}

pass +↩ 1 ⋄ •Out "  PASS  KellyFrac (zero/negative)"

# ── KellyFrac: clipped to [¯1,1] ────────────

{
  # Extreme positive: huge mean/var ratio → clipped to 1
  ret ← 0.5‿0.5‿0.5‿0.5‿0.5001
  k ← 1 risk.KellyFrac ret
  1 As k

  # Extreme negative: clipped to ¯1
  ret2 ← ¯0.5‿¯0.5‿¯0.5‿¯0.5‿¯0.5001
  k2 ← 1 risk.KellyFrac ret2
  ¯1 As k2
  0
}

pass +↩ 1 ⋄ •Out "  PASS  KellyFrac (clipping)"

# ── KellySeries: length matches input ────────

{
  ret ← 0.01‿0.02‿¯0.01‿0.005‿¯0.005‿0.015‿¯0.008‿0.003‿0.01‿¯0.02
  sig ← (≠ret) ⥊ 1
  ks ← 5‿0.5 risk.KellySeries sig‿ret
  ! (≠ks) = ≠ret
  # First n bars are zero (not enough data)
  ! ∧´ 0 = 5↑ks
  0
}

pass +↩ 1 ⋄ •Out "  PASS  KellySeries"

# ── MaxPos: magnitudes ≤ cap, signs preserved ─

{
  pos ← ⟨¯2,¯0.5,0,0.5,2⟩
  capped ← 1 risk.MaxPos pos
  ! ∧´ (|capped) ≤ 1
  ! 0 = 2⊑capped
  ! (0⊑capped) < 0
  ! (3⊑capped) > 0
  # Small positions unchanged
  (¯0.5) As 1⊑capped
  (0.5) As 3⊑capped
  0
}

pass +↩ 1 ⋄ •Out "  PASS  MaxPos"

# ── CircuitBreaker: fires and persists ───────

{
  # Construct returns where bars 1-3 have cumulative < ¯0.10
  ret ← 0.01‿¯0.05‿¯0.04‿¯0.03‿0.02‿0.01‿0.03‿¯0.01‿0.02‿0.01
  pos ← (≠ret) ⥊ 1
  cb ← 3‿(¯0.10) risk.CircuitBreaker pos‿ret
  ! (≠cb) = ≠ret
  # Should have zeros where breaker fires
  ! ∨´ cb = 0
  # Unaffected bars should be 1
  ! ∨´ cb = 1
  # First bar never fires (not enough history)
  ! 1 = ⊑cb
  0
}

pass +↩ 1 ⋄ •Out "  PASS  CircuitBreaker"

# ── DDControl: zeros during drawdown, resumes ─

{
  # Sharp loss then recovery
  ret ← 0.01‿¯0.08‿¯0.03‿0.02‿0.05‿0.06‿0.04‿0.03‿0.02‿0.01
  pos ← (≠ret) ⥊ 1
  ddc ← ¯0.05 risk.DDControl pos‿ret
  ! (≠ddc) = ≠ret
  # First bar: no drawdown → active
  ! 1 = ⊑ddc
  # After big loss: should be zeroed
  ! 0 = 1⊑ddc
  # Eventually recovers (last bars should be 1 after recovery)
  ! 1 = ¯1⊑ddc
  0
}

pass +↩ 1 ⋄ •Out "  PASS  DDControl"

# ══ Overfitting Metrics ═══════════════════════

ovf ← •Import "../engine/ovf.bqn"

# ── PhiInv ─────────────────────────────────

{
  ps ← 0.05‿0.1‿0.3‿0.5‿0.7‿0.9‿0.95
  { p←𝕩 ⋄ ! 1e¯5 > |p - opt.Phi opt.PhiInv p }¨ ps
  0
}

pass +↩ 1 ⋄ •Out "  PASS  PhiInv round-trip"

# ── DSR ────────────────────────────────────

# High SR, n=1, long T → near 1
{
  d ← 1 ovf.DSR 3.0‿0.0‿0.0‿1000
  ! d > 0.99
  0
}

# Low SR, many trials → small
{
  d ← 1000 ovf.DSR 0.1‿0.0‿0.0‿252
  ! d < 0.1
  0
}

pass +↩ 1 ⋄ •Out "  PASS  DSR"

# ── PSR ────────────────────────────────────

# SR well above bench with long T → high
{
  p ← 0 ovf.PSR 0.3‿50‿1‿0.0‿0.0
  ! p > 0.9
  0
}

pass +↩ 1 ⋄ •Out "  PASS  PSR"

# ── HHI ────────────────────────────────────

{
  # Single positive bar → HHI = 1
  1 As ovf.HHI ⟨0.01, ¯0.01, ¯0.01, ¯0.01⟩

  # Three equal → HHI = 1/3
  (1÷3) As ovf.HHI ⟨0.01, 0.01, 0.01⟩
  0
}

pass +↩ 1 ⋄ •Out "  PASS  HHI"

# ── TrialCorrect ──────────────────────────

{
  pvals ← ⟨0.001, 0.01, 0.05, 0.1, 0.3⟩
  rej ← 5‿0.05 ovf.TrialCorrect pvals
  ! 1 = 0⊑rej    # p=0.001 rejected
  ! 1 = 1⊑rej    # p=0.01 rejected
  ! 0 = 2⊑rej    # p=0.05 not rejected
  ! 0 = 4⊑rej    # p=0.3 not rejected
  0
}

pass +↩ 1 ⋄ •Out "  PASS  TrialCorrect"

# ── MinTRL ─────────────────────────────────

{
  # Known: MinTRL(n=1, SR=1.0, sk=0, ku=0) ≈ 3.029
  m ← 1‿1.0 ovf.MinTRL 0.0‿0.0
  ! 0.1 > |m - 3.029
  0
}

pass +↩ 1 ⋄ •Out "  PASS  MinTRL"

# ══ Exec ═══════════════════════════════════════

exec ← •Import "../engine/exec.bqn"

# ── Slippage: zero change → zero ─────────────

{
  pos ← 1‿1‿1‿1‿1
  vol ← 1e6‿1e6‿1e6‿1e6‿1e6
  sl ← 0.1‿0.1 exec.Slippage pos‿vol
  ! 0 < ⊑sl         # first bar: change from 0 to 1
  ! ∧´ 0 = 1↓sl     # no further changes
  0
}

pass +↩ 1 ⋄ •Out "  PASS  Slippage"

# ── FillLimit: clips to cap, preserves sign ──

{
  pos ← ¯2‿¯0.5‿0‿0.5‿2
  vol ← 1e4‿1e4‿1e4‿1e4‿1e4
  fl ← 0.0001 exec.FillLimit pos‿vol  # cap = 1
  ! ∧´ (|fl) ≤ 1
  ! 0 = 2⊑fl
  ! (0⊑fl) < 0
  0
}

pass +↩ 1 ⋄ •Out "  PASS  FillLimit"

# ── RunOHLC: length = ≠pos - 1 ──────────────

{
  d ← GenOHLCV 20
  pos ← (≠d.close) ⥊ 1
  r ← pos bt.RunOHLC d
  ! (≠r) = (≠pos)-1
  0
}

pass +↩ 1 ⋄ •Out "  PASS  RunOHLC"

# ── StopLoss fires correctly ─────────────────

{
  open_v ← 100‿100‿100‿100‿100
  high_v ← 101‿101‿101‿101‿101
  low_v  ← 99‿99‿90‿99‿99
  close_v← 100‿100‿100‿100‿100
  vol_v  ← 1e6‿1e6‿1e6‿1e6‿1e6
  d ← {dates⇐•Fmt¨↕5, open⇐open_v, high⇐high_v, low⇐low_v, close⇐close_v, vol⇐vol_v}
  pos ← 0‿1‿1‿1‿1
  r ← 0.02 exec.StopLoss pos‿d
  # bar 1: enter long, entry_px = open[1]=100, stop=98
  # bar 2: low[2]=90 < 98 → trigger
  ! 1 = 2⊑r.triggered
  ! 0 = 2⊑r.pos
  # stop ret = (98-100)/100 = -0.02
  (¯0.02) As 2⊑r.ret
  0
}

pass +↩ 1 ⋄ •Out "  PASS  StopLoss"

# ── StopTake: stop wins on same-bar conflict ─

{
  open_v ← 100‿100
  high_v ← 100‿115
  low_v  ← 100‿85
  close_v← 100‿100
  vol_v  ← 1e6‿1e6
  d ← {dates⇐•Fmt¨↕2, open⇐open_v, high⇐high_v, low⇐low_v, close⇐close_v, vol⇐vol_v}
  pos ← 1‿1
  r ← 0.05‿0.10 exec.StopTake pos‿d
  # bar 0: entry at 100, stop=95, tp=110
  # bar 1: low=85<95 (stop) and high=115>110 (tp), stop wins
  ! 0 < 1⊑r.triggered
  # fill at stop=95, return = (95-100)/100 = -0.05
  (¯0.05) As 1⊑r.ret
  0
}

pass +↩ 1 ⋄ •Out "  PASS  StopTake"

# ── Slippage → 0 for huge volume ────────────

{
  pos ← ⟨0, 1, 1, 0, 1⟩
  vol ← (≠pos) ⥊ 1e15
  sl ← 0.1‿0.1 exec.Slippage pos‿vol
  ! ∧´ sl < 1e¯5
  0
}

pass +↩ 1 ⋄ •Out "  PASS  Slippage (huge volume)"

# ══ Universe ═════════════════════════════════

uni ← •Import "../engine/uni.bqn"

# Helper: synthetic OHLCV namespace of length n, starting at base
MkNs ← {
  n‿base ← 𝕩
  prices ← base+↕n
  {dates⇐•Fmt¨↕n, close⇐prices, high⇐prices+1, low⇐prices-1, open⇐prices+0.5, vol⇐1000⥊˜n}
}

# ── Universe shape ─────────────────────────────

{
  ns ← MkNs¨ ⟨10‿100, 10‿200, 10‿300⟩
  u ← uni.Universe ns
  ! 10 = u.n_bars
  ! 3 = u.n_assets
  ! (10‿3) ≡ ≢u.close
  ! (10‿3) ≡ ≢u.high
  ! (10‿3) ≡ ≢u.low
  ! (10‿3) ≡ ≢u.open
  ! (10‿3) ≡ ≢u.vol
  0
}

pass +↩ 1 ⋄ •Out "  PASS  Universe shape"

# ── XRank ──────────────────────────────────────

{
  mat ← 3‿4⥊12‿3‿7‿1‿ 5‿9‿2‿8‿ 4‿11‿6‿10
  ranked ← uni.XRank mat
  # Each row is a valid permutation of 0..3
  ! ∧´ {(∧𝕩)≡↕4}˘ ranked
  # Row 0: 1 is smallest (rank 0), 3 is 2nd (rank 1), 7 is 3rd (rank 2), 12 is largest (rank 3)
  3‿1‿2‿0 Ae 0⊏ranked
  0
}

pass +↩ 1 ⋄ •Out "  PASS  XRank"

# ── XScore ─────────────────────────────────────

{
  mat ← 3‿3⥊1‿2‿3‿ 4‿5‿6‿ 7‿8‿9
  scored ← uni.XScore mat
  # Row means should be 0
  ! ∧´ 1e¯10 > |+˝˘scored
  # Shape preserved
  ! (3‿3) ≡ ≢scored
  0
}

pass +↩ 1 ⋄ •Out "  PASS  XScore"

# ── XWeight ────────────────────────────────────

{
  mat ← 3‿3⥊1‿¯2‿3‿ 4‿5‿¯6‿ 7‿8‿9
  w ← uni.XWeight mat
  # Abs row sums = 1
  ! ∧´ 1e¯10 > |(+˝˘|w)-1
  # Shape preserved
  ! (3‿3) ≡ ≢w
  0
}

pass +↩ 1 ⋄ •Out "  PASS  XWeight"

# ── LongOnly ──────────────────────────────────

{
  mat ← 3‿3⥊1‿¯2‿3‿ ¯4‿5‿¯6‿ 0‿0‿0
  lo ← uni.LongOnly mat
  # All non-negative
  ! ∧´ ∧˝ lo≥0
  # Positive rows sum to 1, zero row sums to 0
  sums ← +˝˘lo
  ! 1e¯10 > |1-0⊑sums
  ! 1e¯10 > |1-1⊑sums
  ! 0 = 2⊑sums
  0
}

pass +↩ 1 ⋄ •Out "  PASS  LongOnly"

# ── TopN ───────────────────────────────────────

{
  scores ← 3‿4⥊12‿3‿7‿1‿ 5‿9‿2‿8‿ 4‿11‿6‿10
  tn ← 1 uni.TopN scores
  # Each row: exactly 1 positive (1/n) and 1 negative (-1/n)
  ! ∧´ {1 = +´𝕩>0}˘ tn
  ! ∧´ {1 = +´𝕩<0}˘ tn
  # Row sums = 0 (long-short balanced)
  ! ∧´ 1e¯10 > |+˝˘tn
  # Magnitudes = 1/n = 1
  ! ∧´ ∧˝ (tn=1)∨(tn=¯1)∨(tn=0)
  0
}

pass +↩ 1 ⋄ •Out "  PASS  TopN"

# ── _UniRun ───────────────────────────────────

{
  ns ← MkNs¨ ⟨10‿100, 10‿200, 10‿300⟩
  u ← uni.Universe ns
  AlwaysLong ← {(≠𝕩)⥊1}
  pos ← AlwaysLong uni._UniRun u
  ! (10‿3) ≡ ≢pos
  ! ∧´ ∧˝ pos=1
  0
}

pass +↩ 1 ⋄ •Out "  PASS  _UniRun"

# ── AlignDates ─────────────────────────────────

{
  a ← MkNs 10‿100
  b ← MkNs 7‿200
  c ← MkNs 15‿300
  aligned ← bt.AlignDates ⟨a, b, c⟩
  ! 3 = ≠aligned
  # All trimmed to shortest (7)
  ! 7 = ≠(0⊑aligned).close
  ! 7 = ≠(1⊑aligned).close
  ! 7 = ≠(2⊑aligned).close
  # Tail-aligned: last element of a.close should be last element of aligned[0].close
  ! (¯1⊑a.close) = ¯1⊑(0⊑aligned).close
  0
}

pass +↩ 1 ⋄ •Out "  PASS  AlignDates"

# ══ Summary ══════════════════════════════════

•Out ""
•Out "All " ∾ (•Fmt pass) ∾ " tests passed"
