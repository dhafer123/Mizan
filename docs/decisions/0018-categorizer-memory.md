# ADR 0018: The categorizer's memory is computed from the user's expenses

- Status: accepted
- Date: 2026-10-08
- Task: 5.7 (ARCHITECTURE.md §8)

## Context

§8 asks for a categorizer in three tiers: the user's own memory (learned from corrections), then rules, then the LLM. The memory needs to live somewhere, and "learned from corrections" needs a definition.

## Decision

- **No memory table.** The memory is computed from the user's expenses each time the confirmation sheet opens (`LearnCategories`, through `LoadCategoryMemory`). That follows "compute from rows, never store" (rule 4), syncs with the expenses for free, and needs no outbox (rule 3).
- **Every saved expense is a lesson.** The category the user last saved for a note is the one suggested next time. "Last" means the most recent by date, then by id, which is time-ordered. So one correction changes the next suggestion for the same shop.
- **Order of the tiers** (`SuggestCategory`):
  1. The same note, compared lower case and without accents or punctuation.
  2. The most recently used *distinctive* word of the note.
  3. The keyword list (`ExpenseKeywords`).
  4. The LLM (`AskLlmCategory`), only when nothing above matched and the model is downloaded. It runs in the background on the confirmation sheet. Its answer must name one of the user's active categories.
- **Only distinctive words are remembered.** Words in the keyword list ("café", "taxi") and filler words aren't. So filing "Café Le Baron" under leisure teaches "baron", not that every café is leisure.
- The sheet says where a suggestion came from: "From your past choices" or "Suggested by the assistant". Picking a category clears the hint.

## Consequences

- Reading every expense each time the sheet opens is cheap at a student's scale (thousands of rows). It could be cached later if needed.
- Group expenses don't teach the memory. Only personal expenses carry the user's own notes.
- Accuracy: on a synthetic 60-note month, keywords alone get 61.7% right and memory + keywords 90.0%. The set was written alongside the rules, so it's a regression check, not a held-out score. `tool/categorizer_eval.dart` measures the same on a real CSV export.
