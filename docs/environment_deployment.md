# Environment and Deployment Guide

This guide records the current deployment shape. It should be updated whenever
Firebase project, hosting, domain, or release infrastructure changes.

## Environment Modes

ParkinSUM has two runtime backend modes in code and three intended operational
environments for release management.

Runtime backend modes:

- local mode: no Firebase backend.
- Firebase mode: `--dart-define=PARKINSUM_BACKEND=firebase`.

Operational environments:

- `dev`: developer validation.
- `stage`: production-like release acceptance.
- `prod`: real release.

The current checked-in Firebase options include web configs for all three
Firebase projects. `dev` and `stage` are intentionally web-only in the runtime;
non-web platforms fail fast so a mobile or desktop build cannot silently connect
to the wrong project.

### Local Mode

Local mode is the default. It does not pass `PARKINSUM_BACKEND=firebase`.

```sh
cd ParkinSUM
flutter run -d chrome
```

Use local mode for UI work, local persistence checks, and development that does
not need real Firebase Auth or Firestore behavior.

### Firebase Mode

Firebase mode is enabled with a Dart define:

```sh
cd ParkinSUM
flutter run -d chrome --dart-define=PARKINSUM_BACKEND=firebase
```

Use Firebase mode for account binding, Firestore rules checks, backend-backed
catalog/CDSS reads, and production_candidate smoke tests.

## Current Firebase Configuration

- Prod project id: `parkinsum-companion`
- Stage project id: `parkinsum-companion-stage`
- Dev project id: `parkinsum-companion-dev`
- Firestore rules file: `firestore.rules`
- Firestore indexes file: `firestore.indexes.json`
- Firebase options file: `lib/firebase_options.dart`
- Prod web app config exists in `lib/firebase_options.dart`
- Stage web app config exists in `lib/firebase_options.dart`
- Dev web app config exists in `lib/firebase_options.dart`
- Dev/stage Android/iOS/macOS app configs are not generated; dev/stage are
  web-only in the app runtime.
- Hosting config is declared in `firebase.json` with `build/web` as the public
  directory.
- Hosting cache policy: `/` and `/index.html` use `no-store`; Flutter static
  assets use `public, max-age=31536000, immutable`.

`flutter build web` produces a web artifact but does not by itself publish the
app. Deployment remains operator-controlled through explicit script flags.

## Firebase Project Status

| Environment | Project id | Web app | Firestore | Auth | Hosting URL | Status |
| --- | --- | --- | --- | --- | --- | --- |
| dev | `parkinsum-companion-dev` | `1:36630731726:web:d9359715300da8fb13299f` | rules/indexes deployed | API enabled | not deployed | cloud project and config created |
| stage | `parkinsum-companion-stage` | configured | rules/indexes deployed | email/password test users | `https://parkinsum-companion-stage.web.app` | deployed and live-probed |
| prod | `parkinsum-companion` | configured | existing prod target | unchanged by this P0 pass | `https://parkinsum-companion.web.app` | Hosting deployed; no prod Firestore writes |

Stage live channel record captured by Firebase CLI:

```text
release: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/channels/live/releases/1779408512894000
version: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/versions/f179c5e30c0f115a
releaseTime: 2026-05-22T00:08:32.894Z
```

Prod live channel record captured by Firebase CLI:

```text
release: projects/parkinsum-companion/sites/parkinsum-companion/channels/live/releases/1779408806993000
version: projects/parkinsum-companion/sites/parkinsum-companion/versions/e37ac581d49babae
releaseTime: 2026-05-22T00:13:26.993Z
```

For target project and claim governance, use
`docs/firebase_project_claims.md`.

For production operations, rules testing, backup/export, audit logging,
monitoring, and user data operations, use
`docs/firebase_operations_runbook.md`.

## Deployment Helper

Use the guarded deployment helper for release validation:

```sh
cd ParkinSUM
PARKINSUM_ENV=stage FIREBASE_PROJECT_ID=parkinsum-companion-stage tool/release_deploy.sh
```

Default behavior runs validation/build only. Deployment requires explicit flags:

```sh
PARKINSUM_ENV=stage FIREBASE_PROJECT_ID=parkinsum-companion-stage tool/release_deploy.sh --deploy-firestore
```

Hosting deployment is intentionally blocked unless the explicit
`--deploy-hosting` flag is provided:

```sh
PARKINSUM_ENV=stage FIREBASE_PROJECT_ID=parkinsum-companion-stage tool/release_deploy.sh --deploy-hosting
```

## Firestore Deployment

Deploy rules and indexes only after reviewing the target Firebase project:

```sh
cd ParkinSUM
firebase deploy --only firestore:rules,firestore:indexes --project parkinsum-companion
```

Stage rules and indexes were deployed to `parkinsum-companion-stage` on
2026-05-21. Use this command to redeploy stage rules after rule changes:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project parkinsum-companion-stage --non-interactive
```

Production rule expectations:

- `users/{uid}` is owner-only.
- `users/{uid}/cdss_tables/...` is user-scoped.
- `app_catalog/...` is readable by signed-in users.
- `app_catalog/...` writes require admin/importer custom claims.
- top-level `cdss_tables/...` is closed.
- fallback deny-all remains in place.

## Web Build

Build the Firebase-backed web artifact:

```sh
cd ParkinSUM
flutter build web --dart-define=PARKINSUM_BACKEND=firebase --dart-define=PARKINSUM_ENV=prod --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion
```

Build the stage Firebase-backed web artifact:

```sh
cd ParkinSUM
flutter build web --dart-define=PARKINSUM_BACKEND=firebase --dart-define=PARKINSUM_ENV=stage --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion-stage
```

Build the dev Firebase-backed web artifact:

```sh
cd ParkinSUM
flutter build web --dart-define=PARKINSUM_BACKEND=firebase --dart-define=PARKINSUM_ENV=dev --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion-dev
```

The output is `build/web`. Stage and prod now use Firebase Hosting with the
default `web.app` TLS domain. A custom public domain is not configured yet.
Do not treat the prod deployment as public/legal release until privacy/support
contact, monitoring, backup, and reviewer sign-off blockers are closed.

## Seed Export and Upload

Export curated official catalog/CDSS seed rows:

```sh
cd ParkinSUM
dart run tool/firebase_seed_export.dart --user-uid=<firebase_uid>
```

The export requires a uid so CDSS rows are written under
`users/{uid}/cdss_tables/...`. This keeps the current publication path
user-scoped.

Dry-run upload:

```sh
cd ParkinSUM
node tool/firestore_seed_upload.mjs build/firebase_seed/official_core_seed.json --dry-run
```

Upload after operator approval:

```sh
cd ParkinSUM
node tool/firestore_seed_upload.mjs build/firebase_seed/official_core_seed.json
```

Upload prerequisites:

- Firebase CLI login is active.
- Access token is not expired.
- Target `projectId` and `databaseId` in the payload are correct.
- Operator has reviewed document count and table counts.
- No user-private clinical data is included in shared catalog rows.

## Required Environment Records

Record these before a real production release:

- Firebase project id.
- Firebase Auth providers enabled.
- Admin/importer claim assignment owner.
- Firestore database id.
- Hosting provider and deployment target.
- Domain and TLS owner.
- Rollback process.
- Backup/export process.
- Monitoring/log review process.
- Support contact.

## Production Smoke Test

After deployment or staging publication:

- [ ] Open the deployed URL.
- [ ] Sign in as user A.
- [ ] Create or exercise a meal/medication check.
- [ ] Confirm audit/user data is written under user A only.
- [ ] Sign out.
- [ ] Sign in as user B.
- [ ] Confirm user B cannot read user A data.
- [ ] Confirm catalog/CDSS data loads.
- [ ] Confirm warning/disclaimer copy is visible.
- [ ] Confirm browser console has no release-blocking errors.
