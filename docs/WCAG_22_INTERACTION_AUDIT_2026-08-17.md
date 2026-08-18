# WCAG 2.2 interaction audit — 2026-08-17

## Scope and claim boundary

This pass covers authentication plus the registered-user paths for primary
navigation, onboarding, medication selection, meal entry, next-meal
recommendations, settings, reminders, and the global visual background. It is
an engineering audit against selected WCAG 2.2 AA risks, not a declaration of
full conformance. Flutter widget tests cannot substitute for screen-reader,
switch-control, browser-zoom, or low-vision testing on release devices.

## Current-run visual baseline

The registered-user reminder flow was inspected in the in-app browser at a
desktop viewport. Saved evidence is under:

`/Users/zhouzhenghang/.codex/visualizations/2026/08/17/01a00d6d-f6bc-74b1-8ea5-63d50c4cae30/wcag-audit/`

1. `01-reminders-current.png` — normal reminder-center state.
2. `02-first-tab-focus.png` — visible focus on the back control.
3. `03-second-tab-focus.png` — switch-card focus state.
4. `04-third-tab-focus.png` — delete-control focus state.
5. `05-fourth-tab-focus.png` — add-reminder action reached by Tab.
6. `06-keyboard-open-dialog.png` — Enter opened the reminder dialog.
7. `07-updated-home.png` — rebuilt registered-user dashboard after the fixes.
8. `08-updated-first-focus.png` — rebuilt app-bar focus treatment.
9. `09-updated-next-meal.png` — rebuilt recommendation controls.
10. `10-updated-next-meal-focus.png` — primary-navigation focus traversal.
11. `11-updated-time-picker-focus.png` — recommendation action focus state.

The baseline showed that keyboard activation worked, but focus treatment was
inconsistent and the floating action button did not gain a sufficiently
distinct state. The rebuilt captures show a clear focus ring on the app-bar
settings control and recommendation action. Screenshots alone do not prove
semantic names, contrast, or spoken output.

## Implemented controls

- Authentication reflows in a 320 logical-pixel viewport at 200% text,
  exposes email/password autofill hints, preserves compatibility with existing
  shorter sign-in credentials, requires 15 characters for newly registered
  passwords, and provides a show/hide-password control.
- Primary navigation changes from one crowded row to two rows when the viewport
  or text scale requires it. Each destination has a selected/button semantic
  state, a 48-pixel target, and a visible focus border.
- Registration, medication selection, meal entry, recommendation time, and
  settings selectors are reachable and operable with Tab plus Enter/Space in
  widget journeys.
- Custom glass buttons and selectors expose explicit semantic names and values,
  minimum target heights, and focus treatment.
- The next-meal time picker is a real button rather than a tap-only surface;
  recommendation errors are live regions.
- The decorative liquid-glass background is static. It no longer runs an
  indefinite motion loop that would require a pause mechanism.
- The onboarding action row wraps at large text sizes rather than overflowing.

## Executable evidence

`test/wcag_22_interaction_test.dart` currently exercises:

- accessible authentication and 200% reflow;
- six-destination primary navigation, target labels and keyboard activation;
- reminder-center reflow and labeled targets;
- keyboard-only profile selection and medication selection;
- meal-entry and recommendation focus paths;
- settings selector semantics and activation; and
- the absence of an indefinitely scheduled decorative animation.

Flutter's official accessibility-testing guidance supports the target-size,
labeled-target, and contrast guidelines used by widget tests, but also directs
teams to test with platform accessibility services.

## Remaining blockers

1. Run VoiceOver on iOS/macOS, TalkBack on Android, and a supported desktop web
   screen reader across every critical journey and record the spoken output.
2. Add executable contrast checks for focused, hovered, disabled, error,
   selected, and chart states; do not infer contrast from screenshots.
3. Verify browser zoom/reflow through 400%, 320 CSS-pixel equivalence, landscape
   mobile, and on-screen keyboard states.
4. Verify that focus is not obscured by dialogs, virtual keyboards, app bars,
   bottom navigation, snack bars, or nested scroll regions.
5. Complete visible long descriptions and structured tables for every complex
   chart, conflict view, timeline, and score decomposition.
6. Perform Parkinson-specific motor, visual, and cognitive formative testing;
   technical WCAG evidence does not establish safe interpretation.

## Primary sources

- WCAG 2.2 Recommendation: https://www.w3.org/TR/WCAG22/
- WCAG 2.2 additions: https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum
- Focus Not Obscured (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- Animation from Interactions: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
