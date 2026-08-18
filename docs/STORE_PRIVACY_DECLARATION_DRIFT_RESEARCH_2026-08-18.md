# Store privacy declaration drift gate research

Reviewed: 2026-08-18

## Decision

ParkinSUM now treats store privacy answers as a dated human-reviewed contract,
not as prose that can silently diverge from the application. The repository
gate compares that contract with dependency locks, Apple privacy manifests and
release entitlements, Android permissions and backup policy, literal Dart
network destinations, and explicit data-flow classifications. A built Android
merged manifest or Apple app bundle can be supplied for artifact checks.

The tooling does **not** decide legal compliance, infer a lawful basis, submit
answers, or treat a passing repository comparison as App Store Connect or Play
Console approval.

## Primary-source findings

### Apple

- A privacy manifest is a `PrivacyInfo.xcprivacy` target resource. Apple says
  it records collected-data categories, tracking, tracking domains, and
  required-reason APIs. Invalid manifests can cause App Store submission
  rejection, and the final bundle must contain the manifest at its documented
  location.
  - <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>
  - <https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk>
- App Privacy responses must include the practices of integrated third-party
  code and stay accurate when practices change. App-level answers must be
  comprehensive when platforms differ.
  - <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy>
  - <https://developer.apple.com/app-store/app-privacy-details/>
- Required-reason API declarations use an API category plus approved reason
  identifiers. The current app target does not directly declare such an API;
  reviewed plugin manifests currently cover UserDefaults access by
  `shared_preferences_foundation` and `flutter_local_notifications`. The
  `flutter_secure_storage_darwin` manifest declares no collected-data,
  tracking, or required-reason API entries; its exact bytes and parsed facts
  are now independently pinned through the resolved package path.
  `printing` 5.15.0 does not bundle an Apple privacy manifest, so its print and
  share behavior is reviewed explicitly rather than being inferred from a
  nonexistent manifest. ParkinSUM does not use the package's runtime Google
  Fonts helper or Web `PdfPreview`/PDF.js path for this feature.
  - <https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest>

### Google Play and Android

- Google Play requires the developer to disclose app and third-party SDK data
  handling. Google states that the developer, not the store or SDK provider,
  is responsible for complete and accurate Data Safety answers.
  - <https://support.google.com/googleplay/android-developer/answer/10787469>
  - <https://support.google.com/googleplay/android-developer/answer/13326895>
- Android Auto Backup normally includes preferences, files, and databases.
  `allowBackup=false` is not a complete cross-vendor statement for Android 12+
  device-to-device transfer, so ParkinSUM now supplies explicit deny-all
  `data-extraction-rules` for both cloud backup and device transfer. User-owned
  portability remains an explicit, previewed application workflow.
  - <https://developer.android.com/identity/data/autobackup>

## Repository contract

Authoritative files:

- `config/store_privacy_contract.json`
- `ios/Runner/PrivacyInfo.xcprivacy`
- `macos/Runner/PrivacyInfo.xcprivacy`
- `android/app/src/main/res/xml/data_extraction_rules.xml`
- `tool/store_privacy_contract_check.mjs`

The versioned contract currently records:

- 23 direct Flutter runtime dependencies and the complete `pubspec.lock`
  identity covering 122 resolved packages; the additions are offline `pdf`
  generation and user-initiated system `printing`/sharing;
- the operator-only production Node dependency identity;
- iOS and macOS Swift Package lock identities;
- four Apple collected-data categories for the Firebase-capable product:
  email address, user ID, health data, and other user content;
- no tracking and no tracking domains;
- reviewed plugin required-reason manifest claims, including a byte- and
  fact-pinned `flutter_secure_storage_darwin` manifest;
- Android source and expected merged permissions with one bounded purpose per
  permission;
- 40 literal HTTP(S) hosts found in Dart source plus bounded dynamic Firebase,
  local-AI loopback, and catalog-source classes;
- local, Firebase, notification, portable-export, personal-log handoff,
  privacy-safe support-bundle, platform-protected local owner-capability, and
  explicitly disabled telemetry flows;
- dated draft App Store and Google Play snapshots.

## Commands

```bash
npm run privacy:store
node tool/store_privacy_contract_check.mjs \
  --android-manifest build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml
node tool/store_privacy_contract_check.mjs \
  --apple-bundle build/ios/iphonesimulator/Runner.app
node tool/store_privacy_contract_check.mjs --require-store-approval
```

The last command is expected to fail until an authorized store owner reviews
the current artifacts and records dated approval. This prevents repository
green checks from being mislabeled as store readiness.

The support-bundle flow is local and user initiated. Its schema excludes
health records, account identifiers, endpoints, paths, raw exceptions, logs,
and free-form text; the user reviews the exact bounded JSON before Copy or a
conservative Save / browser-download request. There is no support upload or
issue-creation destination in the current application. A future support-case
workflow must remain a separate consented flow because user-authored text and
screenshots cannot inherit the machine bundle's privacy classification.

## Remaining acceptance boundaries

- CI currently derives an Android merged-manifest comparison from the built
  debug artifact. A release AAB permission report and signed-artifact checksum
  are still required for release evidence.
- Apple bundle presence can be checked locally, but CI does not yet build and
  inspect an archive on a pinned macOS/Xcode runner or aggregate every embedded
  SDK manifest into an independently reviewed report.
- Draft store-answer snapshots are not App Store Connect or Play Console
  receipts. Account-owner approval remains external and intentionally blocks
  `--require-store-approval`.
- Literal-host coverage does not prove runtime egress. Dynamic DNS resolution,
  redirects, Firebase service hosts, certificate behavior, and target-device
  network capture require a separate egress policy and artifact journey.
- A privacy manifest and Data Safety snapshot do not prove privacy-law,
  medical-device, retention, or data-residency compliance.
