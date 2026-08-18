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

## Evidence matrix

| Target | Current evidence | Required next evidence |
|---|---|---|
| macOS desktop | Earlier passing local full-app integration run at the default 800×600 test window, target `macos-local-keyboard-default`, commit metadata `95d92714f80a68b77f550da35e4bb88461e246f4`; onboarding, medication selection, next-meal/settings navigation, and app-root recovery passed. Two later reruns after adding recommendation generation did not complete because the debug host reported `Failed to foreground app; open returned 1` before the test finished loading; this is retained as an unresolved host instability, not a product pass or fail. | Re-run the expanded recommendation journey in an interactive session; VoiceOver run, locale matrix, release-mode artifact |
| Android | Passing API 36.1 arm64 emulator full-app journey, target `android-36.1-emulator-algorithm-scroll-aware`, commit metadata `95d92714f80a68b77f550da35e4bb88461e246f4`; onboarding, seeded medication persistence, production next-meal/mechanistic generation, narrow-screen result scrolling, settings, and app-root recovery passed. A separate local device-integration run against the uncommitted v2 payload-schema worktree, target `android-36.1-emulator-reminder-scheduler`, exercised Android weekly inexact scheduling and cancellation with a fixed, format-valid v2 fixture token; the plugin registry API reported seven pending prompts and then zero after `synchronize([])`, without requesting notification permission or touching user storage. The test does not independently inspect AlarmManager or validate random-token generation. | Persist a run artifact with SDK/ABI metadata; physical-device visible delivery and permission denial/grant; locked-screen body tap, cold start, reboot, timezone-change and OEM restriction cases |
| iOS | Passing iPhone 16e simulator journey on iOS 26.2, target `iphone-16e-ios-26.2-simulator-algorithm-scroll-aware`, commit metadata `95d92714f80a68b77f550da35e4bb88461e246f4`; onboarding, seeded medication persistence, production next-meal/mechanistic generation, narrow-screen result scrolling, settings, and app-root recovery passed | Physical-device journey; VoiceOver and notification permission/body-tap activation cases |
| Web | Passing profile-mode WebDriver journey using Flutter `web-server`, Chrome for Testing 151.0.7922.138 and exactly matched ChromeDriver at 1280×800, target `chrome-151-web-server-profile-algorithm-scroll-aware`; the same onboarding, recommendation generation, settings, and recovery path passed | 200%/400% zoom matrix, desktop screen reader, release artifact served independently of Flutter tooling |
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
