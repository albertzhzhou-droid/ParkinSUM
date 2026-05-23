# Rollback Runbook

Rollback must restore a known accepted app build, ruleset, and knowledge
snapshot. Do not rely on browser cache or local build folders as the only
rollback source.

## Rollback Triggers

Start rollback review when any of these occur:

- production recommendation copy is misleading or unresolved.
- source provenance is missing for promoted facts or rules.
- Firebase account isolation fails.
- release artifacts are missing or corrupt.
- real official data acceptance was based on the wrong snapshot.
- a high-severity review ticket was incorrectly ignored.
- deployment target or Firebase project was wrong.

## Required Inputs

- current release id.
- previous accepted release id.
- current app build artifact or hosting version id.
- previous app build artifact or hosting version id.
- current and previous Firestore rules/indexes.
- current and previous snapshot ids.
- `version_diff.json`.
- rollback summary from release readiness artifacts.
- operator approval.

## App Rollback

If Firebase Hosting is used:

1. Identify the previous Hosting release/version id.
2. Roll back in Firebase Hosting or redeploy the retained previous `build/web`
   artifact.
3. Confirm the deployed URL serves the expected app version.
4. Clear or account for CDN/browser cache behavior.

If another static host is used:

1. Redeploy the retained previous artifact.
2. Confirm domain, TLS, and cache behavior.
3. Record the deployment id.

If Hosting is not configured:

1. Record that app rollback is limited to the retained local/distribution
   artifact.
2. Do not claim public production rollback capability.

## Current P0 Hosting Targets

Stage current live target:

```text
url: https://parkinsum-companion-stage.web.app
release: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/channels/live/releases/1779408512894000
version: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/versions/f179c5e30c0f115a
retained source bundle: build/release_artifacts/p0_stage_20260522T000753Z/p0_stage_20260522T000753Z_source.tar.gz
source bundle sha256: e3ad04eb3feb65712f6fd40a36af11628d1371911be953060e604dd21119da4d
```

Prod current live target:

```text
url: https://parkinsum-companion.web.app
release: projects/parkinsum-companion/sites/parkinsum-companion/channels/live/releases/1779408806993000
version: projects/parkinsum-companion/sites/parkinsum-companion/versions/e37ac581d49babae
retained source bundle: build/release_artifacts/p0_prod_20260522T001247Z/p0_prod_20260522T001247Z_source.tar.gz
source bundle sha256: 53709e93a0f759d9cd7f666cb90b90c29ae4883f7adfc20b611476e87a05871c
```

Firebase CLI on this machine exposes current live channel metadata through
`firebase hosting:channel:list --json`. It does not expose a
`hosting:releases:list` command. Until a previous accepted Hosting release is
recorded, rollback input is the retained source bundle plus a redeploy of the
previous accepted build.

Stage rollback drill status: retained-artifact redeploy path documented; a true
prior-version rollback is still pending because no previous accepted stage
Hosting release was available in this P0 pass.

Prod rollback status: current release/version recorded; no prod rollback was
executed because this was the first technical Hosting deploy in the current P0
chain and prod rollback should not be exercised without a prior accepted target.

## Firestore Rules Rollback

Redeploy the previously accepted rules/indexes when rule behavior is implicated:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project <firebase_project_id>
```

After redeploy:

- [ ] user A cannot access user B private data.
- [ ] unauthenticated private access fails.
- [ ] shared catalog write still requires admin/importer claims.
- [ ] top-level `cdss_tables` remains denied.

## Knowledge Snapshot Rollback

Use release artifacts to identify:

- rollback target or parent snapshot.
- restored fact count.
- restored rule count.
- restored runtime count.
- retired record count.
- active record count after rollback.

Current P0 stage seed rollback input:

```text
snapshot id: firebase_seed_p0_core_v1
import run id: ingest_firebase_seed_p0_core_v1
seed artifact: build/firebase_seed/stage_official_core_seed.json
seed sha256: 70f5fc58fe8e05bba574ddd9d79ed70b2a4b33210b9d8b416eaff019eda54f95
acceptance report: build/acceptance_reports/p0_stage_real_data_acceptance_20260522.md
```

The current seed has no parent snapshot recorded. A future snapshot rollback
must define the previous accepted seed or snapshot artifact explicitly before
publication.

After applying rollback:

- [ ] run production_candidate readiness on the restored snapshot.
- [ ] confirm blocker/warning state is understood.
- [ ] confirm `version_diff.json` matches the intended rollback.
- [ ] run representative recommendation spot checks.
- [ ] record operator decision.

## Post-Rollback Verification

Minimum verification:

```sh
cd ParkinSUM
flutter analyze
flutter test
```

Then verify in Firebase/stage or prod:

- [ ] app opens.
- [ ] sign-in works.
- [ ] catalog/CDSS data loads.
- [ ] recommendation copy is fully rendered.
- [ ] source evidence is inspectable.
- [ ] account isolation still holds.

## Rollback Record

Record:

- rollback start time.
- trigger.
- operator.
- reviewer.
- previous release id restored.
- app artifact or hosting version restored.
- rules/indexes version restored.
- snapshot id restored.
- verification results.
- remaining risks.
- follow-up issue list.
