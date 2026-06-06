# PLAYED

> High-performance offline media player built for East Africa (Uganda & beyond).
> Optimized for low-end Android devices (2GB–4GB RAM, Android 9–14+).

---

## Features

| Tab | Feature |
|---|---|
| **My Space** | Unified media timeline, Cinema shelf (45min+ videos), Street Tapes shelf (DJ/Mix audio) |
| **Air-Drop** | 0MB data file sharing via Wi-Fi Direct + Bluetooth (Nearby Connections) |
| **The Studio** | Choir/Karaoke mode + DJ Drop mode with Spleeter API stem splitting |
| **Vault** | AES-256 encrypted private media vault with biometric + PIN lock |

## Architecture

```
Clean Architecture · Feature-First · Riverpod State Management
```

## Tech Stack

- **Playback**: flutter_vlc_player (hardware-accelerated, MKV/AVI/4K)
- **Database**: Hive (100% offline, AES-256 encrypted vault box)
- **Sharing**: nearby_connections (Wi-Fi Direct + Bluetooth)
- **Processing**: ffmpeg_kit_flutter (background MP4→MP3 extraction)
- **Audio Splitting**: Spleeter/Demucs API + permanent local cache
- **State**: flutter_riverpod
- **Navigation**: go_router
- **UI**: Dark Neon theme (AMOLED optimized), flutter_animate

## Getting Started

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## Build APK

```bash
flutter build apk --release --split-per-abi
```

## Project Structure

```
lib/
├── main.dart
├── app/           # Theme, router, app entry
├── core/          # Models, database, services, utils
└── features/
    ├── my_space/    # Tab 1 — unified media hub
    ├── player/      # Full-screen VLC player
    ├── air_drop/    # Tab 2 — offline file sharing
    ├── studio/      # Tab 3 — audio stem splitting
    └── vault/       # Encrypted private media vault
```

---

Built with Flutter · Dart · Clean Architecture
