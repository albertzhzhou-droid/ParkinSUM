# Changelog

All notable public-showcase changes are documented here.

This project follows versioned release notes for public GitHub releases. Public
release language must preserve the educational-only safety boundary and must not
claim clinical validation, medical-device status, treatment guidance, or
real-world patient-care readiness.

## v0.2.0-beta - 2026-06-02

### Added

- Public beta release package for ParkinSUM Companion, consolidating the
  peripheral-algorithm integration line (P1–P12) and the compiler-governed copy
  layer on top of the v0.1.0-alpha showcase.
- Canonical release notes at `docs/release/v0.2.0-beta-notes.md`.
- Deterministic, review-only peripheral support algorithms, each with a CLI
  report and unit tests: input quality gate (P1), catalog resolution engine
  (P2), source version drift checker (P3), local evidence graph builder (P4),
  synthetic scenario fuzzer (P5), explanation copy compiler + safe copy template
  registry (P6), localization safety lint (P7), local privacy preflight (P8),
  source access contract checker (P9), public demo walkthrough generator (P10),
  contribution safety router (P11), and release snapshot generator (P12).
- Runtime copy migration: user-facing boundary/disclaimer and legacy
  rule-finding copy is now resolved through the compiler-validated
  `ExplanationCopyService` (locale-strict; English byte-identical to the existing
  `app_i18n` source; non-English translations preserved via fallback).
- An i18n parity drift guard that pins every migrated template to its live
  `app_i18n` source so copy cannot silently diverge.
- Capability matrix and per-feature documentation for the peripheral layer.

### Changed

- App version metadata bumped to `0.2.0+2`.

### Safety / Not Included

- No change to the deterministic scoring engine, importers, or Firebase rules.
- No clinical validation, medical-device clearance, regulatory approval, or
  patient-outcome evidence. The peripheral algorithms are review-only report
  tooling and are not wired into scoring.
- Educational synthetic/sample data only; no real patient data, credentials, or
  production deployment.

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
