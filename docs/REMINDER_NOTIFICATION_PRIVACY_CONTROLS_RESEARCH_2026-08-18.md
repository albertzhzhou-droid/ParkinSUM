# Reminder Notification Privacy Controls

Date: 2026-08-18

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

- Reminder-plan schema v3 stores privacy mode and the locale snapshot used for
  system copy. Account-scoped v2 rows migrate once to `minimal` and English;
  future or malformed rows fail closed.
- New and edited reminders snapshot the current App locale. The scheduler uses
  that stored value, so the in-app preview and the installed request do not
  independently consult different locale sources.
- Reviewed system copy exists in Chinese, English, French, and Japanese.
  Unsupported locale snapshots explicitly fall back to English.
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
- reconciliation when the user changes the App locale after a recurring
  request has already been installed;
- inclusion of the privacy mode and locale snapshot in the portable-data
  package, historical migrations, and target-device round trips.

Pending-request counts and plugin registry records are not evidence of visible
delivery or effective lock-screen concealment.

## Future upgrade direction

`notification_locale_snapshot_reconciliation` tracks the separate state
machine needed to update recurring pending copy after an App-locale change.
The existing platform-truth and privacy queue items retain physical-device,
mirrored-surface, accessibility, and requested-versus-effective evidence.

## Sources

- https://developer.android.com/develop/ui/compose/notifications/create-notification
- https://developer.apple.com/documentation/usernotifications/unnotificationsettings/showpreviewssetting
- https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
- https://pub.dev/packages/flutter_local_notifications
- https://support.signal.org/hc/en-us/articles/360043273491-In-App-Notification-Options
- https://github.com/signalapp/Signal-Android
- https://github.com/mollyim/mollyim-android
