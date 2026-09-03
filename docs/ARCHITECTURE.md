# Otya Architecture

Otya is an offline-first Flutter Android application with optional connected
services. Local media playback remains usable when Cloudflare, Firebase, Google
or Next is unavailable.

## Application structure

- `lib/features/` contains user journeys such as Video, Music, Me, Transfer,
  Private, account, tools and Next.
- `lib/core/` contains shared models, local persistence, playback, networking,
  security and platform services.
- `lib/shared/` contains reusable product UI.
- `packages/otya_media_tools/` contains Otya's Android media-tool bridge.
- `test/` contains regression and release-contract tests.

Riverpod owns application state, `go_router` owns navigation, Hive stores local
models and `media_kit` is the shared audio/video playback engine.

## Local data boundary

The media library, playback state, playlists, preferences and Private index are
stored on-device. Private media is moved into app-private storage and protected
by device authentication/PIN controls. Otya does not claim to receive or store
Android biometric templates.

Transfer is an authenticated same-Wi-Fi/hotspot protocol. It validates the Otya
sender marker, supported media types, declared sizes and local/private network
addresses. It is not a cloud file relay.

## Connected services

The Android app talks only to public HTTPS Otya surfaces. Cloudflare Workers own
the account, application API, release delivery and Next control plane. Firebase
provides optional messaging, App Check, analytics and performance collection.
Google Identity and the Drive app-data folder are used only for user-selected
sign-in/recovery flows. Resend handles service email.

Production secrets and privileged provider credentials remain server-side or in
protected CI storage. They must never be compiled into the APK.

## Release model

`main` is the only release branch. Every candidate must pass strict Flutter
analysis, tests, Android build checks and artifact-signature verification. The
`v1.0.0` tag builds signed ARM64/ARM32 APKs and an AAB, publishes versioned APKs
to Cloudflare R2, updates Otya release metadata and creates the GitHub Release.

The app version remains `1.0.0`; the build number may increase for first-release
fixes without changing the public version.
