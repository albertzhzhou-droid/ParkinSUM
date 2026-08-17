# ParkinSUM Public Demo Walkthrough

Educational/research prototype. Synthetic/demo data only. **Not medical advice, not clinically calibrated, and carries no clinical-validation claim.** No patient data is used or shown.

Composed from existing synthetic artifacts. Missing artifacts are reported as `missing_artifact` — never fabricated.

## 1. Synthetic input summary

All inputs are synthetic/demo only (no patient data). Scenarios: 41 synthetic replay scenarios. Capability matrix: see docs/CAPABILITY_MATRIX.md.

## 2. Source quality summary

missing_artifact

## 3. Missingness summary

Missing nutrient/medication fields are recorded as missing (never coerced to a true 0 g), which lowers completeness and widens uncertainty. 25 of 41 replay scenarios model reduced meal-context completeness.

## 4. Mechanistic replay summary

Mechanistic replay: 41/41 deterministic synthetic scenarios passed, each scanned for banned prescriptive phrasing. This is synthetic regression testing, not clinical validation.

## 5. Evidence trace / bundle summary

missing_artifact

## 6. What this demo proves

- Outputs are deterministic and reproducible from synthetic inputs.
- Provenance and missingness are preserved (missing is recorded, not coerced to zero).
- Source quality affects modeled confidence and tie-breaking only.
- Safety copy is scanned so educational text cannot drift into advice.

## 7. What this demo does NOT prove

- Any clinical accuracy, patient-outcome validity, or regulatory approval.
- Any individual plasma-levodopa prediction.
- That the model is clinically calibrated (it is not).
- Anything about a specific person — there is no patient data.

## 8. Safety boundary

Do not change medication, diet, or timing based on this app. Review with a qualified clinician before making health decisions.

## 9. Not clinically calibrated

The mechanistic model is **not clinically calibrated**; numeric magnitudes are literature-informed prototype parameters.

## 10. Not medical advice

This is an educational prototype output. It is not medical advice and must not be used to make medication, dietary, or timing decisions.
