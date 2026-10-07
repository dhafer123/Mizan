# ADR 0011: Push notifications are a hint to sync, and Firebase is optional

- Status: accepted
- Date: 2026-10-06
- Task: 4.6 (builds on ADRs 0007, 0009)

## Context

Task 4.6 calls for three pushes: a new shared expense, being added to a group, and a weekly settle-up reminder. A "data changed" push should also make the other phones sync, so that an expense added on phone A shows on phone B within seconds. Four questions came up:

1. **What does a push carry?** The data itself, or only a signal?
2. **How does Django send to FCM?**
3. **What happens without a Firebase project?** A fresh clone, CI, and the widget tests have none.
4. **What about pushes that arrive while the app is in the background?**

## Decision

- **A push is only a signal; sync moves the data.**
  - Every message is `data: {type: "sync", groupId?}`, so it never carries rows.
  - When one arrives, the app calls the scheduler's "sync now", which pulls through the normal path.
  - Nothing new has to be trusted, conflict-checked or kept in order, and a lost push costs nothing. The app already syncs on start, on reconnect, after writes and through WorkManager.
- **Who gets what** (`server/notifications/services.py`):

  | Event | Data push to | Notification to |
  |---|---|---|
  | Personal rows pushed | the account's other phones | (none) |
  | Group rows pushed | every member's phones, except the one that pushed | (none) |
  | A new shared expense | (as above) | the other members ("Sami paid 900.000 TND") |
  | Someone joins a group through an invite | every member's phones | the other members ("Ali joined the group") |
  | `manage.py send_settle_up_reminders` (weekly cron) | (none) | each member who owes money in a group ("You owe 300.000 TND") |

  - In this design no one adds another user to a group: people join with invites (ADR 0009). So "added to a group" is "someone joined your group".
  - The server computes balances for the reminders from the rows (`groups/balances.py`), the same way the app does. They are never stored.
- **Push tokens.** The app sends its FCM token to `PUT /auth/devices/<id>/push-token` in these cases:
  - on sign-in;
  - when FCM replaces the token;
  - on resume, if the last send failed.

  A token belongs to one device row. If another row had it (a reinstall), it moves to the new one. When FCM says a token is gone (404 / `UNREGISTERED`), the server clears it. Logging out already deletes the device row (task 3.1).
- **Sending: FCM HTTP v1 with `google-auth` and `requests`** (approved), not `firebase-admin`.
  - It's one POST with a service-account OAuth token, and it is easy to fake in tests.
  - Sends run after the transaction commits (`on_commit`), on a single background thread, so `/sync/push` never waits on FCM.
  - Tests send inline (`NOTIFICATIONS_INLINE`) to a recording sender.
- **Firebase is optional.**
  - The app: `FirebasePushMessaging.start()` returns false when `Firebase.initializeApp()` fails, and push is then off.
  - Android: Gradle applies the google-services plugin only when `android/app/google-services.json` exists. The file is gitignored, because each developer uses their own Firebase project.
  - The server: without `FCM_CREDENTIALS_FILE`, pushes are only logged.
- **The app:**
  - FCM delivers data pushes while the app is open.
  - `flutter_local_notifications` (approved) shows notifications while the app is open, because Android doesn't, and creates the `groups` channel that the server names for background ones.
  - Tapping a notification opens its group.
  - `PushListener` (domain) holds the rules, and `PushMessaging` / `PushTokenRepository` are the interfaces.
- **No background message handler.** In the background, the system shows the notification itself. A handler that synced would run in a second isolate while the app's own isolate may be writing the same database. Instead, the app syncs on resume, and WorkManager keeps syncing while it's closed.

## Consequences

- An expense on phone A reaches phone B within seconds while B's app is open: A's push commits, FCM delivers B's data message, and B syncs. While B is in the background, B shows the notification and syncs as soon as it is opened.
- Push adds no new data path, so the sync invariants and the simulation (ADR 0008) are unchanged.
- `flutter_local_notifications` 22 conflicts with `connectivity_plus` 7.3.2 through `dbus`, a Linux-only package. `connectivity_plus` is pinned to 7.3.1 until they line up.
- Android builds now need core library desugaring, which `flutter_local_notifications` requires.
- **To turn push on:**
  1. Create a Firebase project.
  2. Add an Android app `com.mizan.mizan` and put its `google-services.json` in `app/android/app/`.
  3. Download a service-account key and set `FCM_CREDENTIALS_FILE` on the server.
  4. Schedule `send_settle_up_reminders` weekly.
