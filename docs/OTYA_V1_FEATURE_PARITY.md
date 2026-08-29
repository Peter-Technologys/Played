# OTYA 1.0 feature-parity gate

OTYA must be functionally complete in source before the physical-device acceptance stage begins. A file, route, service or old donor implementation does not count as complete unless the user can reach it and its runtime owner is wired.

## Release rule

Physical-device testing starts only after every **required v1** row below is either `complete` or explicitly removed from the v1 product contract. Enhancements that were never shipped in the old app do not become release blockers merely because they are technically possible.

## Required v1 surfaces

| Surface | Required functionality | Source status |
| --- | --- | --- |
| Video library | local scan, folders, search/refresh, queue handoff | complete |
| Video player | playback, resume, seek, prev/next, speed, aspect mode, orientation, control lock, PiP, audio tracks, embedded subtitles, brightness/volume gestures, double-tap seek, 2x hold, share/details, trim, extract audio | complete except subtitle picker/external subtitle enhancement and custom-control accessibility pass |
| Music library | songs, albums, artists, folders, playlists, search/shuffle | complete |
| Music player | queue, prev/next, seek, resume, favorite, shuffle, repeat, speed memory, background/notification controls, lyrics, EQ, sleep timer, Drive Mode, share/details, Private/Transfer actions | complete except custom-control accessibility pass |
| Downloads | Download/Downloads media view with All/Music/Video filters; files remain part of normal Video/Music library | complete |
| Me hub | Transfer, Files, Private, Converter, Playlists, History, Tools, Personalize, Storage | complete; avatar accessibility pass pending |
| Transfer | local-network-only sender/receiver, token authentication, streaming, collision-safe receive, safe resume, cancellation | complete |
| Private | app-private storage, device auth, Private PIN, secure PIN hashing, retry throttle, lock lifecycle, safe restore/delete | complete in source; device acceptance pending |
| Converter | local video-to-audio extraction | complete for v1 |
| Tools | EQ and video trim | complete |
| Storage | storage report, cache clear, read-only Duplicate Finder | complete |
| Personalize | light/dark/AMOLED, themes, wallpaper, seasonal artwork | complete |
| App Lock | persisted setting, root app gate, device authentication, background relock | complete in source; device acceptance pending |
| Ask OTYA | chat UI, scrolling, history within chat, model selection when available, copy, new chat, support handoff, offline-safe failure | complete |
| Account | email registration/login, Google sign-in, verification/recovery flows, consent, 2FA/recovery code, profile/session | complete in source; backend acceptance pending |
| Backup | supported Google Drive playlist backup/restore | complete in source; account/device acceptance pending |
| Notifications | contextual permission, Now Playing/local task notifications, FCM registration, foreground/background push, safe route allow-list | complete in source; signed-build acceptance pending |
| Updates | canonical OTYA update service; direct APK self-update separated from Play AAB update path | complete in source |
| What’s New / usage/history | release changes, playback history/recent activity and usage statistics routes | complete |
| Offline-first startup | UI/local library/playback are not blocked by Cloudflare, Firebase, auth, AI, Resend or update service | complete by architecture/tests |

## Pre-device code tasks still open

1. Player accessibility: guarantee at least 48x48 logical-pixel touch targets for custom audio/video controls and the Me avatar without visually inflating icons.
2. Video subtitles: keep embedded subtitle support; add a proper track chooser. External subtitle-file selection is an enhancement unless it is deliberately promoted into the 1.0 contract.
3. Run repository-wide dead-action/placeholder review after each parity change and keep Flutter analyze/tests green.
4. Keep the release APK size/checksum workflow green on the final feature-complete commit.

## Enhancements, not lost parity

These are valid future additions but were not present as working features in the previous main implementation and should not destabilize 1.0 merely to increase a feature count:

- Music Genres view (requires real metadata/schema/native scanner work)
- broader multi-format Converter workflows beyond video-to-audio extraction
- direct OTYA libmpv/VLC backend replacing MediaKit
- public OTYA Media SDK
- third-party developer API/SDK/MCP activation

## Physical acceptance stage (blocked until the code gate above closes)

Once code parity is complete, test clean installs and upgrades across supported Android versions and real devices, then verify playback, interruptions/headsets, PiP, notifications, Transfer, Private, App Lock, tools, auth/Google/Firebase/FCM/App Check, Ask OTYA, offline/outage behavior, website/account/admin, signed APKs and Play AAB behavior.

Do not merge, tag or publish until that acceptance stage passes.
