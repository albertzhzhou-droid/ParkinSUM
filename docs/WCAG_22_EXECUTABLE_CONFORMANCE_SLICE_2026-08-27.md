# WCAG 2.2 executable conformance slice — 2026-08-27

## Claim boundary

This slice adds engineering safeguards and executable evidence for selected
WCAG 2.2 AA risks. It is not a declaration of WCAG conformance. Widget tests do
not substitute for independently served Web-artifact testing, target-device
assistive-technology runs, effective-pixel contrast measurement, or formative
testing with people affected by Parkinsonian motor, visual, or cognitive
constraints.

## Source-to-contract map

| Source requirement | ParkinSUM executable contract | Limit that remains explicit |
| --- | --- | --- |
| SC 1.4.10 Reflow: ordinary vertically read content must remain available without two-dimensional scrolling at a width equivalent to 320 CSS pixels; 1280 CSS pixels at 400% zoom is the normative equivalence example. | Critical widget interactions run at 320 logical pixels plus 200% text. A separate runner independently serves the dart2js/CanvasKit artifact and probes 1280×800, 640×800, and 320×720 CSS-pixel viewports in Chromium, including semantics, overflow, scrolled-into-view target bounds, and keyboard focus. | Viewport equivalence is not operation of the browser's visible zoom UI. The current artifact evidence covers only the initial setup state in Chromium, not every journey, renderer, browser, 200% text resize, device-pixel-ratio change, or screen reader. |
| SC 2.4.11 Focus Not Obscured (Minimum): a component receiving keyboard focus must not be entirely hidden by author-created content. | `FocusVisibilityGuard` observes focus and viewport-metric changes, then asks the focused render object and enclosing scrollables to reveal it with protected space. A regression starts with the target below the viewport and verifies full reveal. | Every app bar, snack bar, dialog, virtual keyboard, nested scroll region, browser, and target device still needs an artifact-level matrix. |
| SC 2.5.8 Target Size (Minimum): pointer targets are at least 24×24 CSS pixels unless a defined exception applies. | Existing widget journeys run labeled-target and Android 48-logical-pixel target guidelines across critical paths. | Effective CSS target bounds, spacing exceptions, transformed targets, and every reachable state still need release-artifact measurement. |
| W3C complex-image guidance: charts need a short description and an available long textual representation of their essential information. | `AlgorithmObservatoryPage.complexChartIds` enumerates both complex curves. Every registered chart now exposes an image semantic summary, an always-visible labeled long description, and a discoverable point-by-point `DataTable` with a persistent horizontal scrollbar. | VoiceOver, TalkBack, and desktop Web screen readers must still verify reading order, announcements, table navigation, and meaning on release targets. |

## Implemented evidence

- The application root wraps every route and overlay descendant in one
  focus-visibility guard. The guard re-runs after viewport metrics change so an
  on-screen keyboard cannot rely only on the original focus event.
- The gastric-emptying figure visibly explains its modeled windows, disclosed
  ×40 display-only scaling, raw table units, sensitivity boundary, and the fact
  that the threshold is not a clinical measurement.
- The absorption/competition figure visibly explains overlap, peak pressure,
  data mode, delayed-arrival likelihood, and the unitless educational boundary.
- Both charts retain point-by-point values; the visual gastric-arrival curve can
  use its disclosed display scale while the table preserves raw fraction/minute
  values.
- The chart registry is public to the page contract. Adding a new complex chart
  without extending the registry and its three-part alternative is detectable
  in review and regression tests.
- `tool/run_web_reflow_matrix.mjs` starts its own no-store static server for the
  built artifact, opts into Flutter's accessible HTML semantics, measures each
  semantic button after scrolling it fully into view, restores scroll state,
  and fails closed on unavailable semantics, page or semantic horizontal
  overflow, undersized targets, hidden keyboard focus, or incomplete target
  audit. Its JSON and Markdown reports bind the artifact checksum, source HEAD
  and dirty state, Flutter build target and renderer, browser user agent, host,
  Node, and pinned Playwright CLI version.

## Executable checks

- `test/focus_visibility_guard_test.dart`
- `test/wcag_22_interaction_test.dart`
- `test/algorithm_observatory_page_test.dart`
- `tool/complete_app_upgrade_queue_check.test.mjs`
- `tool/run_web_reflow_matrix.test.mjs`
- `npm run accessibility:web-reflow` after `flutter build web --no-wasm-dry-run`

## Remaining gates

1. Extend the initial-state Chromium viewport-equivalence runner to operate the
   visible browser zoom control, resize text independently to 200%, traverse
   every critical journey, preserve screenshots, and cover each supported
   browser and renderer. The current green report is one bounded slice, not this
   completed gate.
2. Record VoiceOver on iOS and macOS, TalkBack on Android, and a supported
   desktop Web screen reader across every critical task, including chart and
   table meaning rather than presence alone.
3. Exercise switch control, voice control, dwell input, mobile landscape,
   virtual keyboards, app bars, dialogs, snack bars, and nested scroll regions;
   prove focused components are not entirely obscured.
4. Measure effective text and non-text contrast for normal, hover, focus,
   pressed, selected, disabled, error, translucent-glass, platform
   high-contrast, and browser forced-colors states.
5. Conduct Parkinson-specific formative evaluation. Technical accessibility
   evidence does not establish clinical safety, comprehension, or fitness for
   patient care.

## Primary sources

- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- Focus Not Obscured (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- Complex images: https://www.w3.org/WAI/tutorials/images/complex/
- Non-text Contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- CSS forced colors: https://www.w3.org/TR/css-color-adjust-1/#forced-colors-mode
- Flutter Web accessibility: https://docs.flutter.dev/ui/accessibility/web-accessibility
- Flutter Web deployment: https://docs.flutter.dev/deployment/web
- Flutter Wasm hosting: https://docs.flutter.dev/platform-integration/web/wasm
- Playwright viewport configuration: https://playwright.dev/docs/test-use-options
