# Media Capture Checklist

Use this checklist before adding or replacing public screenshots, GIFs, or
videos. Public media must show synthetic or sample content only and must remain
inside ParkinSUM's educational, non-clinical boundary.

## Current Reference Capture

- Source: `main@23619f1`
- Capture date: 2026-08-18
- Backend: default local mode (`PARKINSUM_BACKEND` unset)
- App state: fresh synthetic onboarding; no reused account or user records
- Observatory state: fixed, non-personal scenario fixtures
- Desktop browser viewport: 1440 x 1000
- Responsive browser viewport: 390 x 844
- Publication state: draft pending a maintainer's final human pixel review; no
  local OCR utility was available during the capture review

The canonical file descriptions and retired-media record are maintained in the
[screenshot asset index](assets/screenshots/README.md).

## Current Required Files

| Target path | Capture requirement | Acceptance focus |
| --- | --- | --- |
| `docs/assets/screenshots/runtime-dashboard-desktop.png` | Fresh local-mode dashboard after synthetic onboarding. | No account identifier or reused record; local and conservative UI state is visible. |
| `docs/assets/screenshots/capability-center-desktop.png` | Settings and capability center. | Entry points are readable without exposing private configuration or local paths. |
| `docs/assets/screenshots/algorithm-observatory-overview-desktop.png` | Observatory overview with the three fixed scenarios and model trace. | The fixed, non-personal fixture and non-prediction boundary are visible. |
| `docs/assets/screenshots/algorithm-observatory-explanation-desktop.png` | Conflict composition and expanded explanation tree. | Severity and confidence remain separate; evidence and interpretation limits are readable. |
| `docs/assets/screenshots/algorithm-observatory-coverage-desktop.png` | Synthetic replay context and algorithm coverage surface. | Synthetic markers and contract boundaries are visible; no operator or private runtime data appears. |
| `docs/assets/screenshots/algorithm-observatory-responsive.png` | Fixed scenario table at 390 x 844. | Narrow-viewport reflow is legible and is not presented as physical-device evidence. |

## Before Capture

- Check out and record the exact source revision.
- Run the public demo with the default local backend.
- Clear prior app state and complete onboarding with fresh synthetic values.
- Use only the Observatory's fixed, non-personal fixtures.
- Close password managers, personal browser profiles, notifications, terminals,
  developer consoles, and other windows that could enter the capture.
- Capture only the app surface needed to support the stated UI claim.
- Keep educational and non-prediction boundary text readable.

## Human Visual and OCR-Style Review

Automated public preflight does not decode screenshot pixels and is not a
privacy review for raster media. A human reviewer must complete all of the
following before publication:

1. Inspect every pixel region at readable zoom, including all four corners,
   headers, browser/app chrome, overlays, dialogs, tables, chart labels,
   collapsed and expanded rows, and low-contrast text.
2. Perform an OCR-style review: use local OCR when available, then inspect its
   extracted text for emails, UIDs, paths, tokens, account names, dates, or
   health-related records. Treat OCR misses as possible, not as proof of safety.
3. Confirm that every visible meal, medication, dose, timestamp, region, and
   scenario is part of the approved synthetic fixture or is absent.
4. Confirm that the image contains no real email, full UID, token, credential,
   private endpoint, local machine path, user export, raw audit log, browser
   account, notification, or other identifying content.
5. Reject and recapture unsafe media. Do not publish a screenshot whose safety
   depends on a blur, opaque overlay, crop edge, or replacement label.
6. Record the reviewer, source revision, capture date, viewport, and synthetic
   fixture used.

## Evidence Limits

A screenshot is evidence of visible UI/runtime state at one captured revision.
It is not evidence of end-to-end workflow completion, persistence, network
isolation, algorithm correctness, clinical validity, safety, or patient
outcomes.

The 390 x 844 responsive image is a browser viewport check only. It does not
establish physical-device behavior, native Android or iOS behavior, release
packaging, performance, touch ergonomics, screen-reader behavior, switch-control
behavior, or accessibility conformance. Those claims require separate target
platform and assistive-technology evidence.

Do not describe educational curves as gastric-emptying tests, absorbed dose,
plasma concentration, predicted symptoms, or personal medical advice. Do not
describe the displayed algorithm count as clinical validation.

## Retired and Legacy Media

Eight older images with unsafe masking were removed from the current tree. They
remain in Git history and must not be restored for public display:

- `analytics-local-ai.png`
- `catalog-showcase.png`
- `conflict-explanation.png`
- `medications-catalog.png`
- `next-meal-results.png`
- `next-meal-setup.png`
- `timeline-action-state.png`
- `timeline-overview.png`

`auth-sign-in.png`, `dashboard.png`, `meal-entry.png`, and
`conflict-result.png` are safe legacy captures only. They are intentionally not
embedded in the current showcase.

## Suggested Observatory Demo Flow

1. Start in default local mode and complete fresh synthetic onboarding.
2. Show the zero-record runtime dashboard and its conservative path.
3. Open Settings and the capability center.
4. Enter the Algorithm Observatory.
5. Compare the mixed-reference, high-fat-plus-protein, and missing-data fixed
   fixtures without presenting their outputs as patient predictions.
6. Show the educational trace, conflict composition, and separate severity and
   confidence labels.
7. Expand the evidence tree and point out where interpretation must stop.
8. Show the result-affecting algorithm coverage surface.
9. Demonstrate the same fixed scenario table in the 390 x 844 responsive
   browser viewport, explicitly naming it as a viewport check.

The reviewer-facing walkthrough is maintained in
[Demo Path](github-wiki/Demo-Path.md).

## Publication Rules

- Prefer correctly encoded PNG for screenshots.
- Do not add broken links or planned image paths to public pages.
- Embed only files that exist, render on GitHub, and passed the human visual and
  OCR-style review.
- Keep alt text factual: identify the visible route and synthetic fixture, not
  unverified behavior.
- Re-run `npm run public:preflight`, while remembering that a passing result does
  not inspect or clear screenshot pixels.
- Review the final page at normal GitHub width to confirm text remains legible.
