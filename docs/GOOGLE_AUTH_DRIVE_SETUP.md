# OTYA Google Sign-In + private Drive backup

OTYA supports Google Sign-In without Firebase and stores recovery data in the signed-in user's hidden Google Drive `appDataFolder`.

## Google Cloud Console

1. Create or use the Google Cloud project for OTYA Player.
2. Enable **Google Drive API**.
3. Configure the OAuth consent screen for PeterSmart Link / OTYA Player.
4. Add the scope `https://www.googleapis.com/auth/drive.appdata` as the optional Drive recovery permission.
5. Create an **Android OAuth client** for package `com.otyaplayer.app` and register the SHA-1/SHA-256 fingerprints of the real release signing certificate. Add the debug certificate only if local debug Google Sign-In is required.
6. Create a **Web OAuth client**. Its client ID is the server client ID/audience used by both Flutter and `otya-auth`.

## GitHub

Create repository/environment variable:

- `GOOGLE_CLIENT_ID` = the **Web OAuth client ID** (`...apps.googleusercontent.com`).

Debug and Release workflows pass this value using `--dart-define=GOOGLE_CLIENT_ID=...`.

The Android OAuth client ID is configured in Google Cloud for package/signing-certificate recognition. It is **not** the value supplied to the backend `GOOGLE_CLIENT_ID` audience check.

## Cloudflare `otya-auth`

Set the Worker secret/variable named:

- `GOOGLE_CLIENT_ID` = the exact same **Web OAuth client ID** used by the Flutter build.

Do not place a Google client secret in Flutter. OTYA does not require a Google OAuth client secret in the APK.

## Runtime flow

1. Basic Google Sign-In requests identity scopes (`email`, `profile`) only.
2. Flutter sends the Google ID token to `https://petersmartlink.com/auth/google`.
3. `otya-auth` verifies audience, issuer, expiry and `email_verified`, then issues OTYA JWT + refresh token.
4. Google Drive permission is requested **only when the user explicitly starts backup, restore or cloud-backup deletion**.
5. The optional Drive permission is the narrow `drive.appdata` scope.
6. Backup data is stored as `otya-backup.json` inside the user's Drive `appDataFolder`.
7. OTYA JWT/refresh tokens remain in Android Keystore-backed secure storage. Google Drive access tokens remain memory-only and are not sent during basic `/auth/google` authentication.

The Drive App Folder is intentionally hidden from normal My Drive browsing and is intended for per-user application recovery data. OTYA recovery snapshots must not contain passwords, OTPs, OTYA JWTs, refresh tokens, API keys, server secrets, FCM service credentials, raw music/video files, or Safe/private media.
