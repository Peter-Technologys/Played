# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 1.0.x | ✅ Yes |

---

## Reporting a Vulnerability

**Please do NOT open a public issue for security vulnerabilities.**

If you discover a security vulnerability in Played, please report it responsibly:

1. **Email:** Send details to the project maintainer via GitLab's private messaging or the email listed on the profile.
2. **Include:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
3. **Response time:** You will receive an acknowledgement within 48 hours and a resolution timeline within 7 days.

---

## Scope

The following are in scope:

- AES-256 Vault encryption implementation
- Biometric / PIN authentication bypass
- Data leakage from the encrypted Vault
- Insecure file permissions on vault-stored media
- Nearby Connections (Air-Drop) data interception

---

## Out of Scope

- Issues in third-party dependencies (report to the respective maintainers)
- Issues requiring physical access to an unlocked device
- UI/UX bugs (use the Bug Report issue template instead)

---

## Disclosure Policy

We follow **responsible disclosure**. Once a fix is released, the vulnerability will be documented in [CHANGELOG.md](CHANGELOG.md) with credit to the reporter (unless anonymity is requested).
