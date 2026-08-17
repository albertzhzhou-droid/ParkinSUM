# ParkinSUM Explanation Copy Compiler

Educational/research prototype. **Deterministic copy compilation + validation only — no medical advice, no clinical-calibration claim, and not wired into the UI or scoring.**

- templates: 25
- compiled: 25
- info: 0 · warn: 0 · blocker: 0
- pass (0 blocker): true

## Compiled copy

| template | output | locale | text |
| --- | --- | --- | --- |
| mechanistic_explanation_boundary | mechanistic_explanation | en | This educational prototype shows a modeled, source-linked overlap estimate of 42%. It is not medical advice and is not clinically calibrated. |
| source_quality_boundary | boundary | en | Source-quality signals describe how a value was sourced, not its clinical accuracy. Educational only; not clinically calibrated. |
| missing_context_boundary | boundary | en | The source coverage is incomplete, so this result is shown with reduced confidence and is not medical advice. |
| evidence_trace_boundary | boundary | en | This is a local educational evidence trace. It is not a patient record and is not clinical validation. |
| not_advice_default | policy | en | This is an educational prototype output. It is not medical advice and must not be used to make medication, dietary, or timing decisions. |
| not_clinically_calibrated_default | policy | en | This prototype is not clinically calibrated and carries no clinical-validation claim. |
| safety_boundary_default | policy | en | Do not change medication, diet, or timing based on this app. Review with a qualified clinician before making health decisions. |
| onboarding_safety_education_title | boundary | en | Rule guidance is not medical advice |
| legacy_no_conflict | boundary | en | No significant rule conflicts were detected (based only on built-in rules; not medical advice). |
| onboarding_safety_education_body | boundary | en | ParkinSUM gives conservative prompts from medication, meal, and regional rules. Medication changes, stopping therapy, or clinical diet decisions still need a physician or pharmacist. |
| onboarding_account_scope_title | boundary | en | Account data stays user-scoped |
| onboarding_account_scope_body | boundary | en | After onboarding, profile, medications, intakes, and later audit records are saved under the current account user space. |
| legacy_analysis | boundary | en | Built-in rules checked this meal against 1 medication(s), producing a heuristic screening score of 42/100. |
| legacy_analysis_followup | boundary | en | Treat this as a lightweight screening result and confirm exact medication timing when you need more specific guidance. |
| legacy_high_protein_strong | informational | en | High protein timing may strongly affect levodopa absorption |
| legacy_high_protein_strong_detail | informational | en | This meal contains about 40.0 g of protein, which is in a higher-risk range. Taking it close to Sample may compete more strongly for absorption. |
| legacy_high_protein | informational | en | Protein may affect medication absorption |
| legacy_high_protein_detail | informational | en | This meal contains about 25.0 g of protein and may compete with Sample during absorption. Consider scheduling higher-protein meals away from dosing time. |
| legacy_tyramine | informational | en | Possible high-tyramine food risk |
| legacy_tyramine_detail | informational | en | This meal includes foods marked as high tyramine. Combined with Sample, it may increase adverse-effect risk. |
| legacy_mineral | informational | en | Meal timing note for mineral supplements |
| legacy_mineral_detail | informational | en | This meal includes dairy and may suggest higher calcium content. Some mineral supplements can have different absorption or GI tolerance when taken with food. |
| legacy_summary | informational | en | Overall score 42/100 (Moderate), with 2 possible food-drug or nutrition-related alerts. |
| legacy_analysis_protein | informational | en | The current meal estimate contains about 25.0 g of protein. |
| legacy_analysis_tyramine | informational | en | This meal also contains foods tagged as higher tyramine risk in the built-in catalog. |

## Limitations

- Compiles + validates copy templates; it does not migrate UI strings or change scoring.
- Banned-phrase matching reuses the conservative LocalizationSafetyLint families; not a clinical-safety guarantee.
- Required safety/evidence terms are enforced on the default-locale render; other locales are covered by localization:lint.
- Synthetic/demo data only; not clinically calibrated; carries no clinical-validation claim.

## Safety boundary

Deterministic copy compilation + validation only. It adds no medical advice, no dose/timing/diet guidance, and no clinical-calibration claim, and is not wired into the UI or scoring.

This is an educational prototype output. It is not medical advice and must not be used to make medication, dietary, or timing decisions.
