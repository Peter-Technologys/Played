# Otya Security Policy

## Supported version

Security fixes are maintained for the current public Otya release. The first
public release line is `1.0.0`; the Android build number may increase without
changing that public version while first-release fixes are validated.

## Reporting a vulnerability

Do not publish secrets, credentials, private user data, exploit details,
account-recovery material, signing information, OTPs or tokens in a public
issue.

Use a private GitHub security advisory when available, or contact
**support@petersmartlink.com** through an official `petersmartlink.com` channel.

Please include:

- the affected Otya version and build number;
- the device and Android version when relevant;
- reproducible steps and the security impact;
- expected and actual behaviour; and
- sanitized logs or screenshots with personal data and secrets removed.

## Security-sensitive areas

The following require extra review:

- authentication, JWT and refresh-token handling;
- Google Sign-In and Drive app-data recovery;
- Private storage, biometric/device authentication and PIN access;
- local Transfer authorization and file validation;
- Next request isolation and provider routing;
- update/download integrity and APK signing;
- backend URLs, remote configuration and cloud synchronization; and
- dependency and GitHub Actions changes.

## Security boundaries

Otya must never commit or bundle production secrets in Flutter. Authentication,
Resend, Cloudflare, Firebase service-account, signing and internal-service
credentials belong only in protected server-side or CI secret storage.

Google Drive recovery requires explicit user action and must not upload raw
music/video files or Private media. Production releases must fail closed when
release signing credentials are missing.

Internet-facing Otya services use HTTPS. Cleartext HTTP is limited to
authenticated Transfer connections on private/local network addresses.

Third-party dependency vulnerabilities should be reported when they materially
affect Otya so the project can update, mitigate or document the risk.
