# OTYA unified product rules

These rules are implementation constraints for the current OTYA redesign.

## Primary navigation

OTYA has exactly three persistent destinations:

1. Video
2. Music
3. Me

Secondary capabilities must not become permanent bottom-navigation tabs.

## Feature-placement rule

Show a capability where the user naturally needs it, not merely where there is room for another button.

- Everyday destinations stay visible.
- Media-specific actions belong on the selected song/video/file or inside its player.
- Short tasks prefer a bottom sheet/dialog over a dedicated full screen.
- Advanced utilities stay organized under Tools or Settings.
- Background/security/infrastructure behavior should normally be invisible until it needs user attention.
- Do not expose the same capability as multiple equal home destinations.

## Me hierarchy

Me is a personal/control area, not a nine-tile feature launcher.

Strong primary shortcuts:

- Transfer
- Files
- Private

Secondary capabilities are grouped beneath them instead of competing as equal tiles:

- Activity: History and relevant downloaded/recent activity.
- Tools: Converter, Trim, Storage analysis and similar utilities.
- Account & Settings: account, playback/privacy/device settings and Personalize.
- Help & Product: Next and About.

Playlists primarily belong in Music. Personalize and Storage primarily belong in Settings. Converter/Trim remain available in Tools but should also appear contextually on suitable media.

## Music

Music remains a local-library destination: Songs, Albums, Artists, Folders, Playlists and Now Playing.

The v1 product has no built-in streaming provider. Retired Jamendo and Spotify
paths must not return through stale configuration. A future online provider
requires a separate product, licensing, security and privacy review.

## Transfer

Transfer is one capability group. Send, receive, nearby discovery, QR pairing, computer transfer, phone-copy flows and history belong inside it. Contextual Send actions may also appear on media/files.

## AI

AI is an optional intelligence layer, not a permanent app tab. Local Search runs first. Next may help with Otya features and general questions while online, but it must never become required for finding or playing local media.

Next product knowledge must match current Otya behavior and must not describe retired Online Music providers as active features.

## Notifications and errors

OTYA should not feel noisy or technical.

- Playback uses Android media-session controls and the same Now Playing experience for local and online tracks.
- Pressing Play must not trigger an ordinary notification-permission prompt.
- Downloads/Transfer may show useful progress/completion outside the app when work continues in background.
- Optional online failures should usually collapse quietly; lack of internet is not an OTYA failure.
- Recoverable problems use designed inline states or contextual retry actions.
- User-facing messages never expose URLs, provider payloads, stack traces, tokens or raw HTTP errors.

## Offline boundary

The following must remain useful without Cloudflare, Firebase, sign-in or internet:

- app startup
- local video and music playback
- media scanning
- playlists/history stored locally
- themes and core settings
- local Search
- local device-to-device Transfer
- local file/private-media operations
- downloaded media

Remote configuration, account services, Next, update metadata and cloud notifications may enhance the experience but must not block the offline core.

Remote config is loaded after first paint and can use cached state. Any remote feature switch must have a safe local fallback.

## NEW states

Feature-discovery badges are versioned by remote config and remembered locally after the feature is opened.

Newly discovered media is tracked only on-device. The first scan establishes a baseline. Later media discovered from downloads, Bluetooth, messaging apps, transfer apps or OTYA Transfer may receive a subtle NEW state until opened/played.

## UI discipline

- one canonical OTYA mark/logo language everywhere
- no rainbow dashboard tiles competing with media artwork
- media artwork supplies most of the color
- consistent bottom sheets, menus, spacing, typography, loading/empty/error states and touch targets
- new capabilities reuse existing navigation and player flows where possible
- do not add a full screen when a contextual action, sheet or organized section is sufficient
- avoid duplicate entry points unless one is a clearly useful contextual shortcut
