# Repository Audit

Audit date: 2026-05-25

This audit summarizes the current ParkinSUM repository state so future
visibility-oriented work can proceed without weakening existing app behavior or
the public educational prototype boundary.

## Project Structure Summary

- `lib/`: Flutter application code, including app shell, feature pages, local
  and Firebase-capable data services, deterministic rule execution, copy/i18n,
  importer projections, and recommendation orchestration.
- `test/`: Flutter test suite covering rule execution, importer behavior,
  Firebase path isolation, onboarding, copy rendering, recommendation behavior,
  and release-service checks.
- `tool/`: Node and Dart operator tooling for public preflight, Firestore rules
  checks, Firebase operations, seed export/upload, release gates, monitoring,
  audit reports, and related internal validation flows.
- `docs/`: Architecture, rule-engine, release-readiness, Firebase operations,
  public demo boundary, risk, rollback, and acceptance documentation.
- Platform folders: `android/`, `ios/`, `macos/`, `linux/`, `windows/`, and
  `web/` contain generated Flutter platform scaffolding and app configuration.
- Firebase/operator config: `firebase.json`, `firestore.rules`,
  `firestore.indexes.json`, platform Firebase config files, and the Node
  operator scripts support internal validation only.
- CI workflow: `.github/workflows/public-release-preflight.yml` runs `npm ci`,
  public preflight, Firestore rules contract validation, `flutter analyze`, and
  `flutter test --concurrency=1`.

Commands should be run from this Git repository root. The local parent
workspace can contain non-repository artifacts and should not be treated as the
Flutter project root.

## Current Build And Test Commands

The README quick-start commands are accurate for this repository root:

```sh
flutter pub get
flutter analyze
flutter test
```

Additional documented checks:

```sh
npm run public:preflight
node tool/firestore_rules_contract_check.mjs
```

Local app run command:

```sh
flutter run -d chrome
```

Internal Firebase-backed commands in the README and operations docs require
appropriate Firebase project access. They must not be treated as public demo
requirements.

## Verification Results

The following checks were run during this audit:

| Command | Result | Notes |
| --- | --- | --- |
| `flutter pub get` | Pass | Dependencies resolved. Flutter reported newer package versions are available but incompatible with current constraints. |
| `flutter analyze` | Pass | No issues found. |
| `flutter test` | Pass | 148 tests passed. |
| `npm run public:preflight` | Pass | 0 `BLOCKER`, 6 `WARN`, 4 `INFO`. Report written under generated `build/public_release_preflight/`. |
| `node tool/firestore_rules_contract_check.mjs` | Pass | Firestore rules contract passed 10/10 checks. |

Environment note: running Flutter inside the sandbox first failed because the
Flutter SDK cache could not write `bin/cache/engine.stamp`. Rerunning with
permission for the local Flutter SDK cache resolved the limitation. This was an
environment permission issue, not an app code failure.

## Missing Or Fragile Areas

- Many `tool/` scripts are operator or Firebase workflows and require
  credentials, custom claims, project access, or retained operator evidence.
  They should remain separate from public local-first verification.
- `build/public_release_preflight/` is generated output. It can be useful for
  local evidence but should not be confused with source documentation.
- Public screenshots and demo media are placeholders/checklists only. Any
  future media must use synthetic or sample data and avoid credential-bearing
  logs, real medication schedules, real health records, or real patient data.
- The repository contains both local-first app code and Firebase-backed
  internal validation paths. Future visibility work should avoid making Firebase
  a public demo dependency.
- Dependency updates are available, but updating them would be broader than this
  audit. Keep version changes separate and verify with the full Flutter suite.

## Recommended Next Steps

- Keep README commands portable and rooted at the cloned repository root.
- Use `flutter pub get`, `flutter analyze`, and `flutter test` as the baseline
  local verification before public-facing UI or documentation changes.
- Use `npm run public:preflight` and
  `node tool/firestore_rules_contract_check.mjs` before public visibility or
  release-readiness changes.
- Treat Firebase/operator scripts as internal validation tools unless a task
  explicitly requires credentialed project work.
- Add screenshots or demo media only after capturing the current app with
  synthetic/sample data.
- Keep future dependency, architecture, importer, or Firebase changes in
  separate focused work so audit evidence stays easy to interpret.

## Safety And Compliance Notes

ParkinSUM must remain an educational prototype for Parkinson's disease
food-drug interaction awareness. It is not a medical device and must not be
presented as clinical software.

Do not strengthen claims beyond educational, synthetic, sample, or demo wording.
Do not present app output as diagnosis, treatment, individualized dietary
guidance, medication timing advice, patient care, emergency support, or a
replacement for professional medical judgment.

Public demos and public-facing documentation must use only synthetic or sample
data. Do not add real patient data, real health records, real medication
schedules, or paid/cloud API dependencies for public local-first verification.
