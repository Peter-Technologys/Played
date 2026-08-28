# OTYA unified product rules

These rules are implementation constraints for the current OTYA redesign.

## Primary navigation

OTYA has exactly three persistent destinations:

1. Video
2. Music
3. Me

Secondary capabilities must not become permanent bottom-navigation tabs.

## Me hierarchy

Me uses a compact 3×3 feature grid:

- Transfer
- Files
- Private
- Converter
- Playlists
- History
- Tools
- Personalize
- Storage

Account/profile is opened from the top-right avatar. Configuration lives below the grid as normal Settings / Help / About rows.

## Transfer

Transfer is one capability group. Send, receive, nearby discovery, QR pairing, computer transfer, phone-copy flows and history belong inside it. Contextual Send actions may also appear on media/files.

## AI

AI is an optional intelligence layer, not a permanent app tab. Local search runs first. Online answers may appear inline in Search and Help. A longer conversation is a fallback when a user explicitly continues.

## Offline boundary

The following must remain useful without Cloudflare, sign-in or internet:

- local video and music playback
- media scanning
- playlists/history stored locally
- themes and core settings
- local search
- local device-to-device transfer
- local file/private-media operations

Remote configuration, account services, online AI, update metadata and notifications may enhance the experience but must not block the offline core.

## NEW states

Feature-discovery badges are versioned by remote config and remembered locally after the feature is opened.

Newly discovered media is tracked only on-device. The first scan establishes a baseline. Later media discovered from downloads, Bluetooth, messaging apps, transfer apps or OTYA Transfer may receive a subtle NEW state until opened/played.

## UI discipline

- one icon language
- no rainbow dashboard tiles
- media artwork supplies most of the color
- consistent bottom sheets, menus, spacing and typography
- new capabilities reuse existing navigation and player flows where possible
- do not add a full screen when a sheet or contextual action is sufficient
