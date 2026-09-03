# Contributing to Otya

Thank you for helping improve Otya. Keep changes focused, secure and consistent
with the current product instead of reviving retired prototype features.

## Report a problem

Search the repository's existing GitHub issues, then use the Bug Report template.
Include the Otya version/build, device and Android version, reproducible steps,
expected behaviour and sanitized logs when available. Never include passwords,
tokens, private media paths or other personal data.

Security vulnerabilities must use the private process in [SECURITY.md](SECURITY.md),
not a public issue.

## Development setup

```bash
git clone https://github.com/PeterSmartLink/OtyaPlayer.git
cd OtyaPlayer
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Use Flutter 3.32.x, Java 17 and a supported Android SDK, matching GitHub Actions.

## Change rules

- Branch from `main` and use a focused branch name such as
  `fix/playback-resume` or `docs/privacy-clarity`.
- Preserve the public **Otya** product name, **Next** assistant name, package ID,
  signing identity and compatibility-sensitive storage identifiers.
- Do not add secrets, production credentials or private data to source, tests,
  screenshots or logs.
- Do not make local playback depend on account, AI or network availability.
- Add or update regression tests for changed behaviour.
- Run code generation, strict analysis and the complete test suite before review.
- Use a pull request with a clear problem statement, evidence and rollback impact.

Production tags and releases are owner-controlled and must use the reviewed
release workflow.
