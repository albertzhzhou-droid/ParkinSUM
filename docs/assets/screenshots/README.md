# Public Screenshot Assets

This directory contains the current public README capture set. Every image was
captured from `main@23619f1` on 2026-08-18 with the default local backend. The
dashboard and capability views use a fresh synthetic onboarding state; the
Algorithm Observatory views use its fixed, non-personal fixtures.

The five desktop captures use a 1440 x 1000 browser viewport. The responsive
capture uses a 390 x 844 browser viewport. These are browser-rendered UI
captures; they are not physical-device or native-app evidence.

Review record (2026-08-18): PNG encoding, dimensions, references, and full-frame
visible content were checked during capture. No local OCR utility was available.
The proposed media therefore remains subject to a maintainer's final human
pixel review before merge; repository preflight cannot replace that review.

## Current Capture Set

| File | Viewport | UI state represented |
| --- | --- | --- |
| `runtime-dashboard-desktop.png` | 1440 x 1000 | Fresh local-mode dashboard, primary navigation, zero synthetic records, and the conservative candidate path. |
| `capability-center-desktop.png` | 1440 x 1000 | Settings and capability entry points, including the Algorithm Observatory, data integrity, diagnostics, import, privacy, and user-controlled data tools. |
| `algorithm-observatory-overview-desktop.png` | 1440 x 1000 | Three fixed, non-personal scenario fixtures, their sensitivity comparison, and the educational gastric-residence trace. |
| `algorithm-observatory-explanation-desktop.png` | 1440 x 1000 | Conflict composition, separate severity and confidence labels, and an expandable evidence-and-boundary explanation tree. |
| `algorithm-observatory-coverage-desktop.png` | 1440 x 1000 | Synthetic replay-ledger context and the searchable result-affecting algorithm contract surface. |
| `algorithm-observatory-responsive.png` | 390 x 844 | The same fixed scenario comparison reflowed for a narrow browser viewport. |

The displayed values belong only to fixed educational fixtures. They are not
patient predictions, clinical measurements, dosing guidance, dietary guidance,
or evidence of clinical validation.

## What These Images Establish

The captures establish that the named routes, copy, controls, cards, charts,
and responsive reflow were visibly rendered at the recorded source revision.
They do not establish that:

- every visible control completes its workflow;
- persistence, authentication, networking, or native integrations work;
- an algorithm is correct, complete, calibrated, or clinically valid;
- the browser viewport matches a physical device or native build; or
- keyboard, screen-reader, switch-control, contrast, or other accessibility
  conformance has been verified.

Use the repository's automated tests, public-verification commands, and target
platform evidence for claims beyond visible UI/runtime state.

## Mandatory Privacy Review

Public preflight checks repository text and known artifact patterns; it does
**not** inspect pixels or perform OCR on screenshots. Before an image is linked
from public documentation, a human reviewer must inspect the complete image at
readable zoom, including headers, corners, overlays, tables, expanded panels,
and partially obscured text. An OCR-style pass should also be performed when a
suitable local tool is available, but OCR supplements rather than replaces the
human pixel review.

Reject and recapture any image that may expose a real email, UID, health or
medication record, token, credential, private endpoint, local path, operator
artifact, browser account, notification, or other identifying content. Do not
try to make an unsafe capture public by placing a mask over the sensitive text.

See the [media capture checklist](../../media-capture-checklist.md) for the full
acceptance procedure.

## Retired Media

Eight older account-backed captures were removed from the current tree because
their masking left unsafe identifier remnants:

- `analytics-local-ai.png`
- `catalog-showcase.png`
- `conflict-explanation.png`
- `medications-catalog.png`
- `next-meal-results.png`
- `next-meal-setup.png`
- `timeline-action-state.png`
- `timeline-overview.png`

Git history retains those files for repository history. They must not be
restored, relinked, or shown in public documentation.

The following older captures remain only as safe legacy artifacts and are not
embedded in the current public showcase:

- `auth-sign-in.png`
- `dashboard.png`
- `meal-entry.png`
- `conflict-result.png`

New public screenshots should extend or replace the six-file current set only
after the same source, synthetic-state, visual-privacy, and evidence-boundary
checks are recorded.
