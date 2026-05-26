# Changelog

All notable public-showcase changes are documented here.

This project follows versioned release notes for public GitHub releases. Public
release language must preserve the educational-only safety boundary and must not
claim clinical validation, medical-device status, treatment guidance, or
real-world patient-care readiness.

## v0.1.0-alpha - 2026-05-25

### Added

- Public alpha release package for ParkinSUM Companion as a stable educational
  showcase of the prototype architecture.
- Canonical release notes at `docs/release/v0.1.0-alpha-notes.md`.
- Synthetic demo-data guidance at `docs/release/synthetic-demo-data.md`.
- Release checklist at `docs/release/release-checklist.md`.
- GitHub Actions CI documentation through the README badge and local
  verification commands.
- Synthetic visual showcase media in the README: dashboard, meal-entry,
  conflict-result screenshots, and a short demo GIF.

### Included

- Local-first Flutter app prototype for educational diet-medication awareness
  demonstrations.
- Onboarding, meal logging, medication context, deterministic rule checks,
  timeline-oriented flows, and evidence-oriented explanation surfaces.
- Public safety, disclaimer, contribution, preflight, and release-readiness
  documentation.
- Internal Firebase-backed architecture and operator tooling retained for
  governance review, not for public clinical use.

### Not Included

- Clinical validation, medical-device clearance, regulatory approval, or
  patient-outcome evidence.
- Production signing, app-store distribution, Play Store deployment, Firebase
  deployment, secrets, private keys, or service-account credentials.
- Real patient data, real medication schedules, private user exports, raw
  operator logs, or public health-record integrations.

### Verification Baseline

- `flutter pub get`
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- `npm ci`
- `npm run public:preflight`
- `npm run rules:contract`
- `flutter build apk --debug` when Android tooling is available
