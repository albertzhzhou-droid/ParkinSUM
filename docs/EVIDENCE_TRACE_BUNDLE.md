# Local Evidence Trace Bundle

Educational/research prototype only. Synthetic inputs only. Not medical advice.

## What it is

`EvidenceTraceBundle` (`lib/domain/entities/evidence_trace_bundle.dart`, built by
`EvidenceTraceBundleBuilder`) is a **ParkinSUM-local** artifact that pairs the
two FHIR-inspired, PHI-free views — the NutritionIntake-inspired meal view and
the MedicationKnowledge-inspired product view — into a single reviewable trace
for demos and audits.

It exists so a reviewer can see, in one object, *what synthetic meal data and
what medication product provenance* fed a given educational simulation, with the
source refs and missingness from both sides preserved.

## What it is NOT

This is **not a FHIR Bundle**. It deliberately:

- emits `bundle_type = parkinsum_local_evidence_trace_bundle` and
  `conformance_status = local_not_fhir_bundle` — never `resourceType` / `Bundle`
  / `entry` / `fullUrl`;
- contains **no** `patient`, `subject`, `encounter`, `practitioner`, `careTeam`,
  `MedicationRequest`, `MedicationAdministration`, `dosageInstruction`, timing,
  prescription, diagnosis, treatment, or recommendation
  (`phi_policy = no_patient_no_subject_no_encounter`);
- implies **no** clinical interoperability and is **not clinically calibrated**
  (`not_clinically_calibrated = true`);
- carries the shared non-prescriptive safety copy
  (`RuleExplanation.defaultSafetyBoundary` / `defaultNotAdvice`).

A recursive **key-level** no-PHI scan (the shared
`test/helpers/no_phi_json_assertions.dart`) enforces the absence of all of those
keys, plus the bundle-specific FHIR-Bundle keys, in
`test/evidence_trace_bundle_test.dart`.

## Fields

- `bundle_type` / `conformance_status` / `phi_policy` — constant markers above.
- `bundle_id` / `created_at` — caller-supplied identifiers (never a real patient
  timeline).
- `nutrition_view` / `medication_knowledge_view` — the two inspired views
  (either may be null; a missing side is recorded as `*_present: false`, not
  faked).
- `mechanistic_trace_summary` — small, **all-optional** summary (severity /
  confidence band, `ranker_used`, `replay_scenario_id`, top source-authority
  score, medication metadata completeness); only populated when already
  available upstream. No dose/timing instruction.
- `source_refs` — union of both views' source refs (sorted, deduped); no new ref
  is minted beyond what the views already carry.
- `provenance_summary` / `missingness_summary` — deterministic summaries drawn
  only from what each view records (missing ≠ fabricated).
- `safety_boundary` / `not_advice_text` / `not_clinically_calibrated`.

## Determinism

`toJson()` is deterministic and JSON-serializable. The builder is pure (no I/O,
no clock); `created_at` is supplied by the caller.

## Boundary summary

Local educational traceability artifact only. Not a FHIR Bundle, not clinical
interoperability, not clinically calibrated, no PHI, no diagnosis/treatment/
medication-timing/dose guidance.
