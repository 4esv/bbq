# bbq — BQN Based Quant
# engine/bt.bqn — backtesting engine

core ← •Import "core.bqn"

# Re-export core (strategies only import bt.bqn)
⟨eps, tdy, Split, Pstd, Wilder,
 Load, Validate, Align, LoadMany, AlignDates,
 MA, EMA, WMA, Std, RSI, MACD, ATR, Mom, ROC, Stoch, BB, OBV, VWAP, AD, RMax, RMin,
 Cross, CrossDown, Mask, Fill, Thresh, ThreshDown, Hold⟩ ⇐ core

# ── Simulation ───────────────────────────────

# Step _Sim init‿obs → positions
# Step: state 𝔽 observation → new_state (first element = position)
_Sim ⇐ {
  Fn ← 𝔽
  init‿obs ← 𝕩
  state ← init
  {
    state ↩ state Fn 𝕩
    ⊑state
  }¨ obs
}

# ── Backtest Core ────────────────────────────

# Ret prices → simple returns (1 shorter than input)
Ret ⇐ 1⊸↓∘-⟜» ÷ 1⊸↓∘»

# LogRet prices → log returns (1 shorter than input)
LogRet ⇐ 1⊸↓ ⋆⁼∘÷⟜»

# pos Run ret → strategy returns
Run ⇐ ×

# pos RunOHLC data → strategy returns using open-to-open execution
# Assumes positions decided at end of bar i, fills at open of bar i+1
RunOHLC ⇐ {
  pos ← 𝕨 ⋄ d ← 𝕩
  opret ← ((1↓d.open) - ¯1↓d.open) ÷ ¯1↓d.open
  (¯1↓pos) × opret
}

# rate Cost pos → transaction cost array
Cost ⇐ ×⟜(|∘-⟜»)

# Equity ret → equity curve starting at 1
Equity ⇐ ×`∘(1⊸+)

# ── Metrics ──────────────────────────────────

# Internal: drawdown series from returns
DdSeries ← {
  eq ← ×`1+𝕩
  mx ← ⌈`eq
  (eq-mx)÷mx
}

# Annualized Sharpe ratio (Rf=0, sample std N-1)
Sharpe ⇐ {
  n ← ≠𝕩
  m ← (+´𝕩)÷n
  s ← √(+´(𝕩-m)⋆2)÷(n-1)⌈1
  (√tdy) × m ÷ s⌈eps
}

# Sortino ratio (downside deviation, population semi-variance N)
Sortino ⇐ {
  m ← (+´÷≠)𝕩
  dd ← 0⌊𝕩
  ds ← √(+´dd⋆2)÷≠𝕩
  (√tdy) × m ÷ ds⌈eps
}

# Maximum drawdown (negative number)
MaxDD ⇐ ⌊´∘DdSeries

# Longest drawdown duration (bars)
MaxDDDur ⇐ ⌈´∘(0⊸({𝕩×1+𝕨})`)∘(<⟜0)∘DdSeries

# Total cumulative return
TotalRet ⇐ -⟜1 ¯1⊸⊑∘Equity

# Compound annual growth rate (252 days/yr)
# NOTE: clamp terminal equity to eps — negative equity makes fractional exponent undefined
CAGR ⇐ -⟜1 eps⊸⌈∘(¯1⊸⊑)∘Equity ⋆ tdy⊸÷∘≠

# Annualized volatility
AnnVol ⇐ (√tdy)⊸×∘Pstd

# Calmar ratio (CAGR / |MaxDD|)
Calmar ⇐ CAGR ÷ eps⊸⌈∘|∘MaxDD

# Win rate (positive returns / non-zero returns, excludes flat days)
WinRate ⇐ +´∘>⟜0 ÷ 1⊸⌈∘+´∘≠⟜0

# Profit factor (gross profit / gross loss)
ProfitFactor ⇐ +´∘(>⟜0⊸×) ÷ eps⊸⌈∘|∘(+´)∘(<⟜0⊸×)

# Average winning return
AvgWin ⇐ (+´÷1⊸⌈∘≠)∘(>⟜0⊸/)

# Average losing return (negative number)
AvgLoss ⇐ (+´÷1⊸⌈∘≠)∘(<⟜0⊸/)

# Expectancy (mean return per active bar)
Expectancy ⇐ (+´÷1⊸⌈∘≠)∘(≠⟜0⊸/)

# Trades — count position changes (takes positions)
Trades ⇐ +´∘(»⊸≠)

# Time in market (takes positions)
TimeIn ⇐ +´∘≠⟜0 ÷ ≠

# Exposure — alias for TimeIn
Exposure ⇐ TimeIn

# Skewness (third standardized moment)
Skew ⇐ {
  m ← (+´÷≠)𝕩
  s ← Pstd 𝕩
  (+´((𝕩-m)÷s⌈eps)⋆3) ÷ ≠𝕩
}

# Excess kurtosis (fourth standardized moment minus 3)
Kurt ⇐ {
  m ← (+´÷≠)𝕩
  s ← Pstd 𝕩
  ¯3 + (+´((𝕩-m)÷s⌈eps)⋆4) ÷ ≠𝕩
}

# ── Portfolio ───────────────────────────────

# weights PortRun assets — weighted portfolio returns
# assets: list of pos‿ret pairs, weights: per-asset allocation (must sum to 1)
PortRun ⇐ {
  ! 1e¯6 > |1-+´𝕨
  strats ← {p‿r ← 𝕩 ⋄ p×r}¨ 𝕩
  +´ 𝕨 × strats
}

# rates PortCost positions — combined transaction costs
# positions: list of pos arrays, rates: per-asset cost rate
PortCost ⇐ {+´ 𝕨 {𝕨 × |-⟜»𝕩}¨ 𝕩}

# PortEquity — alias for Equity (clarity for portfolio context)
PortEquity ⇐ Equity

# name‿cpos PortReport assets‿cret
# assets: list of ticker‿strat_ret pairs, cret: combined portfolio returns
PortReport ⇐ {
  name‿cpos ← 𝕨
  assets‿cret ← 𝕩

  •Out "═══ " ∾ name ∾ " ═══"

  # Per-asset one-liners
  {
    ticker‿sr ← 𝕩
    •Out "  " ∾ (8 Pad ticker) ∾ "Sharpe: " ∾ (Rd Sharpe sr) ∾ "  Total: " ∾ (Pct TotalRet sr) ∾ "  MaxDD: " ∾ (Pct MaxDD sr)
  }¨ assets

  •Out ""
  name‿cpos Report cret‿cret
}

# ── Reporting helpers ────────────────────────

# Format percentage with sign
Pct ⇐ {
  v ← ⌊0.5+1000×|𝕩
  d ← •Fmt 10|v
  w ← •Fmt ⌊v÷10
  ((𝕩<0)/"-") ∾ ((𝕩>0)/"+") ∾ w ∾ "." ∾ d ∾ "%"
}

# Round to 2 decimal places with sign
Rd ⇐ {
  v ← ⌊0.5+100×|𝕩
  d ← •Fmt 100|v
  d ↩ ((2>≠d)/"0") ∾ d
  w ← •Fmt ⌊v÷100
  ((𝕩<0)/"-") ∾ w ∾ "." ∾ d
}

# Right-pad string to width
Pad ⇐ (⊣⌈≠∘⊢)⊸↑

# ── Reporting ────────────────────────────────

# name‿pos Report strat_ret‿bh_ret — print formatted summary
Report ⇐ {
  name‿pos ← 𝕨
  strat‿bh ← 𝕩

  # Format a metric line: label, strategy value, benchmark value
  Line ← {l‿sv‿bv:
    (16 Pad l) ∾ (10 Pad sv) ∾ "  (B&H: " ∾ bv ∾ ")"
  }

  # Format a solo metric line (no benchmark)
  Solo ← {l‿sv:
    (16 Pad l) ∾ sv
  }

  paired ← ⟨
    "Total:"‿(Pct TotalRet strat)‿(Pct TotalRet bh)
    "CAGR:"‿(Pct CAGR strat)‿(Pct CAGR bh)
    "Sharpe:"‿(Rd Sharpe strat)‿(Rd Sharpe bh)
    "Sortino:"‿(Rd Sortino strat)‿(Rd Sortino bh)
    "MaxDD:"‿(Pct MaxDD strat)‿(Pct MaxDD bh)
    "MaxDD Dur:"‿(•Fmt MaxDDDur strat)‿(•Fmt MaxDDDur bh)
    "Calmar:"‿(Rd Calmar strat)‿(Rd Calmar bh)
    "Volatility:"‿(Pct AnnVol strat)‿(Pct AnnVol bh)
  ⟩

  singles ← ⟨
    "Win Rate:"‿(Pct WinRate strat)
    "Profit Factor:"‿(Rd ProfitFactor strat)
    "Expectancy:"‿(Pct Expectancy strat)
    "Trades:"‿(•Fmt Trades pos)
    "Time In:"‿(Pct TimeIn pos)
    "Skew:"‿(Rd Skew strat)
    "Kurtosis:"‿(Rd Kurt strat)
  ⟩

  •Out "═══ " ∾ name ∾ " ═══"
  •Out¨ Line¨ paired
  •Out¨ Solo¨ singles

  # Verdict
  sharpe ← Sharpe strat
  maxdd ← MaxDD strat
  verdict ← {
    maxdd<¯0.40 ? "Max drawdown > 40%, reconsider";
    sharpe≥1.0  ? "Worth paper trading";
    sharpe≥0.5  ? "Has potential, needs work";
    "Not worth pursuing"
  }
  •Out "───"
  •Out "Verdict: " ∾ verdict
}
