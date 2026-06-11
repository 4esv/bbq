# CLAUDE.md

Guidance for working in the **bbq** (BQN Based Quant) codebase. Read this
before changing engine code or docs.

## What this is

A quantitative-finance toolkit written in [BQN](https://mlochbaum.github.io/BQN/),
run with [CBQN](https://github.com/dzaima/CBQN). Eleven engine modules cover
indicators, signal composition, backtesting, walk-forward validation, options
pricing, Monte Carlo simulation, rolling analytics, risk controls, execution
realism, anti-overfitting diagnostics, and multi-asset universe management.

There are no third-party dependencies. The only runtime requirement is the
`bqn` interpreter on `PATH`.

## Commands

```bash
make test            # run the full suite (tests/verify.bqn) — must stay green
make run name=X      # run examples/X.bqn
make new name=X      # scaffold examples/X.bqn from the template
make clean           # remove data/*.csv
```

Run a single file directly: `bqn examples/ma_cross.bqn`. Examples expect a CSV
at `data/spy.csv` (`Date,Open,High,Low,Close,Volume`, 3 header lines — yfinance
layout); `data/` is gitignored.

## Architecture

```
core.bqn ← bt.bqn ← wf.bqn        # the import spine; each re-exports the layer below
```

- **Strategies import `bt.bqn`**; **walk-forward scripts import `wf.bqn`**.
  Both re-export everything beneath them, so a strategy never needs `core.bqn`
  directly.
- **Leaf modules** — `cmp`, `opt`, `mc`, `roll`, `risk`, `ovf`, `exec`, `uni`
  — import `bt.bqn` or `core.bqn` and are imported à la carte by scripts.

When you add a public name to `core`/`bt`, add it to the re-export `⟨…⟩ ⇐`
blocks at the top of `bt.bqn` and `wf.bqn`, or it won't be visible downstream.

## Design model

A backtest is a fold. Indicators are array operations. Positions are arrays of
`1` (long), `0` (flat), `¯1` (short); the engine multiplies positions by
returns. Two phases:

1. **Indicators** — pure, vectorized array ops (SIMD-friendly).
2. **Execution** — compound-state scans, inherently sequential.

`_Sim` threads bar-by-bar state for strategies that need it (trailing stops,
regime filters) and emits a position array that feeds the same `Run` pipeline.

## Conventions

- **Comment tags**: `# TODO:`, `# NOTE:`, `# BUG:`, `# FIX:`, `# HACK:`,
  `# PERF:`, `# WARNING:`.
- **Section dividers**: `# ── Name ─────────────────────────────`.
- **Assignment**: `←` for first definition, `↩` for reassignment.
- **Division guards**: clamp the denominator with `eps⌈x` (max), never `eps+x`.
  The canonical `eps ← 1e¯10` and `tdy ← 252` live in `core.bqn`.
- **No lookahead**: every backtest position must be lagged one bar before it
  multiplies returns (`(¯1↓pos)‿(1↓ret)`). Expanding-window stats (`ENorm`)
  are preferred over full-array ones (`Norm`) for anything that goes live.

## Idiomatic style

- **Prefer trains/forks** for pure, point-free functions — e.g.
  `Cross ⇐ ≥ ∧ <○»`, `Cost ⇐ ×⟜(|∘-⟜»)`. Reach for an explicit `{…}` block
  only when it genuinely reads better.
- **Keep explicit blocks for stateful functions** — `_Sim`, `Hold`, `Fill`,
  the stop/take-profit family, `CircuitBreaker`, `Drawdowns`. Per-bar state
  mutation via sequential `¨` with `↩` is clearer than forcing a fork.
- **Capitalization carries role**: capitalized names are functions, lowercase
  are subjects, leading `_` are 1-modifiers, leading/trailing `_…_` are
  2-modifiers. Naming fights the parser if you ignore this.

## Performance

The indicator and rolling layers should be **O(n)**, not O(n·window):

- Rolling sums/means/variances use **prefix sums** (`cs ← 0∾+`x`, then window
  sum `= (n↓cs) - (-n)↓cs`). See `MA`/`Std` in `core.bqn` and `RSharpe`/`RVol`/
  `RBeta` in `roll.bqn`, `VolTarget` in `risk.bqn`. Sample variance is
  `(Σx² - (Σx)²/n)/(n-1)`; clamp with `√0⌈…` to absorb cancellation noise.
- Genuinely path-dependent windows (`RMaxDD`, `RMax`/`RMin`) stay windowed —
  there is no clean prefix-sum form.
- Hoist loop-invariant computations out of `˘`/`¨` bodies.

When you touch a hot path, sanity-check the rewrite against the previous
implementation on random data (max abs diff well under `1e¯6`) before relying
on the test suite.

## Data contract

`Load path` returns a namespace `{dates, close, high, low, open, vol}` of
equal-length flat float arrays. `Validate` enforces finiteness, OHLC
relationships, and (strict mode) positivity; pass `0` as `𝕨` for futures mode
to allow negative prices. Any source that produces this shape works.

## Adding a module

1. Place it in `engine/`, import `bt.bqn` (or `core.bqn` for a leaf).
2. Export the public API with `⇐`; keep internals on `←`.
3. Add tests to `tests/verify.bqn` (every public export needs coverage).
4. Document the API in `README.md` and update this file if conventions shift.
5. Add an `examples/` script if the module has a natural usage pattern.

Use Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`,
`perf`). Keep `make test` green.
