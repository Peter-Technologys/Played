# Otya v1 Privacy & Data Inventory

**Status:** engineering inventory for the Otya `1.0.0+1` release candidate. This is not a substitute for the final legal Privacy Policy.

The final public Privacy Policy, Google Play Data safety form, in-app privacy text and account-deletion page must be reconciled against this inventory and the live backend before release.

## Why this exists

The repository currently contains legacy privacy text that describes older Played/Otya generations and no longer matches current code. Legal/trust copy must be generated from verified behavior rather than inherited wording.

## Local-only / primarily local data

### Media library
Otya reads local audio/video metadata and file paths to build the local library and play media. Core local playback is designed to work without an Otya account or cloud availability.

### Playlists/history/settings
Local application state can include playlists, playback history, settings, EQ/personalization state and related local preferences. Some account/backup flows may synchronize selected supported state when explicitly enabled; raw media files are not part of ordinary cloud recovery.

### Private
Otya Private stores protected media inside app-private storage. Android biometric/device authentication is used to authorize access. Otya must not claim that it receives or stores the user's biometric template.

### Transfer
Transfer is designed for authenticated same-Wi-Fi/hotspot transfer. The transport is local-network oriented rather than a general cloud file relay.

## Otya account and authentication

When a user creates or uses an Otya account, the service can process data necessary for account operation and security, including:
- email address;
- profile/name fields supplied by the user;
- Otya account identifier;
- authentication/session records and refresh/access-token state;
- consent state and policy versions;
- verification/recovery/2FA-related security state;
- Google identity token/identity data when the user chooses Google Sign-In.

Passwords, OTPs, recovery codes and tokens are security-sensitive data. The public policy must describe their purpose without exposing implementation details.

## Device registration and notifications

Current client code can send device/service metadata needed for Otya services and notifications, including:
- Otya device identifier;
- app version and build number;
- device architecture;
- platform;
- locale;
- Firebase Cloud Messaging token.

FCM is used for push delivery such as update alerts and announcements when enabled/configured.

## Diagnostics

### Crash reporting
The current client has an Otya crash-reporting path. A crash record can include:
- device identifier;
- app version/build;
- error type;
- truncated error description;
- truncated stack trace;
- timestamp.

The final policy must not say that crash reports are never sent while this path exists.

### Firebase Analytics and Performance
Current code can enable Firebase Analytics and Firebase Performance collection through Otya's remote policy. The public policy/Data Safety declaration must reflect the actual production configuration and data categories used by those SDKs.

### Firebase App Check / Play Integrity
Otya can use Firebase App Check with Android Play Integrity to attest protected requests. The public trust explanation should distinguish security attestation from advertising or media scanning.

## Next

Next is optional and is not required for local playback.

When a user sends content to Next, the request and necessary service metadata are transmitted to the Otya backend and configured AI-processing infrastructure to generate the response. Public documentation must not imply that Next prompts always remain only on the device.

Before release, verify and document:
- which AI processors/providers can receive request content;
- whether conversation content is retained server-side and for how long;
- whether content is used for model training by Otya or upstream providers;
- what controls a user has over Next history/deletion;
- what safety/security logging is retained.

Do not publish guesses for these points.

## Google Sign-In and Google Drive

Google Sign-In is optional. Otya uses Google identity data/tokens necessary to authenticate the user with the Otya account service.

Google Drive recovery/backup is explicit and user-initiated. Current client design does not store the Google OAuth access token on disk. The final policy must accurately state what Otya writes to Google Drive and whether it uses app-specific Drive storage.

## Online Music and external providers

Otya can request online music through the Otya backend. Provider data such as catalog metadata, artwork and stream/download URLs can originate from external music providers. Users may therefore connect to provider-controlled URLs while using online music.

Provider attribution, download restrictions and privacy disclosures must reflect the providers actually enabled in production.

## Website/support/email

The final policy must also cover, where applicable:
- support messages and attachments;
- contact forms;
- transactional email through the configured email provider;
- product/news email subscriptions and preference/unsubscribe state;
- website analytics/cookies if enabled;
- security reports;
- account-deletion requests made through the website.

These cannot be finalized from the Flutter client alone; verify the live website/Cloudflare/Resend implementation.

## Current Android permissions

Current `AndroidManifest.xml` requests:
- `READ_EXTERNAL_STORAGE` only through Android 12 / API 32;
- `READ_MEDIA_AUDIO`;
- `READ_MEDIA_VIDEO`;
- `INTERNET`;
- `ACCESS_NETWORK_STATE`;
- `ACCESS_WIFI_STATE`;
- `CAMERA`;
- `USE_BIOMETRIC`;
- `USE_FINGERPRINT`;
- `FOREGROUND_SERVICE`;
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK`;
- `WAKE_LOCK`;
- `POST_NOTIFICATIONS`;
- `VIBRATE`.

Current v1 code deliberately does **not** request `MANAGE_EXTERNAL_STORAGE` or `REQUEST_INSTALL_PACKAGES`.

## Deletion and user control

Current app code includes an in-app account deletion flow that requires confirmation from the server before claiming success.

Before Google Play release, Otya must also provide a discoverable external web path where a user can request deletion of the account and associated data, and the published Privacy Policy must state any data that is retained after deletion and the reason/retention period.

Also verify whether users need:
- account data export/download;
- deletion of selected cloud data without deleting the account;
- connected-service revocation;
- marketing/email preferences;
- notification controls;
- Next history controls.

Only expose controls that are actually implemented.

## Legal/policy reconciliation checklist

Before declaring the public Privacy Policy final:

- [ ] Verify live Otya auth/database fields and retention.
- [ ] Verify Cloudflare Worker logging/Analytics Engine behavior.
- [ ] Verify Resend transactional and marketing data flows.
- [ ] Verify Firebase production toggles and Play Console Data Safety declarations.
- [ ] Verify Next provider/content retention/training terms.
- [ ] Verify Google Drive backup payload and deletion/revocation behavior.
- [ ] Verify online music providers enabled in production.
- [ ] Verify website cookies/analytics and consent behavior.
- [ ] Publish external account-deletion path.
- [ ] Establish canonical Privacy Policy URL, version and effective date.
- [ ] Make signup consent, app links and website link to that same version.
- [ ] Archive superseded policies instead of leaving contradictory active copies.

## Naming

Public legal/trust copy uses **Otya**. Historical references such as Played may remain only in clearly archived historical documents.
