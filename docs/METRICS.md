# Metrics — Mizan

Rules: release build, real device, median of 10 runs for timings. Write the date and device on every row.

**Test device:** Samsung Galaxy A16 (SM-A165F), 4 GB RAM, Android 16

## Correctness

| Date | Check | Result |
|---|---|---|
| 2026-10-05 | Domain test coverage | 98.1% (357/364 lines, `core/` + `*/domain/`) |
| 2026-10-05 | Property tests (splits, balances, simplification) | 13 / 13 pass, 1,000 runs each (13,000 cases) |
| 2026-10-06 | Sync simulation: random scenarios, all 4 invariants hold | 1,000 / 1,000 per CI run against the fake server (locally after the fixes: 4 runs, 4,000 / 4,000); 150 / 150 against the real Django server. A typical 1,000: 16,793 ops, 373 lost push responses, 650 merges, 425 same-field overwrites, 111 edits rejected after a delete |
| 2026-10-06 | Server conflict-policy tests (pytest) | 179 / 179 |

## Forecast (backtest on real data)

From `app/`: `dart run tool/forecast_backtest.dart <export.csv> --income AMOUNT:WHEN --budget AMOUNT --end <export day>` (ADR 0014). Record the learned-rate MAE over exact days, and in Notes the exact / lower-bound / censored day counts, the MAE with lower bounds, the bias and the in-range share.

| Date | Days of data | Mean abs. error (days) | Notes |
|---|---|---|---|

## Quick input

| Date | Test set | Method | Accuracy (amounts + items) | Median time (s) |
|---|---|---|---|---|
| 2026-10-08 | 61 phrases (EN/FR/Darija, 8 hard) | Rules only | 55 / 61 (90.2%); 0 wrong at confidence ≥ 60; all 8 hard ones sent to the fallback | |
| | 30 held-out phrases | Rules only | | — |
| 2026-10-08 | 30 held-out phrases | Rules + LLM fallback (Qwen2.5 0.5B) | not measured yet | 5.54 (median of 8 spoken phrases, release, Galaxy A16; recognizer in en-US) |
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
