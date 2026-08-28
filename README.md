<div align="center">

<img src="assets/icons/play_store_512.png" alt="OTYA Player" width="112" height="112" />

# OTYA Player

**Private. Powerful. Offline-first media.**

Private production source repository for OTYA Player by PeterSmart Link.

[OTYA](https://petersmartlink.com) · [Documents](https://petersmartlink.com/documents) · [Download](https://petersmartlink.com/download/otya-player) · [Security](SECURITY.md)

![Version](https://img.shields.io/badge/OTYA-1.7.0-6C5CE7)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)
![Status](https://img.shields.io/badge/Status-Production-2EA44F)
![License](https://img.shields.io/badge/License-Proprietary-critical)

</div>

---

## Repository purpose

This is the private production source repository for OTYA Player. It is intended for authorized development, CI/CD, security review and release engineering only.

Public product information, downloads, support notices and customer documentation should be published through the official OTYA website rather than exposing internal source or infrastructure details from this repository.

## OTYA Player

OTYA Player is designed around local-first playback: music and videos remain usable without a network connection, while the shared OTYA account, recovery, updates and optional online services connect securely to the OTYA backend when needed.

| Experience | Highlights |
|---|---|
| **Home** | Recent local media, quick access and media discovery |
| **Music** | Songs, albums, artists, folders and playlists |
| **Video** | Local video library, thumbnails, folders and playback |
| **My Space** | Tools, account, settings and personal media utilities |
| **Audio Player** | Queue, shuffle, repeat, speed control, EQ, lyrics, sleep timer and background playback |
| **Video Player** | Hardware-accelerated playback, subtitles, PiP, aspect controls, battery saver and gestures |
| **Beam** | Local Wi-Fi / hotspot file transfer designed to work without mobile data |
| **Safe** | Private media protection with device authentication, biometric unlock and PIN fallback |
| **Playlists** | Create, organize and play personal collections |
| **Themes** | Light, Dark, AMOLED and System appearance choices |
| **Account** | Shared OTYA authentication with email verification and password recovery |
| **OTYA AI** | Optional assistant available from Settings and Support; never required for local playback |
| **Google & Drive** | Google identity sign-in and explicit opt-in private recovery backup |
| **Updates** | Secure version checks and signed Android release delivery |

## Privacy and security principles

- Core local playback must not depend on a permanently available backend or AI service.
- Production secrets must never be committed or bundled into Flutter.
- The shared OTYA account provides identity across products, while product-specific private data remains separately scoped.
- Google Drive recovery is explicit and user-initiated.
- Recovery data must not upload a user's raw media library or Safe/private media.
- Production releases must be signed and fail closed when signing credentials are missing.
- Security reports must use the private process documented in [SECURITY.md](SECURITY.md).

## Release line

OTYA Player `1.7.0+11` is the current release line in this repository.

Release builds are produced by GitHub Actions, verified with checksums, and distributed through the official OTYA release infrastructure.

## Public access

Official public surfaces:

- OTYA: **https://petersmartlink.com**
- Documents: **https://petersmartlink.com/documents**
- OTYA AI: **https://petersmartlink.com/ai**
- Download: **https://petersmartlink.com/download/otya-player**

Do not publish source archives, internal deployment instructions, backend credentials, signing material, private endpoints or infrastructure inventories as customer documentation.

## Source and licensing

OTYA Player is proprietary software. The current source, application design, backend integration code, release infrastructure, branding and project materials may not be copied, redistributed, modified or commercially reused without written permission from PeterSmart Link, except where third-party components are separately licensed.

Historical copies previously distributed under another license remain governed by the license that accompanied those specific copies. See [LICENSE](LICENSE) for the current repository terms.

---

<div align="center">

**OTYA · PeterSmart Link**

Private production source. Public information lives on the official website.

</div>
