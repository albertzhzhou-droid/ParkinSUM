# Evidence & Traceability Demo Guide

Educational/research prototype. Synthetic inputs only. **Not medical advice. Not
clinically calibrated.**

This guide lets a reviewer understand ParkinSUM's evidence and traceability
story end-to-end **without reading the whole codebase**. It points at the
deterministic artifacts the project produces and explains exactly what each one
does — and does not — prove.

## 1. Purpose

ParkinSUM Companion demonstrates production-style architecture, data provenance,
and a deterministic, literature-informed *educational* mechanistic model of how
meals may affect levodopa availability for absorption. This guide consolidates
the evidence artifacts (replay report, FHIR-inspired views, local evidence-trace
bundle, source-quality perturbation report) into one reviewable walkthrough.

## 2. Safety boundary

ParkinSUM is **not a medical device** and not clinical software. It does not
provide diagnosis, treatment, medication timing, dose guidance, diet decisions,
patient-care guidance, patient monitoring, or clinical decision support. Every
output is deterministic, evidence-linked, non-prescriptive, and carries an
explicit not-advice boundary. See `CLAUDE.md`, `DISCLAIMER.md`, and
`docs/PUBLIC_DEMO_BOUNDARY.md`.

## 3. What the demo proves

- The mechanistic engine is **deterministic** and **inspectable**: every modeled
  value traces to a `Bibliographies.md` source via `sourceRefs`.
- **Missingness is preserved**: absent nutrient/medication fields lower
  completeness and widen uncertainty rather than being silently treated as data.
- **Source quality is visible and influences confidence**, not advice: authority
  tier, jurisdiction match, metadata completeness, and FDC nutrient-provenance
  tier are surfaced and affect ranking confidence/tie-breaking.
- **Provenance is serializable**: FHIR-inspired views and the local evidence
  bundle export the trace in a structured, PHI-free form.
- **Conflict overlap stays dominant**: provenance/source-quality can refine or
  break ties but can never overpower a substantial modeled conflict gap.

## 4. What the demo does NOT prove

- It is **not clinical validation**. Mechanistic replay passing ≠ any clinical
  claim.
- It does **not** predict any individual's plasma levodopa concentration.
- FDC provenance tiers (analytical / calculated / imputed-or-assumed / unknown)
  are **source-quality signals, not clinical or biological accuracy estimates**.
- The model is **not clinically calibrated**; magnitudes are prototype
  heuristics tagged in `model_assumption_registry.dart`.

## 5. Data-flow overview

```
Importers / CDSS records
  → canonical metadata (DrugProductVariantMetadata, FoodVariantMetadata)
  → MetadataCompletenessGate + SourceAuthorityScorer  (source quality)
  → MealCompositionNormalizer (missing ≠ zero) + AminoAcidExtractor (FDC tier)
  → TimeAxisConflictContext
  → GastricEmptying → AbsorptionOpportunity → LNAA competition
  → MechanisticConflictEngine → MechanisticConflictResult (sourceRefs, bands)
  → MechanisticNextMealScorer → MechanisticCandidateScore (conflict-dominant)
Serialization / evidence views (no PHI):
  → FHIR-inspired NutritionIntake view
  → FHIR-inspired MedicationKnowledge view (+ LOINC section codes)
  → EvidenceTraceBundle (local, NOT a FHIR Bundle)
Reports:
  → Mechanistic replay report
  → Source-quality perturbation report
```

## 6. Evidence artifacts

| Artifact | Where | What it shows |
| --- | --- | --- |
| Mechanistic replay report | `build/mechanistic_replay/latest.{json,md}` | Deterministic per-scenario engine outputs + banned-phrase scan. |
| FHIR-inspired NutritionIntake view | `lib/domain/entities/fhir_inspired_nutrition_intake_view.dart` | Meal composition + nutrient/amino-acid provenance, PHI-free. |
| FHIR-inspired MedicationKnowledge view | `lib/domain/entities/fhir_inspired_medication_knowledge_view.dart` | Product metadata + label-section refs + LOINC codes, PHI-free. |
| Local EvidenceTraceBundle | `lib/domain/entities/evidence_trace_bundle.dart` | Pairs both views for review (local, not a FHIR Bundle). |
| Source-quality perturbation report | `build/source_quality_perturbation/latest.{json,md}` | How candidate scoring moves when only source/provenance quality changes. |
| Standards scorecard / traceability matrix | `docs/BIOMEDICAL_STANDARDS_CONFORMANCE_SCORECARD.md`, `docs/BIOMEDICAL_TRACEABILITY_MATRIX.md` | Code-grounded posture vs FHIR/LOINC/FDC/FAIR. |

## 7. Commands to run

All commands below already exist in the repo:

```sh
flutter test --concurrency=1
dart run tool/run_mechanistic_replay.dart      # or: npm run mechanistic:replay
npm run public:preflight
node tool/firestore_rules_contract_check.mjs
dart run tool/run_source_quality_perturbation_report.dart   # or: npm run source:quality
dart run tool/run_release_snapshot.dart                     # or: npm run release:snapshot
dart run tool/generate_public_demo_walkthrough.dart         # or: npm run demo:walkthrough
dart run tool/generate_evidence_graph.dart                  # or: npm run evidence:graph
```

The last three **compose** the artifacts above into reviewer summaries:
`build/release_snapshot/latest.{json,md}` (a per-check evidence table),
`build/public_demo_walkthrough/latest.{md,json}` (a synthetic end-to-end
walkthrough), and `build/evidence_graph/latest.{json,mmd,md}` (a local
evidence/provenance graph — nodes + edges + Mermaid; see `docs/EVIDENCE_GRAPH.md`,
explicitly NOT a FHIR Provenance resource or W3C PROV export). All report
`missing_artifact` rather than fabricating results, and none emits advice or PHI.
See `docs/PUBLIC_VERIFICATION.md`.

## 8. Expected outputs

- `flutter test --concurrency=1` → all tests pass.
- replay → `N/N scenarios passed` and report files under
  `build/mechanistic_replay/`.
- `npm run public:preflight` → `"pass": true`, `BLOCKER: 0`.
- firestore contract → `13/13`.
- source-quality report → row count printed and files under
  `build/source_quality_perturbation/`.

## 9. How to inspect replay output

Open `build/mechanistic_replay/latest.md` for the human-readable table or
`latest.json` for the full per-scenario report. Each row carries severity /
confidence bands, `sourceRefs`, the amino-acid confidence tier, and
`clinical_calibration_status: not_clinically_calibrated`. See
`docs/REPLAY_RUNNER.md`. The runner exits non-zero if any banned prescriptive
substring leaks.

## 10. How to inspect the EvidenceTraceBundle

`EvidenceTraceBundleBuilder.build(...)` returns an `EvidenceTraceBundle` whose
`toJson()` pairs the two inspired views. Confirm `bundle_type =
parkinsum_local_evidence_trace_bundle`, `conformance_status =
local_not_fhir_bundle`, `phi_policy = no_patient_no_subject_no_encounter`, and the
**absence** of any `resourceType` / `Bundle` / patient / subject / encounter key.
See `docs/EVIDENCE_TRACE_BUNDLE.md` and `test/evidence_trace_bundle_test.dart`.

## 11. How to inspect the source-quality perturbation report

Run the command in §7, then open `build/source_quality_perturbation/latest.md`.
It shows how candidate scoring moves when **only** source/provenance quality
changes, holding the meal/conflict/model input constant. See
`docs/SOURCE_QUALITY_PERTURBATION_REPORT.md` and
`test/source_quality_perturbation_report_test.dart`.

## 12. How to inspect the FHIR-inspired views

Both views are built by their mappers (`fhir_inspired_nutrition_intake_mapper.dart`,
`fhir_inspired_medication_knowledge_mapper.dart`) and serialize to deterministic,
snake_case JSON. Both declare `conformance_status = inspired_not_conformant` and a
`phi_policy`. The shared recursive **key-level** no-PHI scan
(`test/helpers/no_phi_json_assertions.dart`) asserts neither view emits
patient-care/clinical keys. The MedicationKnowledge view exposes label-section
refs with both the original `section_code` and an optional discrete `loinc_code`.

## 13. How missingness and source quality affect confidence

- Missing nutrient/medication fields are recorded as **missing** (never coerced
  to a true `0 g`), lowering `compositionCompleteness` and widening the
  gastric-emptying / LNAA uncertainty bands.
- `MetadataCompletenessGate` grades candidate-food completeness; weaker source
  quality lowers the grade and thus the candidate's `metadataCompletenessScore`.
- `SourceAuthorityScorer` keeps official-in-jurisdiction above synthetic/seed;
  seed/synthetic can never outrank official data.

## 14. How FDC nutrient derivation affects uncertainty / completeness

USDA FDC `foodNutrientDerivation` codes map (conservatively) to a confidence
tier: **analytical** (measured) > **calculated** (derived) > **imputed/assumed**
(borrowed) > **unknown**. A weaker-than-analytical tier:

- widens the LNAA competition uncertainty band (amino-acid layer); and
- lowers the candidate-food **metadata completeness** grade via
  `MetadataCompletenessGate.scoreCandidateFood(..., nutrientConfidenceTier:)`,
  which flows into `CandidateMetadata.completeness` →
  `MechanisticCandidateScore`.

A missing derivation yields a **null** tier and never raises confidence. These
tiers are **source-quality signals, not biological/clinical certainty**, and
affect confidence/tie-breaking only — never medical advice, and never overriding
source-authority or jurisdiction policy.

## 15. Known limitations

- The model is **not clinically calibrated**; numeric magnitudes are prototype
  heuristics.
- All artifacts are exercised via **synthetic fixtures**, not live ingestion.
- FHIR-inspired views are `inspired_not_conformant`; the EvidenceTraceBundle is a
  local artifact, **not** a FHIR Bundle.
- Product strength in the MedicationKnowledge view is **product metadata, not a
  user intake dose**.
- LOINC section-code mapping is partial/conservative (known FDA SPL headings
  only; otherwise `unknown`).

## 16. Suggested reviewer checklist

- [ ] `flutter test --concurrency=1` passes.
- [ ] Replay report is `N/N` and banned-phrase-clean.
- [ ] `npm run public:preflight` is `BLOCKER: 0` and the clinical-calibration
      guardrail phrase is present in README + `CONFLICT_ENGINE_MODEL.md`.
- [ ] Firestore contract is `13/13`.
- [ ] Source-quality report runs; analytical ≥ calculated ≥ imputed/assumed ≥
      unknown when other inputs match; conflict overlap stays dominant.
- [ ] FHIR-inspired views + EvidenceTraceBundle emit **no** patient / subject /
      encounter / `resourceType` / `Bundle` keys.
- [ ] Missing nutrient is recorded missing, distinct from a true `0 g`.
- [ ] No diagnosis / treatment / dose / timing / diet advice anywhere.
