# ADR 0017: Receipts are read from rebuilt rows, and a total must be printed on the receipt

- Status: accepted
- Date: 2026-10-08
- Task: 5.6 (ARCHITECTURE.md §8)

## Context

Quick input reads receipt photos: ML Kit text recognition → total and date extractor → LLM fallback → confirmation sheet. Three problems came up:

1. **ML Kit returns blocks, not printed rows.** A receipt's "TOTAL TTC" and its amount often land in different blocks: a left column and a right column.
2. **A receipt prints many amounts.** Item prices, the subtotal, the tax, the cash given and the change all look like the total.
3. **The small LLM can make up a number.**

## Decision

- **Rows come back from the boxes** (`GroupReceiptRows`). Lines whose vertical middles fall inside each other's height form one row, read left to right.
- **The total is found by name** (`ExtractReceipt`):
  - The names, strongest first: "NET A PAYER", "TOTAL TTC", "TOTAL A PAYER", "TOTAL", "MONTANT".
  - The amount is on the named row, or on the row under it when the named row has none.
  - Rows naming something else are skipped: subtotals, HT, TVA, discounts, cash and change, cards, item counts.
  - The strongest name wins, then the largest amount.
  - With no named total, a printed subtotal is taken (confidence 50); with no subtotal either, the largest amount (confidence 40). Both are below 60, so the LLM tier runs.
- **What counts as an amount:** it needs decimals, or a currency unit before or after it ("12 DT", "$24"). That tells prices apart from codes, quantities, phone numbers, times and dates. Spaces never group digits, so a quantity can't merge with a price. In TND, "12.500" and "12,500" are both 12.5 DT.
- **The date** is the first real day/month/year (or ISO) date that isn't in the future and is at most a year old.
- **The shop** is the first row at the top with a few letters. It becomes the expense's note.
- **The LLM's total must be printed on the receipt** (`ReadReceiptAnswer`): it has to equal one of the amounts the extractor finds on it. An invented number is rejected and the rules' reading stays.
- **Dependencies:** google_mlkit_text_recognition 0.16.0 (bundled Latin model, offline) and image_picker 1.2.3 (decided with the user). The picker uses the system camera, so Mizan needs no camera permission.
- **Accuracy is measured on the phone**, with `integration_test/receipt_eval_test.dart`, on 30+ real photos kept out of git (`receipts_eval/`).

## Consequences

- One receipt gives one expense: its total, with the date and shop. Splitting a receipt into items is not in v1.
- Receipts in Arabic script aren't read. ML Kit has no Arabic model.
- The arm64 APK grows by about 12 MB (to ~100 MB) for the bundled OCR model.
