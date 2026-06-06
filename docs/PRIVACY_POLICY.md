# Privacy Policy — Played

**Last updated:** January 2024

---

## Overview

Played is an **offline-first** media player. We are committed to your privacy.

---

## Data We Collect

**We do not collect any personal data.**

All data processed by Played stays on your device:

| Data | Where it's stored | Shared? |
|---|---|---|
| Media file metadata (title, artist, duration) | Local Hive database | ❌ Never |
| Playback history & seek positions | Local Hive database | ❌ Never |
| Vault media (encrypted) | App private directory | ❌ Never |
| Settings & preferences | Local Hive database | ❌ Never |
| Stem split results (Studio) | Local cache directory | ❌ Never |

---

## Permissions

| Permission | Why it's needed |
|---|---|
| `READ_EXTERNAL_STORAGE` / `READ_MEDIA_*` | Scan device for audio & video files |
| `WRITE_EXTERNAL_STORAGE` | Save trimmed/extracted files to Downloads |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | Vault biometric unlock |
| `NEARBY_WIFI_DEVICES` / `BLUETOOTH` | Air-Drop file sharing |
| `POST_NOTIFICATIONS` | Now-playing media notification |
| `INTERNET` | Fetch lyrics (lyrics.ovh API) · Studio stem splitting API |

---

## Third-Party Services

| Service | Purpose | Data sent |
|---|---|---|
| lyrics.ovh | Fetch song lyrics | Song title + artist name only |
| Spleeter/Demucs API | Audio stem splitting | Audio file (only when you use Studio) |
| Google Mobile Ads | Non-intrusive banner ads | Standard ad identifiers (can be opted out) |

---

## Air-Drop

Files shared via Air-Drop are transferred **directly device-to-device** using Wi-Fi Direct and Bluetooth. No data passes through any server.

---

## Children's Privacy

Played is not directed at children under 13. We do not knowingly collect data from children.

---

## Changes to This Policy

Any changes will be reflected in the app and in this document with an updated date.

---

## Contact

For privacy questions, contact the maintainer via [GitLab](https://gitlab.com/apk-v1).
