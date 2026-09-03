# Otya Changelog

This changelog describes public Otya releases. Earlier prototype version labels
are preserved in Git history and are not public Otya releases.

## [1.0.0] — 2026-09-03

### Highlights

- Offline-first local music and video libraries with background playback,
  subtitles, Picture-in-Picture, queue controls, speed controls and EQ.
- Me hub for Transfer, Files, Private, playlists, history, tools,
  personalization and storage.
- Authenticated same-Wi-Fi/hotspot Transfer with resume and integrity checks.
- Private app storage protected by device authentication and secure PIN fallback.
- Optional Otya account with recovery, 2FA, Google sign-in and user-selected
  Google Drive playlist recovery.
- Optional Next assistant that does not block local playback.
- English and Luganda localization foundations and a modern adaptive Otya icon.

### Reliability and security

- Hardened startup so network, Firebase, update and Next failures remain
  non-blocking.
- Fixed playback switching, notification metadata, video PiP state, transfer
  resume, Private collision handling, trim ranges and runtime ABI selection.
- Removed retired Online Music/Jamendo/Spotify paths from the v1 product.
- Added strict analysis, regression tests, secret scanning and signed APK/AAB
  verification to the release pipeline.
- Added Cloudflare-hosted release metadata with architecture-specific downloads
  and short-lived update aliases.

### Distribution

- Signed ARM64 and ARM32 APKs for direct public testing.
- Signed Android App Bundle for later store submission.
- Canonical download and release information at petersmartlink.com.
