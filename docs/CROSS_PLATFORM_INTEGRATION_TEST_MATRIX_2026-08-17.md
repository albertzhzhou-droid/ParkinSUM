# Cross-platform integration-test matrix — 2026-08-17

## Delivered harness

`integration_test/registered_user_journey_test.dart` boots the complete app
with the production repository/state/UI layers and an explicit process-memory
storage boundary. It does not read or overwrite the installed user's SQLite,
shared-preference, Firebase, or reminder data.

The first critical journey proves that a fresh local user can:

1. complete the safety and profile steps;
2. select a real seeded medication;
3. finish onboarding and persist the selection;
4. execute the production next-meal recommendation and mechanistic-conflict
   pipeline, including narrow-screen result discovery;
5. open settings; and
6. recreate the app root and recover the registered-user state.

The result payload records the tested commit/target, Flutter target platform,
storage boundary, real-user-data flag, product version, and covered journeys.
Release runs should supply `PARKINSUM_TEST_COMMIT` and
`PARKINSUM_TEST_TARGET` as Dart defines.

`test/reminder_notification_route_test.dart` adds a deterministic app-root
journey for notification-owned navigation. It proves that foreground and
synthetic pre-bootstrap cold-start events wait for bootstrap and an available
current-user scope, open empty meal or explicit-medication intake drafts, write
no records, remove stacked notification routes on sign-out, and request
old-schedule cancellation. It also seeds a pending activation in one journal
coordinator and proves that a new coordinator recovers and claims it after
bootstrap. `test/user_logging_reminder_test.dart` exercises a real temporary
file with two independent store instances and observes one successful claim
and one replay result. Production Firebase mode additionally requires sign-in.
This is widget/process/filesystem evidence, not proof that an operating system
displayed a notification, that a killed process captured a callback, or that a
repeating OS request has a unique delivery identity.

`test/reminder_schedule_manifest_test.dart` and the reminder controller tests
add a pure pre-native boundary for request capacity and identity. They cover
0/1/7/63/64/65/70 projections, disabled plans, a real 31-bit FNV collision,
injected collisions, deterministic ordering, preflight-before-permission, and
best-effort rollback after synthetic native or persistence failure. The UI
shows projected requests, the conservative 64-request product limit, and
headroom. These tests do not prove an OS capacity limit, atomic native install,
or the identity of requests actually installed on a device.

`parkinsum.reminder-notification-capability-matrix/1` is now the shared gateway
and Reminder Center truth contract. Android, iOS and macOS are scheduled-mode
profiles whose adapter, permission-request, app-level permission-inspection,
pending-inspection, body-tap, cold-start and visible-delivery paths remain
`implementedUnverified`; Android channel-level inspection and background
actions remain unavailable. Request-call results and current inspection state
are separate and neither proves a specific user choice or delivery. Web, Windows, Linux and
unknown targets fail closed to local plan-only mode and make no native
notification calls. The Delivery Readiness card presents local-plan state,
schedule request, permission request and inspection, plugin-registry identity,
and visible-delivery evidence as separate claims. A registry match cannot
promote visible delivery.

The Android scheduler integration report schema v4 records a unique run ID,
HEAD and full non-ignored source-state SHA-256, build mode, capability-matrix
schema/version, full manifest SHA-256, selected profile SHA-256, platform/mode,
storage boundary, privacy state and evidence state. The outer
`parkinsum.android-reminder-run-attestation/4` envelope additionally binds the
isolated application ID and visible label, staged APK and pulled installed
`base.apk`, compiled APK manifest tree, ABI/SDK facts, `pubspec.lock`, the
pinned notification plugin package, source and merged manifests, Gradle output
metadata, and `apksigner` result, certificate, schemes, build-tools identity and
verifier bytes. Its nested
`parkinsum.android-reminder-execution-isolation/2` record binds cooperative
leases for `buildOutput` and `deviceApplication`, heartbeat and process-start
provider, nine ordered ownership checkpoints, continuous ownership, child
drain before device cleanup, and cleanup while still owned. Linux uses
`linuxProcStat` with `/proc` boot ID plus process start time for conclusive stale
reclaim; macOS uses fail-closed `darwinNoReclaim`. It also proves that the
isolated application ID was absent before installation and removed after the
run. Node and Dart independently validate the canonical report. A verified signature with
`identity_assurance: observedUnreviewed` proves integrity under the observed
debug certificate only; it is not a reviewed production-signing identity.
It always reports `visible_delivery_verified: false` and
`release_eligible: false`: seven plugin-reported pending requests followed by
zero after cancellation prove registry behavior, not that Android displayed or
delivered a notification or that the integration-test APK is releasable.

The v4/v2 lease is cooperative, single-host execution isolation for this runner.
It does not fence an independent `flutter build`, a detached Gradle daemon or
another non-participating writer, and it does not establish reproducible
source-to-binary provenance. Deterministic coordinator tests require child
drain, heartbeat stop and successful lease release before publication; release
failure or a signal during drain/release suppresses the finalizer. The current
multi-file publication is not crash-durable and a final-name artifact without
the validated `latest.json` completion pointer remains incomplete. The exact
protocol and primary sources are in
`docs/ANDROID_ATTESTATION_EXECUTION_ISOLATION_RESEARCH.md`.

One current ignored development outer-v4/inner-v4 Android run with nested
execution-isolation-v2 passed on a dedicated API 36 arm64 emulator. It bound the
dirty source snapshot and isolated debug artifact, matched installed bytes,
passed all nine ownership checkpoints and the exact private lease-evidence
digest, removed the isolated application, released both leases, and only then
advanced the completion pointer. It observed seven plugin-pending requests and
zero after cancellation without requesting notification permission or accessing
user storage. It remains emulator-only, observed-unreviewed debug-signed,
`visible_delivery_verified: false`, and `release_eligible: false`; generated
identifiers and digests remain ignored and are not pinned here. Historical
outer-v3/nested-v1 evidence remains rejected by the current validator.

## Run commands

Desktop or connected mobile target:

```sh
flutter test integration_test/registered_user_journey_test.dart \
  -d <device-id> \
  --dart-define=PARKINSUM_TEST_COMMIT=<full-sha> \
  --dart-define=PARKINSUM_TEST_TARGET=<device-os-accessibility-profile>
```

Web requires a ChromeDriver that exactly matches the browser plus the
checked-in driver entry point. Use `web-server`; `-d chrome` did not create a
usable WebDriver target in the current Flutter 3.44/macOS environment:

```sh
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/registered_user_journey_test.dart \
  -d web-server \
  --profile \
  --browser-name=chrome \
  --headless \
  --browser-dimension=1280x800@1 \
  --dart-define=PARKINSUM_TEST_COMMIT=<full-sha> \
  --dart-define=PARKINSUM_TEST_TARGET=<browser-os-profile>
```

Android reminder scheduler evidence is an emulator-only, no-user-storage
development harness:

```sh
node tool/run_android_reminder_attestation.mjs \
  --device <emulator-id> \
  --mode development \
  --build-mode debug \
  --flutter <flutter-sdk>/bin/flutter \
  --android-sdk <android-sdk>
```

## Evidence matrix

| Target | Current evidence | Required next evidence |
|---|---|---|
| macOS desktop | Earlier passing local full-app integration run at the default 800×600 test window, target `macos-local-keyboard-default`, commit metadata `95d92714f80a68b77f550da35e4bb88461e246f4`; onboarding, medication selection, next-meal/settings navigation, and app-root recovery passed. Two later reruns after adding recommendation generation did not complete because the debug host reported `Failed to foreground app; open returned 1` before the test finished loading; this is retained as an unresolved host instability, not a product pass or fail. | Re-run the expanded recommendation journey in an interactive session; VoiceOver run, locale matrix, release-mode artifact |
| Android | Passing API 36.1 arm64 emulator full-app journey, target `android-36.1-emulator-algorithm-scroll-aware`, commit metadata `95d92714f80a68b77f550da35e4bb88461e246f4`; onboarding, seeded medication persistence, production next-meal/mechanistic generation, narrow-screen result scrolling, settings, and app-root recovery passed. A current ignored local development outer-v4/inner-v4 scheduler attestation with nested execution-isolation-v2 also passed on a dedicated API 36 arm64 emulator: it bound dirty development source, the isolated reminder-attestation application, debuggable integration entrypoint, byte-identical installed APK, compiled manifest, plugin lock, exact private lease-evidence digest, seven-to-zero registry result and observed-unreviewed debug-signature integrity. Cooperative build-output and device/application leases, heartbeat, the macOS no-stale-reclaim provider, command-start barrier, all nine ownership checkpoints, tracked-child drain and device cleanup passed while owned; both leases released before promotion. No permission or user storage was used, and the isolated application was absent before and removed afterward. The generated run ID and digests remain ignored and are not pinned here; visible delivery and release eligibility remain false. | Physical-device visible delivery and permission denial/grant using the isolated test application ID; locked-screen body tap, cold start, reboot, timezone/DST, Doze and OEM restriction cases; independent AlarmManager/channel inspection; isolation from independent Flutter builds and detached Gradle daemons; reviewed production signer; clean signed production-entrypoint release artifact and reproducible provenance |
| iOS | Passing iPhone 16e simulator journey on iOS 26.2, target `iphone-16e-ios-26.2-simulator-algorithm-scroll-aware`, commit metadata `95d92714f80a68b77f550da35e4bb88461e246f4`; onboarding, seeded medication persistence, production next-meal/mechanistic generation, narrow-screen result scrolling, settings, and app-root recovery passed | Physical-device journey; VoiceOver and notification permission/body-tap activation cases |
| Web | Passing profile-mode WebDriver journey using Flutter `web-server`, Chrome for Testing 151.0.7922.138 and exactly matched ChromeDriver at 1280×800, target `chrome-151-web-server-profile-algorithm-scroll-aware`; the same onboarding, recommendation generation, settings, and recovery path passed. A separate current-worktree Playwright CLI runner independently served the dart2js/CanvasKit release artifact and passed the initial setup state at 1280×800, 640×800, and 320×720 CSS pixels with no page-level horizontal overflow, no uncontained semantic overflow, five semantic buttons measured after scrolling into view, and visible keyboard focus; the generated report binds artifact SHA-256 and runtime metadata. A second checksum-bound Playwright runner served one local-engine Wasm artifact under no isolation, COEP `credentialless`, and COEP `require-corp`: all three reached Initial setup with 12 semantics nodes, requested Wasm/Skwasm without dart2js fallback or cross-origin engine resources, and had zero console errors; only the isolated profiles exposed `crossOriginIsolated` and SharedArrayBuffer. | Operate real 200%/400% browser zoom and independent 200% text resize; cover every critical journey, Chromium/Firefox/WebKit and supported renderers; desktop screen reader; production HTTPS/CDN/proxy, service-worker update/offline, Firebase/App Check/reCAPTCHA, rollback, and signed hosting evidence. The controlled Wasm result is local Chromium initial-setup evidence only. |
| Windows | Compile/plugin configuration plus plan-only application behavior | Native device journey, keyboard/screen-reader profile, and proof that recurring delivery is neither attempted nor claimed |
| Linux | Compile/plugin configuration plus plan-only application behavior; unsupported scheduled/pending plugin calls are disabled | Native GNOME/KDE journey, keyboard/screen-reader profile, and proof that recurring delivery and terminated-app activation are neither attempted nor claimed |

## Boundary and remaining work

This harness proves one deterministic registered-user path through the real app
layers. The notification route and journal tests prove confirmation-first UI
behavior for synthetic foreground/cold-start events plus local
callback-envelope recovery and single claim. They do not prove
operating-system notification delivery, per-occurrence identity, locked-screen
activation, background action execution, reboot recovery, deep links, Firebase
authentication, offline
reconciliation, migrations from every historical schema, screen-reader spoken
output, or clinical validity. Those remain separate matrix rows and may not be
claimed from a green local run.

The passing macOS run used the debug integration-test host. Flutter emitted a
non-fatal foregrounding warning in this headless runner, while the application
still launched and completed the journey. That result is not a substitute for
a user-driven launch or accessibility run of a signed release application.

The iOS run caused Flutter to raise the generated project deployment target to
iOS 15 and add Swift Package Manager integration. The journey passed, but the
project still contains CocoaPods integration and Flutter emitted both a mixed
package-manager warning and a future UIScene-lifecycle migration warning.
Those are tracked platform migrations, not silently counted as completed.

Primary references:

- https://docs.flutter.dev/testing/integration-tests
- https://github.com/flutter/flutter/wiki/Plugin-Tests
- https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers
- https://flutter.dev/to/uiscene-migration
