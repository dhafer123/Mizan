# Metrics — Mizan

Rules: release build, real device, median of 10 runs for timings. Write the date and device on every row.

**Test device:** <model, RAM, Android version>

## Correctness

| Date | Check | Result |
|---|---|---|
| | Domain test coverage | % |
| | Property tests (splits, balances, simplification) | pass / runs |
| | Sync simulation: random scenarios, all 4 invariants hold | x / 1,000 |
| | Server conflict-policy tests | pass / total |

## Forecast (backtest on real data)

| Date | Days of data | Mean abs. error (days) | Notes |
|---|---|---|---|

## Quick input

| Date | Test set | Method | Accuracy (amounts + items) | Median time (s) |
|---|---|---|---|---|
| | 50 phrases | Rules only | | |
| | 30 held-out phrases | Rules + LLM fallback | | |
| | 30+ receipts | OCR + extractor (+LLM) | total correct: | |
| | Categorization | Memory + rules + LLM | | |
| | Manual entry (baseline) | — | — | |

## Performance

| Date | Metric | Value |
|---|---|---|
| | Cold start (s) | |
| | Scroll 2,000 expenses (dropped frames %) | |
| | Sync 500 ops, push + pull (s) | |
| | APK size (MB) | |

## Beta

| Date | Installs | Weekly active | Expenses logged | % via voice / receipt | Groups created |
|---|---|---|---|---|---|
