.PHONY: new run test clean help

define STRATEGY_TEMPLATE
# Strategy: $(name)
# Hypothesis: TODO — What do you believe about the market?
# Parameters: TODO — List tunable values
# Created: $(shell date +%Y-%m-%d)

bt ← •Import "../engine/bt.bqn"
data ← bt.Validate bt.Load "../data/spy.csv"
c ← data.close

# ── Indicators ──────────────────────────────
# TODO: compute your indicators here

# ── Signals / Positions ─────────────────────
# TODO: generate position array (1=long, 0=flat, ¯1=short)
pos ← 0⥊˜≠c  # placeholder: flat

# ── Backtest ────────────────────────────────
ret ← bt.Ret c
pos‿ret ↩ bt.Align pos‿ret
pos‿ret ↩ (¯1↓pos)‿(1↓ret)  # 1-bar shift: trade on next open
strat ← (pos bt.Run ret) - 0.001 bt.Cost pos
bh ← ret

"$(name)"‿pos bt.Report strat‿bh
endef
export STRATEGY_TEMPLATE

# Create a new strategy from template
# Usage: make new name=bollinger
new:
	@test -n "$(name)" || (echo "Usage: make new name=strategy_name" && exit 1)
	@test ! -f examples/$(name).bqn || (echo "examples/$(name).bqn already exists" && exit 1)
	@echo "$$STRATEGY_TEMPLATE" > examples/$(name).bqn
	@echo "Created examples/$(name).bqn"

# Run a strategy
# Usage: make run name=ma_cross
run:
	@test -n "$(name)" || (echo "Usage: make run name=strategy_name" && exit 1)
	bqn examples/$(name).bqn

# Run test suite
test:
	bqn tests/verify.bqn

# Remove downloaded data
clean:
	rm -f data/*.csv

help:
	@echo "bbq — BQN Based Quant"
	@echo ""
	@echo "  make new name=X      Create strategy from template"
	@echo "  make run name=X      Run a strategy"
	@echo "  make test             Run test suite"
	@echo "  make clean            Remove data files"
