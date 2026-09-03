# OTYA 1.0 feature-parity gate

OTYA must be functionally complete in source before the physical-device acceptance stage begins. A file, route, service or old donor implementation does not count as complete unless the user can reach it and its runtime owner is wired.

## Release rule

Physical-device testing starts only after every **required v1** row below is `complete` and the final source-complete commit passes Security, Flutter analysis/tests and release APK verification. Enhancements that were never shipped in the old app do not become release blockers merely because they are technically possible.

## Required v1 surfaces

| Surface | Required functionality | Source status |
| --- | --- | --- |
| Video library | local scan, folders, search/refresh, queue handoff | complete |
| Video player | playback, resume, seek, prev/next, speed, aspect mode, orientation, control lock, PiP, audio tracks, embedded subtitles, brightness/volume gestures, double-tap seek, 2x hold, share/details, trim, extract audio | complete |
| Music library | songs, albums, artists, folders, playlists, search/shuffle | complete |
| Music player | queue, prev/next, seek, resume, favorite, shuffle, repeat, speed memory, background/notification controls, lyrics, EQ, sleep timer, Drive Mode, share/details, Private/Transfer actions | complete |
| Downloads | Download/Downloads media view with All/Music/Video filters; files remain part of normal Video/Music library | complete |
| Me hub | Transfer, Files, Private, Converter, Playlists, History, Tools, Personalize, Storage | complete |
| Transfer | local-network-only sender/receiver, token authentication, streaming, collision-safe receive, safe resume, cancellation | complete |
| Private | app-private storage, device auth, Private PIN, secure PIN hashing, persistent retry throttle, lock lifecycle, safe restore/delete | complete |
| Converter | local video-to-audio extraction | complete for v1 |
| Tools | EQ and video trim | complete |
| Storage | storage report, cache clear, read-only Duplicate Finder | complete |
| Personalize | light/dark/AMOLED, themes, wallpaper, seasonal artwork | complete |
| App Lock | persisted setting, root app gate, device authentication, background relock | complete |
| Next | chat UI, scrolling, history within chat, copy, new chat, support handoff, offline-safe failure | complete |
| Account | email registration/login, Google sign-in, verification/recovery flows, consent, 2FA/recovery code, profile/session | complete |
| Backup | supported Google Drive playlist backup/restore | complete |
| Notifications | contextual permission, Now Playing/local task notifications, FCM registration, foreground/background push, safe route allow-list | complete |
| Updates | canonical OTYA update service; direct APK self-update separated from Play AAB update path | complete |
| What’s New / usage/history | release changes, playback history/recent activity and usage statistics routes | complete |
| Offline-first startup | UI/local library/playback are not blocked by Cloudflare, Firebase, auth, AI, Resend or update service | complete by architecture/tests |

## Final pre-device gate

1. The feature-surface regression contract must pass so required routes/actions cannot disappear silently.
2. Security must be green on the final source-complete commit.
3. `flutter analyze` and all unit/widget tests must be green on the final source-complete commit.
4. Release APK build, size budget and checksum verification must be green.

## Physical/pre-publication quality checks

These are important acceptance checks on already-working functionality rather than missing v1 features:

- verify custom audio/video controls and the Me avatar are comfortable and accessible on real phones; increase hit targets where required without visually inflating icons
- verify embedded subtitle behavior across files with zero, one and multiple subtitle tracks; a richer track chooser can be added if real-device testing shows the current toggle is insufficient
- verify text scaling, tablets/foldables, landscape, edge-to-edge and Android system gesture interaction
- verify large-library scrolling, memory, battery and media startup performance in profile/release mode

## Enhancements, not lost parity

These are valid future additions but were not present as working features in the previous main implementation and should not destabilize 1.0 merely to increase a feature count:

- Music Genres view (requires real metadata/schema/native scanner work)
- external subtitle-file browser and richer subtitle styling controls
- broader multi-format Converter workflows beyond video-to-audio extraction
- direct OTYA libmpv/VLC backend replacing MediaKit
- public OTYA Media SDK
- third-party developer API/SDK/MCP activation

## Physical acceptance stage

After the final pre-device CI gate passes, test clean installs and upgrades across supported Android versions and real devices. Verify playback, gestures, accessibility, interruptions/headsets, PiP, notifications, Transfer, Private, App Lock, tools, auth/Google/Firebase/FCM/App Check, Next, offline/outage behavior, website/account/admin, signed APKs and Play AAB behavior.

Do not merge, tag or publish until that acceptance stage passes.
