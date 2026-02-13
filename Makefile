.PHONY: new fetch run test source clean help

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
strat ← pos bt.Run ret
bh ← ret

"$(name)"‿pos bt.Report strat‿bh
endef
export STRATEGY_TEMPLATE

# Create a new strategy from template
# Usage: make new name=bollinger
new:
	@test -n "$(name)" || (echo "Usage: make new name=strategy_name" && exit 1)
	@test ! -f strategies/$(name).bqn || (echo "strategies/$(name).bqn already exists" && exit 1)
	@echo "$$STRATEGY_TEMPLATE" > strategies/$(name).bqn
	@echo "Created strategies/$(name).bqn"

# Fetch market data
# Usage: make fetch [ticker=AAPL] [period=5y]
fetch:
	python data/fetch.py $(or $(ticker),SPY) $(or $(period),5y)

# Run a strategy
# Usage: make run name=ma_cross
run:
	@test -n "$(name)" || (echo "Usage: make run name=strategy_name" && exit 1)
	bqn strategies/$(name).bqn

# Run test suite
test:
	bqn tests/verify.bqn

# Create a new data source (fetcher + parser pair)
# Usage: make source name=alpaca
source:
	@test -n "$(name)" || (echo "Usage: make source name=source_name" && exit 1)
	@test ! -f data/$(name)_fetch.py || (echo "data/$(name)_fetch.py already exists" && exit 1)
	@printf '# $(name) data fetcher\n# Downloads market data to data/*.csv\n# Parser: $(name)_load.bqn\n\nimport sys\n\n# TODO: implement fetcher\n# Output: CSV with columns Date,Open,High,Low,Close,Volume\n# Save to: data/{ticker}.csv\n' > data/$(name)_fetch.py
	@printf '# $(name) data parser\n# Reads CSV from $(name)_fetch.py into bbq data contract\n# Fetcher: $(name)_fetch.py\n#\n# Must return: {dates⇐, close⇐, high⇐, low⇐, open⇐, vol⇐}\n# All numeric arrays: flat floats, same length\n\n# TODO: implement parser\n' > data/$(name)_load.bqn
	@echo "Created data/$(name)_fetch.py  — fetcher: download to data/*.csv"
	@echo "Created data/$(name)_load.bqn  — parser: CSV -> {dates,close,high,low,open,vol}"

# Remove downloaded data
clean:
	rm -f data/*.csv

help:
	@echo "bbq — BQN Based Quant"
	@echo ""
	@echo "  make new name=X      Create strategy from template"
	@echo "  make fetch [ticker=X] Download market data"
	@echo "  make run name=X      Run a strategy"
	@echo "  make test             Run test suite"
	@echo "  make source name=X   Create data source (fetcher + parser)"
	@echo "  make clean            Remove data files"
