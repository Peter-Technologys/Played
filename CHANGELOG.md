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

## [1.3.3] — 2026-07-14

### Fixed
- **Cold-start crash** — added missing `MediaKit.ensureInitialized()` call; video playback was silently failing on many devices
- **ProGuard stripping** — added keep rules for `media_kit`, `media_kit_libs_android_video`, native JNI methods, `flutter_secure_storage` KeyStore provider, `androidx.startup`, `androidx.biometric`, and Google Play Services classes
- **Release build crash** — removed `--obfuscate` flag from CI builds; it was renaming Dart symbols and breaking WorkManager task dispatch and Hive adapter registration
- **Vault data loss** — vault encryption key fallback now persists to SharedPreferences instead of generating a throwaway random key that was lost on restart
- **Audio auto-advance on video** — fixed `skipToNext()` being called when a video file completed playback
- **Video player 60fps rebuilds** — throttled position `setState` to fire only when position changes by more than 500ms
- **Stacked stream subscriptions** — removed `_streamsAttached = false` from `AudioPlayerNotifier.load()` that was defeating the dedup guard
- **PiP race condition** — added `_pipInitialized` guard to prevent PiP being attempted before async init completes
- **Isolate platform channel crash** — `compute()` now falls back to main isolate on `IsolateSpawnException` since `MethodChannel` cannot cross isolate boundaries
- **MediaStore scan missing files** — receive-dir scan now always runs in parallel with MediaStore instead of only as a fallback
- **Memory pressure on large dirs** — receive-dir scan now processes in batches of 5 instead of all at once
- **Appwrite backup performance** — history and playlist backups now run in parallel chunks of 10/5 instead of sequentially
- **ABI detection** — replaced broken `Platform.environment['SUPPORTED_ABIS']` with `Abi.current()` from `dart:ffi`
- **MediaStore queries on main thread** — moved `queryAudio`, `queryVideo`, `getVideoThumbnail`, `getAlbumArt` to background coroutine scope
- **GitHub Actions secrets error** — moved all secret references to `env:` blocks; `secrets` context is not allowed in shell `if` expressions

### Changed
- `SystemChrome.setSystemUIOverlayStyle` moved out of `build()` into `initState` + `ref.listen` to avoid side-effects on every rebuild
- Appwrite history backup batched: 200 sequential HTTP calls reduced to parallel chunks of 10
- FFmpeg trim/extract operations moved from raw `Thread` to `kotlinx.coroutines` `Dispatchers.IO` scope

---

## [1.3.0] — 2026-07-07

### Added
- **Flash Share** — pure Dart HTTP P2P file sharing over local Wi-Fi, no Google Play Services or CMake required. QR code send/receive with real-time progress ring.
- **Web Mirror** — phone-to-PC browser streaming gateway on port 8085. Full HTML dashboard with search, stream, and download from any browser on the same Wi-Fi.
- **Vault XOR obfuscation** — header byte-shift (XOR first 512 bytes) runs in a background Isolate. Corrupts file format signatures so gallery apps cannot scan vault files.
- **Storage Analyzer** — multi-segment CustomPainter ring chart showing Videos, Audio, Cache, Other, and Free space. One-tap cache purge with bytes-freed confirmation.
- **Real-time Storage Watcher** — Directory.watch() stream with per-path debounce. Library auto-refreshes when files are added or removed by external apps.
- **Neon UI Toolkit** — ModernNeonContainer (4-layer BoxShadow glow), ModernNeonText (ShaderMask gradient), GlowingNeonProgressRing (CustomPainter SweepGradient), NeonMediaDashboard.
- **2027 MediaPlaybackHandler** — BaseAudioHandler with QueueHandler + SeekHandler. Full queue management, auto-advance, notification metadata updates before track load.
- **P2P Chat Service** — TCP socket chat on port 9091 with broadcast StreamController. ChatMessage model with typed factory constructors.
- **Glass Notification Banner** — Overlay floating banner with BackdropFilter blur, 4-second auto-dismiss, ChatNotificationMixin for zero-boilerplate integration.
- **Seasonal Theme Engine** — auto-detects Christmas, Halloween, New Year from DateTime. CustomThemeManager persists wallpaper to app sandbox.
- **Local TCP Event Pipeline** — LocalEventServer + LocalEventClient for device-to-device state sync.
- **Google Drive Backup** — pure http package, no native plugin. Multipart/related upload + PATCH overwrite.
- **Settings Service** — pure dart:io JSON serializer with atomic write (temp file + rename). IntentLauncher via Process.run('am', [...]) — no url_launcher plugin.
- **Settings Screen** — profile name, skip silence, lyrics toggle, default speed, storage analyzer, support links, legal.

### Fixed
- Vault OOM crash on large files: stream in 4 MB chunks instead of readAsBytesSync()
- Storage purge ConcurrentModificationError: collect entities before deleting
- df parsing failure on some Android versions
- Storage watcher single shared debounce replaced with per-path Map<String,Timer>
- Settings data loss on kill-mid-write: atomic write via temp file + rename
- Web Mirror path traversal vulnerability: validate path before serving
- nearby_connections removed: eliminated CMake native compilation CI timeout
- open_filex upgraded to ^4.7.0 (1.x was yanked from pub.dev)

### Changed
- Air-Drop screen renamed to Flash Share
- pubspec: nearby_connections replaced with qr_flutter + mobile_scanner
- CI: parallel Gradle builds, CMake cached, 45-minute build timeout

---

## [1.2.1] — 2026-07-06

### Added
- **Automated release pipeline** — GitLab CI/CD + GitHub Actions upload APKs to Cloudflare R2 on every `v*` tag
- **WorkManager update checker** — background check every 24 hours, no Firebase required
- **Update notifications** — high-priority local notification with "Download Now" / "Later" actions
- **Appwrite releases collection** — CI/CD writes release metadata; app reads it for update info
- **Device registration** — app registers device ID, ABI, and version in Appwrite on first launch
- **Rollback support** — previous 5 versions archived in R2 under `releases/v<version>/`
- **version.json generator script** — `scripts/generate_version_json.sh`
- **Rollback script** — `scripts/rollback.sh <version>`
- **versionCode comparison** — update checker now uses integer versionCode (not string) for reliable comparison
- **package_info_plus** — installed version read from OS, not hardcoded

### Changed
- `update_service.dart` — uses `package_info_plus` for installed versionCode; no more hardcoded `'1.2.0'`
- `environment.dart` — added Worker URL constants, releases + devices collection IDs
- `main.dart` — WorkManager initialized on startup; device registration + immediate update check run after first frame
- `pubspec.yaml` — added `workmanager`, `package_info_plus`

### Fixed
- `version.json` in CI now includes full shape: `versionCode`, `changelog`, `minSdk`, `targetSdk`
- GitLab pipeline: `version.json` uploaded AFTER APKs (Worker never points to missing files)
- GitHub Actions: dedicated `release.yml` with R2 upload (was missing from `build.yml`)

---

## [1.2.0] — 2026-06-18

### Added
- **Google Sign-In via Appwrite OAuth** — one-tap Google login, no email/password
- **Cloud backup** — playlists and play history backed up to Appwrite on sign-in
- **Cloud restore** — merge cloud playlists back to device
- **Profile & Settings screen** — unified screen behind the top-right avatar icon:
  Appearance, Account, Audio, Video, Privacy & Security, Backup & Sync, Library, About
- **What's New screen** — in-app release notes viewer
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

[Unreleased]: https://gitlab.com/updates1793427/apk-v1/played/-/compare/v1.2.1...HEAD
[1.2.1]: https://gitlab.com/updates1793427/apk-v1/played/-/compare/v1.2.0...v1.2.1
[1.2.0]: https://gitlab.com/updates1793427/apk-v1/played/-/compare/v1.1.0...v1.2.0
[1.1.0]: https://gitlab.com/updates1793427/apk-v1/played/-/compare/v1.0.0...v1.1.0
[1.0.0]: https://gitlab.com/updates1793427/apk-v1/played/-/tags/v1.0.0
