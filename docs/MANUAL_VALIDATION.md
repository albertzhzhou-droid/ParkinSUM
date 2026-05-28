# Manual Validation Guide

Educational prototype only. Synthetic/demo data only. Not medical advice.

This guide walks through validating the mechanistic next-meal flow and the
multi-jurisdiction metadata trace by hand, plus the deterministic replay.

## Run the app

1. `flutter run -d chrome`
2. Select or add a **catalog-backed levodopa context** on the medications page
   (a carbidopa/levodopa catalog item). Bare numbers / unitless entries are
   rejected by the medication-context gate by design.
3. Open the **Next meal** page.
4. Set a **user-defined meal window** using the window chooser
   (none / 30 / 60 / 90 min). The app — not the engine — owns the window.
5. Generate. Confirm:
   - `Ranker used: mechanistic_primary` appears **when context is sufficient**
     (window provided + medium/high confidence + every candidate scored).
   - The per-candidate trace chips show worst/best/avg overlap, sample count,
     `protein-window <role>`, `redistribution <pct>`, `aa-mode <mode>`, and
     `src <sourceSystem>`.
   - The model-trace card (expansion tile) shows interaction score, severity,
     confidence, drivers, modeled windows, limitation, safety boundary, and
     not-advice text. Raw JSON is **not** shown by default.
6. Set the window chooser to **none** and regenerate. Confirm the page states
   *"Mechanistic-primary ranking is unavailable because no user-defined meal
   window was provided."* and `Ranker used: heuristic_legacy_fallback`.

## Run the deterministic replay

```sh
dart run tool/run_mechanistic_replay.dart   # or: npm run mechanistic:replay
```

- Confirm `26 / 26 scenarios passed`.
- Inspect `build/mechanistic_replay/latest.json` and `latest.md`. Each case
  carries `ranker_used`, `amino_acid_data_mode`, `amino_acid_nutrient_ids`,
  `top_protein_window_role`, `top_final_candidate_score`, source system, and
  pass/fail.

## Troubleshooting

| Symptom | Likely cause | What to check |
| --- | --- | --- |
| Ranker stays `heuristic_legacy_fallback` | No window, low confidence, or a candidate is insufficient | `rankerEligibility.fallbackReasons` in the result / replay JSON |
| "no user-defined meal window" message | Window chooser set to none | Pick 30/60/90 min |
| Medication context invalid | Unitless/bare medication input | Use a catalog-backed levodopa item with unit + form + release type |
| Candidate low confidence | Missing nutrient fields | Composition completeness < 1.0; nutrient basis missing |
| `aa-mode unknown` | No protein and no amino-acid fields | Provide protein grams or amino-acid profile |
| `aa-mode protein_source_proxy` | Protein present but no amino-acid fields | Expected fallback; add an `AminoAcidProfile` for actual-fields mode |
| Source-linked explanation blocked | Missing `sourceRefs` | Completeness gate downgrades explanations without provenance |
| dm+d / EU-national source can't supply mechanism evidence | Identity-only record (no SmPC/label text) | These are identity/coding sources; mechanism needs a label/SmPC source |

## Live source smoke (opt-in)

```sh
dart run tool/run_live_source_smoke.dart            # SKIPS (no network)
npm run live:smoke                                   # same via wrapper
```
Without `PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE=1` it prints a skip message and
exits 0 without contacting the network. It validates fetch shape only, fetches
official metadata only, and never stores raw payloads. Do not enable it in CI.

## Notes

- The mechanistic model is **not clinically calibrated** — literature-informed
  prototype gastric-emptying parameters + an educational LNAA proxy; no
  patient-specific PK/PD prediction.
- Live network fetch exists behind `SourceFetchClient` / `LiveSourceFetchClient`
  but is **not** used by tests and **not** used to fetch clinical advice. All
  adapters are validated against synthetic fixtures.
- Source-specific legal/license review remains future work
  (`docs/SOURCE_ACCESS_AND_LICENSES.md`).
- Nothing here is medical advice, a diagnosis, a dosing/timing recommendation,
  or a claim of clinical validation.
