# bbq — BQN Based Quant
# engine/wf.bqn — walk-forward validation

bt ← •Import "bt.bqn"

# Re-export bt (which includes core)
⟨eps, tdy, Split, Pstd, Wilder,
 Load, Validate, Align, LoadMany, AlignDates,
 MA, EMA, WMA, Std, RSI, MACD, ATR, Mom, ROC, Stoch, BB, OBV, VWAP, AD, RMax, RMin,
 Cross, CrossDown, Mask, Fill, Thresh, ThreshDown, Hold,
 _Sim, Ret, LogRet, Run, RunOHLC, Cost, Equity,
 Sharpe, Sortino, MaxDD, MaxDDDur, TotalRet, CAGR, AnnVol, Calmar,
 WinRate, ProfitFactor, AvgWin, AvgLoss, Expectancy, Trades, TimeIn, Exposure, Skew, Kurt,
 Report, PortRun, PortCost, PortEquity, PortReport,
 Pct, Rd, Pad⟩ ⇐ bt

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
  fold_results ← ⟨⟩

  {
    train_p‿test_p ← 𝕩
    train_ret ← bt.Ret train_p
    test_ret ← bt.Ret test_p

    # Grid search on train
    # NOTE: tail-take aligns warmup-padded pos with ret (zero warmup at front, not end)
    scores ← {
      pos ← (-≠train_ret)↑ 𝕩 Strat train_p
      sr ← pos bt.Run train_ret
      cost ← cr bt.Cost pos
      Metric sr-cost
    }¨ grid

    # NOTE: ⍒ breaks ties by first index (lowest param combo)
    best_idx ← ⊑⍒scores
    best_params ← best_idx⊑grid
    train_metric ← best_idx⊑scores

    # Evaluate best params on test
    test_pos ← (-≠test_ret)↑ best_params Strat test_p
    test_sr ← test_pos bt.Run test_ret
    test_cost ← cr bt.Cost test_pos
    test_oos ← test_sr - test_cost
    test_metric ← Metric test_oos

    fold_results ∾↩ <{params⇐best_params, train_score⇐train_metric, test_score⇐test_metric, oos_ret⇐test_oos, all_scores⇐scores}
  }¨ folds

  # NOTE: OOS folds concatenated directly — assumes no temporal gap between folds
  oos_ret ← ∾ {𝕩.oos_ret}¨ fold_results
  oos_eq ← bt.Equity oos_ret
  summary ← {sharpe⇐bt.Sharpe oos_ret, maxdd⇐bt.MaxDD oos_ret, total_ret⇐bt.TotalRet oos_ret, calmar⇐bt.Calmar oos_ret}

  {folds⇐fold_results, oos_ret⇐oos_ret, oos_eq⇐oos_eq, summary⇐summary}
}

# name‿train‿test‿grid_size WFReport results — print walk-forward summary
WFReport ⇐ {
  name‿tr‿te‿gs ← 𝕨
  r ← 𝕩

  •Out "═══ Walk-Forward: " ∾ name ∾ " ═══"
  •Out "Folds:        " ∾ •Fmt ≠r.folds
  •Out "Train window: " ∾ (•Fmt tr) ∾ " bars"
  •Out "Test window:  " ∾ (•Fmt te) ∾ " bars"
  •Out "Grid size:    " ∾ (•Fmt gs) ∾ " combinations"
  •Out ""

  •Out "Fold  Best Params       Train     Test"
  •Out "────  ───────────       ─────     ────"
  {
    f ← 𝕩⊑r.folds
    pstr ← 1↓ ∾ "‿"⊸∾¨ •Fmt¨ f.params
    •Out (6 Pad •Fmt 𝕩) ∾ (18 Pad pstr) ∾ (10 Pad Rd f.train_score) ∾ Rd f.test_score
  }¨ ↕≠r.folds

  •Out ""
  •Out "─── Out-of-Sample Aggregate ───"
  •Out "Sharpe:         " ∾ Rd r.summary.sharpe
  •Out "Total:          " ∾ Pct r.summary.total_ret
  •Out "MaxDD:          " ∾ Pct r.summary.maxdd
  •Out "Calmar:         " ∾ Rd r.summary.calmar

  # Param stability: count most common param tuple
  all_params ← {𝕩.params}¨ r.folds
  counts ← {p ← 𝕩 ⋄ +´{p≡𝕩}¨ all_params}¨ all_params
  best_count ← ⌈´counts
  best_param ← (⊑⍒counts)⊑all_params
  pstr ← 1↓ ∾ "‿"⊸∾¨ •Fmt¨ best_param
  •Out "Param Stability: " ∾ (•Fmt best_count) ∾ "/" ∾ (•Fmt ≠r.folds) ∾ " folds chose " ∾ pstr

  # Verdict
  sharpe ← r.summary.sharpe
  maxdd ← r.summary.maxdd
  verdict ← {
    maxdd<¯0.40 ? "Max drawdown > 40%, reconsider";
    sharpe≥1.0  ? "Worth paper trading";
    sharpe≥0.5  ? "Has potential, needs work";
    "Not worth pursuing"
  }
  •Out "───"
  •Out "Verdict: " ∾ verdict
}
