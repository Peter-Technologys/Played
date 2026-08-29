# OTYA compatibility rules

These rules protect existing users while OTYA is modernized.

## Never break these contracts

- Keep the Android application/package ID unchanged for normal upgrades.
- Never require sign-in for local video, local music, local scanning or local transfer.
- Keep existing account user IDs and server authentication compatible across app upgrades.
- Prefer additive database migrations. Do not wipe local databases, playlists, history, favorites, vault state or preferences during a UI redesign.
- Preserve existing SharedPreferences keys unless a migration copies their values first.
- Keep legacy deep links as redirects when a feature is renamed. `/airdrop` redirects to `/transfer`; `/ai` redirects to `/support`.
- Treat the first NEW-media scan as a baseline. Existing libraries must not suddenly be labelled NEW after an upgrade.
- Media NEW/unseen state stays local. Do not upload the user's local media library to Cloudflare.
- Backend, AI or account outages must not stop the app opening or local playback.
- Transfer must remain usable on the local network without an OTYA account.
- Remote feature flags may hide a connected feature, but must not disable core local playback.

## Safe rollout order

1. Add new routes/services alongside old compatibility paths.
2. Ship and validate the new UI against existing user data.
3. Keep old route redirects for at least one stable release cycle.
4. Remove dead implementation files only after code search and CI show no callers.
5. Remove old stored keys only through an explicit migration, never by clearing app data.

## Release gate

Before merging a modernization release:

- Flutter analyze passes.
- Tests pass.
- Debug APK builds.
- App opens offline.
- Existing library remains visible.
- Existing playlists/history/settings remain present.
- Video and audio playback work without login.
- Old `/airdrop` and `/ai` links still resolve safely.
- Auth refresh/login still accepts existing accounts.
- New media received/downloaded after the baseline can be discovered without a backend dependency.
