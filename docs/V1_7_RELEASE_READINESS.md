# OTYA Player v1.7.0 — Production Readiness Gates

v1.7.0 is not release-ready until every gate below is verified on an installed release-signed APK and the deployed production backend.

## Identity, account and legal
- Email/password registration and login work against production.
- Google Sign-In works on the release-signed Android package and links by verified email to the same OTYA account.
- Email verification OTP is delivered, uses 5 segmented inputs, expires correctly and rate limits safely.
- Password reset OTP is delivered and reset invalidates/revokes appropriate sessions.
- Welcome, verification, password-reset and security emails are personalized and branded.
- Terms of Service and Privacy Policy acceptance is mandatory at account creation.
- Marketing/news/promotions consent is separate, optional, recorded with timestamp/version and can be changed later.
- Material Terms/Privacy changes can require re-acceptance without treating legal notices as marketing.
- Account deletion removes cloud account data while preserving local user media.
- Sign out and token refresh/revocation are verified.

## Communications
- Transactional/legal email does not depend on marketing consent.
- Promotional/news/announcement delivery only targets opted-in users.
- Automated mail uses noreply@petersmartlink.com; human support uses support@petersmartlink.com.
- Email provider failures are observable and do not silently masquerade as successful delivery.
- Bounce/complaint/unsubscribe handling is defined before promotional campaigns are enabled.

## Navigation and UI
- Watch, Listen and Hub are the persistent primary app destinations.
- Account, Settings, Appearance, Downloads, Equalizer and other secondary screens always provide a clear way back into the app.
- Each feature has one owning screen; other locations only link to it and do not duplicate controls.
- No placeholder, duplicate or dead screens remain.
- Hub labels do not truncate critical feature names.
- UI matches the approved premium dark/cyan-violet-pink visual direction consistently.

## Media
- Video thumbnails work on real-device release APKs for MediaStore and file-path media.
- Music embedded artwork is extracted where available; fallback artwork is intentional and consistent.
- Audio/video playback, seeking, resume, queue, shuffle, repeat and speed work.
- Background playback, lock-screen controls, Bluetooth/media buttons and foreground notification work.
- Call/audio-focus interruptions pause/resume correctly.
- Video orientation/fullscreen/gestures work.
- Scanner/database initialization and offline startup remain stable.

## Onboarding, branding and assets
- Onboarding images are packaged and render in the release APK with no broken-image state.
- Final OTYA logo/icon replaces legacy launcher, adaptive, monochrome, splash, notification and in-app branding assets.
- Themes use valid packaged/remote assets and user-selected themes override automatic themes.

## Notifications and updates
- Android notification permission is requested at the appropriate time.
- Playback and update notifications use valid channels and work on Android 13+.
- v1.7.0 reports its correct version/build number.
- Update API, download, checksum/ABI selection and install handoff are verified.

## Backend and infrastructure
- Auth Worker and main Worker deploy successfully from GitHub Actions.
- D1 schemas/migrations are verified in production before release.
- KV/R2/queues/service bindings remain required and healthy.
- Resend, Google OAuth, JWT/internal secrets stay server-side.
- Health checks and analytics do not expose sensitive data.
- Release workflow and cache normalization are verified.
- No legacy Cloudflare Email binding paths remain in production behavior.

## Security, privacy and reliability
- No secrets are bundled in Flutter or committed to source control.
- Secure token storage is verified.
- Rate limits cover registration, login, OTP and Google auth.
- Backup/restore encryption and Google Drive app-data behavior are verified end to end.
- Privacy policy accurately reflects collected data, analytics, notifications, backups and communications.
- Crash/startup regression test passes from clean install and upgrade install.

## Release acceptance
- Static analysis and automated tests pass.
- Release APK builds with production configuration and release signing.
- Clean-install test passes.
- Upgrade-from-v1.6 test passes without corrupting local media/library state.
- All user-reported v1.6 screenshots/issues are re-tested on v1.7.0.
- v1.7.0 is only tagged/published after real-device acceptance passes.
