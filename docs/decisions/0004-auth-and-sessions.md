# ADR 0004: Email accounts, rotating JWTs, and local-only mode

- Status: accepted
- Date: 2026-10-06
- Task: 3.2

## Context

Sync (3.6) and groups (week 4) need to know who a request comes from. The app must stay fully usable without an account, and a phone can be offline for days. The user approved `djangorestframework-simplejwt` (server) and `dio` (app). `mocktail` was not approved: tests use a scripted dio `HttpClientAdapter` instead.

## Decision

**Accounts (server)**
- A custom `accounts.User` signs in with email + password and has no username. Emails are trimmed and lowercased before they are stored or looked up, so uniqueness ignores case. The display name is optional and at most 50 characters.
- Sign-up runs Django's password validators. Their codes (`password_too_short`, `password_too_common`, …) go back to the app.
- A wrong password, an unknown email and an inactive account all get the same `401 invalid_credentials`.
- Login and sign-up share a per-IP throttle (`AUTH_THROTTLE_RATE`, 20/min by default).
- Every error is `{"code", "detail", "fields"?}` (`mizan/errors.py`), so the app maps errors by code, not by text.

**Tokens**
- An access token lasts 15 minutes and a refresh token 30 days.
- `accounts.services.refresh_tokens` swaps a refresh token for a new pair and blacklists the old one, so **each refresh token works once**. If two refreshes race with the same token, only one wins: the blacklist row is a one-to-one `get_or_create`. A deleted or inactive user gets a 401, not a 500 like simplejwt's own refresh serializer.
- `CHECK_REVOKE_TOKEN` is on. Tokens carry a hash of the password, so changing it signs out every device.
- `POST /auth/logout` blacklists the refresh token and deletes the device. It is idempotent, and an invalid token still gets a 204.

**Devices**
- `Device(id, user, platform, name, fcm_token, last_seen_at)`. The phone makes the id (a UUIDv7) once per install and keeps it in secure storage, so it survives logging out.
- The device is upserted at sign-up and login, in the same request. If a phone signs in to another account, the device row moves to that account and its push token is cleared. FCM tokens arrive in task 4.6.

**App**
- **Local-only mode** is the default. The app opens to home with no account, and Settings → Account offers "Sign in to sync". Signing in or logging out never touches local data.
- The session (account + tokens) is stored as one JSON value in `flutter_secure_storage`. The domain never sees tokens: `AuthRepository` exposes `watchAccount`, `signUp`, `logIn` and `logOut`.
- `AuthInterceptor` (a `QueuedInterceptor` on `apiDioProvider`) adds the access token. On a 401 it refreshes once and retries the request, and other requests that fail at the same time reuse the new token instead of refreshing again.
  - If the server rejects the refresh token, the session ends: local sign-out, and the account shows as signed out.
  - If the refresh fails because the phone is offline or the server errors, the tokens are kept and the error is passed on.
- Logging out while offline still signs out on the phone. The refresh token then stays valid on the server until it expires.
- The API URL defaults to `http://10.0.2.2:8000` (the Android emulator's view of the host) and can be overridden with `--dart-define=MIZAN_API_URL=…`. Cleartext HTTP is allowed in debug builds only.

## Consequences

- Local rows are not tied to an account. If you log out of account A and sign in to B, the existing local data would sync to B. Task 3.6 has to decide what happens (e.g. ask before uploading, or keep data per account).
- A background sync (WorkManager isolate, 3.6) runs outside the app's interceptor queue. If both refresh at the same moment, one loses and the user is signed out. 3.6 should refresh from one place, or retry once after re-reading the stored tokens.
- Email verification and password reset are not built yet.
