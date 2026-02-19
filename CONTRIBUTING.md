# Contributing

PRs are welcome. Open an issue first for anything non-trivial so we can align on approach before you write code.

## Issues

- **Bugs**: include a minimal repro (BQN snippet + expected vs actual output) and BQN version / OS
- **Feature proposals**: describe motivation and proposed API (signature + example)

## Pull Requests

Target `main` directly. Small, focused PRs are easier to review.

Checklist before opening:
- `make test` passes (129 tests)
- New exports have tests in `tests/verify.bqn`
- `CLAUDE.md` and `AGENTS.md` updated if you added or changed any exported API
- Conventional commit message (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`)

## Code Standards

Follow the conventions in `CLAUDE.md`:
- Comment tags: `# TODO:`, `# NOTE:`, `# BUG:`, `# FIX:`, `# HACK:`, `# PERF:`, `# WARNING:`
- Section dividers: `# ── Name ─────────────────────────────`
- Use `←` for first definition, `↩` for reassignment
- Division guards: `eps⌈x` (max), not `eps+x`
- All backtesting positions must be 1-bar lagged to avoid lookahead bias

## New Modules

Follow the pattern of existing engine files. If adding a new module:

1. Place it in `engine/`
2. Import `bt.bqn` (or `core.bqn` for leaf modules)
3. Export with `⇐`
4. Add tests in `tests/verify.bqn`
5. Add an API section to both `CLAUDE.md` and `AGENTS.md`
6. Add an example to `examples/` if the module has a natural usage pattern
