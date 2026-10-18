# Demo video script (task 6.7, 90 s)

Voice entry → forecast warning → shared rent with a roommate → airplane-mode edit → sync → settle up.

One phone (Galaxy A16) on camera, as **Dhafer**. The roommate **Sami** is a real second account. The PC acts for him between shots (`demo_roommate pay`), so his payment really syncs through the server.

## Before recording

1. **Server on the PC.** Postgres running, then from `server/`:
   ```powershell
   $env:DJANGO_DEBUG="0"; $env:DJANGO_SECRET_KEY="local-demo-only-not-secret-0123456789abcdef"
   $env:DJANGO_ALLOWED_HOSTS="localhost,127.0.0.1,192.168.0.181"
   .venv\Scripts\python manage.py seed_demo --reset
   .venv\Scripts\python manage.py runserver 0.0.0.0:8000 --noreload
   ```
   Seeding gives Dhafer:
   - a 450 DT scholarship on the 1st, and a 450 DT budget;
   - four weeks of everyday spending, so money runs out about a week before payday;
   - "Flat 4B" with Sami, who joined through an invite. Sami paid the internet (45 DT) and Dhafer the cleaning things (18 DT), so Dhafer owes Sami 13.500 DT.
2. **The app on the phone.** The profile build, pointed at the PC:
   ```powershell
   cd app
   flutter build apk --profile --split-per-abi --target-platform android-arm64 --dart-define=MIZAN_API_URL=http://192.168.0.181:8000
   adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-profile.apk
   ```
3. **Sign in** as `dhafer@example.com` / `mizan-demo-2026`. On a fresh install, skip the welcome steps, then go to Settings → Account → Sign in. Wait for the cloud icon to show **Synced**. Home should show the forecast warning and Penny looking worried.
4. **Phone:**
   - Do Not Disturb on, battery above 50%, the phone and the PC on the same Wi-Fi.
   - Mizan's assistant model downloaded (Settings → Assistant).
   - Theme as you want it on camera (dark looks best).
   - Start the screen recorder.
5. **Retake:** in the app, Settings → Account → Log out. On the PC, `seed_demo --reset`. Sign in again: the phone sees a different account, wipes and pulls fresh.

## Shots

| Time | On screen | Do | Say (voice-over) |
|---|---|---|---|
| 0:00–0:08 | Home | Hold on Home: Penny, money left, the forecast card. | "Mizan is a budget app for students. It works offline and warns you *before* you run out." |
| 0:08–0:22 | Quick input | Tap the mic and say "coffee 2.5 and taxi 8". The confirm screen shows two items; tap Save. Penny cheers and money left counts down. | "I just say what I spent. Speech and parsing run on the phone, and nothing is saved until I confirm." |
| 0:22–0:32 | Home forecast | Scroll to the forecast card: the runway from today to payday, with the run-out marked before payday. | "At this pace my money runs out around the 24th, a week before my scholarship arrives." (Read the date off the card: the seed alone gives Oct 25, and the voice entry can pull it a day earlier.) |
| 0:32–0:48 | Groups → Flat 4B | Add expense: Rent, 600, paid by Dhafer, split equally. Open Balances: "You're owed 286.500 DT". | "Rent is shared with my roommate Sami. Mizan splits it to the millime, and the balances always add up to zero." |
| 0:48–1:02 | Airplane mode | Swipe down and turn airplane mode on; the cloud icon shows **Offline**. Edit today's taxi to 7. The icon shows **Changes waiting to sync**. | "No signal? Everything still works. Every change waits in an outbox." |
| 1:02–1:10 | Sync | Turn airplane mode off. The icon goes **Syncing** → **Synced**. | "Back online, it syncs by itself, ordered by the server, never by phone clocks." |
| 1:10–1:25 | Settle up | Off camera, on the PC: `python manage.py demo_roommate pay` (it prints "Sami paid Dhafer 286.500 DT"). On the phone, open Flat 4B → Settle up and tap Sync now if needed. It shows **Everyone is settled up.** and Penny celebrates. | "Sami pays me back from his phone. Payments are never edited, only reversed, so the history stays honest." |
| 1:25–1:30 | Home | Back to Home. | "Mizan: know before you're broke." |

## If something goes wrong

- **The cloud icon stays Offline after airplane mode:** wait for Wi-Fi to reconnect, then tap the icon → **Sync now**.
- **"Couldn't reach the server":** check that `runserver` is still running and the phone is on the same Wi-Fi. Opening `http://192.168.0.181:8000/health` in the phone's browser should show `{"status":"ok"}`.
- **The assistant takes a few seconds:** that's the on-device model's first load. Say a test phrase once before recording.
- **`demo_roommate pay` says Sami owes nothing:** the rent wasn't synced yet. Sync the phone first.
