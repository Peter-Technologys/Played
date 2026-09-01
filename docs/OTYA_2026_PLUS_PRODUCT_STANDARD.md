# Otya 2026+ Product Standard

**Status:** Engineering product standard  
**Owner:** PeterSmart Link / Otya  
**Applies to:** Android app, Next, public web surfaces, backend contracts, release tooling and user-facing communications  
**Rule:** This document is a quality gate, not a release claim.

## Product principle

Otya must feel current or ahead of the platform year without becoming trendy, cluttered or fragile. We adopt mature patterns from high-quality products and platform guidance, but we do not copy another company's visual identity, information architecture, wording or feature set.

Modernization means the whole experience: visual design, interaction, motion, responsiveness, accessibility, latency, offline behavior, security, privacy, failure handling, architecture, release safety and public trust.

## Big-company rules

1. **One source of truth.** A user concept, policy, release state or account fact has one canonical owner. Other surfaces adapt it; they do not become competing truths.
2. **Fewer, stronger surfaces.** Do not create a new top-level destination when a contextual action, section or sheet is clearer. Otya's primary product hierarchy stays deliberate.
3. **Progressive disclosure.** Common actions are obvious; advanced tools appear when relevant. Internal provider, Worker, model, storage and infrastructure details do not leak into normal-user UX.
4. **Consistency beats novelty.** Reuse shared typography, spacing, shape, motion, empty/loading/error states and interaction behavior before inventing screen-specific styles.
5. **User work is never blocked by optional cloud features.** Local playback, library access and supported local operations remain usable when Next, Firebase, online music or backend services are unavailable.
6. **Fail soft for optional services; fail closed for security.** A recommendation outage must not break the library. Invalid auth, release approval, integrity or destructive operations must stop safely.
7. **Measure before claiming.** "Fast", "secure", "ready", "released", "accessible" or similar claims require evidence.
8. **No accidental destructive behavior.** Updates, migrations, vault operations, downloads, account operations and release automation need explicit ownership and rollback-safe behavior.
9. **Compatibility is intentional.** Public naming may modernize while package IDs, storage keys, routes or migration identifiers remain legacy when changing them would break users.
10. **Small independently reviewable changes.** Cross-cutting modernization is delivered in bounded slices with contracts/tests. A giant redesign that cannot be isolated or verified is not acceptable.

## Visual and interaction quality

- Material 3 is the base design language, adapted into Otya's own identity.
- Edge-to-edge is intentional. Interactive content must never be obscured by status/navigation bars or cutouts.
- Compact, medium and expanded layouts are treated as different arrangements, not stretched phone screens.
- Preserve user text scaling and system accessibility settings. Do not globally clamp text merely to protect a layout.
- Minimum interactive target: 48dp unless a platform-native control safely provides an equivalent accessible target.
- Use a restrained shape hierarchy. Large expressive radii are for meaningful containers/sheets, not every object.
- Elevation is rare. Prefer tonal/surface hierarchy over decorative shadows.
- Media artwork should feel important in a media product, but never reduce legibility or control discoverability.
- Loading, empty, error, offline and permission states must be intentionally designed. No unexplained blank screens, indefinite spinners or generic "Something went wrong" when a useful recovery exists.
- Destructive actions are visually and verbally distinct and require confirmation when consequences are not trivially reversible.
- Haptics/animation provide feedback, not decoration. Repeated or ambient motion must respect reduced-motion settings.
- Navigation transitions must be short, consistent and non-blocking. Player presentation may be more expressive than ordinary settings/detail navigation.
- No UI should expose AI model names/providers, internal Worker names, D1/KV/R2 concepts, raw exception text, internal IDs or secret-bearing values to ordinary users.

## Accessibility quality

- Meaningful icon-only controls require semantic labels/tooltips where appropriate.
- Toggle, selected, checked, expanded, progress and live states must expose semantics instead of relying only on color or shape.
- TalkBack order must follow the visual task order.
- Text must remain usable at large font scales without clipping primary actions.
- Do not communicate important state using color alone.
- Reduced motion is respected for branded thinking animation and general navigation/transition motion.
- Keyboard, pointer and large-screen behavior must not be intentionally blocked where Android supports it.
- Accessibility is physically tested before any public accessibility conformance claim.

## Performance quality

Performance is a product feature. CI success is not performance evidence.

Targets for physical-device measurement:

- Cold startup: target <= 500 ms where realistic on supported reference hardware.
- Warm startup: target <= 200 ms.
- Hot startup: target <= 150 ms.
- No synchronous full-library scan, database migration, Firebase initialization, network call or AI initialization may block first frame.
- Scrolling in the main Video, Music and Me surfaces should remain visually smooth under representative large libraries.
- Artwork decoding must be bounded to display needs; avoid decoding full-resolution images into memory when a smaller decode is sufficient.
- Expensive blur, shader, clipping and repaint effects require profiling on mid-range Android hardware.
- Network requests use bounded connect/response timeouts, duplicate-request coalescing where useful, and cancellation/obsolescence handling where stale results can race newer user intent.
- Next performance is measured as preflight time, connection time and time-to-first-useful-token, not one blended spinner duration.
- Media playback must remain independent of AI/cloud latency.

### Required performance evidence before final release

- Macrobenchmark or equivalent repeatable startup measurements.
- Scroll/jank measurement on representative library sizes.
- Physical ARM64 acceptance and an ARM32 path when ARM32 remains distributed.
- Playback start/seek/queue/background-control acceptance.
- Memory sanity under artwork-heavy browsing and repeated player navigation.

Baseline Profiles should be evaluated after stable benchmark journeys exist; do not add performance machinery without measuring its benefit.

## Security and privacy quality

- Authentication sessions are atomic: incomplete token/user state is rejected before persistence.
- Secrets never live in source, public logs, public docs, screenshots, analytics events or crash payloads.
- Production release publication requires explicit human/owner authority and artifact/signing verification.
- Android APK signing identity is verified with Android signing tooling, not inferred from a generic JAR check.
- Private/Vault operations must be collision-safe, rollback-safe and must never overwrite another protected item.
- File sharing uses scoped content grants instead of broad file exposure.
- Otya does not request all-files access or package-installer permission for ordinary operation.
- App/internet APIs use HTTPS. Any cleartext allowance used for local-device Transfer is a documented compatibility exception, not permission for internet APIs.
- Local Transfer endpoints remain authenticated/ephemeral and must not become a general unauthenticated local web server.
- Use Play Integrity/App Check as risk signals where appropriate; do not turn transient platform-service outages into loss of local playback.
- User-facing privacy statements must match actual Firebase, Cloudflare, Resend, Google, Next and provider behavior.
- Do not claim encryption, zero knowledge, anonymity, end-to-end security or similar properties unless the implementation has been specifically verified.

## Architecture quality

- One playback engine owns playback state. Background media integration bridges that same state rather than creating a competing player.
- One account identity authority owns the canonical Otya session.
- One public assistant identity: Next. Provider/model routing remains behind backend policy.
- Owner/admin AI capabilities are explicitly separated from normal-user Next capabilities.
- Feature modules own their domain behavior; shared/core code contains reusable platform/domain infrastructure, not random cross-feature state.
- Avoid global singletons unless the lifecycle is intentionally application-wide and tested.
- Async work that can race user intent needs generation/cancellation/obsolescence protection.
- Public APIs, internal APIs and admin APIs are separate contracts.
- Unknown or unsupported typed AI actions fail closed.

## Reliability and offline behavior

Every major screen or flow defines:

1. loading state;
2. success state;
3. empty state;
4. recoverable failure state;
5. offline/degraded state when relevant;
6. retry behavior;
7. cancellation/back behavior;
8. persistence/restore behavior where relevant.

Optional network features must degrade without making local Otya look broken.

## Next quality

- Next is friendly and general-purpose, with extra Otya knowledge when relevant.
- Normal users see Next, not a list of upstream AI vendors/models.
- Retrieval is bounded and used for clearly Otya-specific questions, not every generic word such as music/video/help.
- Retrieved text is factual context and never trusted as instructions.
- AI cannot claim an action occurred unless the execution layer returns confirmed success.
- Local/destructive/admin actions require typed permission boundaries; arbitrary shell/URL/route/file execution is forbidden.
- Quota/provider failure returns a useful degraded response and preserves local app functionality.

## Backend and operational quality

- Validate the complete system before production deployment, but deploy only components that actually changed.
- A documentation or web-only change must not unnecessarily repair auth D1 or redeploy unrelated Workers.
- Production mutation jobs fail closed when a selected earlier component fails.
- Public smoke tests verify the canonical website/download/version surfaces after relevant deployment.
- Operational monitoring uses customer/product concepts; public status does not expose internal Worker/D1/KV names.
- Email, Telegram, LinkedIn, website/newsroom and GitHub have distinct roles. One factual source is adapted per channel rather than copy-pasted everywhere.

## Release-quality evidence ladder

Never collapse these stages:

1. **Coded** — source change exists.
2. **CI/test passed** — automated checks passed for the asserted scope.
3. **Built** — required artifact was successfully produced and integrity-checked.
4. **Physical-device tested** — applicable device behavior was verified.
5. **Deployed/live** — applicable backend/web change was deployed and smoke-tested.
6. **Released** — approved public distribution actually occurred.

A green CI run does not imply physical-device acceptance, production deployment or release.

## Public trust quality

- Public product spelling: **Otya**.
- Assistant: **Next**.
- Company/operator: **PeterSmart Link**.
- Help, product, Trust/legal, company, developer and engineering information remain separate information classes.
- Release notes describe user-visible changes; internal implementation identifiers stay in engineering history.
- Privacy, Terms, account deletion and Play Data Safety must be reconciled to live behavior before store release.
- No invented partnerships, dates, user counts, performance superiority or security superlatives.

## Modernization acceptance for each screen

A screen is not considered modernized merely because it looks newer. Acceptance requires:

- correct place in the product hierarchy;
- shared design tokens and Material 3 behavior;
- usable edge-to-edge/insets;
- compact + larger-window sanity;
- text scaling sanity;
- semantic labels/state for important controls;
- intentional loading/empty/error/offline states;
- no unnecessary network work during entry;
- no internal implementation leakage;
- measured or at least instrumentable performance for expensive journeys;
- CI contract for high-risk behavior;
- physical-device review before final acceptance.

## Current known exceptions / work still requiring evidence

- Android network security currently permits base cleartext traffic to support dynamic local-device Transfer addresses. Internet Otya/Peter Smart Link domains remain HTTPS-only. Treat this as a constrained compatibility exception and do not broaden its use.
- Final Privacy/Terms/account-deletion/Data Safety reconciliation still depends on verified live provider behavior.
- Physical-device acceptance remains required for notification/Now Playing, Google sign-in, Transfer, Private, updater, Next latency and final playback journeys.
- Performance budgets are targets until repeatable physical measurements exist.

## Change rule

When modernization conflicts with reliability, accessibility, privacy, offline playback, backward compatibility or truthful public communication, those constraints win. A modern Otya is a product that feels calm, fast, coherent and trustworthy—not merely one with newer visual effects.
