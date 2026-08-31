# OTYA Android brand/startup audit

This audit tracks the launcher, startup, notification and small-size brand surfaces separately from normal in-app UI.

## Fixed in `fix/otya-launcher-splash-optical-20260831`

- Adaptive launcher foreground no longer uses the legacy purple play-circle artwork.
- Canonical OTYA twisted-O foreground is optically reduced to stay inside Android adaptive-icon safe area.
- Dedicated monochrome/themed icon vector is used by adaptive icons.
- Android 12+ uses the platform SplashScreen contract.
- Pre-Android 12 launch screen is reduced to one calm background plus a modest OTYA mark.
- Duplicate Flutter fake splash/logo/spinner was removed so startup transitions from the OS splash directly into the app.
- Notification small icon uses a simplified one-color OTYA micro mark instead of the old play-circle glyph.
- Debug APK and Security workflows are green for the branch.

## Still requires physical/device visual validation before merge

- Samsung launcher icon mask and apparent size.
- Pixel launcher icon mask and themed-icon appearance.
- One Android 11-or-older device/emulator for the legacy launch background.
- Android 12+ cold start to confirm there is no double splash or white flash.
- Light/dark wallpaper contrast for launcher and themed icon.

## Remaining asset normalization

The repository still contains raster launcher/store assets from earlier generations. They should be regenerated from the same optically-corrected OTYA source before a public release:

- `mipmap-mdpi/ic_launcher.png` — 48x48
- `mipmap-hdpi/ic_launcher.png` — 72x72
- `mipmap-xhdpi/ic_launcher.png` — 96x96
- `mipmap-xxhdpi/ic_launcher.png` — 144x144
- `mipmap-xxxhdpi/ic_launcher.png` — 192x192
- `assets/icons/play_store_512.png` — 512x512

Do not scale the detailed large logo blindly into tiny files. Small sizes require optical correction: simpler edges, stronger contrast, sufficient negative space, and larger surviving color accents.

## Meaning rules

- Full OTYA twisted-O = product/app identity.
- Three blue/red/yellow circles = OTYA AI identity and AI-processing animation only.
- Monochrome OTYA micro mark = Android notification/status surfaces.
- Generic progress indicators remain generic for downloads, account loading, media indexing, etc.; do not use the AI animation for ordinary loading.
