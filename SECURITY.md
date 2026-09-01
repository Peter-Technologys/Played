# Otya Security Policy

## Supported version

Otya `1.0.0+1` is currently in final pre-release acceptance and has not yet been declared the first public production release.

Until v1 is published, security fixes are applied to the current `main` release candidate and verified before release. After public launch, this document must name the supported production release line explicitly and be updated whenever support changes.

## Reporting a vulnerability

Do not publish secrets, credentials, private user data, exploit details, account-recovery material, signing information, OTPs or tokens in a public issue.

Use a private GitHub security advisory when available, or the official security/support contact published on `petersmartlink.com`.

Please include:
- affected Otya version and build number;
- device and Android version when relevant;
- reproducible steps;
- expected and actual behavior;
- security impact;
- sanitized logs or screenshots with personal data and secrets removed.

## Security-sensitive areas

The following require extra review:
- authentication, JWT and refresh-token handling;
- Google Sign-In and Google Drive app-data recovery;
- Otya Private storage, biometric and PIN access;
- Transfer local-network authorization;
- update/download integrity and APK/AAB signing;
- Next request authentication and App Check;
- backend URLs, remote configuration and cloud synchronization;
- Firebase/FCM configuration;
- dependency and GitHub Actions changes.

## Security boundaries

Otya must never commit or bundle production secrets in Flutter. Authentication secrets, Resend keys, Cloudflare credentials, signing keys and internal service secrets belong only in approved secret storage or server-side runtime configuration.

Google Drive recovery requires explicit user action and must not upload raw music/video files or Private media. Production releases must fail closed when release signing credentials are missing.

Transfer is designed for authenticated local-network transfer rather than an open Internet file relay. Private storage must never overwrite another protected item and must preserve recoverability on restore failure.

Third-party dependency vulnerabilities should still be reported when they materially affect Otya so the project can update, mitigate or document the risk.

## Public security communication

Customer-facing security information should explain what users need to know without exposing exploit-enabling implementation details. Public incident communication should include impact, affected versions/services, mitigation and resolution status. Sensitive technical evidence belongs in the private security-reporting path.
