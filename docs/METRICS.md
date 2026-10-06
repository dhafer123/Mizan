# Metrics — Mizan

Rules: release build, real device, median of 10 runs for timings. Write the date and device on every row.

**Test device:** <model, RAM, Android version>

## Correctness

| Date | Check | Result |
|---|---|---|
| 2026-10-05 | Domain test coverage | 98.1% (357/364 lines, `core/` + `*/domain/`) |
| 2026-10-05 | Property tests (splits, balances, simplification) | 13 / 13 pass, 1,000 runs each (13,000 cases) |
| 2026-10-06 | Sync simulation: random scenarios, all 4 invariants hold | 1,000 / 1,000 per CI run against the fake server (locally after the fixes: 4 runs, 4,000 / 4,000); 150 / 150 against the real Django server. A typical 1,000: 16,793 ops, 373 lost push responses, 650 merges, 425 same-field overwrites, 111 edits rejected after a delete |
| 2026-10-06 | Server conflict-policy tests (pytest) | 179 / 179 |

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
