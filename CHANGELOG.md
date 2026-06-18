# Changelog

All notable changes to **OTYA Player** are documented here.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Chromecast / Cast to device
- Home screen now-playing widget
- Android Auto support
- iOS support

---

## [1.2.0] — 2026-06-18

### Added
- **Google Sign-In via Appwrite OAuth** — one-tap Google login, no email/password
- **Cloud backup** — playlists and play history backed up to Appwrite on sign-in
- **Cloud restore** — merge cloud playlists back to device
- **Profile & Settings screen** — unified screen behind the top-right avatar icon:
  Appearance, Account, Audio, Video, Privacy & Security, Backup & Sync, Library, About
- **What’s New screen** — in-app release notes viewer
- **Rebrand to OTYA Player** — new name, icon, gradient logo, package ID `com.otyaplayer.app`
- **Video thumbnails** — real frames extracted via `MediaMetadataRetriever`
- **Album art** — real cover art from MediaStore
- **File management** — rename and delete files from inside the app
- **LRC lyrics** — fetched and cached offline after first load
- **Auto-load subtitles** — `.srt`/`.ass` loaded automatically alongside videos
- **Folder pin** — pin favourite folders to the top of My Space
- **Playback speed memory** — default speed persisted in settings
- **Crossfade** — configurable 1–10 s blend between tracks
- **Skip silence** — auto-skip silent sections during playback
- **Auto Picture-in-Picture** — video floats when leaving the app
- **Pause during calls** — audio pauses automatically on incoming calls
- **App lock** — biometric gate on app open
- **Hide Vault from Recents** — blur screenshot when switching apps
- **Notification controls** — skip next/previous wired to lock screen and notification bar
- **Periodic library refresh** — 5-minute background timer + foreground resume scan
- **Shuffle fix** — replaced `DateTime.millisecond` with proper `List.shuffle()`
- **WhatsApp Trimmer** — offline trim using Android `MediaExtractor` + `MediaMuxer` (no FFmpeg binary)
- **Audio extract** — extract audio track from any video, fully offline

### Changed
- Settings moved into Profile screen (single unified screen, no duplicate)
- Nav bar: Settings icon removed, Profile avatar added to My Space header
- `build_runner` removed from CI — generated files committed, saves ~2 min per pipeline
- Release builds now trigger on version tags only (`v*`), not every `main` push
- Unit tests run on PRs only, not on every push

### Fixed
- `unawaited()` missing `dart:async` import in `appwrite_service.dart`
- `user.$id` backslash-escape parse errors causing 20+ analyzer errors
- `signInAnonymouslyIfNeeded()` call to non-existent method in `main.dart`
- Wrong import paths in `profile_screen.dart` (`../../settings/` → `../settings/`)
- `_ProfileNavItem` unused class removed from `router.dart`
- `isPro` unused parameter removed from `_NavItem`
- `final estimatedTotalSec` → `const` in `lyrics_screen.dart`
- Cold-launch race condition — audio handler retry loop until ready
- Vault playback path check corrected
- Missing closing brace in `_FoldersTabState`

### Removed
- **Studio** (Choir/Karaoke/DJ Drop) — depended on deleted Cloudflare workers and Spleeter API
- `ffmpeg_kit_flutter` — replaced with native `MediaExtractor`/`MediaMuxer`
- `shake_service.dart` — never wired up
- `sensors_plus` — removed from pubspec
- Anonymous Appwrite sessions — Google OAuth only

---

## [1.1.0] — 2026-06-14

### Added
- **Playlists** — create, rename, delete; add/remove tracks; drag-to-reorder; Play All
- **Mini player auto-show** — appears automatically when any track starts
- **MANAGE_EXTERNAL_STORAGE** — full SD card + all-folders indexing on Android 11+
- **Battery optimisation exemption** — prompts Unrestricted mode on first launch
- **RECEIVE_BOOT_COMPLETED** — background service restarts after reboot
- **SCHEDULE_EXACT_ALARM** — precise sleep timer on Android 12+
- **BootReceiver.kt** — Kotlin broadcast receiver for boot restart
- **network_security_config.xml** — cleartext for AdMob only, HTTPS enforced elsewhere
- **Open-with support** — OTYA Player appears in Android share sheet for audio/video files

### Fixed
- Mini player never appeared (`miniPlayerItemProvider` was never set)
- Permission gate now explains All Files Access and battery exemption
- Removed stale `FFmpegKitConfig` receiver
- ProGuard rules updated for Firebase + AdMob

---

## [1.0.0] — 2024-01-01

### Added
- **My Space** — unified media hub with Cinema shelf, Street Tapes shelf, Recently Played
- Sort & filter by date, name, size, duration
- **Audio Player** — shuffle, repeat, speed, EQ, lyrics, queue, sleep timer, favorites, share
- **Video Player** — VLC, subtitles, aspect ratio, PiP, battery saver, gesture controls
- **Air-Drop** — Wi-Fi Direct + Bluetooth file sharing
- **Vault** — AES-256 encrypted vault with biometric + PIN
- **Settings** — Appearance, Playback, Notifications, Privacy, Storage
- **Tools** — WhatsApp Trimmer
- Persistent mini player
- Hive offline database
- AMOLED dark neon theme

---

[Unreleased]: https://gitlab.com/apk-v1/played/-/compare/v1.2.0...HEAD
[1.2.0]: https://gitlab.com/apk-v1/played/-/compare/v1.1.0...v1.2.0
[1.1.0]: https://gitlab.com/apk-v1/played/-/compare/v1.0.0...v1.1.0
[1.0.0]: https://gitlab.com/apk-v1/played/-/tags/v1.0.0
