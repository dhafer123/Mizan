# ADR 0016: The on-device assistant is Qwen2.5 0.5B on flutter_gemma 0.12.6, opt-in, and never trusted blindly

- Status: accepted
- Date: 2026-10-08
- Task: 5.5 (ARCHITECTURE.md §8)

## Context

Quick input's second tier is a small on-device LLM, used when the rule parser (ADR 0015) is less sure than 60%. When this task started:

- The app is on Flutter 3.38.9 / Dart 3.10.8. Current flutter_gemma (1.x) and its successor flutter_edge_ai (2.x) need Flutter ≥ 3.44 / Dart 3.12. flutter_gemma 0.12.7–0.16.5 need sqlite3 3.x, which clashes with the sqlite3 2.9.4 pin that drift's host tests use (2.1).
- The Gemma models on HuggingFace are gated. Downloading them needs a token, and a token can't ship in the app.
- A 0.5B model writes plausible nonsense now and then.

## Decision

- **flutter_gemma 0.12.6** (decided with the user): the newest version that resolves without other changes. Its line is discontinued (renamed flutter_edge_ai), but it sits behind `ExpenseLlm`, so a later Flutter upgrade can swap it without touching the domain. speech_to_text is pinned to 7.4.0 for the same reason.
- **Qwen2.5 0.5B Instruct, 8-bit, MediaPipe `.task`** (decided with the user): Apache-2.0 and not gated. The app downloads it (~547 MB) straight from HuggingFace, with no token and nothing for us to host. It runs on the CPU with greedy decoding, one fresh session per phrase.
- **The download is opt-in**, from Settings, with a Wi-Fi warning. Until then, quick input works with the rules alone. It doesn't use Android's foreground service, which would need more permissions. On Wi-Fi the download ends well inside the 9-minute job limit, and the plugin retries.
- **The model is never trusted blindly** (`ReadLlmAnswer`):
  - the answer must hold JSON `{"items":[{"label","amount"}]}` with 1–10 items;
  - each amount must read as more than 0 in the app's currency (number amounts go through the same `MoneyParser`, never a double);
  - each label must share a word with the phrase, so the model can't invent items.

  Anything else rejects the whole answer. Errors, a 20-second timeout and a missing model all fall back to the rules' reading. Either way, everything goes to the confirmation sheet first (CLAUDE.md rule 7).
- **Unused native engines are left out of the APK**: `.litertlm`, embeddings, the text chunker and the vector store, about 70 MB per ABI. The plugin loads each one only when its API is called.

## Consequences

- **The arm64 APK grows from about 24 MB to about 88 MB** for everyone, even people who never download the model, because MediaPipe's inference and vision libraries ship in the app. Moving the engine into a Play feature module, or dropping the LLM, would win that back.
- MediaPipe's GenAI has no 32-bit ARM library. On those phones the model can download but can't run, so quick input stays on the rules.
- Accuracy (rules vs rules + LLM) is measured on the phone with `integration_test/quick_input_eval_test.dart`, on 30 phrases the user writes. The voice timing comes from the release app (Settings → Voice timings).
