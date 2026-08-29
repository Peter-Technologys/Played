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
- Authentication: one OTYA Auth contract; local playback/scanning/transfer never require sign-in.
- Transfer: one OTYA Transfer engine and public vocabulary.
- Files: one file operations service.
- Private media: one OTYA Private/Safe service.
- Conversion/editing: one local native media processing service.
- Settings/preferences: one canonical settings store.
- Themes: one appearance/theme engine.
- Notifications: one notification router with transport adapters.
- Updates: one update/release service.
- Remote configuration: one Cloudflare-backed config contract.
- Crash/diagnostics: one diagnostics pipeline.

## Offline contract

Without internet, auth, AI or backend availability, OTYA must still start and support local media scanning, playback, playlists/history stored locally, local transfer, local tools and local settings.

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

Before v1 release verify: startup, scanning, audio/video playback, background audio, call interruption, gestures/orientation, subtitles/tracks, playlists/history, new-media discovery, transfer, files/private, converter/tools, search/help, Ask OTYA handoff, account/security, push/local notifications, updates, offline/backend outage states, Light/Dark/AMOLED, permissions, website mobile/desktop, admin operations and install/update behavior.