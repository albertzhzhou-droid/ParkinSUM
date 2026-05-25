# v0.1.0-alpha Release Checklist

Use this checklist before creating a GitHub Release for `v0.1.0-alpha`.

Do not publish the release if any step requires private keys, signing files,
Firebase secrets, service-account credentials, real patient data, private user
exports, or environment-specific operator files.

## Required Verification

Run from the repository root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
npm ci
npm run public:preflight
npm run rules:contract
```

Expected result:

- Formatting check exits with `0`.
- `flutter analyze` reports no issues.
- `flutter test` passes.
- Public preflight reports `0` `BLOCKER` findings.
- Firestore rules contract passes.

## Android Demo APK

Android project files are present. If local Android tooling is available, build
a debug demo APK:

```sh
flutter build apk --debug
```

If the build succeeds, the default artifact is:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

For release-asset review, copy it to an ignored build folder with a clear demo
label:

```sh
mkdir -p build/release
cp build/app/outputs/flutter-apk/app-debug.apk build/release/parkinsum-v0.1.0-alpha-demo-debug.apk
```

Do not present this APK as production-signed. It is an alpha/demo/debug artifact
only and is not intended for Play Store, app-store, clinical, or patient-care
distribution.

## Release Notes

Confirm the GitHub Release body links to:

- `CHANGELOG.md`
- `docs/release/v0.1.0-alpha-notes.md`
- `docs/release/synthetic-demo-data.md`
- `docs/PUBLIC_DEMO_BOUNDARY.md`
- `DISCLAIMER.md`
- `SECURITY.md`

## Safety Review

Before publishing, confirm:

- No clinical validation, diagnosis, treatment, medication timing, dietary
  guidance, patient-care, or emergency-support claims are made.
- No real health information, real medication schedules, private user exports,
  service-account files, Firebase secrets, signing keys, raw operator logs, or
  local token files are staged.
- Screenshots, GIFs, demo videos, and demo narratives use synthetic or sample
  data only.
- Android artifacts are clearly labeled as alpha/demo/debug or unsigned unless
  production signing is handled in a separate release process.

## Suggested Git Commands

Inspect staged and untracked files before publishing:

```sh
git status --short
git diff --stat
git diff --name-only --cached
```

If a release asset is generated under `build/`, it should remain ignored by git
and be attached manually only after confirming it contains no secrets or real
user data.
