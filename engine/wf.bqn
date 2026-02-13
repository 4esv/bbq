# bbq — BQN Based Quant
# engine/wf.bqn — walk-forward validation

bt ← •Import "bt.bqn"

# Re-export bt (which includes core)
⟨Load, Validate, Align,
 MA, EMA, WMA, Std, RSI, MACD, ATR, Mom, ROC, Stoch, BB, OBV, VWAP, AD, RMax, RMin,
 Cross, CrossDown, Mask, Fill, Thresh, ThreshDown, Hold,
 _Sim, Ret, LogRet, Run, Cost, Equity,
 Sharpe, Sortino, MaxDD, MaxDDDur, TotalRet, CAGR, AnnVol, Calmar,
 WinRate, ProfitFactor, AvgWin, AvgLoss, Expectancy, Trades, TimeIn, Exposure, Skew, Kurt,
 Report, PortRun, PortCost, PortEquity, PortReport⟩ ⇐ bt

# ── Walk-Forward ───────────────────────────

# train‿test Windows prices — rolling train/test window splits
Windows ⇐ {
  tr‿te ← 𝕨 ⋄ p ← 𝕩
  nf ← 1+⌊((≠p)-tr+te)÷te
  ! nf>0
  {s ← 𝕩×te ⋄ ⟨tr↑s↓p, te↑(s+tr)↓p⟩}¨ ↕nf
}

# Grid ranges — cartesian product of parameter ranges
Grid ⇐ {
  ! 0<≠𝕩
  1=≠𝕩 ? <¨⊑𝕩;
  rest ← 𝕊 1↓𝕩
  ∾ {𝕩⊸∾¨ rest}¨ ⊑𝕩
}
