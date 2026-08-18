# Manual Validation Guide

Educational prototype only. Synthetic/demo data only. Not medical advice.

This guide walks through validating the mechanistic next-meal flow and the
multi-jurisdiction metadata trace by hand, plus the deterministic replay.

## Run the app

1. `flutter run -d chrome`
2. Select the generic **carbidopa/levodopa** catalog context. Its formulation
   is intentionally `unspecified`: the current product picker does not yet
   persist a governed route/form/release snapshot, so the model must abstain
   rather than assume immediate release. Bare numbers / unitless entries are
   also rejected by design.
3. Open the **Next meal** page.
4. Set a **user-defined meal window** using the window chooser
   (none / 30 / 60 / 90 min). The app — not the engine — owns the window.
5. Generate. Confirm:
   - `Recommendation ranker: heuristic_legacy_fallback` appears and the page
     states that the mechanistic trace changes order: no. If separately
     consented local AI actually reorders the safe whitelist, the ranker must
     instead read `local_ai_safe_candidate_rerank`.
   - The generic medication path shows `insufficient` formulation context,
     renders no numeric score/curve, and leaves the conservative order intact.
   - Open **Algorithm Observatory** and select an explicitly labelled synthetic
     IR scenario to inspect worst/best/average overlap, samples, modeled curves,
     provenance, limitations, and the not-advice boundary. Raw JSON is not
     shown by default.
6. Set the window chooser to **none** and regenerate. Confirm the page states
   that no per-candidate trace was generated and recommendations remain on the
   conservative heuristic.

## Run the deterministic replay

```sh
dart run tool/run_mechanistic_replay.dart   # or: npm run mechanistic:replay
```

- Confirm every committed scenario passes.
- Inspect `build/mechanistic_replay/latest.json` and `latest.md`. Each case
  carries `ranker_used`, `amino_acid_data_mode`, `amino_acid_nutrient_ids`,
  `top_protein_window_role`, `top_final_candidate_score`, source system, and
  pass/fail.

## Troubleshooting

| Symptom | Likely cause | What to check |
| --- | --- | --- |
| Ranker stays `heuristic_legacy_fallback` | Expected production behavior; model is trace-only | Confirm `mechanistic_trace_only_not_validated_for_ranking` is surfaced |
| No per-candidate model trace | No window or the context is insufficient/out of domain | Inspect the visible abstention predicates before changing inputs |
| Medication context invalid/insufficient | Unitless input or generic product without governed formulation | Preserve abstention; use only an explicitly identified synthetic IR Observatory fixture for model inspection |
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
