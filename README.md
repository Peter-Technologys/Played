<div align="center">

<img src="assets/icons/app_icon.png" alt="Played Logo" width="96" height="96" />

# PLAYED

**High-performance offline media player built for East Africa.**  
Optimized for Android 9–14+ · 2 GB–4 GB RAM devices · 100% offline-first.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-00D4FF.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)]()
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20Feature--First-7C3AED)]()

</div>

---

## ✨ Features

| Screen | What it does |
|---|---|
| 🏠 **My Space** | Unified media hub — Cinema shelf (45 min+ videos), Street Tapes shelf (DJ/mix audio), Recently Played timeline, sort & search |
| 📡 **Air-Drop** | Zero-data file sharing via Wi-Fi Direct + Bluetooth (Nearby Connections API) |
| 🎤 **Studio** | Choir/Karaoke mode + DJ Drop mode — splits any track into vocals & instrumental via Spleeter, cached offline |
| 🔒 **Vault** | AES-256 encrypted private media vault with biometric + PIN unlock |
| ▶️ **Audio Player** | Shuffle, repeat, speed, EQ, lyrics, queue, sleep timer, favorites, share |
| 🎬 **Video Player** | Hardware-accelerated VLC, subtitles, aspect ratio, PiP, battery saver, gesture controls |
| ⚙️ **Settings** | Appearance, playback, notifications, vault, privacy, storage, language |

---

## 🏗 Architecture

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
│   ├── models/             # MediaItem, Playlist, VaultItem, StemCache
│   ├── permissions/        # Permission gate screen
│   ├── services/           # FFmpeg, MediaScanner, Notification, PiP, Vault
│   └── utils/              # DurationFormatter, ShelfSorter
├── features/
│   ├── my_space/           # Home tab — shelves, search, sort
│   ├── player/             # Audio + Video full-screen players, mini player
│   ├── air_drop/           # Nearby Connections file sharing
│   ├── studio/             # Stem splitting (Karaoke + DJ Drop)
│   ├── vault/              # Encrypted media vault
│   ├── settings/           # All app preferences
│   └── tools/              # WhatsApp trimmer
└── shared/
    ├── extensions/         # BuildContext extensions
    └── widgets/            # NeonButton, LoadingShimmer, AdBannerSlot
```

---

## 🛠 Tech Stack

| Layer | Library |
|---|---|
| Video playback | `flutter_vlc_player` — hardware-accelerated, MKV/AVI/4K |
| Audio playback | `just_audio` + `audio_session` |
| Processing | `ffmpeg_kit_flutter` — MP4→MP3 extraction, trimming |
| Audio splitting | Spleeter/Demucs API + local stem cache |
| Database | `hive` — 100% offline, AES-256 encrypted vault box |
| Sharing | `nearby_connections` — Wi-Fi Direct + Bluetooth |
| State | `flutter_riverpod` |
| Navigation | `go_router` |
| UI / Animations | `flutter_animate`, AMOLED dark neon theme |
| Auth | `local_auth` — biometrics + PIN |

---

## 🚀 Getting Started

### Prerequisites

- Flutter `>=3.0.0`
- Android SDK 21+ (Android 5.0 Lollipop minimum, 9.0 Pie recommended)
- Java 17

### Setup

```bash
# Clone the repo
git clone https://gitlab.com/apk-v1/played.git
cd played

# Install dependencies
flutter pub get

# Generate Hive adapters & Riverpod code
flutter pub run build_runner build --delete-conflicting-outputs

# Run on a connected device
flutter run
```

### Build APK

```bash
# Split APKs per ABI (recommended — smaller download size)
flutter build apk --release --split-per-abi

# Universal APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/`

---

## 📋 Roadmap

- [ ] iOS support
- [ ] Playlist creation & management
- [ ] Chromecast / Cast to device
- [ ] Offline lyrics sync (LRC files)
- [ ] Widget (home screen now-playing)
- [ ] Background audio with Android Auto support
- [ ] Cloud backup for Vault

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🔐 Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

---

## 📄 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

<div align="center">
Built with ❤️ in Uganda · Flutter · Dart · Clean Architecture
</div>
