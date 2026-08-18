# Education-only logging reminders: research and product boundary

Reviewed: 2026-08-17

## Decision

ParkinSUM may offer device-local, user-authored prompts to **record** a meal or medication intake. It must not infer, optimize, recommend, or prescribe a medication time. System-visible content is generic and includes that boundary; the user's private label, medication, dose, meal, and account identifier are not placed in notification content or payloads. Android uses inexact scheduling because this is not a dose alarm or other time-critical medical alert.

This is an engagement aid, not evidence that a dose was taken and not a medication-adherence intervention with established patient benefit.

## Evidence map

| Source | Evidence type | Product-relevant finding | Limit that remains visible in the product |
| --- | --- | --- | --- |
| Lakshminarayana et al., 2017, PMID 28649602 | Randomized controlled trial in Parkinson's disease | A smartphone self-management application was associated with better self-reported adherence and consultation measures. | The study does not validate ParkinSUM's reminder wording, schedule, clinical outcomes, or patient-level dose timing. |
| Armitage et al., 2020, PMCID PMC7045248 | Systematic review and meta-analysis of medication-adherence apps | App interventions showed a pooled adherence improvement. | Much of the included evidence used self-report; intervention components and populations were heterogeneous. |
| Motolese et al., 2022, PMCID PMC8817212 | Systematic review of self-care applications in Parkinson's disease | Reminders are a common app component. | Adherence was rarely measured, and the review reports no between-group compliance difference in one comparison. Presence of a reminder is not proof of benefit. |
| FDA, General Wellness: Policy for Low Risk Devices, January 2026 | Current US guidance | Low-risk wellness claims have a defined policy context. | A Parkinson's disease app cannot assume that a disclaimer converts medication-timing functionality into general wellness. Intended use and claims still control. |

## Platform truth table

| Platform | Current implementation | Known boundary |
| --- | --- | --- |
| Android | Weekly, timezone-aware, inexact local notifications with reboot receivers. A local API 36.1 device-integration run exercised native scheduling and cancellation with a fixed, format-valid v2 fixture token; the plugin registry API reported seven pending weekday requests and then zero after clearing the plan. Schema-v3 plans request `SECRET` for the default minimal copy or `PRIVATE` for generic logging copy. | These are requested visibility levels, not proof of effective concealment: users and channel settings retain control. Plugin-reported pending requests do not prove AlarmManager state, permission, visible delivery, locked-screen presentation, reboot restoration, or OEM reliability; no exact-alarm permission is requested. |
| iOS | Weekly local notifications after explicit permission; ordinary UI-presenting tap and notification-launched startup APIs are wired. | iOS pending-request capacity, Focus/preview settings, visible delivery, and physical-device tap behavior remain unverified. |
| macOS | Weekly local notifications after explicit permission; ordinary tap handling runs on the main isolate and launch details are available on supported macOS versions. | Cold-start, permission, preview, and signed-artifact behavior remain unverified; this is not evidence of a background action isolate. |
| Linux | The reminder plan persists locally; UI reports that recurring system delivery is unavailable. | `flutter_local_notifications` 22.3.0 does not implement scheduled/pending notifications on Linux, and terminated-app activation would require application-owned DBus activation work. ParkinSUM no longer calls the unsupported scheduler. |
| Windows | The reminder plan persists locally; UI reports that recurring system delivery is unavailable. | The selected plugin does not provide repeating scheduled notifications. Packaged activation and any rolling one-shot adapter require separate evidence. |
| Web | The reminder plan persists locally; UI reports that recurring system delivery is unavailable. | The selected browser implementation does not provide local scheduled/repeating notifications. Push would require a backend, service-worker and browser matrix, separate consent, and new privacy analysis. |

Timezone lookup fails closed: the reminder stays persisted, but the UI reports that system scheduling failed. ParkinSUM does not silently substitute UTC because that could move a prompt to the wrong local time.

The reminder center re-reads the device IANA timezone and reconciles every
user-authored plan after load, manual refresh, application resume, bootstrap,
and account transition. Users can edit a plan without changing its visible
identifier, see the latest successful system reconciliation, and must confirm
deletion before the durable plan and corresponding pending requests are
removed. Account change closes all notification-owned pages and cancels the old
system schedule. Native schedule/cancel mutations share a scope-and-epoch-aware
serial queue: newer account or plan work invalidates older work, and an outer
timeout does not remove an unfinished native mutation from the queue. This
improves recovery and prevents late old-account work from overtaking
cancellation; it does not establish that a notification was displayed or acted
upon.

Before permission, persistence, cancellation, plugin initialization, or any
new native request, the worktree now expands every enabled plan into a stable
plan-by-weekday schedule manifest. The manifest validates opaque plan IDs and
capabilities, detects duplicate plans and 31-bit notification-ID collisions,
and calculates projected request count, product limit, and headroom without
copying user labels. A known real FNV collision is retained as a regression
fixture. The reminder center shows this budget, and an invalid candidate fails
before changing the saved or installed plan.

ParkinSUM currently uses 64 as a conservative **product request budget** on
Android, iOS, and macOS. The locked plugin documentation describes 64 pending
notifications for iOS; the same number is not claimed as an Android or macOS
operating-system limit. Nine all-week plans project to 63 requests, while ten
project to 70 and are rejected. Candidate installation now occurs before local
persistence, with a best-effort reinstall of the previous plan after native or
storage failure. The previous durable plan remains authoritative and is retried
at launch/resume; this compensation is not an atomic operating-system
transaction and still requires target-device partial-failure testing.

## Notification response and privacy boundary

The current response route implements two UI-presenting paths described by the
official plugin example:

1. `onDidReceiveNotificationResponse` while the application UI can be shown.
2. `getNotificationAppLaunchDetails` when a notification launches the app.

Both paths wait for bootstrap and an available current-user scope, then re-read
the current user-scoped reminder; production Firebase mode additionally
requires sign-in. The payload contains only a schema marker, a
cryptographically random per-plan activation token, and an opaque reminder ID.
Editing or toggling a reminder rotates the token, so an older scheduled
revision fails closed. A meal reminder opens an empty meal draft; an intake
reminder opens an empty draft that requires explicit medication selection.
Opening either page writes nothing and is not evidence of intake, adherence,
omission, or dose timing.

The worktree now captures each main-isolate response callback into a bounded,
device-local activation journal before authentication or navigation. Each
journal row has a random 128-bit identifier, callback origin, receipt time,
24-hour expiry, and the already non-clinical payload. The journal contains no
account scope, user label, medication, dose, meal, email, or adherence field.
Android, iOS, and macOS use a flushed temporary file plus atomic replacement in
the application database directory, guarded by an in-process path mutex and an
exclusive file lock. Web, Windows, and Linux retain only a process-memory
implementation because this release remains plan-only there.

The app recovers pending rows after bootstrap or resume, atomically marks one
row claimed before navigation, then re-reads the current user-scoped plan and
validates enabled state and plan capability. Account change closes owned
routes, gates new capture behind disposal of the previous pending set, and
cancels the previous schedule. A crash after claim but before route display can
lose that navigation; this is an explicit fail-closed, at-most-once-effect
tradeoff, not an exactly-once UI guarantee. Corrupt journal files are preserved
under a quarantine name and the triggering operation fails closed.

The journal intentionally does not use `shared_preferences`: its official
package documentation says writes are not guaranteed durable after return,
must not be used for critical data, and warns about cache coherence across
isolates or multiple Flutter engines. Real-file tests cover recovery through a
new store instance, concurrent claim by two store instances, expiry, capacity,
UTF-8 payload bounds, invalid nonce factories, and corrupt-file quarantine.
Widget tests cover pre-bootstrap journal recovery and prove that opening the
draft writes no health record. These are local process/filesystem tests, not
evidence of a killed mobile process or operating-system delivery.

The five-second persisted comparison is accurately described as **one callback
window duplicate suppression**, not per-occurrence replay prevention. A
recurring operating-system request reuses its v2 payload on later valid
occurrences, and the plugin response object does not expose a portable delivery
timestamp. A distinct queue item therefore owns the v3 occurrence identity and
schedule-ledger decision: rolling one-shot requests with per-occurrence nonces
versus a small native adapter. Until that decision is implemented, ParkinSUM
does not claim exactly-once operating-system delivery or persistent replay
prevention across recurring occurrences.

ParkinSUM does not currently configure notification action buttons or
`onDidReceiveBackgroundNotificationResponse`. In plugin 22.3.0, non-UI actions
have different execution models across platforms: Android/iOS may start a
separate Flutter engine, while macOS/Linux use the main isolate and Windows/Web
do not expose the same callback contract. Any future background action may
only enqueue an opaque activation intent; it must never navigate, write a meal
or intake, or assert Taken/Missed/Skipped from the background.

## Open-source pattern review

The open-source Flutter Pills Reminder project was reviewed only for architectural patterns: local persistence, a notification adapter, and separation between UI and scheduling. ParkinSUM does not copy its visual design or clinical semantics. Its “pill reminder” framing is intentionally not adopted because ParkinSUM's permitted feature is a logging prompt, not a dose instruction.

The official plugin example handles UI-presenting responses and
notification-launched startup as distinct events; ParkinSUM now preserves that
distinction and routes both to confirmation-first drafts. It intentionally does
not adopt open-source pill-reminder shortcuts that mark a dose as taken from a
notification action.

## Upgrade queue implications

The reminder programme remains `in_progress` until target-device permission,
timezone-change, reboot, visible delivery, recurrence, cancellation,
OEM-restriction, capacity, and accessibility checks are recorded. The queue now
separates evidence-bounded follow-ups for platform truth/delivery, lock-screen
privacy, durable callback ingestion, per-occurrence identity, action human
factors, capacity budgeting, preflight schedule manifests, installed-identity
attestation, and desktop/Web adapter research. A
separate research item covers consent-bound caregiver coordination; it cannot
ship merely by adding a shared notification because medication data,
delegation, revocation, and auditability require explicit design and legal
review.

## Sources

- https://pubmed.ncbi.nlm.nih.gov/28649602/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7045248/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC8817212/
- https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices
- https://pub.dev/documentation/flutter_local_notifications/22.3.0/
- https://pub.dev/packages/flutter_timezone
- https://github.com/MoazSalem/Flutter_Pills_Reminder
- https://github.com/MaikuB/flutter_local_notifications/blob/flutter_local_notifications-v22.3.0/flutter_local_notifications/README.md
- https://github.com/MaikuB/flutter_local_notifications/blob/flutter_local_notifications-v22.3.0/flutter_local_notifications/example/lib/main.dart
- https://pub.dev/packages/shared_preferences
- https://developer.android.com/guide/components/activities/process-lifecycle
- https://developer.android.com/topic/architecture/data-layer
- https://developer.apple.com/documentation/usernotifications/unnotification/date
- https://developer.android.com/develop/ui/views/notifications/notification-permission
- https://developer.android.com/reference/android/app/Notification#VISIBILITY_PRIVATE
- https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions
- https://developer.apple.com/design/human-interface-guidelines/notifications
- https://www.nice.org.uk/guidance/cg76/chapter/Recommendations
