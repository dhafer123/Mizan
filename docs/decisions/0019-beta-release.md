# ADR 0019: Beta as a sideloaded APK, with a hosted server, anonymous feedback and opt-in usage counts

- Status: accepted
- Date: 2026-10-09
- Task: 5.8 (ARCHITECTURE.md §9, §10)

## Context

Classmates need to install the app on their own phones, reach a server for sign-in, sync and groups, send feedback, and (if they agree) tell us how much they use it. Until now the server ran only on the developer's PC over plain HTTP on the LAN. Android release builds block plain HTTP.

## Decision

- **Distribution: APK, not Play Store.** Built with `app/tool/build_beta.ps1 -ApiUrl https://…`, which refuses a non-HTTPS URL and checks `/health` first. It makes split-per-ABI APKs; most phones take `app-arm64-v8a-release.apk`. They are signed with the **debug key** (decided with the user): fine for sideloading, but every update must be built on the same PC, or it won't install over the old one. The Play Store needs a real upload key (task 6.8).
- **Hosting: Render** (`render.yaml`, decided with the user). A Docker web service from `server/Dockerfile` plus Postgres, both on the free plan in Frankfurt, with HTTPS on `*.onrender.com`. The production image now runs **gunicorn** (approved dependency). `docker-compose.yml` still runs the dev server with the dev requirements. The free plan has costs to live with: the service sleeps after 15 idle minutes, so the first request can take about a minute (the app shows "offline" and syncs on the next try), and the free database expires after about 30 days, which covers the beta but not 6.8.
- **Feedback: a server endpoint** (`POST /beta/feedback`, decided with the user). Settings > Beta > Send feedback opens a form with a message and an optional email or phone for a reply. It is sent through the public client with **no token**, and the server ignores authentication on `/beta/*`. So feedback is never tied to an account unless the sender writes a contact. If it can't be sent, the form keeps the text and shows the error. It is not queued: the user can tap Send again.
- **Usage counter: opt-in, anonymous, counts only.**
  - It is off by default. Turning it on in Settings makes a random **UUIDv4** install id (not the account, the device id, or a time-based id). Turning it off forgets the id, so turning it on again starts a new install that can't be linked to the old one.
  - A report holds, per day, how many expenses were logged by input method (`manual`, which includes typed quick input, then `voice` and `receipt`). There are no amounts, notes, categories or ids.
  - **Counts are computed from rows**, not stored in a counter table (rule 4). The logged moment is read from the expense's UUIDv7 id (`uuidV7Time`). The day is the phone's local calendar day, and only live expenses count.
  - Each report covers the days from the opt-in day to today, at most the last 14, with 0 for quiet days. The server **replaces** each (install, day, method) count, so resending is safe. The app sends at most once a day: on start, and whenever the app comes back. A failed send is retried next time. The first report goes out right after opting in.
  - It is stored in secure storage next to the app lock: device-only and never synced, so no outbox (like `sent_alerts`, ADR 0013).
- **Reading the results:** `python manage.py beta_report` prints installs (all-time, and active in the last 7 days), per-day totals by method, and the latest feedback. On Render, run it from the service's Shell tab. There is no Django admin. The API stays admin-free.
- `/beta/*` has its own throttle scope (`BETA_THROTTLE_RATE`, 120 an hour per IP). It is generous because a campus Wi-Fi puts many students behind one IP.

## Consequences

- "10+ students have it installed" is counted from `beta_report` (installs that opted in) plus a manual tally, since installs that don't opt in send nothing.
- A user signed in on two phones who opts in on both shows as two installs, with their synced expenses counted twice. That's acceptable for a beta-sized count.
- An expense created on another device and synced here is counted on this phone's report, on the day it was created.
- Before 6.8: an upload key, a paid or other database before the 30 days run out, and a cron for `send_settle_up_reminders` (Render's free plan has no cron jobs).
