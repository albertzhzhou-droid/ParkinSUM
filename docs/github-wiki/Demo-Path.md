# Demo Path

Use this walkthrough when showing ParkinSUM Companion to a reviewer, classmate,
mentor, or open-source contributor. It demonstrates visible software behavior
with synthetic fixtures; it is not a clinical workflow or medical-use demo.

## Reproducible Demo Context

- Source: `main@23619f1`
- Reference capture date: 2026-08-18
- Backend: default local mode
- State: fresh synthetic onboarding with no reused account records
- Observatory inputs: fixed, non-personal scenario fixtures
- Reference viewports: 1440 x 1000 desktop browser and 390 x 844 responsive
  browser

## Walkthrough

1. Start the Flutter app in default local mode.
2. Complete a fresh onboarding flow using synthetic values only.
3. Show the runtime dashboard and explain that its visible cards establish only
   the captured UI state.
4. Open Settings, then the capability center.
5. Enter the Algorithm Observatory.
6. Compare the mixed-reference, high-fat-plus-protein, and missing-data fixed
   fixtures. Explain that their values are educational model outputs, not
   patient predictions.
7. Show the scenario comparison and educational gastric-residence trace. Do not
   describe the curves as measured gastric emptying, absorbed dose, plasma
   concentration, predicted symptoms, or medical advice.
8. Show conflict composition and point out that severity and confidence are
   reported separately.
9. Expand the explanation tree to show inputs, emitted trace values, evidence
   references, and the boundary where interpretation must stop.
10. Open the result-affecting algorithm coverage surface and describe it as an
    auditable UI contract, not proof that the algorithms are clinically valid.
11. Reflow the fixed scenario table at 390 x 844 and explicitly identify it as
    a responsive browser viewport check.
12. Finish with the public verification commands and the project's educational,
    non-clinical boundary.

## Current Reference Media

| Demo step | Repository asset |
| --- | --- |
| Runtime dashboard | `docs/assets/screenshots/runtime-dashboard-desktop.png` |
| Capability center | `docs/assets/screenshots/capability-center-desktop.png` |
| Observatory overview | `docs/assets/screenshots/algorithm-observatory-overview-desktop.png` |
| Conflict composition and explanation tree | `docs/assets/screenshots/algorithm-observatory-explanation-desktop.png` |
| Replay and algorithm coverage | `docs/assets/screenshots/algorithm-observatory-coverage-desktop.png` |
| Responsive scenario comparison | `docs/assets/screenshots/algorithm-observatory-responsive.png` |

There are no planned or nonexistent media paths in this walkthrough. The asset
index and retirement record are maintained at:

https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/assets/screenshots/README.md

## Evidence Boundaries

The desktop and responsive images show browser-rendered UI at one source
revision. They do not prove workflow completion, persistence, native-platform
behavior, algorithm correctness, clinical validity, or patient outcomes.

The 390 x 844 image is not physical-device evidence and does not establish
native Android/iOS behavior, performance, touch ergonomics, screen-reader or
switch-control behavior, or accessibility conformance. Use separate target
platform and assistive-technology evidence for those claims.

## Media Safety

Every public image requires a human, full-image pixel review and an OCR-style
text review. `npm run public:preflight` does not inspect pixels or perform OCR,
so a passing preflight cannot clear screenshot privacy. Reject and recapture any
image that relies on masking, blurring, or cropping to conceal an identifier.

Eight older masked images were removed from the current tree and must not be
restored from Git history for display. Four safe older files remain legacy and
unembedded. See the
[media capture checklist](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/media-capture-checklist.md)
for the exact retired and legacy lists and the publication procedure.

## Verification Commands

```sh
flutter analyze
flutter test
npm run public:preflight
npm run rules:contract
npm run mechanistic:replay
npm run source:quality
```

See:
https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/PUBLIC_VERIFICATION.md
