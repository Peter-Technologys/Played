<div align="center">

<img src="assets/branding/otya_mark.svg" alt="Otya" width="112" height="112" />

# Otya

**Private. Powerful. Offline-first media.**

Otya by PeterSmart Link combines local video and music playback, local Transfer and Private tools, optional online services, and Next without making core playback depend on the cloud.

[Otya](https://petersmartlink.com) · [Next](https://petersmartlink.com/ask) · [Help & docs](https://petersmartlink.com/docs) · [Download](https://petersmartlink.com/download/otya-player) · [Security](SECURITY.md)

</div>

---

## Product surfaces

| Experience | Highlights |
|---|---|
| **Video** | Local video library, folders, playback, subtitles, PiP, gestures, aspect/orientation, queue and trim/extract |
| **Music** | Local songs, albums, artists, folders and playlists plus optional Online Music |
| **Online Music** | Provider-neutral Otya catalog gateway; Jamendo is the current independent-music provider for legal discovery/streaming and artist-permitted downloads |
| **Me** | Transfer, Files, Private, Converter, Playlists, History, Tools, Personalize and Storage |
| **Audio Player** | Queue, shuffle/repeat, speed, EQ, lyrics, sleep timer, background playback and Android media controls |
| **Transfer** | Authenticated same-Wi-Fi/hotspot streaming and resumable local transfer without a cloud relay |
| **Private** | App-private media protection with device authentication/biometrics and PIN fallback |
| **Next** | Optional conversational assistant; never required for local playback |
| **Account** | Otya-owned authentication, recovery, 2FA and optional Google sign-in |

## Product identity

- **Otya** is the product name. Public copy uses `Otya`, not all-caps `OTYA`.
- **Next** is the assistant inside Otya. Legacy `Ask OTYA` wording is not canonical public copy.
- Package IDs, database fields, route names, historical filenames and compatibility identifiers may retain legacy naming where changing them would break compatibility.

## Online Music identity model

Otya remains the user's main account and product identity. Public online music does not require a Jamendo account. Otya-owned favorites and playlists remain separate from provider accounts.

Catalog access is routed through the Otya backend rather than hard-coded throughout Flutter. A Download action may be presented only when the provider reports that download is permitted for that track.

## Privacy and security principles

- Core local playback must not depend on Cloudflare, Firebase, Jamendo, AI, or a permanently available backend.
- Production secrets must never be committed or bundled into Flutter.
- The shared Otya account provides identity across Otya surfaces; third-party service connections remain explicit and separately revocable.
- Google Drive recovery is explicit and user-initiated.
- Recovery data must not upload a user's raw media library or Private media.
- Production releases must be signed and fail closed when signing credentials are missing.
- Security reports use the private process documented in [SECURITY.md](SECURITY.md).

## Release status

Otya `1.0.0+1` is the intended first public release and is currently in final reliability/real-device acceptance. Passing source analysis or CI is not the same as release acceptance.

Do not merge, tag, publish, or describe v1 as released until the current acceptance gate has passed: clean install, playback/media-session behavior, auth/Google/OTP/2FA, notifications, Transfer, Private restore, update flow, signed ARM32/ARM64 artifacts, and live website smoke testing.

## Documentation boundaries

The repository contains engineering documentation. Customer-facing help, legal policies, release announcements and trust information must have one canonical public source and must not expose internal deployment instructions, backend credentials, signing material, private endpoints, or infrastructure inventories.

See [docs/PUBLIC_SURFACE_GOVERNANCE.md](docs/PUBLIC_SURFACE_GOVERNANCE.md) for the public-information model.

Official public surfaces:

- Otya: **https://petersmartlink.com**
- Next: **https://petersmartlink.com/ask**
- Help & docs: **https://petersmartlink.com/docs**
- Download: **https://petersmartlink.com/download/otya-player**

---

<div align="center">

**Otya · PeterSmart Link**

</div>
