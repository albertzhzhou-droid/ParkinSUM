# Public Screenshot Assets

## Current Paper Capture Set — 2026-09-29

Four actual Chrome browser captures from a local Flutter release-web build,
using a fresh isolated browser profile and the local backend. Capture source:
`release/paper-evidence-update-20260929`, dirty worktree based on committed HEAD
`94e7ef30b64059ea6893a1ed431d15daac3ff859`. The build predates final registry
count/validation adjustments in this publication iteration. These images must
not be described as captures of the eventual final commit or as a binary
attestation of that commit.

Onboarding used zero medications and no AI consent. One banana meal named
`Synthetic demo meal` was added. The capture exercise observed
**Add → Save → Timeline → Today**, with the Today meal count at one. This is a
bounded synthetic browser journey; it does not establish persistence across
restart, all controls, native integrations, or model correctness.

| File | Viewport | Visible state |
| --- | --- | --- |
| `paper-today.png` | 1440 × 1000 | Today composer, one synthetic meal, zero active medications/intakes, and conservative candidate preview. |
| `paper-timeline.png` | 1440 × 1000 | Saved synthetic meal in the Timeline chapter. |
| `paper-next-meal.png` | 1440 × 1000 | Next-meal comparison settings before result generation. |
| `paper-library.png` | 1440 × 1000 | Built-in medication catalog and zero selected medications. |

Capture review: all four complete images were visually inspected by the agent
at readable size; no personal identifiers, private records, or credentials
were visible. This records agent visual review, not human acceptance or OCR
certification. The unchanged privacy-review procedure below still describes
the separate human-review requirement for public media.

The captions describe visible UI state only. No Observatory screenshot is
presented as current Paper-runtime evidence. Older August screenshots remain
historical and must not be used to imply current trace/registry counts.

### SHA-256

- `paper-today.png`: `a5be78a76c6da8edc406042c3d8e8c0960d89ec3f8e01d3a880ff603049f848a`
- `paper-timeline.png`: `74cc4fb57f2b9754641b7efdfab0f1d1055484984646e845ecf3395891ea5d84`
- `paper-next-meal.png`: `3c8b45fb878cbd3f25bd2a141aca071274d9730dd1a0dd1b58e9f957d842dddd`
- `paper-library.png`: `9c62d1cd1f3ddd333b38f2f99319585c51d0df7341bf0a69c67fb811fb232b71`

## Historical Capture Context

The August 2026 capture set below is retained as historical interface evidence.
It does not represent the September Paper interface. Every August image was
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

## Historical August 2026 Capture Set

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

New public screenshots should extend the archive or replace current showcase media only
after the same source, synthetic-state, visual-privacy, and evidence-boundary
checks are recorded.
