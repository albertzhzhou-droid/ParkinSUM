# Firebase Production Acceptance Report

Date: 2026-05-21 / 2026-05-22 operator continuation

Scope: local/static Firebase production acceptance preflight, release-candidate
tooling, stage live Firebase writes, stage user-rights drill, stage official
seed acceptance, stage/prod Firebase Hosting technical smoke, and prod
read-only live probes using disposable Auth test users. Prod Firestore data,
prod custom claims, and real prod user data were not written or deleted.

Release manifest:

```text
build/release_manifests/p0_prod_20260521T182839Z.json
build/release_manifests/p0_stage_20260521T1858Z.json
build/release_manifests/p0_stage_20260522T000753Z.json
build/release_manifests/p0_prod_20260522T001247Z.json
```

Manifest status:

- environment: `prod`
- project: `parkinsum-companion`
- stage environment: `stage`
- stage project: `parkinsum-companion-stage`
- dev environment: `dev`
- dev project: `parkinsum-companion-dev`
- app version: `1.0.0+1`
- analyzer: PASS
- full Flutter test suite: PASS
- importer smoke: PASS
- Firestore rules contract: PASS
- dev/stage/prod web builds: PASS
- stage/prod Hosting deploy: PASS
- browser smoke: public visual Browser evidence passed for stage/prod public
  URLs; HTTP/Hosting smoke also passed
- stage live Firestore probe: PASS
- stage user export/delete drill: PASS
- stage official seed acceptance/upload: PASS
- prod read-only live probe: PASS with disposable readonly Auth users,
  `writeProbeAllowed=false`
- stage backup export/restore: PASS with billing, budget, bucket lifecycle, and
  restore drill
- prod backup: manual-only, not connected to billing or automated export

## Code and Rules Preflight

Command:

```sh
PARKINSUM_ENV=prod \
PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion \
tool/firebase_production_acceptance.sh
```

Result: PASS after rerunning with permission to update the local Flutter SDK
cache.

Completed checks:

- `flutter analyze`: PASS, no issues found.
- `flutter test test/firebase_user_binding_test.dart`: PASS, 4 tests passed.
- `node tool/firestore_rules_contract_check.mjs`: PASS, 10/10 checks passed.
- `flutter build web --dart-define=PARKINSUM_BACKEND=firebase --dart-define=PARKINSUM_ENV=prod --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion`:
  PASS, `build/web` generated.

Rules contract checks passed:

- signed-in helper exists.
- owner helper binds `request.auth.uid` to `uid`.
- admin/importer helper recognizes custom claims.
- `users/{uid}` subtree is owner-only.
- user-scoped `cdss_tables` are owner-only.
- `app_catalog` read requires signed-in user.
- `app_catalog` write requires admin/importer.
- top-level `cdss_tables` are closed.
- fallback deny-all exists.
- no blanket allow-all rule exists.

## Browser Smoke

Served artifact:

```sh
python3 -m http.server 8788 --bind 127.0.0.1 --directory build/web
```

HTTP check:

```text
HTTP/1.0 200 OK
Content-type: text/html
Content-Length: 1223
```

Browser plugin check:

- Opened `http://127.0.0.1:8788/`.
- Firebase-backed build rendered a nonblank first screen.
- First screen displayed `ParkinSUM Account`.
- Sign-in UI rendered with email, password, sign-in button, and register link.
- Browser console showed app bootstrap and Firebase sign-in wait messages only;
  no runtime errors were observed during the smoke.
- Screenshot artifact:
  `build/browser_smoke/p0_prod_20260521T182839Z.png`.

No real Firebase login, registration, claim grant, or production write was
attempted because no test credentials were supplied and those actions would
modify external account/backend state.

## Documents Added or Updated

- `docs/firebase_operations_runbook.md`
- `docs/privacy_policy_draft.md`
- `tool/firestore_rules_contract_check.mjs`
- `tool/firebase_production_acceptance.sh`
- `tool/firebase_ops.mjs`
- `tool/firestore_live_probe.mjs`
- `tool/release_manifest.mjs`
- `tool/release_deploy.sh`
- `docs/real_data_acceptance_report_template.md`
- `README.md`
- `docs/release_readiness_runbook.md`
- `docs/production_release_checklist.md`
- `docs/environment_deployment.md`
- `docs/privacy_disclaimer_draft.md`
- `docs/known_risks.md`
- `firebase.json`
- `lib/firebase_options.dart`
- `lib/core/services/firebase_backend.dart`
- `package.json`
- `package-lock.json`
- `.gitignore`
- `.firebaserc`
- `tool/firebase_stage_test_accounts.mjs`

## Operator Environment Setup

System setup completed on this machine:

- Homebrew `node` installed; `npm 11.12.1` is available.
- Homebrew `corepack 0.35.0` is available.
- `~/.zshrc` now adds `/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin`
  to interactive zsh `PATH`.
- Google Cloud CLI installed, and `~/.zshrc` now adds
  `/opt/homebrew/share/google-cloud-sdk/bin` to interactive zsh `PATH`.
- Application Default Credentials were created with
  `gcloud auth application-default login` at
  `/Users/zhouzhenghang/.config/gcloud/application_default_credentials.json`;
  `~/.zshrc` exports this path as `GOOGLE_APPLICATION_CREDENTIALS`.
- `firebase-admin` dependency installed into local `node_modules`.
- `firebase-admin` was updated to `13.10.0`.
- `npm audit --audit-level=low`: PASS, found 0 vulnerabilities.

## Stage Firebase Setup

Stage cloud setup completed on 2026-05-21:

- Firebase project created: `parkinsum-companion-stage`.
- Stage Firebase Web app created: `ParkinSUM Companion Stage Web`.
- Stage Web app config added to `lib/firebase_options.dart`.
- Stage Firestore rules and indexes deployed with Firebase CLI.
- Stage Firestore `(default)` database created by Firebase CLI during deploy.
- Stage Authentication initialized.
- Email/password sign-in enabled for stage test accounts.
- Stage test accounts created for user A, user B, and importer.
- Stage admin and disposable test accounts created for the P0 operator drill.
- Importer test account received `cdssImporter: true`.
- Admin test account received `admin: true`.
- Stage ID tokens were written only to local `build/operator_tokens/`.
- Stage Hosting was deployed to `https://parkinsum-companion-stage.web.app`.

Stage local validation:

- `flutter analyze`: PASS.
- `flutter test test/firebase_user_binding_test.dart`: PASS, 4 tests passed.
- `npm run rules:contract`: PASS, 10/10 checks passed.
- `npm audit --audit-level=low`: PASS, found 0 vulnerabilities.
- `flutter build web --dart-define=PARKINSUM_BACKEND=firebase --dart-define=PARKINSUM_ENV=stage --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion-stage`:
  PASS.
- Browser smoke for the stage build: PASS. Screenshot artifact:
  `build/browser_smoke/p0_stage_20260521T1858Z.png`.

Dev cloud setup completed on 2026-05-21:

- Firebase project created: `parkinsum-companion-dev`.
- Firebase Web app created: `ParkinSUM Companion Dev Web`.
- Web app id: `1:36630731726:web:d9359715300da8fb13299f`.
- Dev web Firebase options added to `lib/firebase_options.dart`.
- Firestore rules and indexes deployed to dev.
- Dev build passed with `PARKINSUM_ENV=dev` and
  `PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion-dev`.

Prod technical Hosting setup completed on 2026-05-21:

- Prod Hosting deployed to `https://parkinsum-companion.web.app`.
- Prod source bundle retained at
  `build/release_artifacts/p0_prod_20260522T001247Z/p0_prod_20260522T001247Z_source.tar.gz`.
- Prod web artifact checksum recorded in
  `build/release_manifests/p0_prod_20260522T001247Z.json`.
- Prod readonly disposable Auth users were created for read/deny probing on
  2026-05-22 and retained enabled by operator decision. No prod Firestore
  write, prod claim mutation, or prod user deletion was performed.

## Operator Tooling Dry Runs

The following dry runs were executed locally. They wrote local operator audit
JSONL records only and did not mutate Firebase:

- claims dry run for `cdssImporter` on a stage test uid: PASS.
- user export dry run scoped to `users/stage_test_user_a`: PASS.
- user delete dry run scoped to `users/stage_test_disposable_uid`: PASS.
- Firestore backup command generator for release `p0_operator_test`: PASS.
- live probe without ID tokens: PASS as a dry-run readiness check, reporting the
  required token inputs.

Real `--execute` mode still requires the expected Firebase project and explicit
confirmation flags such as `--confirm <uid>` and `--confirm-project <projectId>`.

Stage live Firestore probe completed with PASS:

- user A wrote `users/{uidA}/app_meta/{probe}`: PASS.
- user A could not read user B private `app_meta`: PASS.
- normal signed-in user could read allowed `app_catalog` path; missing row
  returned 404 as expected: PASS.
- normal signed-in user could not write `app_catalog`: PASS.
- importer user could write `app_catalog/live_probe/rows/{probe}`: PASS.
- top-level `cdss_tables` read remained denied: PASS.
- admin user could write `app_catalog/live_probe_admin/rows/{probe}` before
  claim removal: PASS.
- importer/admin writes failed after claims were cleared and tokens refreshed:
  PASS.
- after stage official seed upload, normal signed-in read of
  `app_catalog/foods/rows/food_banana` returned 200: PASS.

Latest run id:

```text
p0_seed_read_20260522
```

Prod Auth disposable readonly users were created later for the approved prod
read-only probe. No prod claims, prod Firestore writes, or prod deletes were
performed.

## Official Data Acceptance

Stage official seed acceptance was completed using the current curated P0 seed:

```text
report: build/acceptance_reports/p0_stage_real_data_acceptance_20260522.md
seed: build/firebase_seed/stage_official_core_seed.json
sha256: 70f5fc58fe8e05bba574ddd9d79ed70b2a4b33210b9d8b416eaff019eda54f95
snapshot id: firebase_seed_p0_core_v1
import run id: ingest_firebase_seed_p0_core_v1
documents: 504
```

Document counts:

- `app_catalog/foods`: 20
- `app_catalog/medications`: 21
- `app_catalog/interaction_rules`: 3
- `users/liJgCPx8N8UQOler81M7Srkdyd22`: 460

Readiness status: 0 blockers, 2 warnings. The warnings are that curated seed
acceptance does not replace external clinical/domain professional review, and
public contact is now `parkinsumservice@gmail.com`.

Stage seed upload committed 504/504 documents. A post-upload live probe
confirmed signed-in catalog read and normal-user write denial.

## User Rights Drill

Stage disposable account drill completed:

```text
uid: uAN2yV1gfRSGR1DsLE0uLk6Ey2P2
write probe path: users/uAN2yV1gfRSGR1DsLE0uLk6Ey2P2/app_meta/p0_user_rights_20260522
export artifact: build/user_exports/p0_stage_disposable_export.json
post-delete export artifact: build/user_exports/p0_stage_disposable_after_delete.json
```

Results:

- user export scoped to `users/{uid}` only: PASS, 1 document exported.
- user deletion removed Firestore private data: PASS, 1 document deleted.
- optional Auth account deletion for the disposable test account: PASS.
- post-delete verification export: PASS, 0 documents.
- operator audit JSONL recorded each action.

## Hosting and Browser Smoke

Stage Hosting:

```text
url: https://parkinsum-companion-stage.web.app
release: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/channels/live/releases/1779408512894000
version: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/versions/f179c5e30c0f115a
source bundle sha256: e3ad04eb3feb65712f6fd40a36af11628d1371911be953060e604dd21119da4d
web build sha256: b702b79f6ca551bc05d22f7ba9d85b6b46b9a5c59b2fecfc5785154ce9852a65
```

Prod Hosting:

```text
url: https://parkinsum-companion.web.app
release: projects/parkinsum-companion/sites/parkinsum-companion/channels/live/releases/1779408806993000
version: projects/parkinsum-companion/sites/parkinsum-companion/versions/e37ac581d49babae
source bundle sha256: 53709e93a0f759d9cd7f666cb90b90c29ae4883f7adfc20b611476e87a05871c
web build sha256: e8b59d5a3d32d75e9693ff08af51276e99fc47672a298e99d426f8611d07dc17
```

HTTP/Hosting smoke for the public stage and prod Hosting URLs passed. HTTP HEAD
checks for both URLs returned 200 and `cache-control: no-store, max-age=0`.

The current in-app Browser public visual smoke opened both Firebase `web.app`
targets in read-only mode and captured screenshot evidence. This is recorded at
`build/browser_smoke/public_visual_smoke_20260523.json` with status `PASS`.

Prod read-only probe:

```sh
node tool/firestore_live_probe.mjs --env prod --project parkinsum-companion --read-only --token-file build/operator_tokens/prod_readonly_tokens.json
```

Result:

```text
status: PASS
runId: p0p1_prod_full_structure_20260522_live_probe
writeProbeAllowed: false
account retention: enabled_after_probe
uid hashes: e10ee14e916c, af3e1dd65fa0
```

The local prod token file is mode `0600` and stays under ignored `build/`.
The probe verified unauthenticated private denial, user A denied on user B
private data, signed-in catalog read, top-level `cdss_tables` denial, and
fallback denial. It performed no prod Firestore writes.

## Backup Export and Restore

Stage billing/budget/bucket setup completed:

```text
billing account: billingAccounts/012517-646CBE-B0D4EC
stage billing: enabled
prod billing: disabled
budget: billingAccounts/012517-646CBE-B0D4EC/budgets/2d7dd940-9fc2-4839-a483-edfc62309743
budget thresholds: CAD 1, CAD 5, CAD 10
bucket: gs://parkinsum-companion-stage-p0-backups
bucket location: US multi-region
lifecycle: delete objects older than 14 days
public access prevention: enforced
uniform bucket-level access: enabled
```

Stage export drill:

```text
output: gs://parkinsum-companion-stage-p0-backups/parkinsum/stage_export_drill_20260522
operation: projects/parkinsum-companion-stage/databases/(default)/operations/ASA1NGI3ZTJmNTkwOGEtOWQ5Yi00ZjA0LTZmZDgtOTZhYjg0NWQkGnNlbmlsZXBpcAkKMxI
result: SUCCESSFUL
documents: 479
bytes: 461114
```

Stage restore drill:

```text
preferred target: parkinsum-companion-dev
preferred target result: blocked because dev billing remains disabled by policy
actual target: parkinsum-companion-stage
operation: projects/parkinsum-companion-stage/databases/(default)/operations/AiAzOGJhNGI1NzkwZDktYzM3OS04Mzg0LWJlOGMtN2FhYjUzYTckGnNlbmlsZXBpcAkKMxI
result: SUCCESSFUL
documents: 479/479
bytes: 461114/461114
```

Report:
`docs/stage_billing_backup_drill_20260522.md`.

Prod backup is now configured for explicit operator-run exports. Prod billing,
budget, bucket lifecycle, and one manual export drill are complete. No scheduled
prod export was created and no Firestore import was run:

```sh
node tool/firebase_ops.mjs backup-command --env prod --project parkinsum-companion --release-id <release_id> --bucket gs://parkinsum-prod-backups
```

Prod export drill:

```text
output: gs://parkinsum-prod-backups/parkinsum/prod_export_drill_20260522
operation: projects/parkinsum-companion/databases/(default)/operations/ASBiNmJiYzc4NTYzZDktYzRjYi1mY2M0LTM4ZGQtNGExNjYxMzkkGnNlbmlsZXBpcAkKMxI
result: SUCCESSFUL
documents: 524
bytes: 826166
restore verification: metadata-only, no import run
```

Report:
`docs/prod_billing_backup_monitoring_drill_20260522.md`.

## Remaining Live Production Acceptance

These remain before public/legal release:

- confirm production monitoring and incident response owners.
- decide retention/cleanup timing for the retained prod readonly disposable
  Auth test accounts.
- retain Browser/Chrome visual verification evidence without changing Firebase
  state.
- support/privacy contact is `parkinsumservice@gmail.com`.
- owner/operator internal clinical/domain and privacy/legal acceptance is
  recorded; external professional review is not claimed.
