# Demo Path

Use a fresh **local-mode, synthetic** profile when showing ParkinSUM to a
reviewer. Keep the educational boundary visible. The current Paper navigation
is Today, Timeline, Next meal, Insights, and Library.

## A short walkthrough

1. **Open Today.** Show the single composer for a meal, medication intake, or
   observation. A fresh empty state is valid; do not invent prior records.
2. **Inspect Library.** Distinguish selected medications from the source catalog.
   Show provenance and jurisdiction without treating catalog identity as proof
   of a complete product/formulation context.
3. **Add a synthetic entry.** Use explicit units and supported context. In
   Timeline, inspect the record and its source rather than inferring missing
   values or promoting self-reported data to verified clinical evidence.
4. **Open Next meal.** Supply a user-defined time window. Inspect candidate
   explanations and visible missingness. Abstention is an expected result when
   the context does not support interpretation.
5. **Open Algorithm Observatory** from the evidence sidebar group or command
   palette. Compare fixed, non-personal fixtures; inspect production-derived
   traces and the explanation tree. Static contracts remain separately labeled.
6. **Open the synthetic rule test workbench.** Show authored expectations and
   expected/actual assertions in its disposable workspace. A passing case does
   not authorize installing a rule or establish clinical correctness.
7. **Show verification evidence.** Use the capability matrix, command guide, and
   dated iteration timeline to explain what was tested and what remains open.

## Decision boundaries

Deterministic rules own classifications, scores, safety gates, and evidence.
The mechanistic model remains `trace_only`: it does not select a meal time or
reorder candidate recommendations. Optional consent-gated loopback AI may only
rerank rule-screened, non-BLOCK candidates or polish existing copy.

Observatory curves are educational sensitivity views. They are not clinical
measurements, plasma concentrations, symptom predictions, or individualized
medication/diet guidance. A registry descriptor count is a snapshot of that
revision, not a permanent count or proof of complete executable coverage.

## Reference media

Use the [screenshot index](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/assets/screenshots/README.md)
for current Paper captures, recorded capture context, and historical media.
August 2026 screenshots document their older source revision. Retired unsafe
captures must not be restored or reused.

Browser images establish visible rendering at a recorded state. They do not
prove complete workflow execution, persistence, native integrations, algorithm
correctness, clinical validity, physical-device behavior, or accessibility
conformance.

Follow the [media checklist](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/media-capture-checklist.md):
review each full image at readable zoom and supplement with OCR-style review
when available. Repository preflight does not inspect pixels. Exclude real
account identifiers, health records, credentials, private endpoints, logs,
notifications, and machine-specific paths.

## Verification commands

```sh
npm ci
flutter analyze
flutter test
npm run public:preflight
npm run rules:contract
npm run mechanistic:replay
npm run source:quality
```

The [verification guide](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/PUBLIC_VERIFICATION.md)
records prerequisites and scope. Actual results and unresolved limits belong
in the [iteration timeline](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/APP_EVOLUTION_TIMELINE.md).
