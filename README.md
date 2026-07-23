<div align="center">

<img src="assets/icons/play_store_512.png" alt="OTYA Player" width="96" height="96" />

# OTYA Player

**Premium offline audio player — built for Android.**  
Play any audio file, 100% offline. No account required.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-00D4FF.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)]()
[![Version](https://img.shields.io/badge/Version-1.4.0-8A2BE2)]()

</div>

---

## Features

| Screen | What it does |
|---|---|
| **My Space** | Unified media hub — songs, folders tabs, recently played, search, sort, pin folders |
| **Audio Player** | Shuffle, repeat, speed (0.5×–2×), 5-band EQ, LRC lyrics, queue, sleep timer, share |
| **Air-Drop** | Zero-data file sharing via Wi-Fi Direct + Bluetooth (Nearby Connections) |
| **Vault** | Private media vault with biometric + PIN unlock |
| **Playlists** | Create, rename, reorder, play playlists |
| **Profile & Settings** | Google sign-in, cloud backup, appearance, audio, privacy |
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
│   ├── services/           # Auth, Cloudflare backup, Notification, Vault
│   └── utils/              # Formatters, helpers
├── features/
│   ├── my_space/           # Home tab — audio library
│   ├── player/             # Audio player, mini player, lyrics, EQ
│   ├── air_drop/           # Nearby Connections file sharing
│   ├── vault/              # Encrypted media vault
│   ├── playlists/          # Playlist management
│   ├── profile/            # Profile & Settings screen
│   └── settings/           # Settings provider, privacy policy
└── shared/
    ├── extensions/         # BuildContext extensions
    └── widgets/            # AdBannerSlot, LoadingShimmer, Logo
```

---

## Tech Stack

| Layer | Library |
|---|---|
| Audio playback | `media_kit` — hardware-accelerated, unified engine |
| Background audio | `audio_service` — lock screen controls, OS media notifications |
| Database | `hive` — 100% offline, AES-256 encrypted vault box |
| Cloud backup | Cloudflare Workers — playlist + history sync |
| Nearby sharing | `nearby_connections` — Wi-Fi Direct + Bluetooth |
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| UI / Animations | `flutter_animate`, AMOLED dark theme (violet + cyan) |
| Biometrics | `local_auth` — fingerprint + PIN vault unlock |
| Ads | `google_mobile_ads` |

---

## Getting Started

### Prerequisites

- Flutter `>=3.0.0` (stable channel)
- Android SDK 21+ (Android 5.0 minimum, 9.0+ recommended)
- Java 17

### Setup

```bash
git clone https://gitlab.com/apk-v1/played.git
cd played
flutter pub get
flutter run
```

### Build

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release — split APKs per ABI (smaller download)
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
git tag v1.2.0
git push origin v1.2.0
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
Built with ❤️ in Uganda · Flutter · Dart · Clean Architecture
</div>
