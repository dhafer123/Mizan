# Beta release (task 5.8)

How to put the server online, build the APK, and share it with classmates. Decisions: ADR 0019.

## 1. Deploy the server on Render (once)

1. Push `main` to GitHub (Render deploys from the repo).
2. On <https://render.com>, sign in with GitHub, then **New > Blueprint**, pick the `Mizan` repo. Render reads `render.yaml` and creates:
   - `mizan-db`: free Postgres in Frankfurt.
   - `mizan-api`: the Django API from `server/Dockerfile` (gunicorn). It runs the migrations on every start.
3. When it asks for `FCM_CREDENTIALS_FILE`, either leave it empty (push off: the app still syncs on its own) or, for push:
   - In `mizan-api` > **Environment > Secret Files**, add `fcm-mizan.json` with the contents of `server/fcm-mizan.json`.
   - Set `FCM_CREDENTIALS_FILE=/etc/secrets/fcm-mizan.json`.
4. Wait for the deploy, then open `https://<service>.onrender.com/health`. It should say `{"status":"ok"}`. Note this URL, since the APK needs it.

Only changes under `server/` (or to `render.yaml`) redeploy it.

The free plan sleeps after 15 idle minutes. The first request after that takes about a minute, so the app shows offline and syncs on the next try. The free database expires about 30 days after creation.

## 2. Build the APK

From `app/`, in PowerShell:

```powershell
.\tool\build_beta.ps1 -ApiUrl https://<service>.onrender.com
```

It checks the server answers, then builds `build\app\outputs\flutter-apk\`:

| File | For |
|---|---|
| `app-arm64-v8a-release.apk` | Almost every phone from the last ~7 years. **Share this one.** |
| `app-armeabi-v7a-release.apk` | Old 32-bit phones, if the first one says "App not installed". |

**For each update:** bump `version:` in `pubspec.yaml` (e.g. `0.1.0+1` → `0.1.0+2`) and `appVersion` in `lib/app/app_version.dart` (a test checks they match). Build on **this PC**: the APK is signed with this machine's debug key, and an APK signed with another key won't install over it.

## 3. Share it

- Put the APK in a Google Drive folder (anyone with the link can view) or send it in a group chat.
- Installing: open the file, then allow **Install unknown apps** for the browser or Files app when Android asks. Play Protect may warn about an unknown developer. Tap **More details > Install anyway**.
- What to tell testers:
  - Sign up in Settings to sync and use groups. Everything else works offline without an account.
  - **Settings > Beta > Send feedback** for anything broken or confusing.
  - **Settings > Beta > Share anonymous usage counts** (optional): how many expenses they log each day and how. No amounts, notes, categories or account.
  - The voice assistant is an optional ~550 MB download (Settings > Quick input). Use Wi-Fi.

## 4. Read the results

In Render, `mizan-api` > **Shell**:

```bash
python manage.py beta_report            # last 14 days, latest 20 messages
python manage.py beta_report --days 30 --feedback 100
```

Installs that didn't opt in send nothing, so keep a manual tally of who installed it for "10+ students have it installed".
