# OTYA Console Information Architecture

This document records the agreed OTYA Console structure so the UI stays original, compact, and free of duplicate destinations.

## Core rule

- **Left side = navigation and discovery.**
- **Center = active workspace.**
- **Right side = icon-only utilities.**
- A feature or function must have one primary home. Do not repeat the same destination on both sides.

## Left: Workspace Navigation

Search stays at the top of the left rail. Search can find users, content, logs, settings, releases, errors, and system resources without becoming a separate utility on the right.

Top-level sections:

1. **Overview**
   - Dashboard
   - Key metrics
   - Recent system activity
   - Health summary

2. **Users**
   - Accounts
   - Roles and permissions
   - Devices
   - Sessions
   - Account actions

3. **Content**
   - Music/media library
   - Playback
   - Downloads
   - Offline content
   - Media processing
   - Playback problems

4. **Insights**
   - Analytics
   - Retention
   - Usage trends
   - Playback trends
   - AI usage
   - Reports
   - App-version adoption

5. **App Control**
   - Remote config
   - Feature flags
   - Themes
   - Maintenance mode
   - Announcements
   - Releases and versions
   - Rollout and rollback

6. **Platform**
   - APIs
   - Workers/services
   - D1/database
   - R2/object storage
   - KV/cache
   - Queues
   - Webhooks
   - Background jobs
   - Backup/restore status
   - Rate/usage limits

7. **Security**
   - Authentication
   - Turnstile/bot protection
   - Suspicious activity
   - Audit history
   - Revoked sessions
   - Security controls
   - Admin action history

8. **Connections**
   - GitHub
   - Google
   - Resend/email
   - Telegram
   - External APIs

9. **Settings**
   - Project details
   - Domains
   - Branding
   - App identifiers
   - Environments (production/staging)
   - Team/admin access
   - Developer configuration
   - Data export tools

## Right: OTYA Utility Rail

The right rail uses **icons only**. Tooltips and accessible labels provide names. Panels can open from the icons, but they are not duplicate navigation destinations.

Order from top to bottom:

1. **Profile**
   - Account identity
   - Admin role
   - Workspace/environment context
   - Sign out

2. **OTYA AI**
   - Uses only the three small OTYA circles: blue, red, yellow
   - The full OTYA logo is never used as the AI icon
   - Idle: circles are still
   - Thinking/processing: circles animate on smooth curved paths around an invisible center
   - The main OTYA brand logo stays unchanged everywhere else
   - AI may assist with error analysis, logs, system inspection, reports, explanations, and suggested actions

3. **Notifications**
   - System alerts
   - Security alerts
   - Release alerts
   - Failed jobs
   - User reports
   - Integration warnings

4. **Control Center**
   - System/service health
   - Recent operational activity
   - Maintenance status
   - Safe quick controls
   - Publish config
   - Release actions
   - Queue/job status
   - Storage/database health
   - Incident status

5. **Help**
   - Documentation
   - Shortcuts
   - Support
   - System guide

6. **Theme**
   - Light
   - Dark
   - System

## AI identity

The main OTYA logo remains the product/brand identity. The OTYA AI identity is a derived sub-mark made only from the three small colored balls.

Recommended asset/state names:

- `otya_ai_mark`
- `otya_ai_mark_idle`
- `otya_ai_mark_thinking`
- `otya_ai_mark_success`
- `otya_ai_mark_error`

The AI mark must remain recognizable while stationary; animation is a state signal, not the identity itself.

## Responsive behavior

- Desktop/tablet: left navigation, center workspace, right icon utility rail shown side by side.
- Small mobile: left navigation becomes a drawer; right utility rail stays compact and accessible.
- Avoid making the right rail a second full menu.

## Design direction

Do not visually clone Firebase. OTYA Console should use OTYA terminology, proportions, iconography, spacing, interaction patterns, and brand behavior. Structural conventions such as a sidebar and utility rail are fine; the identity and information architecture must be OTYA-specific.
