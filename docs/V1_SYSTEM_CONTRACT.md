# OTYA v1 System Contract

OTYA v1 is the first public product release. The previous app is a donor of proven functionality, not an architecture that must be preserved.

## Core rule

One responsibility has one owner. If two implementations do the same job, compare them, migrate the useful parts into the stronger implementation, test it, then delete the duplicate.

## Product structure

Main navigation is exactly: **Video | Music | Me**.

Search, Ask OTYA, Transfer, Files, Private, Converter, Playlists, History, Tools, Personalize, Storage, Account, Settings, Support, Updates and About are supporting capabilities, not extra apps.

## Single owners

- Playback: MediaKit playback engine and one queue contract.
- Media discovery: one Android MediaStore/local scanner.
- Search: one OTYA Search service; Video and Music use filters on the same engine.
- Product AI: one Ask OTYA client/backend contract.
- Authentication/session authority: OTYA Auth on Cloudflare; local playback/scanning/transfer never require sign-in.
- Email/password + OTP/2FA: OTYA Auth + Resend.
- Firebase Auth: optional linked identity provider only. Firebase UID never replaces the OTYA user id or OTYA session/JWT.
- Transfer: one OTYA Transfer engine and public vocabulary.
- Files: one file operations service.
- Private media: one OTYA Private/Safe service.
- Conversion/editing: one local native media processing service.
- Settings/preferences: one canonical settings store.
- Themes: one appearance/theme engine.
- Notifications: one OTYA notification router; Firebase Cloud Messaging is the Android remote-push transport.
- Updates/releases: Flutter UpdateService + Cloudflare/R2 release workflow. Firebase App Distribution is only a downstream test-build mirror.
- Remote configuration: Cloudflare `/api/app-config` is the app-facing control contract. Firebase Remote Config stores/mirrors only approved client presentation/experiment values behind Cloudflare.
- App attestation: Firebase App Check with Play Integrity on Android; Cloudflare verifies `X-Firebase-AppCheck`. Enforcement starts in monitor mode and must never block local playback.
- Product telemetry: Firebase Analytics and Firebase Performance may collect only when enabled by Cloudflare app config. Their failure is non-fatal.
- Crash/diagnostics: OTYA CrashReporter + Cloudflare. Do not add Firebase Crashlytics while this remains the canonical crash pipeline.
- Backend data/business logic: Cloudflare Workers + D1/KV/R2/Queues.

## Firebase / Cloudflare boundary

Cloudflare is OTYA's control plane. Firebase is used only where it is stronger for Android/device services.

Server-orchestrated Firebase capabilities:

- FCM push delivery
- Firebase Remote Config publishing/mirroring
- Firebase identity verification/linking
- Firebase App Distribution test-release mirroring

Device-required Firebase capabilities:

- App Check token creation
- Analytics event collection
- Performance telemetry

Cloudflare remotely enables/disables the device-required capabilities through OTYA app config. Firebase/Google outages must never stop the app from opening or using local media.

Do not add Firestore, Realtime Database, Firebase Storage, Cloud Functions or Crashlytics while D1/R2/Workers/OTYA CrashReporter remain the stronger canonical owners. Do not add Firebase A/B Testing while OTYA keeps its existing stable rollout/experiment engine; adopting Firebase A/B later requires replacing that owner rather than running both.

## Offline contract

Without internet, auth, AI or backend availability, OTYA must still start and support local media scanning, playback, playlists/history stored locally, local transfer, local tools and local settings.

No Firebase, Cloudflare, auth, AI, update or remote-config network operation may be required before the usable app shell is shown. Optional-service failures are isolated, timeout-safe and non-fatal.

## No placeholders

A feature does not appear in production UI unless its action works. Do not ship Coming Soon, fake buttons, dead routes or empty shells.

## Deletion rule

Do not delete a donor implementation until the replacement has tests and the relevant CI gate is green. Once the replacement is proven, remove obsolete duplicate code instead of keeping permanent compatibility wrappers for unreleased builds.

## First-release identity

- Product name: OTYA
- Public version line starts at 1.0.0.
- Keep Android package/signing identity unless a release requirement proves otherwise.
- Keep working Cloudflare resources, domains and secrets; simplify their contracts rather than recreating infrastructure without reason.

## Release gates

Before v1 release verify: startup, scanning, audio/video playback, background audio, call interruption, gestures/orientation, subtitles/tracks, playlists/history, new-media discovery, transfer, files/private, converter/tools, search/help, Ask OTYA handoff, account/security, push/local notifications, App Check monitor/enforcement transition, Firebase Analytics/Performance policy, updates, offline/backend/Firebase outage states, Light/Dark/AMOLED, permissions, website mobile/desktop, admin operations, Firebase Remote Config sync, App Distribution mirror and install/update behavior.