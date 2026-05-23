# ParkinSUM Production Release Checklist

Use this checklist for every production_candidate release. Do not mark a release
complete from local tests alone.

P0 status: the technical stage/prod Hosting and stage live Firebase drills have
been completed, but this checklist is not fully closed for public release.
Support/privacy contact, monitoring ownership, Browser visual evidence, and
owner/operator internal acceptance are recorded. External clinical/legal
professional review is not claimed.

## 1. Scope Freeze

- [ ] Release name and version recorded.
- [ ] Release channel recorded: dev, stage, or prod.
- [ ] Release tag or non-git source bundle id recorded.
- [ ] Intended user group recorded.
- [ ] Intended use statement reviewed.
- [ ] Non-goals recorded: no standalone diagnostic use, no emergency triage, no
      automatic treatment instruction.
- [ ] Supported jurisdictions and source families recorded.
- [ ] Known unsupported source families recorded.
- [ ] User-facing limitations reviewed in the app copy.

## 2. Code and Build Gate

- [ ] `flutter pub get` completed.
- [ ] `flutter analyze` completed with no issues.
- [ ] Full `flutter test` completed.
- [ ] `test/p0_importers_test.dart --concurrency=1` completed.
- [ ] `test/firebase_user_binding_test.dart` completed.
- [ ] `node tool/firestore_rules_contract_check.mjs` completed.
- [ ] Firebase-backed web build completed.
- [ ] No release-blocking TODO/FIXME found in app-owned files.
- [ ] App version and release notes match the intended release.

Recommended commands:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" pub get
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" analyze
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" test
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" test test/p0_importers_test.dart --concurrency=1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" build web --dart-define=PARKINSUM_BACKEND=firebase
```

Latest P0 local gate results:

- `npm audit --audit-level=low`: PASS
- `node tool/firestore_rules_contract_check.mjs`: PASS
- `flutter analyze`: PASS
- `flutter test --concurrency=1`: PASS
- `flutter test test/p0_importers_test.dart --concurrency=1`: PASS
- Firebase web builds for dev/stage/prod: PASS

## 3. Firebase and Data Boundary Gate

- [ ] Target Firebase environment recorded: dev, stage, or prod.
- [ ] Target Firebase project id recorded.
- [ ] `firestore.rules` reviewed for the target project.
- [ ] `users/{uid}` owner-only access verified.
- [ ] `app_catalog` read/write policy verified.
- [ ] Top-level `cdss_tables` remains closed.
- [ ] Admin/importer custom-claim assignment process recorded.
- [ ] Stale admin/importer claims reviewed and removed.
- [ ] Claim grant/removal operator log path recorded.
- [ ] Seed export requires an explicit Firebase uid.
- [ ] Seed upload target project and database confirmed before upload.
- [ ] No patient data is written to shared catalog collections.

## 4. Real Official Data Gate

- [ ] Real official-source import completed.
- [ ] Source family, run id, snapshot id, and backend recorded.
- [ ] Release readiness drill completed on the real snapshot.
- [ ] Blocking issue count recorded.
- [ ] Warning count recorded.
- [ ] Sample issue ids reviewed.
- [ ] Human review tickets resolved or ignored with reviewer, reason, and time.
- [ ] Manifest artifacts confirmed durable.
- [ ] Rollback target confirmed.

## 5. Clinical Safety Gate

- [ ] Every high-risk recommendation exposes a readable reason.
- [ ] Every recommendation with source support exposes provenance/source
      references.
- [ ] Missing data states degrade to cautionary copy instead of confident
      conclusions.
- [ ] Placeholder text and unresolved template variables are absent from
      user-facing copy.
- [ ] The app does not present recommendations as mandatory treatment
      instructions.
- [ ] The app does not claim emergency detection or real-time alarm behavior.
- [ ] Disclaimers are visible before production use.

## 6. Privacy and Security Gate

- [ ] Privacy notice reviewed.
- [ ] Disclaimer reviewed.
- [ ] Account deletion/data deletion process recorded.
- [ ] Support/contact path recorded.
- [ ] Firebase project access list reviewed.
- [ ] Service account/API key exposure reviewed.
- [ ] Firestore backup/export strategy recorded.
- [ ] Audit log retention expectation recorded.
- [ ] Error monitoring path reviewed.
- [ ] Monitoring notification channel verified.
- [ ] Uptime and ERROR alert policies verified.
- [ ] User data export path reviewed.
- [ ] User data deletion path reviewed.

## 7. Release Artifact Gate

- [ ] Release manifest retained.
- [ ] Release tag or source bundle id retained.
- [ ] `release_readiness.json` retained.
- [ ] `conflict_rationale.json` retained.
- [ ] `rule_trace.json` retained.
- [ ] `version_diff.json` retained.
- [ ] `snapshot_manifest.json` retained.
- [ ] Distribution manifest retained.
- [ ] Build artifact retained.
- [ ] Release notes retained.
- [ ] Known-risk record reviewed.
- [ ] Rollback runbook inputs retained.
- [ ] Internal release index retained.
- [ ] Owner/operator acceptance form retained.

## 8. Final Sign-Off

- [x] Operator sign-off for internal/private prerelease.
- [x] Technical reviewer evidence recorded through automated gates.
- [x] Privacy/legal owner acceptance recorded for internal/private prerelease.
- [x] Release decision recorded: internal/private prerelease pass; public
      professional review not claimed.
- [ ] External clinical/legal professional review, if public launch requires
      that claim.

Current P0 decision: hold public release. Technical Hosting deployment and stage
operator validation are complete enough for internal review, but public release
has owner/operator internal acceptance. Public launch still needs any required
external clinical/legal professional review before that claim is made.

## Stop Conditions

Do not publish when any of these are true:

- source provenance is missing for promoted CDSS facts or rules.
- high-severity review tickets are open.
- Firestore user isolation cannot be verified.
- user-facing recommendation text contains unresolved placeholders.
- release artifacts are missing or non-durable without acknowledged warning.
- rollback target is unknown.
- intended use or disclaimer text implies standalone diagnostic use or treatment.
