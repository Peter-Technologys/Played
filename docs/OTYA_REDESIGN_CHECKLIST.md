# OTYA v1 product experience validation checklist

This checklist is a release-quality contract, not a feature-presence checklist.

## Foundation

- [ ] Flutter analyze, tests and release build pass.
- [ ] Bottom navigation remains Video, Music, Me only.
- [ ] One coherent OTYA design system is used across Video, Music, Me, Next, account, Transfer, Private, Tools and Settings.
- [ ] Screens work edge-to-edge without clipped system bars, keyboard overlap or inaccessible controls.
- [ ] Light/dark/theme variants preserve contrast, hierarchy and readability.
- [ ] Every network or processing action has immediate feedback, useful progress/loading state, specific failure state and a recovery action where possible.
- [ ] No generic spinner or blank wait is accepted when a meaningful state can be shown.

## Me

- [ ] Me is a personal hub with hierarchy, not a 3×3 grid of equal utilities.
- [ ] Account/profile identity is prominent but does not consume excessive space.
- [ ] Continue/recent activity may be surfaced when useful and locally available.
- [ ] Primary quick actions prioritize Transfer, Private and Media Tools.
- [ ] Library actions such as Playlists, History and Files are grouped separately.
- [ ] Personalization, Storage and Settings are secondary rather than competing equally with daily actions.
- [ ] Next has one canonical entry and is never labelled Ask OTYA in new UI.
- [ ] Feature availability/disabled states explain why an action is unavailable.

## Music

- [ ] Local music remains primary and works offline.
- [ ] Songs, Albums, Artists and Playlists have visually distinct hierarchy instead of one dense file-list treatment.
- [ ] Artwork loading has placeholders and does not cause scrolling jank.
- [ ] Queue, mini-player and Now Playing stay synchronized.
- [ ] Search returns local results first; online discovery is an enhancement, not a separate identity.
- [ ] Provider downloads appear in the normal local library after indexing/scanning.

## Video

- [ ] Video library emphasizes thumbnails/resume/recent media rather than generic file rows where metadata is available.
- [ ] Playback controls are immersive, responsive and accessible.
- [ ] Seek, play/pause, next/previous, speed, subtitles/audio tracks and PiP behave consistently where supported.
- [ ] Unsupported codecs/containers produce a useful explanation or fallback instead of a generic failure.

## Transfer

- [ ] Transfer opens around nearby-device discovery and clear Send / Receive actions.
- [ ] Local transfer remains usable without OTYA Account or cloud when the underlying engine supports it.
- [ ] Device discovery, connection, progress, speed, completion, cancellation and failure states are clear.
- [ ] Received media is indexed into the normal OTYA library when appropriate.

## Private

- [ ] Private clearly communicates locked/unlocked state and device-local privacy behavior.
- [ ] Protected media does not leak thumbnails/metadata into normal recent/history surfaces.
- [ ] Import, restore/export and uninstall/data implications are understandable.

## Media Tools

- [ ] Convert and Trim use a guided choose -> options -> process -> result flow.
- [ ] Unsupported inputs are identified before expensive processing whenever possible.
- [ ] Processing shows progress and output destination.
- [ ] Trim 30 seconds succeeds on supported media or returns a specific recoverable reason; generic "could not be completed" is not release-acceptable.

## Next

- [ ] Canonical product name is Next / Next by OTYA.
- [ ] Sending a message produces visible feedback immediately.
- [ ] The user does not stare at a long blank/full-answer wait; response text streams or otherwise appears progressively as soon as the backend can provide it.
- [ ] Simple/general questions do not unnecessarily invoke web/search tooling.
- [ ] OTYA product questions use OTYA knowledge when useful.
- [ ] Current/time-sensitive questions use live retrieval when available and say when facts could not be verified.
- [ ] Browser/tool state is visible in human language such as Searching or Checking a source.
- [ ] Stop and Retry behavior is available for long/failed generations.
- [ ] Tool timeout/failure does not become an endless spinner.
- [ ] No model picker is required for ordinary users unless product research shows a clear user benefit; server policy should choose sensible defaults.

## Account

- [ ] Email registration succeeds end-to-end in production.
- [ ] Email/password sign-in succeeds after registration.
- [ ] Google sign-in succeeds on a physical Android device and on the web where offered.
- [ ] Password reset succeeds through actual email delivery and code redemption.
- [ ] Errors explain the problem and next action instead of generic Account creation failed / Sign in failed text.
- [ ] Session creation, refresh and sign-out work consistently between app and web.

## Media session / physical Android acceptance

- [ ] Notification metadata and controls are correct.
- [ ] Lock-screen controls are correct.
- [ ] Bluetooth/headset play/pause/next/previous work.
- [ ] Audio focus handles other apps and phone calls correctly.
- [ ] Playback behavior is correct with screen off and after task removal according to product policy.
- [ ] Queue/seek/next/previous remain synchronized.
- [ ] Artwork, title and artist metadata update correctly.
- [ ] Video PiP behaves correctly where supported.

## Privacy and offline behavior

- [ ] Existing media establishes an unseen baseline; later scans may mark new media locally.
- [ ] No local media filenames/library lists are uploaded merely for NEW-state tracking.
- [ ] Settings, themes, media scanning and core local playback remain usable offline.
- [ ] Permissions are requested in context and only when required.

Only features that pass implementation, functional verification, product-quality verification and final release verification count toward OTYA 1.0 readiness.
