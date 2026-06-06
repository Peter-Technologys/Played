# Contributing to Played

Thank you for your interest in contributing! 🎉  
Please read this guide before opening issues or merge requests.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Report a Bug](#how-to-report-a-bug)
- [How to Request a Feature](#how-to-request-a-feature)
- [Development Setup](#development-setup)
- [Branch Naming](#branch-naming)
- [Commit Messages](#commit-messages)
- [Merge Request Process](#merge-request-process)
- [Code Style](#code-style)

---

## Code of Conduct

Be respectful, inclusive, and constructive. Harassment of any kind is not tolerated.

---

## How to Report a Bug

1. Search [existing issues](https://gitlab.com/apk-v1/played/-/issues) first.
2. Open a new issue using the **Bug Report** template.
3. Include: device model, Android version, steps to reproduce, expected vs actual behaviour, and logs if possible.

---

## How to Request a Feature

1. Search [existing issues](https://gitlab.com/apk-v1/played/-/issues) first.
2. Open a new issue using the **Feature Request** template.
3. Describe the problem it solves and the proposed solution.

---

## Development Setup

```bash
git clone https://gitlab.com/apk-v1/played.git
cd played
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

Requirements:
- Flutter `>=3.0.0`
- Dart `>=3.0.0`
- Android SDK 21+
- Java 17

---

## Branch Naming

| Type | Pattern | Example |
|---|---|---|
| Feature | `feat/short-description` | `feat/playlist-support` |
| Bug fix | `fix/short-description` | `fix/audio-resume-crash` |
| Chore | `chore/short-description` | `chore/update-dependencies` |
| Docs | `docs/short-description` | `docs/update-readme` |

Always branch from `main`.

---

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Optional longer body.
```

**Types:** `feat` · `fix` · `chore` · `docs` · `refactor` · `test` · `style`

**Examples:**
```
feat(player): add repeat one mode
fix(vault): biometric fallback to PIN on unsupported devices
chore(deps): upgrade flutter_riverpod to 2.5.0
```

---

## Merge Request Process

1. Fork the repo and create your branch from `main`.
2. Make your changes with tests where applicable.
3. Run `flutter analyze` and fix all warnings.
4. Run `flutter test` — all tests must pass.
5. Open a Merge Request with a clear title and description.
6. Link the related issue (e.g. `Closes #42`).
7. Wait for review — at least one approval is required before merging.

---

## Code Style

- Follow the rules in `analysis_options.yaml`.
- Use `prefer_single_quotes`, `prefer_const_constructors`.
- Keep files under 300 lines where possible — split into smaller widgets.
- Feature-first folder structure — new features go in `lib/features/<name>/`.
- State management via Riverpod — no `setState` in feature screens.
- No hardcoded colors — use `AppColors` constants.
- No hardcoded strings — use constants or localization keys.
