# OTYA System — Product Branding Standard

This document is the source of truth for the OTYA identity across the client, backend, website, APIs, email, documentation, and release infrastructure.

## Brand hierarchy

- **OTYA System** — the umbrella technology/platform identity.
- **OTYA Player** — the media-player product inside OTYA System.
- **OTYA Auth** — authentication service inside OTYA System.
- **OTYA Store** — backend/data/API service inside OTYA System.

Do not present PeterSmartLink as the primary product identity. It may remain as the legal/organisation or domain owner where required.

## Canonical names

- Product: `OTYA Player`
- Platform: `OTYA System`
- Authentication service: `OTYA Auth`
- Store/backend service: `OTYA Store`
- Website/domain: `petersmartlink.com` until an OTYA-specific production domain is introduced.
- Support: `support@petersmartlink.com`

## User-facing rule

The app should say **OTYA Player** when referring to the application and **OTYA System** when referring to the platform/ecosystem.

Examples:

- `OTYA Player is part of OTYA System.`
- `OTYA System Account`
- `OTYA System Support`
- `OTYA Player Settings`
- `OTYA Auth` for technical authentication service references.

Avoid:

- Played
- WOP Player
- old PlayIt-style product names
- PeterSmart as the product name
- mixed legacy product identities

## Technical naming

Package/application IDs should not be changed casually after release. The current Android ID `com.otyaplayer.app` is therefore retained unless a deliberate pre-release migration is approved.

Internal service names, API responses, logs, email subjects, documentation, and deployment metadata should use the OTYA naming hierarchy consistently.

## Email branding

Transactional email should use OTYA System/OTYA Player branding, for example:

- `OTYA Player — Verify your email`
- `OTYA System — Password reset`
- `OTYA System Security — New sign-in`

Sender identity should use the verified `petersmartlink.com` domain until a dedicated OTYA domain is configured.

## Security naming rule

Never expose secrets, tokens, internal service credentials, or infrastructure identifiers in user-facing branding, logs, API responses, or Flutter source.
