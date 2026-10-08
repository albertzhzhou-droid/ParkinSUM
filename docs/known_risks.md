# Known Risks

This register tracks accepted and unresolved launch risks. Update it before
every stage/prod release decision.

## P0 Risk Status Table

| Risk | Status | P0 mitigation |
| --- | --- | --- |
| Regulatory positioning | open | Keep decision-support scope and complete legal/privacy review. |
| Firebase environment separation | mitigated | Dev/stage/prod Firebase web configs exist; dev/stage are web-only and fail fast on non-web platforms. |
| Hosting and rollback | mitigated | Stage/prod Hosting are deployed with retained source bundles and live channel release/version records. |
| Real official data acceptance | mitigated | Stage curated seed acceptance and upload passed; owner/operator accepted internal prerelease. External clinical/domain professional review is not claimed. |
| Web backend durability | accepted | Keep backend capability warning visible and documented. |
| Importer conservatism | accepted | Keep uncertain fields in provenance/audit/raw payloads. |
| Custom claims misconfiguration | mitigated | Safe CLI uses dry-run by default and requires confirm flags for writes. |
| User-facing copy integrity | monitored | Existing copy tests and spot-checks remain required. |
| Support and incident response | mitigated for internal prerelease | Support/privacy contact and alert notification email are `parkinsumservice@gmail.com`; `zhouzhenghang` is monitoring and incident response owner for internal/private prerelease. |
| User data export/deletion | mitigated | Stage disposable-account export/delete/Auth deletion drill passed; prod path remains operator-controlled. |
| Backup export and restore | mitigated | Stage export/restore drill passed. Prod billing, budget, controlled bucket, lifecycle, and one manual export passed; prod restore verification is metadata-only and no scheduled export exists. |
| Prod live signed-in probe | mitigated for internal prerelease | Prod read-only probe passed with disposable Auth test users and `writeProbeAllowed=false`; test accounts are retained enabled by operator decision. |
| Monitoring and audit | mitigated for internal prerelease | Cloud Logging/Error Reporting APIs are enabled for prod, Monitoring email notification channel and uptime/error alert policies are configured, local redacted operator-audit summary exists, and `zhouzhenghang` owns monitoring/incident response for internal/private prerelease. |
| Browser public visual smoke | mitigated | Current public visual smoke evidence is recorded in `build/browser_smoke/public_visual_smoke_20260523.json`. |
| Food composition accuracy and interdependency | monitored | Verbatim USDA SR Legacy, FNDDS and FDC 2025 data and NLM RxNorm identities, pinned by SHA-256; energy/closure/derivation and food-specific factor tests; convention-aware carbohydrate handling; food-borne L-dopa and dry/cooked ambiguity widen uncertainty only. See R14. |

## R1: Regulatory Positioning

Status: open.

The app includes clinical decision support behavior. Public positioning must
avoid standalone diagnostic use, treatment instruction, emergency detection, or
claims that bypass professional judgment.

Required mitigation:

- keep intended use decision-support oriented.
- keep evidence basis inspectable.
- complete privacy/legal/regulatory review before public release.

## R2: Firebase Environment Separation

Status: mitigated.

Separate dev/stage/prod Firebase web configs are present and the app validates
the requested environment/project pairing. Dev and stage remain web-only until
non-web FlutterFire configs are intentionally generated.

Required mitigation:

- generate non-web configs only when mobile/desktop stage or dev release is in
  scope.
- prevent prod data from being used for dev testing.

## R3: Hosting and Rollback

Status: mitigated.

`firebase.json` declares Hosting for `build/web`. Stage and prod have been
deployed to Firebase Hosting default `web.app` TLS domains, and retained source
bundles plus live channel release/version ids are recorded.

Required mitigation:

- keep retained build/source artifacts for every release candidate.
- add a custom domain only after domain/TLS ownership is reviewed.
- perform a true prior-version rollback drill once a previous accepted Hosting
  release exists.

## R4: Real Official Data Acceptance

Status: mitigated.

The P0 stage curated official seed generated a retained acceptance report,
uploaded 504/504 documents to stage, and passed post-upload rules/read checks.
This does not replace clinical/domain reviewer sign-off.

Required mitigation:

- complete `docs/real_data_acceptance_checklist.md`.
- retain import logs and release artifacts.
- require operator sign-off.

## R5: Web Backend Durability

Status: accepted with warning when visible.

The web backend may be lightweight or non-transactional compared with native
SQLite paths. This must remain visible in readiness warnings and operator
review.

Required mitigation:

- surface backend capability warnings.
- avoid hiding non-durable artifact fallback.
- do not overclaim transactional guarantees.

## R6: Importer Conservatism

Status: accepted.

Some official-source raw/free-text fields are intentionally not force-structured
into primary tables.

Required mitigation:

- keep uncertain fields in raw payload, provenance, audit output, or readiness
  gaps.
- do not fabricate structured package quantity/size/unit data.
- promote fields only after schema review.

## R7: Custom Claims Misconfiguration

Status: mitigated.

Incorrect `admin` or `cdssImporter` claims could allow unintended writes to
shared reference collections.

Required mitigation:

- use the claims checklist in `docs/firebase_project_claims.md`.
- keep claim grants minimal.
- verify privileged and non-privileged users before release.
- remove stale claims and force token refresh/sign-in when needed.

P0 stage verification granted importer/admin claims, confirmed privileged
catalog writes, cleared the claims, refreshed tokens, and confirmed privileged
writes were denied.

## R8: User-Facing Copy Integrity

Status: monitored.

Recommendation and risk text must remain fluent, localized, and free of
unresolved placeholders.

Required mitigation:

- run copy-focused tests.
- spot-check representative recommendations.
- verify runtime locale overrides and seed export paths.

## R9: Support and Incident Response

Status: mitigated for internal/private prerelease.

The app has a documented support/privacy contact and an internal/private
prerelease incident owner.

Required mitigation:

- support/privacy contact: `parkinsumservice@gmail.com`.
- monitoring and incident response owner: `zhouzhenghang`.
- keep rollback trigger and response time expectations in the operations
  runbook.

## R10: Backup Export and Restore

Status: mitigated.

Stage now has a controlled Cloud Storage bucket and a completed export/restore
drill. Prod now has billing, a controlled Cloud Storage bucket, a 14-day
lifecycle, and one completed manual export drill. Prod restore verification was
metadata-only; no prod, stage, or dev import was run. No scheduled prod export
was created.

Stage evidence:

- billing account linked to `parkinsum-companion-stage`.
- budget:
  `billingAccounts/012517-646CBE-B0D4EC/budgets/2d7dd940-9fc2-4839-a483-edfc62309743`
  with CAD 1 / CAD 5 / CAD 10 thresholds.
- bucket: `gs://parkinsum-companion-stage-p0-backups`.
- lifecycle: delete objects older than 14 days.
- export drill: 479 documents, 461114 bytes.
- restore drill: imported the stage export back into stage, 479/479 documents.
- report: `docs/stage_billing_backup_drill_20260522.md`.

Prod evidence:

- billing account linked to `parkinsum-companion`.
- budget:
  `billingAccounts/012517-646CBE-B0D4EC/budgets/716aa6b7-dae3-4cef-a38d-fce2aebd101e`
  with CAD 1 / CAD 5 / CAD 10 thresholds.
- bucket: `gs://parkinsum-prod-backups`.
- lifecycle: delete objects older than 14 days.
- export drill: 524 documents, 826166 bytes.
- restore verification: metadata-only, no Firestore import executed.
- report: `docs/prod_billing_backup_monitoring_drill_20260522.md`.

Required mitigation:

- require explicit operator confirmation before each future prod export.
- do not enable scheduled prod exports until a separate retention, cost, and
  incident-response review approves automation.
- document retention and deletion-request implications.

## R11: Prod Live Signed-In Probe

Status: mitigated for internal prerelease.

Prod Hosting has been deployed and smoke-checked through HTTP/Hosting checks.
Two disposable readonly prod Auth test users were created for read/deny probing
and are retained enabled by operator decision. No custom claims were granted.
The prod read-only probe passed with `writeProbeAllowed=false`.

Retained account evidence:

- created at: `2026-05-22T16:15:00.228Z`
- uid hashes: `e10ee14e916c`, `af3e1dd65fa0`
- token file: `build/operator_tokens/prod_readonly_tokens.json`, local only,
  mode `0600`
- operator gate:
  `build/operator_reports/p0p1_prod_full_structure_20260522_operator_gate.json`

Required mitigation:

- keep prod read-only probes under `--read-only`; do not perform prod write
  probes.
- do not grant custom claims to retained readonly probe users.
- clean up retained users through audited CLI when no longer needed.
- record any future token refresh or account rotation in operator audit.

## R12: Monitoring and Audit

Status: mitigated for P1, open for public release.

The P1 layer uses Google Cloud Logging/Error Reporting plus local redacted
operator-audit reports. No Crashlytics, analytics, or third-party monitoring is
enabled before privacy/legal review. This reduces premature transmission of
sensitive health input to third-party tools. Incident ownership is assigned for
internal/private prerelease.

Required mitigation:

- owner/operator: `zhouzhenghang`.
- complete sensitive-data redaction review.
- keep Cloud Logging/Error Reporting as the approved internal monitoring path
  unless final privacy review requires a different route.
- keep operator audit summaries free of ID tokens, credential paths, complete
  email addresses, complete UIDs, and user-entered health details.

## R13: Browser Public Visual Smoke

Status: open.

The latest in-app Browser public URL smoke attempt was blocked by Browser
automation policy before opening the Firebase `web.app` targets. HTTP/Hosting
smoke passed for stage/prod, and local preflight browser smoke previously
verified the login UI, but a current public visual Browser pass is not
available.

Required mitigation:

- re-run Browser visual smoke when the Browser policy block is resolved, or
  record an approved manual visual verification.
- keep Chrome/Computer Use read-only if used for visual verification.
- do not route around Browser policy with another automation surface in the
  same blocked session.

## R14: Food Composition Accuracy and Interdependency

Status: monitored.

Food values are sample averages and depend on variety, preparation and the
database's definitions. The 2026-10-08 update adds a verbatim USDA SR Legacy
subset (224 foods), tests every record against energy and closure identities,
tests 23 raw/cooked, dried, juiced and salted derivations plus egg
part–whole, and fixes a carbohydrate-convention mismatch that double-counted
fibre across sources.

Residual risks:

- The subset is retrieved through a third-party mirror (direct USDA access is
  blocked in the build environment); identity checks detect transcription
  errors but not an upstream value that is internally consistent yet wrong.
- Eight CIQUAL-labelled seed foods have a value differing materially from USDA and
  need re-verification against the official CIQUAL file
  (`docs/FOOD_COMPOSITION_INTERDEPENDENCY_RESEARCH_2026-10-08.md`, Section 5).
- Food-borne L-dopa (broad beans, Mucuna) is detected by name/reference id and
  shown as unquantified context; published content varies more than 280-fold
  by tissue and variety. A name the matcher does not know is missed.
- Evidence-currency records for the new sources are not registered yet.
- Iteration 2 replaced hand-entered seed-food nutrients with verbatim USDA SR
  Legacy or FNDDS values; 44 of 186 seed foods have no verified record and
  show every nutrient as unknown. Seven proxy matches (a close but
  non-identical record) are labelled as proxies.
- Eighteen catalog medications carry verified RxNorm (2 December 2024)
  ingredient identities and five carbidopa/levodopa clinical drugs carry
  RxNorm dose forms; three medications (safinamide, the generic iron entry
  and levodopa/benserazide) remain unverified with a reason.
  Identity data never implies a dose or schedule.
- The FoodData Central 2025-04-24 nutrient definitions and conversion factors
  are pinned; a later FDC release can renumber or redefine nutrients and
  needs a re-pin. One food-specific energy factor (coconut oil) disagrees
  across releases and is documented, not corrected.

Required mitigation:

- keep food-borne L-dopa and tyramine as presence/variability context; never
  derive a dose equivalent or a food instruction from them.
- re-verify flagged seed values against official source files before any
  public demonstration relies on them.
- review questions about food, iron, or medicines with a qualified clinician.
