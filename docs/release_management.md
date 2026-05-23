# Release Management

This document defines release tags, version records, and artifact retention for
ParkinSUM Companion. It is a process document only; it does not create tags by
itself.

## Release Channels

- `dev`: local and developer-facing validation. Data may be temporary.
- `stage`: production-like validation with test users and accepted test data.
- `prod`: public or real operator-facing release. Requires full sign-off.

Do not promote directly from `dev` to `prod`. A release candidate must pass the
stage gate before prod publication.

## Version Format

App version is declared in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

Use semantic versioning for user-visible releases:

- Patch: copy fixes, documentation, small non-breaking bug fixes.
- Minor: new supported workflow, new source family, or material UI capability.
- Major: changed intended use, data model, safety boundary, or release gate
  behavior.

Build number must increase for every distributed build.

## Tag Format

Use annotated tags when the repository is a real git checkout:

```sh
git tag -a parkinsum-v<app_version>-rc.<n> -m "ParkinSUM <app_version> release candidate <n>"
git tag -a parkinsum-v<app_version> -m "ParkinSUM <app_version> production release"
```

Examples:

- `parkinsum-v1.0.0-rc.1`
- `parkinsum-v1.0.0`

If the working directory is not a git checkout, record the release id in the
release manifest and artifact folder instead of inventing a tag.

Current P0 source identity uses retained source bundles because this directory
is not a git checkout:

| Environment | Release id | Manifest | Source bundle sha256 |
| --- | --- | --- | --- |
| stage | `p0_stage_20260522T000753Z` | `build/release_manifests/p0_stage_20260522T000753Z.json` | `e3ad04eb3feb65712f6fd40a36af11628d1371911be953060e604dd21119da4d` |
| prod | `p0_prod_20260522T001247Z` | `build/release_manifests/p0_prod_20260522T001247Z.json` | `53709e93a0f759d9cd7f666cb90b90c29ae4883f7adfc20b611476e87a05871c` |

## Release Manifest Fields

Every production_candidate release should retain a manifest with:

- release id.
- app version and build number.
- channel: dev, stage, or prod.
- source reference: git commit/tag, archive checksum, or operator-controlled
  source bundle id.
- Firebase project id and database id.
- backend mode and hosting target.
- source family, import run id, snapshot id, and parent snapshot id.
- test command results.
- release artifact paths.
- readiness status, blocker count, warning count, and review ticket summary.
- rollback target.
- override reason, if used.
- sign-off names and timestamps.

## Artifact Retention

Retain these for every stage/prod candidate:

- `build/web` or the published hosting version id.
- release manifest.
- release notes.
- `release_readiness.json`.
- `conflict_rationale.json`.
- `rule_trace.json`.
- `version_diff.json`.
- `snapshot_manifest.json`.
- import logs.
- seed payload checksums.
- Firebase rules/indexes used for the release.

Keep prod artifacts durable enough to support rollback and audit review.

## Current Hosting Records

Stage:

```text
url: https://parkinsum-companion-stage.web.app
release: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/channels/live/releases/1779408512894000
version: projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/versions/f179c5e30c0f115a
web build sha256: b702b79f6ca551bc05d22f7ba9d85b6b46b9a5c59b2fecfc5785154ce9852a65
```

Prod:

```text
url: https://parkinsum-companion.web.app
release: projects/parkinsum-companion/sites/parkinsum-companion/channels/live/releases/1779408806993000
version: projects/parkinsum-companion/sites/parkinsum-companion/versions/e37ac581d49babae
web build sha256: e8b59d5a3d32d75e9693ff08af51276e99fc47672a298e99d426f8611d07dc17
```

Cache policy is recorded in `firebase.json`: `index.html` and `/` are
`no-store`; Flutter static assets are long-cache immutable. Custom domain and
public launch sign-off are not complete.

## Release Notes Template

```md
# ParkinSUM Companion <version>

Channel:
Release id:
Build:
Firebase project:
Snapshot id:
Rollback target:

## Changes

-

## Validation

- flutter analyze:
- flutter test:
- importer smoke:
- Firebase account isolation:
- real official data acceptance:

## Known Risks

-

## Sign-Off

- Operator:
- Technical reviewer:
- Domain reviewer:
- Privacy/legal reviewer:
```
