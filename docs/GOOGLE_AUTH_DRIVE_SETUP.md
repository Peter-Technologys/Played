# OTYA Google Sign-In + private Drive backup

OTYA supports Google Sign-In without Firebase and stores backup data in the signed-in user's hidden Google Drive `appDataFolder`.

## Google Cloud Console

1. Create or use the Google Cloud project for OTYA Player.
2. Enable **Google Drive API**.
3. Configure the OAuth consent screen for PeterSmart Link / OTYA Player.
4. Add the scope `https://www.googleapis.com/auth/drive.appdata`.
5. Create an **Android OAuth client** for package `com.otyaplayer.app` and register the SHA-1/SHA-256 fingerprints of the real release signing certificate. Add the debug certificate too if local debug Google Sign-In is required.
6. Create a **Web OAuth client**. Its client ID is the server client ID used to verify Google ID tokens.

## GitHub

Create repository/environment variable:

- `GOOGLE_CLIENT_ID` = the Web OAuth client ID.

Debug and Release workflows pass this value using `--dart-define=GOOGLE_CLIENT_ID=...`.

## Cloudflare `otya-auth`

Set the Worker secret/variable named:

- `GOOGLE_CLIENT_ID` = the exact same Web OAuth client ID.

Do not place a client secret in Flutter. OTYA does not need a Google OAuth client secret in the APK.

## Runtime flow

1. Flutter asks Google for identity plus `drive.appdata` permission.
2. Flutter sends only the Google ID token to `/auth/google` for OTYA account authentication.
3. `otya-auth` validates Google token audience/issuer/expiry and issues OTYA JWT + refresh token.
4. Drive access is used only for `/auth/backup` operations.
5. The backup is stored as `otya-backup.json` inside the user's Drive `appDataFolder`.
6. OTYA JWT/refresh tokens remain in Android Keystore-backed secure storage. The Google Drive access token is kept in memory and refreshed through Google Sign-In.

The Drive App Folder is intentionally hidden from normal My Drive browsing and is intended for per-user application data.
