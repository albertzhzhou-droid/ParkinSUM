# Physiology reference model (prototype)

A real-unit reference model of meals, levodopa and amino-acid competition at
the blood-brain barrier, and the published human data it must reproduce.
Educational research prototype; see
[docs/design/PHYSIOLOGY_MODEL_V2.md](../../docs/design/PHYSIOLOGY_MODEL_V2.md)
for structure, results and boundaries.

Python 3.9+, standard library only. Run from the repository root:

```sh
python3 -I tool/physiology_reference/reality_checks.py --json build/physiology_reference/report.json
python3 -I tool/physiology_reference/whatif.py --svg docs/design/assets/physiology-whatif.svg
python3 -I tool/physiology_reference/calibrate.py          # print fits; --write stores them
python3 -I tool/physiology_reference/agreement.py          # rewrite the Dart agreement fixture
npm run physiology:reality                                 # reality checks + fixture freshness + Dart agreement
```

| File | Purpose |
| --- | --- |
| `model.py` | Stomach, levodopa (unchanged since v2), amino-acid (protein type, digestibility, splanchnic first pass, insulin action, habitual intake) and blood-brain-barrier equations; nutrition-only outputs (`competing_lnaa_load`, `meal_response`); seeded population draws |
| `parameters.json` | Every value with unit, source and status (literature, calibrated, heuristic, verify), including USDA FDC protein-type amino-acid profiles |
| `scenarios.py` | Published experiments rebuilt from their abstracts, with stated assumptions |
| `calibrate.py` | Fits the four calibrated parameters to their named targets only |
| `reality_checks.py` | 28 checks labelled calibrated, independent, structural or known gap; non-zero exit on failure |
| `whatif.py` | Meal-offset comparison with 5th-95th percentile bands and a theme-aware SVG |
| `agreement.py` | Writes or checks `test/fixtures/physiology_reference_agreement.json`, which the Dart port (`lib/domain/usecases/physiology_reference_model.dart`) must reproduce |

Outputs are population-typical curves for synthetic scenarios. They are not
predictions for any person and not dosing, timing or dietary advice.
