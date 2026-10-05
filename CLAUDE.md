# CLAUDE.md — Mizan (offline-first student finance app)

Project context for Claude Code. Read this before every task.
- The full design is in `docs/ARCHITECTURE.md`. Read the sections that apply to your task before writing code.
- The task list is in `TASKS.md`. Work on **one task at a time**.

## What we're building

A Flutter app that helps university students track spending, warns them **before** they run out of money, and splits shared expenses with roommates. It works fully offline and syncs through a Django server when online. Voice and receipt input are processed on the device.

It's a portfolio project. Correctness (money, sync), clean architecture, tests and measured metrics matter as much as features.

## Non-negotiable rules

1. **Clean architecture, dependency rule:** `presentation → domain ← data`.
   - `domain/` is pure Dart: no imports from `package:flutter`, drift, http, dio, or any plugin.
   - Widgets and notifiers call **use cases**, never DAOs, APIs or plugins.
   - Interfaces live in `domain/repositories/`; implementations in `data/`, wired in `app/di/`.
2. **Money is `Money(int minorUnits, Currency)`. Never use `double` for money.** Parse and format only at the UI edge.
3. **Every local write is one drift transaction that also appends to the `outbox`.** No exceptions.
4. **Never store balances or totals.** Compute them from rows.
5. **Settlements are insert-only.** Fix mistakes with a reversing settlement.
6. **Order with `serverSeq`, never device clocks.** Get the time from the `Clock` interface (never `DateTime.now()` in domain code) so tests can control it.
7. **Nothing parsed by voice, OCR or the LLM is saved without the user confirming it.**
8. **Server re-validates everything** (share sums, membership, permissions).
9. **Domain functions get tests first or alongside**, including property-based tests for invariants (balances sum to 0, shares sum to the amount, simplification zeroes balances).
10. **Ask before adding a dependency.** Say why, and what the alternative is.
11. **Check plugin APIs against the installed version** (pub cache or README), not memory.
12. When a task is done, tick it in `TASKS.md` and add a one-line note if a decision changed. Big decisions get a short ADR in `docs/decisions/`.

## Stack

| Concern | Choice |
|---|---|
| App | Flutter, Dart 3, Riverpod (+ riverpod_generator), go_router, freezed |
| Local DB | drift (SQLite) |
| HTTP | dio, with interceptors for the JWT refresh |
| Background sync | connectivity_plus, workmanager |
| Push | firebase_messaging (FCM), flutter_local_notifications |
| Security | local_auth, flutter_secure_storage |
| Speech | speech_to_text (behind the `SpeechRecognizer` interface) |
| OCR | google_mlkit_text_recognition |
| On-device LLM (fallback parser) | flutter_gemma, small model |
| Charts | fl_chart |
| IDs | uuid (v7) |
| Tests | test, flutter_test, integration_test, mocktail, glados |
| Server | Django, Django REST Framework, simplejwt, PostgreSQL, pytest-django, Docker Compose |
| CI | GitHub Actions: app (analyze, test, coverage) and server (pytest) |

## Layout (summary — see ARCHITECTURE.md §3)

```
app/lib/
  app/        router, theme, di/
  core/       money/, result/, ids/, clock/
  features/<feature>/{domain/{entities,value_objects,repositories,usecases}, data/{db,repositories,mappers,remote}, presentation/}
  features:   expenses, budget, groups, sync, quick_input, auth, settings
server/       accounts/, ledger/, sync/, groups/, notifications/, tests/
docs/         ARCHITECTURE.md, METRICS.md, decisions/
```

## Conventions

- Files in snake_case. One public class per file. Tests mirror the `lib/` paths.
- Entities and value objects are immutable (freezed). Use cases are classes with a single `call()` method.
- Errors: domain returns `Result<T, Failure>`. Never throw across layers. The UI shows every failure as a message.
- Notifiers expose `AsyncValue` states. Loading, empty and error states are required on every screen.
- No business logic in widgets, DAOs or Django views. It belongs in domain use cases (app) or service functions (server).
- Commit style: `feat(groups): add settle-up screen`, `test(sync): conflict on same field`.

## Commands

```bash
# app
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --coverage
flutter test integration_test

# server
cd server
docker compose up -d db
python manage.py migrate
pytest
```

## Definition of done (every task)

- `flutter analyze` is clean and all tests pass (app and server, where touched).
- New domain logic has tests. Invariants have property-based tests.
- Screens have loading, empty and error states.
- The task's "Done when" in TASKS.md is true, and the box is ticked.
