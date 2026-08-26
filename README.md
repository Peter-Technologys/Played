<div align="center">

<img src="assets/icons/play_store_512.png" alt="OTYA Player" width="96" height="96" />

# OTYA Player

**Premium offline media player — built for Android.**  
Play any audio or video file, 100% offline. No account required.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-00D4FF.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)]()
[![Version](https://img.shields.io/badge/Version-1.6.0-8A2BE2)]()

</div>

---

## OTYA System

OTYA Player is the official Android media product of **OTYA System**. Authentication, platform APIs, updates, downloads and account services are provided by the OTYA platform backend.

## Features

| Screen | What it does |
|---|---|
| **My Space** | Unified media hub — songs, videos, folders tabs, recently played, search, sort, pin folders |
| **Audio Player** | Shuffle, repeat, speed (0.5×–2×), 5-band EQ, LRC lyrics, queue, sleep timer, share |
| **Video Player** | Hardware-accelerated media playback, subtitles, aspect ratio, PiP, battery saver, gesture controls |
| **Air-Drop** | Zero-data file sharing over supported local connectivity |
| **Vault** | Private media vault with biometric + PIN unlock |
| **Playlists** | Create, rename, reorder, play playlists |
| **Profile & Settings** | Account, cloud backup, appearance, audio and privacy settings |
| **Tools** | Browse by Folder, Storage Cleaner |

---

## Architecture

```
Clean Architecture · Feature-First · Riverpod · Offline-First
```

```
lib/
├── main.dart
├── app/
│   ├── app.dart            # MaterialApp entry
│   ├── router.dart         # go_router — all routes
│   └── theme/              # AppColors, AppTextStyles, AppTheme
├── core/
│   ├── database/           # Hive setup, adapters
│   ├── models/             # MediaItem, Playlist, VaultItem
│   ├── permissions/        # Permission helper
│   ├── services/           # Auth, OTYA backend, notifications, vault
│   └── utils/              # Formatters, helpers
├── features/
│   ├── my_space/           # Home tab — media library
│   ├── player/             # Audio + Video players, mini player, lyrics, EQ
│   ├── air_drop/           # Local file sharing
│   ├── vault/              # Encrypted media vault
│   ├── playlists/          # Playlist management
│   ├── profile/            # Profile & Settings screen
│   ├── settings/           # Settings provider, privacy policy
│   ├── video/              # Video tab screen
│   └── tools/              # Tools tab screen
└── shared/
    ├── extensions/         # BuildContext extensions
    └── widgets/            # AdBannerSlot, LoadingShimmer, Logo
```

---

## Tech Stack

| Layer | Library |
|---|---|
| Video & Audio playback | `media_kit` — unified audio + video engine |
| Background audio | `audio_service` — lock-screen and OS media controls |
| Offline trim/extract | Android native media APIs |
| Database | `hive` — local encrypted storage |
| Cloud backup | OTYA Backend on Cloudflare Workers |
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| UI / Animations | `flutter_animate`, AMOLED dark theme |
| Biometrics | `local_auth` |
| Ads | `google_mobile_ads` |

---

## Getting Started

### Prerequisites

- Flutter stable
- Android SDK 21+ (Android 5.0 minimum)
- Java 17

### Setup

Clone the GitHub repository and run it from the repository root:

```bash
git clone https://github.com/PeterSmartLink/OtyaPlayer.git
cd OtyaPlayer
flutter pub get
flutter run
```

### Build

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release — split APKs per ABI
flutter build apk --release --split-per-abi

# App Bundle (Play Store)
flutter build appbundle --release
```

---

## CI / CD

Builds run on **GitHub Actions** (`.github/workflows/build.yml`).

| Trigger | Jobs |
|---|---|
| Pull request | Analyze, Unit tests, Debug APK |
| Push to `main` | Analyze only |
| Version tag `v*` | Signed release AAB + split APKs → GitHub Release |

**To publish a release:**
```bash
git tag v1.6.0
git push origin v1.6.0
```

---

## Roadmap

- [ ] Chromecast / Cast to device
- [ ] Home screen now-playing widget
- [ ] Android Auto support
- [ ] iOS support

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center">
Part of OTYA System · Built with Flutter and Dart
</div>
