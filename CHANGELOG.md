# Changelog

All notable changes to **Played** are documented here.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Chromecast / Cast to device
- Offline LRC lyrics sync
- Home screen now-playing widget
- Android Auto support
- iOS support

---

## [1.1.0] — 2026-06-14

### Added
- **Playlists** — create, rename, delete playlists; add/remove tracks;
  drag-to-reorder; Play All button; wired into My Space header
- **Mini player auto-show** — mini player now appears automatically
  whenever any track starts playing (was never set before)
- **MANAGE_EXTERNAL_STORAGE** — full SD card + all-folders media indexing
  on Android 11+; non-blocking prompt to grant via Settings
- **Battery optimisation exemption** — prompts Unrestricted mode on first
  launch so Android never kills the background playback service
- **RECEIVE_BOOT_COMPLETED** — background service restarts after reboot
- **SCHEDULE_EXACT_ALARM** — precise sleep timer on Android 12+
- **BootReceiver.kt** — Kotlin broadcast receiver for boot restart
- **network_security_config.xml** — cleartext allowed only for AdMob
  domains; all other traffic enforced HTTPS
- **Open-with support** — PLAYED now appears in Android share sheet for
  audio/*, video/*, .ogg, and .mkv files
- **Playlists route** `/playlists` added to GoRouter

### Fixed
- Mini player never appeared (miniPlayerItemProvider was never set)
- Permission gate now explains All Files Access and battery exemption
- Removed stale FFmpegKitConfig receiver (package was already removed)
- ProGuard rules updated: removed arthenica, added Firebase + AdMob

---

## [1.0.0] — 2024-01-01

### Added
- **My Space** — unified media hub with Cinema shelf, Street Tapes shelf, Recently Played timeline
- Sort & filter files by date, name, size, duration
- **Audio Player** — shuffle, repeat (off/one/all), speed (0.5×–2×), EQ, lyrics, queue, sleep timer, favorites, share
- **Video Player** — hardware-accelerated VLC, subtitles, aspect ratio (Fit/Fill/16:9/4:3), PiP, battery saver mode, gesture controls (swipe brightness/volume/seek)
- **Air-Drop** — zero-data file sharing via Wi-Fi Direct + Bluetooth (Nearby Connections)
- **Studio** — Choir/Karaoke mode + DJ Drop mode with Spleeter stem splitting, offline cache
- **Vault** — AES-256 encrypted private media vault with biometric + PIN unlock
- **Settings** — Appearance (Dark/AMOLED/Light), Playback, Notifications, Vault, Privacy, Storage, Language
- **Tools** — WhatsApp Trimmer (30s / 16 MB compress)
- Persistent mini player across all tabs
- My Space centered in bottom nav with gradient glow button
- Onboarding screen (3 pages)
- Permission gate screen
- Hive offline database with AES-256 vault encryption
- SpaceGrotesk font throughout
- AMOLED dark neon theme (Electric Blue + Deep Violet)

---

[Unreleased]: https://gitlab.com/apk-v1/played/-/compare/v1.0.0...HEAD
[1.0.0]: https://gitlab.com/apk-v1/played/-/tags/v1.0.0
