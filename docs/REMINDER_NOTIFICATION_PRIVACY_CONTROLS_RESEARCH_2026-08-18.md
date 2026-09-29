# Reminder Notification Privacy Controls

Reviewed: 2026-08-31

## Decision

ParkinSUM exposes two reversible, non-sensitive presentation modes. Neither
mode can include the user-authored reminder label, reminder kind, medication,
dose, meal, account, disease, or adherence status.

| Mode | System-visible copy | Android request | Darwin boundary |
| --- | --- | --- | --- |
| Minimal (default) | App name plus a request to open ParkinSUM for a private reminder | `VISIBILITY_SECRET` | The submitted copy is minimized, but lock-screen preview remains controlled by the user's operating-system setting. |
| Generic logging prompt | Generic, non-clinical logging copy | `VISIBILITY_PRIVATE` | The same generic copy is submitted; ParkinSUM cannot promise that Darwin will conceal it. |

Android documents `PUBLIC`, `SECRET`, and `PRIVATE` as requested lock-screen
visibility levels and explicitly states that the user has ultimate control via
notification and channel settings. Apple exposes `showPreviewsSetting` as a
system notification setting. The application therefore reports requested
behavior, never verified effective lock-screen behavior.

## Implemented contract

- Reminder-plan schema v4 stores privacy mode, the locale snapshot actually
  used for system copy, and the last App-locale decision separately.
  Account-scoped v2 rows migrate once to `minimal` and English; v3 rows keep
  their scheduled locale and derive a language-family decision. Future or
  malformed rows fail closed.
- New and edited reminders snapshot the supported App language family. If the
  App locale later changes, the Reminder Center requires an explicit,
  rollback-safe choice to retain the installed language or update every
  reminder. Updating rotates activation capabilities; retaining preserves the
  exact scheduled copy while durably acknowledging the new App locale.
- Reviewed system copy exists for all 13 shipped language families: Chinese,
  English, French, Japanese, Korean, Hindi, Spanish, Vietnamese, Thai,
  Indonesian, Russian, Polish, and Arabic. Unsupported locale snapshots
  explicitly fall back to English; numeric BCP-47 regions such as `es-419`
  and script-plus-region tags such as `zh-Hant-TW` normalize by language
  family.
- Each policy result has a SHA-256 presentation identity over its schema,
  privacy mode, resolved language, exact title/body, requested Android
  visibility, and Darwin system-control boundary. The schedule manifest and
  new v3 activation payload bind that identity, so pending-registry attestation
  detects old-language or replaced copy without recording notification text.
  Captured v2 activations remain readable for compatibility while their opaque
  capability is still current.
- The presentation policy API has no parameter for a user-authored label or
  reminder kind. Tests also scan every copy variant for sensitive terms.
- The reminder editor displays the exact title/body selected by the policy and
  explains the Android-versus-Darwin boundary before save.
- Web, Windows, and Linux remain plan-only in the current adapter and never
  claim recurring system delivery.

## Open-source pattern review

Signal's user-facing notification choices were reviewed as a privacy-control
pattern, and the Signal Android and Molly repositories were reviewed for
separation between notification preferences and message content. No upstream
source code, strings, branding, or UI were copied. Messaging-specific sender
and message-preview options were deliberately not adopted: ParkinSUM's allowed
surface is a low-risk logging prompt, not a message or medication action.

## Evidence limits

The repository tests prove serialization, migration, policy selection,
reviewed copy, and UI preview. They do not prove effective presentation on a
locked or unlocked physical device. Outstanding evidence includes:

- Android channel overrides, notification history, OEM skins, work profiles,
  screen sharing, and locked/unlocked screenshots;
- iOS/macOS `showPreviewsSetting`, Notification Center history, Apple Watch or
  other mirroring, Focus modes, and locked/unlocked screenshots;
- Wear OS, Android Auto, CarPlay, desktop relay, and other mirrored surfaces;
- TalkBack, VoiceOver, large text, bidirectional text, and every shipped App
  locale on release-equivalent artifacts;
- target-device import, newly issued activation capabilities, partial-install
  rollback, and physical cross-platform round trips. Portable-package schema
  v3 now includes privacy mode, scheduled language, locale-decision state and
  source presentation digest; a reviewed v2 preview migration defaults missing
  presentation intent without requesting permission or scheduling.

Pending-request counts and plugin registry records are not evidence of visible
delivery or effective lock-screen concealment.

## Future upgrade direction

`notification_locale_snapshot_reconciliation` records the implemented software
state machine and retains the physical-device, background/terminated,
bidirectional-text, reboot, timezone, account-switch, accessibility, and
mirrored-surface evidence still needed.
`notification_presentation_portable_round_trip` now has its first software
phase implemented: schema v3 export and v2-compatible no-write preview include current
copy-policy drift and explicit target-consent UI. Target-device import,
capability re-issuance, rollback, and release-device evidence remain open.
Existing platform-truth and privacy items retain requested-versus-effective
system evidence.

## Sources

- https://developer.android.com/develop/ui/compose/notifications/create-notification
- https://developer.apple.com/documentation/usernotifications/unnotificationsettings/showpreviewssetting
- https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
- https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidFlutterLocalNotificationsPlugin-class.html
- https://support.signal.org/hc/en-us/articles/360043273491-In-App-Notification-Options
- https://github.com/signalapp/Signal-Android
- https://github.com/mollyim/mollyim-android
