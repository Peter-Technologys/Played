<div align="center">

<img src="assets/branding/otya_mark.svg" alt="OTYA" width="112" height="112" />

# OTYA Player

**Video · Music · Transfer · Private · Ask OTYA**

A polished, offline-first Android media experience by PeterSmart Link.

[OTYA](https://petersmartlink.com/otya-player) · [Ask OTYA](https://petersmartlink.com/ask) · [Docs](https://petersmartlink.com/docs) · [Download](https://petersmartlink.com/download/otya-player) · [Security](SECURITY.md)

![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)
![Target](https://img.shields.io/badge/Android-API%2036-3DDC84)
![Status](https://img.shields.io/badge/Status-v1%20rebuild-6A19FF)
![License](https://img.shields.io/badge/License-Proprietary-critical)

</div>

---

## What OTYA is

OTYA Player is built around three primary destinations:

| Area | Purpose |
|---|---|
| **Video** | Local video library, folders, playlists, resume, subtitles, tracks, gestures, PiP, aspect controls, trim and audio extraction |
| **Music** | Songs, albums, artists, folders, playlists, queue, favorites, shuffle/repeat, lyrics, EQ, sleep timer, Drive Mode and background playback |
| **Me** | Transfer, Files, Private, Converter, Playlists, History, Tools, Personalize and Storage |

OTYA is offline-first. Local scanning, playback, queueing, Private and Transfer must remain useful without Cloudflare, Firebase, authentication, AI, Resend or update services.

## Ask OTYA

Ask OTYA is the user-facing assistant for help, learning and product guidance. It is optional and must never block local playback.

- branded OTYA thinking state rather than a generic spinner
- conversational follow-up questions
- suggested prompts and New Chat
- copy/retry and human-support handoff
- no Admin or private infrastructure capabilities

The private owner/admin experience is a separate product surface: **OTYA Command Center**.

## Privacy and security

- Core playback is local-first and does not require a permanent backend connection.
- Production secrets, signing material, Firebase Admin credentials and infrastructure tokens must never be bundled into Flutter.
- Private media uses app-private storage with device authentication and secure PIN fallback.
- Failed Private PIN attempts use persistent encrypted throttling.
- External writes from private Admin AI require explicit approval.
- Large media sharing uses Android `content://` access rather than exposing raw file URIs.
- Production releases must be signed and fail closed when signing credentials are missing.

## Android quality bar

OTYA targets Android API 36 and is being validated for:

- edge-to-edge layouts and responsive phone/tablet navigation
- 48dp minimum interactive touch targets
- adaptive + monochrome/themed launcher icon support
- audio focus, headset/call interruptions and background audio
- PiP, notifications and media controls
- Android 10–16 media/notification permission behavior
- real-device startup, crash and ANR testing

## Brand system

The canonical identity is the approved **twisted OTYA O**. The same geometry is used for the Android launcher, Flutter UI, Ask OTYA thinking state, website and documentation surfaces.

Do not introduce a generic play triangle, plain ring, alternate O shape or a second competing logo.

Canonical repository artwork: `assets/branding/otya_mark.svg`.

## Current release gate

The `v1-rebuild` branch remains the integration branch until all of these are complete:

1. source-complete feature surface
2. zero-issue Flutter analysis
3. all unit/widget tests passing
4. release APK/AAB compile and verification
5. real signed build
6. clean-install physical-device testing
7. startup/crash/ANR verification
8. Video/Music/player/Transfer/Private/App Lock acceptance
9. Firebase/FCM/App Check/account acceptance
10. offline/outage behavior verification

Do not merge, tag or publish a production release before the complete gate passes.

## Public surfaces

- OTYA Player: **https://petersmartlink.com/otya-player**
- Ask OTYA: **https://petersmartlink.com/ask**
- Docs: **https://petersmartlink.com/docs**
- Download: **https://petersmartlink.com/download/otya-player**
- Support: **support@petersmartlink.com**

## Source and licensing

OTYA Player is proprietary software. Source code, application design, backend integration code, release infrastructure, branding and project materials may not be copied, redistributed or commercially reused without written permission from PeterSmart Link, except where third-party components are separately licensed.

---

<div align="center">

**OTYA · PeterSmart Link**

One product identity across app, website, AI, Admin, email and release surfaces.

</div>
