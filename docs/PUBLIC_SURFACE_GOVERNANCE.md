# Otya Public Surface Governance

This document defines how Otya presents itself to users, developers, partners and the public. It is an organization rule, not a feature roadmap.

## 1. Canonical naming

- Product: **Otya**
- Assistant: **Next**
- Company: **PeterSmart Link**
- Public copy uses `Otya`, not all-caps `OTYA`.
- Legacy/internal identifiers may retain old names only when compatibility requires it. Do not rename package IDs, stored database keys, old migration identifiers or externally registered callbacks merely for visual consistency.
- Historical documents may retain old names when clearly marked as historical/archived.

## 2. One source of truth per kind of information

Otya must not maintain conflicting versions of the same public information.

| Information | Canonical public owner | Other surfaces should do |
|---|---|---|
| Product overview | Otya website | Link/summarize |
| User help | Help Center | Link/contextual deep-link |
| Privacy Policy | `/privacy` | Link to same policy/version |
| Terms of Service | `/terms` | Link to same terms/version |
| Account/data deletion | public account-deletion page | Link from app and store listing |
| Security reporting | Security/Trust page | Link from GitHub and app support |
| Release notes | Changelog / What's New | Summarize in app/social/email |
| Incidents | Status page | Link from support/social when needed |
| Developer/API docs | Developer docs | Do not mix with ordinary user help |
| Engineering internals | repository/private engineering workspace | Never publish as customer help |

If a policy is updated, its effective date/version must change once and every surface must point to that same version.

## 3. Public information classes

### Public product information
Safe and useful for everyone:
- what Otya does;
- supported platforms and current release status;
- how core features work from a user's perspective;
- download links;
- release notes;
- help/troubleshooting;
- privacy, terms, acceptable-use/safety rules;
- accessibility information;
- security reporting instructions;
- provider/partner attributions that are contractually required;
- company/contact information intended for users.

### User-private information
Visible only to the authenticated user:
- account/profile details;
- sessions/devices;
- backup state;
- consent/preferences;
- personal support history;
- data export/deletion state.

### Staff/admin information
Never expose through ordinary public pages:
- moderation/admin dashboards;
- operational metrics with sensitive detail;
- account intervention controls;
- internal incident timelines;
- customer/support tooling.

### Engineering information
May be public in an intentionally public repository only when safe:
- architecture overview without secrets;
- contribution/development setup;
- release/test contracts;
- public API documentation.

Do not publish credentials, signing material, private endpoints, internal service secrets, database dumps, private user data, exploit-enabling details, provider secrets or privileged infrastructure inventories.

## 4. Website structure

The public site should be organized by user need, not by backend service names.

### Product
- Otya overview
- Download
- What's New
- Online Music/provider information where needed
- Next overview

### Help
- Getting started
- Playback
- Library and files
- Transfer
- Private
- Account and sign-in
- Updates/downloads
- Next
- Troubleshooting
- Contact support

### Trust
- Privacy
- Terms
- Security
- Data & privacy controls
- Account deletion
- Cookies (when the website uses non-essential cookies/tracking)
- Accessibility
- Third-party services / subprocessors where appropriate
- Responsible AI / Next transparency
- Community or acceptable-use rules when applicable

### Company
- About PeterSmart Link / Otya
- Newsroom
- Contact
- Press/brand assets when there is a real need
- Partnerships/contact path

### Developers
Only if Otya exposes an actual developer surface:
- Getting started
- API reference
- Authentication
- Errors/rate limits
- Webhooks/integrations
- Security guidance
- Changelog

Do not create a developer portal merely to look large.

## 5. App information architecture

Ordinary settings should not become a dump of legal and company links.

Recommended hierarchy:

**Account**
- Profile
- Sign-in/security
- Connected services
- Data & privacy
- Delete account

**Settings**
- Look & feel
- Playback
- Privacy & device permissions
- Notifications
- Storage
- Language/accessibility where supported

**Help & About**
- Help Center
- Contact support / report a problem
- What's New
- Check for updates
- About Otya
- Version/build
- Privacy
- Terms
- Security
- Open-source/third-party notices

A policy link shown during signup must resolve to the same policy version recorded by consent.

## 6. Trust center model

Otya does not need a giant enterprise trust portal. It does need a small, credible trust area that answers:
- what data is collected and why;
- what stays on the device;
- what is sent to Otya services;
- what is sent to third parties;
- how long important account/service data is retained;
- how users can access/delete their data;
- how to report a security problem;
- how Next processes user prompts;
- how material policy/security incidents are communicated.

## 7. Communication model

One event can produce different channel versions, but all must use the same facts.

- Website/newsroom: authoritative long-form announcement.
- Changelog: exact release/change record.
- Telegram: concise community update.
- LinkedIn: company/product/engineering story.
- Email: only when relevant to that recipient or subscription topic.
- GitHub: technical evidence and source change.
- Status: incidents only.

Do not publish CI-green changes as shipped features before merge, deployment and acceptance.

## 8. Policy lifecycle

Every legal/trust document must have:
- canonical title;
- effective date;
- document version;
- scope (app/site/services covered);
- company/controller/service-provider identity as applicable;
- contact path;
- change-notice rule;
- archive of replaced versions when appropriate.

Policy content must be derived from verified current behavior, not copied from an older product generation.

## 9. Search and discoverability

Public pages intended for users should have:
- one canonical URL;
- meaningful page title and description;
- canonical metadata;
- sitemap inclusion;
- robots rules that do not accidentally block intended public pages;
- stable redirects when URLs change;
- structured data where it genuinely helps search engines.

Legal/help pages should be reachable without sign-in.

## 10. Release gate for public truth

Otya v1 is not ready for public release while any of these are materially inconsistent:
- app behavior vs Privacy Policy/Data Safety disclosure;
- Terms/Privacy versions vs signup consent versions;
- app version vs release metadata;
- public download vs signed artifact;
- product name/assistant name across main user surfaces;
- Help Center instructions vs current UI;
- account deletion promises vs actual deletion paths;
- What's New/changelog vs shipped build.

Public truth is part of product quality, not marketing polish.
