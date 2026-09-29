# Web release-artifact reflow matrix research — 2026-08-27

## Decision

ParkinSUM now has a bounded, fail-closed Web release-artifact reflow runner.
It is useful executable evidence, but it is not a WCAG conformance claim and
does not replace human browser-zoom or assistive-technology testing.

W3C identifies 320 CSS pixels as the reflow width and gives 1280 CSS pixels at
400% zoom as its equivalence example. Playwright supports deterministic CSS
viewports, so the runner uses 1280×800, 640×800, and 320×720 as 100%, 200%, and
400% width-equivalence probes. It describes them as equivalents because it does
not operate the browser's visible zoom control.

Flutter Web exposes its internal Semantics tree as accessible HTML only after
accessibility is enabled. The runner waits up to 45 seconds for Flutter's
documented `Enable accessibility` placeholder, activates it, and requires a
non-empty semantic tree. This prevents a canvas-only page from passing merely
because the outer HTML document does not overflow.

## Executable contract

`npm run accessibility:web-reflow`:

1. serves the existing `build/web` directory from an ephemeral loopback port
   with `Cache-Control: no-store`;
2. hashes every relative artifact path and file digest into one SHA-256;
3. records source HEAD and dirty state, Flutter build candidates, Playwright CLI
   version, browser user agent, host platform, architecture, Node version,
   device-pixel ratio, and cross-origin-isolation state;
4. activates Flutter semantics and resizes Chromium through the three CSS
   viewport profiles;
5. measures document horizontal overflow and semantic bounds, scrolls every
   semantic button fully into view before measuring the 24 CSS-pixel minimum,
   restores scroll state, and traverses by keyboard until a visible button owns
   focus; and
6. writes `build/web_reflow_matrix/latest.json` and `latest.md`, returning a
   non-zero status for any failed probe.

The unit contract at `tool/run_web_reflow_matrix.test.mjs` mutates page overflow,
focus visibility, semantics availability, viewport width, semantic overflow,
and target size to prove that those failures cannot be reported as green.

## Observed current-worktree result

The independently served dart2js/CanvasKit artifact with SHA-256
`800083096367bbbbad0c59fc4a005c232feebbbea2f0e5822fc178d0fd53bdf7`
passed all three profiles in Chromium. Each profile had zero page-level
horizontal overflow and zero uncontained semantic overflows. Five semantic
buttons were measured after scrolling fully into view and none was under 24 CSS
pixels. Keyboard focus remained at least partially visible.

One intermediate failure is retained as useful diagnostic evidence: at 320×720
the third onboarding step initially exposed only 16 pixels at the bottom of its
vertical scroll viewport. DOM inspection showed the complete target was 72
pixels high after `scrollIntoView`. The runner therefore measures targets after
bringing them fully into view instead of treating a viewport-clipped fragment
as the control's full target size.

This result belongs to an uncommitted local worktree and changes whenever the
built artifact changes. The generated report, not this dated narrative, is the
source of truth for a later run.

## Wasm follow-up evidence

The earlier Error state was not caused by absent isolation headers. A controlled
same-artifact comparison found that the application selected unsupported
`dart.library.html` stubs under Wasm. After migrating the database factories and
portable browser-export sink to `dart.library.js_interop` and localizing engine
resources, all three hosting profiles started the real Initial setup surface.

The plain profile ran Skwasm single-threaded with `crossOriginIsolated` and
`SharedArrayBuffer` false. Both COOP `same-origin` plus COEP `credentialless`
and COEP `require-corp` enabled isolation and shared memory. All profiles
requested Wasm and Skwasm, avoided the dart2js fallback and cross-origin engine
resources, and logged zero console errors. The checksum-bound evidence and its
remaining production boundaries are recorded in
`docs/WASM_HOSTING_ATTESTATION_RESEARCH_2026-08-27.md`.

## Remaining claim boundary

- The current matrix covers only Chromium and the initial setup state.
- CSS viewport equivalence does not prove browser-UI zoom behavior or 200% text
  resizing.
- The reflow matrix does not cover Firefox, WebKit, Wasm/Skwasm reflow,
  device-pixel-ratio changes,
  every critical journey, screenshots, spoken screen-reader output, switch or
  voice control, or human comprehension.
- The 24 CSS-pixel probe does not adjudicate WCAG target-size exceptions.
- A green engineering probe does not establish clinical safety, regulatory
  compliance, or suitability for patient care.

## Primary sources

- W3C Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- W3C Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- W3C Focus Not Obscured (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- Flutter Web accessibility: https://docs.flutter.dev/ui/accessibility/web-accessibility
- Flutter Web deployment: https://docs.flutter.dev/deployment/web
- Flutter Wasm hosting: https://docs.flutter.dev/platform-integration/web/wasm
- Playwright viewport configuration: https://playwright.dev/docs/test-use-options
- Playwright browser coverage: https://playwright.dev/docs/intro
