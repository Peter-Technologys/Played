# OTYA v1 System Contract

This document is the ownership contract for the OTYA 1.0 rebuild. A feature is not considered complete because it compiles; its UI, behavior, error state, offline behavior, platform integration and tests must agree with this contract.

## Product shell

OTYA has three primary destinations only:

- **Video** — local videos, folders and playback.
- **Music** — local songs, albums, artists, folders, playlists and background audio.
- **Me** — the 3×3 product map plus Account, Settings, Support and About.

Me contains exactly:

1. Transfer
2. Files
3. Private
4. Converter
5. Playlists
6. History
7. Tools
8. Personalize
9. Storage

Downloads are a Files/local-media view, not a fourth primary destination. Ask OTYA is reached through Search/Support, not a bottom-navigation tab.

## Offline-first startup

Local playback and local library access are the critical path. OTYA must reach a usable local UI without waiting for:

- Cloudflare
- Firebase
- authentication
- Ask OTYA
- Resend
- remote config
- update checks
- seasonal/online themes

Remote services start after the first Flutter frame and fail non-fatally.

## Single owners

| Responsibility | Canonical owner |
| --- | --- |
| Video/audio playback | MediaKit + OTYA playback coordinator |
| Local media discovery | Android MediaStore through one OTYA media repository/provider |
| Playback queue | OTYA queue provider |
| OTYA account/session authority | Cloudflare `otya-auth` |
| Email/password + OTP/2FA | OTYA Auth + Resend |
| Firebase/Google identity | Linked identity behind OTYA Auth |
| Push transport | Firebase Cloud Messaging |
| Server push decisions | Cloudflare |
| Canonical application/account data | D1 |
| Sessions/rate limits/fallback config | KV |
| Release/file objects | R2 |
| Ask OTYA | OTYA AI/Cloudflare backend |
| Crash diagnostics | OTYA Cloudflare CrashReporter |
| Client experiment/presentation config | Firebase Remote Config, proxied/cached by Cloudflare |
| Server safety config | Cloudflare |
| Android app attestation | Firebase App Check + Cloudflare verification |
| Android usage/performance telemetry | Firebase Analytics/Performance behind Cloudflare policy |
| Tester APK mirror | Firebase App Distribution after the canonical OTYA release |

No Firestore, Realtime Database, Firebase Storage, Firebase Functions or duplicate Crashlytics backend is part of v1.

## Firebase rule

Cloudflare remains the OTYA control plane. The Android app must never contain Firebase service-account credentials.

Cloudflare may use server credentials/API access for FCM, Remote Config, Firebase identity verification and App Distribution. Device-only services such as App Check, Analytics and Performance use the minimum required client SDK and remain remotely governed through OTYA configuration.

The Flutter app does **not** use the Firebase Remote Config client SDK. It reads one OTYA `/api/app-config` response from Cloudflare, which composes server-critical Cloudflare config with cached Firebase-owned client parameters.

## Search and AI

There is one OTYA Search. It searches local content first:

- songs and videos
- albums
- artists
- folders
- playlists
- offline OTYA help

Ask OTYA is a friendly general-purpose assistant with additional OTYA product context. It is offered after local/help results or when the user explicitly opens Ask OTYA. Public Ask OTYA does not receive unrestricted D1/R2/Firebase/admin credentials.

Private Admin AI uses separately authorized, approved internal tools. Secrets, OTPs, refresh tokens and service-account keys are never exposed to the model.

## Transfer

OTYA Transfer is local-network only for v1. It uses direct HTTP over the current Wi-Fi/hotspot, a random one-time transfer token, streamed file IO and HTTP range resume.

Resume must be bound to the same transfer identity. A different transfer with the same filename must never append to unrelated partial bytes. Same-name completed files use a safe unique destination.

Because dynamic local-network HTTP requires Android cleartext allowance, the receiver must accept only the OTYA transfer protocol: private/loopback IPv4, `/media`, and a cryptographically random 64-hex token. Arbitrary cleartext internet URLs are not valid OTYA transfers.

Transfer remains usable without an OTYA account.

## Private

Private is local protected media. User-facing copy says **Private**, not Safe or Vault. Platform storage implementation names may remain internal.

Private authentication uses device authentication and/or local PIN fallback. Protected media must auto-lock after the configured session timeout and remain local unless the user explicitly performs a separate cloud/account action.

## Media tools

Converter and Trim are local operations. Android native media muxing is used instead of bundling a large FFmpeg binary.

Generated media must be published to user-visible shared storage using modern MediaStore on Android 10+:

- video output → `Movies/OTYA`
- audio output → `Music/OTYA`

Temporary/app-private output is not the final user result.

## Android platform ownership

`MainActivity` is a bridge, not a second application controller. It may own:

- MediaStore APIs
- PiP bridge
- brightness/volume bridge
- Android equalizer bridge
- local media muxing
- file operations requiring Android APIs

Flutter owns:

- playback state
- call/audio interruption pause/resume decisions through the shared audio session
- updates
- navigation
- product state
- remote configuration behavior

Native update scheduling/boot receivers are not part of v1.

## Permissions

Request only permissions used by current product features. OTYA must not request broad all-files, image-library, Bluetooth/location or background permissions merely because old donor features once used them.

Current legitimate categories include media audio/video read access, notifications, camera for Transfer QR scanning, biometric authentication, network/Wi-Fi access and playback foreground service.

## Performance and adaptive quality

OTYA must remain responsive on lower-end Android phones and adapt to tablets, foldables and multi-window layouts.

- Expensive library computations that can exceed a frame budget must not run synchronously on Flutter's UI isolate.
- Large user-selected images must be decoded near their display size rather than unbounded source resolution where practical.
- Navigation adapts from bottom navigation to a navigation rail based on available window width, not device-type detection.
- Local playback, scrolling and gestures are evaluated in profile/release-like builds on physical devices, not judged from debug/emulator performance alone.
- Custom interactive controls must preserve accessible touch targets even when the visible artwork is compact.

## Trusted web and update surfaces

OTYA's in-app WebView is a trusted product surface, not a general browser. Only official `petersmartlink.com` HTTPS pages may execute inside its unrestricted JavaScript context; off-domain links open in the system browser.

Update metadata may only launch official PeterSmart Link HTTPS destinations. OTYA does not request package-installer permission and does not silently install APKs.

## Updates and releases

Flutter `UpdateService` is the only app update owner. `/latest` is the canonical release metadata endpoint. Compatibility endpoints may adapt to it but must not become separate authorities.

A release becomes valid in Cloudflare/R2/D1 first. Firebase App Distribution is only a best-effort tester mirror and may never invalidate a successful OTYA release.

## Branding and language

OTYA uses one visible product identity across launcher, startup, app headers and website. Do not create unrelated generic play marks for individual surfaces.

OTYA v1 advertises only languages for which OTYA's own strings are actually translated. Partial framework localization is not a translated product.

## Release gate

Do not merge the v1 rebuild until all applicable gates are green:

- Flutter analyze
- unit/widget tests
- Security workflow
- ARM64/ARM32 release APK build and checksum verification
- server Security
- full Cloudflare validation
- clean-install and upgrade testing
- airplane-mode startup
- local video/music playback
- queue/background/headset/call/PiP behavior
- gestures/subtitles/orientation
- Search/Files/Downloads/Transfer/Private/Converter/Playlists
- account/OTP/identity/session flows
- FCM/App Check/config/update behavior
- website/account/support/admin mobile + desktop
- Cloudflare/Firebase/AI/Resend outage behavior
- physical-device profile/release performance checks including startup, first-frame playback, 30-second smooth playback, memory/bitmap pressure and ANR/crash observation

CI success is necessary but not sufficient; device acceptance is required for platform and UX behavior.
