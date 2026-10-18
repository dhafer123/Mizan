# ADR 0026: Measuring performance on the phone like a user, and trimming the APK

- Status: accepted
- Date: 2026-10-18
- Task: 6.3

## Context

Task 6.3 asks for cold start, scrolling 2,000 expenses and syncing 500 ops, measured and recorded, and for anything slow to be fixed. The test phone is a Galaxy A16: low-end MediaTek, 4 GB RAM, a 90 Hz screen.

The first on-device numbers said the list was janky: 8.7% of frames over 16 ms. Tracing showed the test causing it, not the app:
- `tester.fling` sends its finger moves in bursts, so the list jumped 6–8 rows in one frame.
- `pumpAndSettle` on a phone only draws a frame every 100 ms while the list coasts, so each frame laid out 5–14 rows.

## Decision

- **`integration_test/perf_test.dart` measures as a user sees it**, in a profile build, through `flutter drive` with `--no-dds` (needed for the frame timings):
  - The engine draws at the screen's own rate (`framePolicy = fullyLive`), and the test waits in real time.
  - Each flick sends one finger move per 90 Hz frame, timestamped, so the list knows the finger's speed and coasts when it lets go.
  - Only frames where something moved count (build ≥ 1 ms). The engine also draws idle frames, which would flatter the result.
  - The budget is 11.1 ms (90 Hz), not 16.
  - `--dart-define=MIZAN_PERF_TRACE=true` records a full timeline instead, with each widget's build and layout, for finding the cause of slow frames.
- **Sync uses the real client against the Django server on the PC.** Phone A pushes 500 new expenses and pulls back the merged result. Phone B is a fresh database, signs in to the same account and pulls everything. Both claim their local data first, as the app's sync loop does.
- **Ten runs, medians**, summarised by `tool/perf_summary.dart`. Cold start is ten `am start -W` launches of the release APK.
- **The one fix: a smaller APK.** `flutter_gemma` depends on MediaPipe's vision tasks and image generator, but Mizan only uses its text model, and receipts use ML Kit. Their native libraries are now excluded in Gradle, like the unused engines before them:
  - `libmediapipe_tasks_vision_jni.so`
  - `libmediapipe_tasks_vision_image_generator_jni.so`
  - `libimagegenerator_gpu.so`

  Each library loads only when its API is used, nothing links to them, and the text engine doesn't name them. This takes the arm64 APK from 101.4 MB to 64.5 MB.

## Results (Galaxy A16, 2026-10-18)

| | |
|---|---|
| Cold start | 0.42 s |
| Open Expenses with 2,000 rows | 56 ms |
| Scrolling | 0.58% of moving frames over budget; build p99 7.4 ms |
| Push 500 ops and pull back | 4.40 s |
| Fresh phone pulls 500 ops | 0.91 s |
| arm64 APK | 64.5 MB |

Nothing else was slow enough to change. A list row costs about 2–3 ms to build and lay out (mostly its three texts), and a real flick brings in one or two rows per frame.

## Consequences

- `flutter drive` uninstalls the app like `flutter test` does, so this run wipes the phone's local data.
- The profile build now allows plain HTTP, so it can reach the dev server. Debug already did; release stays HTTPS-only.
- If `flutter_gemma` ever starts using a vision API (an image-input model, for example), the excluded libraries must come back. The failure would be an `UnsatisfiedLinkError` the first time that API is used.
- Sync time is mostly the server (about 1 s per 200-op page on the dev server) plus pulling back the merged rows. It's fine for a backlog of 500, and it's the place to look if real backlogs get larger.
