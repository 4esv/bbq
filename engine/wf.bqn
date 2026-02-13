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

# prices Strategy _WF config → results
# Strategy: params 𝔽 prices → positions
# config: train‿test‿grid‿cost_rate‿Metric
_WF ⇐ {
  Strat ← 𝔽
  tr‿te‿grid‿cr‿Metric ← 𝕩
  prices ← 𝕨

  folds ← tr‿te Windows prices
  ret_all ← bt.Ret prices
  fold_results ← ⟨⟩

  {
    train_p‿test_p ← 𝕩
    train_ret ← bt.Ret train_p
    test_ret ← bt.Ret test_p

    # Grid search on train
    scores ← {
      pos ← (-≠train_ret)↑ 𝕩 Strat train_p
      sr ← pos bt.Run train_ret
      cost ← cr bt.Cost pos
      Metric sr-cost
    }¨ grid

    best_idx ← ⊑⍒scores
    best_params ← best_idx⊑grid
    train_metric ← best_idx⊑scores

    # Evaluate best params on test
    test_pos ← (-≠test_ret)↑ best_params Strat test_p
    test_sr ← test_pos bt.Run test_ret
    test_cost ← cr bt.Cost test_pos
    test_oos ← test_sr - test_cost
    test_metric ← Metric test_oos

    fold_results ∾↩ <{params⇐best_params, train_score⇐train_metric, test_score⇐test_metric, oos_ret⇐test_oos}
  }¨ folds

  oos_ret ← ∾ {𝕩.oos_ret}¨ fold_results
  oos_eq ← bt.Equity oos_ret
  summary ← {sharpe⇐bt.Sharpe oos_ret, maxdd⇐bt.MaxDD oos_ret, total_ret⇐bt.TotalRet oos_ret, calmar⇐bt.Calmar oos_ret}

  {folds⇐fold_results, oos_ret⇐oos_ret, oos_eq⇐oos_eq, summary⇐summary}
}
