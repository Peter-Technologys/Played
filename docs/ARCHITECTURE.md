# Architecture — Played

## Overview

Played follows **Clean Architecture** with a **Feature-First** folder structure.
State is managed entirely with **Riverpod**. Navigation uses **go_router**.
All data is stored offline with **Hive**.

---

## Layers

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  Screens · Widgets · Providers (UI)     │
├─────────────────────────────────────────┤
│             Domain Layer                │
│         Use Cases · Entities            │
├─────────────────────────────────────────┤
│              Data Layer                 │
│   Repositories · Data Sources · Models  │
├─────────────────────────────────────────┤
│              Core Layer                 │
│  Database · Services · Utils · Models   │
└─────────────────────────────────────────┘
```

---

## Feature Structure

Each feature follows this pattern:

```
lib/features/<feature_name>/
├── data/
│   └── <feature>_repository.dart     # Data access
├── domain/
│   └── <feature>_use_case.dart       # Business logic
└── presentation/
    ├── <feature>_screen.dart          # Main screen
    ├── providers/
    │   └── <feature>_provider.dart   # Riverpod providers
    └── widgets/
        └── <widget>.dart             # Screen-specific widgets
```

---

## State Management

- **Riverpod** is used exclusively — no `setState` in feature screens.
- `FutureProvider` for async data (media scanning).
- `StateNotifierProvider` for mutable state (player, settings, queue).
- `StateProvider` for simple toggles (battery saver, controls visible).

---

## Navigation

All routes are defined in `lib/app/router.dart` using `go_router`.

| Route | Screen |
|---|---|
| `/` | My Space (home) |
| `/airdrop` | Air-Drop |
| `/studio` | Studio |
| `/settings` | Settings |
| `/vault` | Vault Lock Screen |
| `/player/audio` | Audio Player |
| `/player/video` | Video Player |
| `/player/equalizer` | Equalizer |
| `/tools/whatsapp` | WhatsApp Trimmer |

---

## Database

Hive is used for all local persistence:

| Box | Contents |
|---|---|
| `media_items` | Scanned media metadata |
| `playlists` | User playlists |
| `vault_items` | Encrypted vault entries |
| `stem_cache` | Cached stem split results |
| `seek_positions` | Resume positions per file |

The vault box uses AES-256 encryption via the `encrypt` package.

---

## Security

- Vault media is AES-256 encrypted at rest.
- Biometric authentication via `local_auth`.
- PIN fallback stored as a hashed value.
- Vault files are stored in the app's private directory (not accessible to other apps).
