# OTYA Player Security Policy

## Supported version

Security fixes are maintained for the current production release line. The current source version is `1.6.0+10`.

## Reporting a vulnerability

Do not publish secrets, credentials, private user data, exploit details, account-recovery material, signing information, OTPs or tokens in a public issue.

Use a private GitHub security advisory when available, or the official support/contact channel published on `petersmartlink.com`.

Please include:
- affected OTYA version and build number;
- device and Android version when relevant;
- reproducible steps;
- expected and actual behavior;
- security impact;
- sanitized logs or screenshots with personal data and secrets removed.

## Security-sensitive areas

The following require extra review:
- authentication, JWT and refresh-token handling;
- Google Sign-In and Drive App Data recovery;
- Safe/vault encryption, biometric and PIN access;
- Beam local transfer authorization;
- update/download integrity and APK signing;
- backend URLs, remote configuration and cloud synchronization;
- dependency and GitHub Actions changes.

## Security boundaries

OTYA must never commit or bundle production secrets in Flutter. Authentication secrets, Resend keys, Cloudflare credentials, signing keys and internal service secrets belong in GitHub/Cloudflare secret storage or server-side runtime configuration.

Google Drive recovery requires explicit user action and must not upload raw music/video files or Safe/private media. Production releases must fail closed when release signing credentials are missing.

Third-party dependency vulnerabilities should still be reported when they materially affect OTYA so the project can update, mitigate or document the risk.
