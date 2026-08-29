<div align="center">

<img src="assets/branding/otya_mark.svg" alt="OTYA" width="112" height="112" />

# OTYA Player

**Private. Powerful. Offline-first media.**

OTYA Player by PeterSmart Link combines local video and music playback, local transfer/private tools, optional online services and Ask OTYA without making core playback depend on the cloud.

[OTYA](https://petersmartlink.com) · [Ask OTYA](https://petersmartlink.com/ask) · [Documents](https://petersmartlink.com/docs) · [Download](https://petersmartlink.com/download/otya-player) · [Security](SECURITY.md)

</div>

---

## Product surfaces

| Experience | Highlights |
|---|---|
| **Video** | Local video library, folders, playback, subtitles, PiP, gestures, aspect/orientation, queue and trim/extract |
| **Music** | Local songs, albums, artists, folders and playlists plus optional Online Music |
| **Online Music** | Provider-neutral OTYA catalog gateway; Jamendo is provider 1 for legal discovery/streaming and artist-permitted downloads |
| **Me** | Transfer, Files, Private, Converter, Playlists, History, Tools, Personalize and Storage |
| **Audio Player** | Queue, shuffle/repeat, speed, EQ, lyrics, sleep timer, background playback and media controls |
| **Transfer** | Authenticated same-Wi-Fi/hotspot streaming and resumable local transfer without mobile data |
| **Private** | App-private media protection with device authentication/biometrics and secure PIN fallback |
| **Ask OTYA** | Optional conversational assistant; never required for local playback |
| **Account** | OTYA-owned authentication, recovery, 2FA and optional Google sign-in |

## Online Music identity model

OTYA remains the user's main account and product identity. Public online music does not require a Jamendo account. OTYA-owned favorites/playlists remain separate from Jamendo.

If Jamendo account synchronization is introduced later, it must be an explicit user-selected OAuth connection. OTYA must never silently create a Jamendo account or attach one to an OTYA signup.

Jamendo catalog access is routed through the OTYA backend rather than hard-coded throughout Flutter. This lets OTYA cache catalog calls, enforce provider download permissions and add/change providers later without changing local playback architecture.

A Download action may be presented only when the provider returns permission for that track. Downloaded music belongs in user-visible Android music storage and should then appear in OTYA's normal local library.

## Privacy and security principles

- Core local playback must not depend on Cloudflare, Firebase, Jamendo, AI or any permanently available backend.
- Production secrets must never be committed or bundled into Flutter.
- The shared OTYA account provides identity across OTYA surfaces; third-party service connections remain explicit and separately revocable.
- Google Drive recovery is explicit and user-initiated.
- Recovery data must not upload a user's raw media library or Private media.
- Production releases must be signed and fail closed when signing credentials are missing.
- Security reports use the private process documented in [SECURITY.md](SECURITY.md).

## Release gate

The current v1 rebuild remains a Draft integration branch. It must not be merged, tagged or published until the current head passes strict Flutter analysis, all tests, Android/Kotlin release compilation, verified signed artifact checks and real-device acceptance on the target Samsung/Android range.

Official public surfaces:

- OTYA: **https://petersmartlink.com**
- Ask OTYA: **https://petersmartlink.com/ask**
- Documents: **https://petersmartlink.com/docs**
- Download: **https://petersmartlink.com/download/otya-player**

Do not publish source archives, internal deployment instructions, backend credentials, signing material, private endpoints or infrastructure inventories as customer documentation.

---

<div align="center">

**OTYA · PeterSmart Link**

</div>
