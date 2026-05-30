# Capability Matrix

Educational/research prototype. Synthetic/demo data only. Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.

This matrix summarizes what ParkinSUM Companion's evidence/traceability layer
actually implements, how it is exercised, and where its boundaries are. Status
values:

- **implemented** — runtime code, exercised by unit tests.
- **fixture-tested** — implemented and validated against synthetic fixtures only
  (no live ingestion).
- **deterministic-report** — a deterministic CLI/report artifact for review.
- **documentation-only** — described in docs; not a code capability.
- **future-work** — not implemented; recorded for transparency.

| Capability | Status | Files / docs | Test coverage | Safety boundary | Limitations |
| --- | --- | --- | --- | --- | --- |
| Mechanistic replay runner | deterministic-report + fixture-tested | `lib/domain/usecases/mechanistic_replay_runner.dart`, `tool/run_mechanistic_replay.dart`, `docs/REPLAY_RUNNER.md` | `test/mechanistic_replay_runner_test.dart` (41 scenarios) | Deterministic synthetic regression; exits non-zero on banned-phrase hit | Not clinical validation; synthetic scenarios only |
| Release snapshot generator (P12) | deterministic-report | `lib/domain/usecases/release_snapshot_generator.dart`, `tool/run_release_snapshot.dart` (`npm run release:snapshot`) | `test/release_snapshot_generator_test.dart` | Composes existing artifacts; missing input → `missing_artifact`, never fabricated | Not clinical validation; counts injected/parsed, no slow commands in tests |
| Public demo walkthrough generator (P10) | deterministic-report | `lib/domain/usecases/public_demo_walkthrough_generator.dart`, `tool/generate_public_demo_walkthrough.dart` (`npm run demo:walkthrough`) | `test/public_demo_walkthrough_generator_test.dart` | Synthetic walkthrough; no advice; no PHI/patient/subject/encounter; missing → `missing_artifact` | Composes existing artifacts only; not clinical validation |
| Source-quality perturbation report | deterministic-report | `lib/domain/usecases/source_quality_perturbation_report.dart`, `tool/run_source_quality_perturbation_report.dart`, `docs/SOURCE_QUALITY_PERTURBATION_REPORT.md` | `test/source_quality_perturbation_report_test.dart` | Shows how scoring moves with source quality only; conflict overlap stays dominant | Not a clinical dashboard; no user-facing advice |
| EvidenceTraceBundle (local) | implemented | `lib/domain/entities/evidence_trace_bundle.dart`, `lib/domain/usecases/evidence_trace_bundle_builder.dart`, `docs/EVIDENCE_TRACE_BUNDLE.md` | `test/evidence_trace_bundle_test.dart` | Local artifact; **not** a FHIR Bundle; no patient/subject/encounter | Synthetic fixtures; pairs two views for review |
| FHIR-inspired NutritionIntake view | implemented | `lib/domain/entities/fhir_inspired_nutrition_intake_view.dart`, mapper | `test/fhir_inspired_nutrition_intake_view_test.dart` | `inspired_not_conformant`; PHI-free key-level scan | Not FHIR conformant; no clinical interoperability |
| FHIR-inspired MedicationKnowledge view | implemented | `lib/domain/entities/fhir_inspired_medication_knowledge_view.dart`, mapper | `test/fhir_inspired_medication_knowledge_view_test.dart` | `inspired_not_conformant`; product strength is product metadata, not an intake dose | Not FHIR conformant; no coded RxCUI/ATC |
| LOINC section-code trace | implemented | `lib/domain/entities/label_section_code.dart`, `lib/domain/usecases/label_section_code_mapper.dart` | `test/label_section_code_mapper_test.dart` | Conservative map of known FDA SPL headings; unknown stays unknown | Partial map; missing LOINC ≠ invalid provenance |
| FDC nutrient provenance tier | implemented | `lib/domain/entities/nutrient_derivation.dart`, `source_metadata.dart`, `metadata_completeness_gate.dart` | `test/fdc_provenance_metadata_completeness_test.dart` | Source-quality signal, **not** clinical/biological accuracy | Missing derivation → null tier (never raises confidence) |
| Metadata completeness gate | implemented | `lib/domain/usecases/metadata_completeness_gate.dart` | `test/multi_jurisdiction_metadata_test.dart`, FDC tests | Grades completeness; widens uncertainty, never fakes precision | Educational grading only |
| Source authority scoring | implemented | `lib/domain/usecases/source_authority_scorer.dart` | `test/candidate_metadata_authority_test.dart`, multi-jurisdiction tests | Official-in-jurisdiction outranks synthetic/seed; seed never overrides official | Deterministic heuristic; not a trust certification |
| Multi-dose medication trace | implemented | `lib/domain/usecases/mechanistic_conflict_engine.dart` (per-event traces) | replay multi-dose scenarios, engine tests | Per-dose modeled overlap; deterministic max-overlap aggregate | Educational simulation; no PK/PD prediction |
| Missing nutrients ≠ true zero | implemented | `meal_composition_normalizer.dart`, `cdss_catalog_projection_service.dart` | `test/missing_not_zero_test.dart` | Missing recorded as missing; lowers completeness/widens uncertainty | A real measured 0 is preserved as a true zero |
| Dose passthrough / no hidden dosage | implemented | `lib/domain/usecases/medication_entry_validator.dart` | `test/medication_entry_validator_test.dart` | Intake dose comes only from the user's explicit value+unit; no default | Ambiguous/unitless dose → insufficient context |
| Live source smoke | fixture-tested (opt-in) | `tool/run_live_source_smoke.dart`, `npm run live:smoke` | excluded from normal test runs | Opt-in; fetches official metadata only; not used for advice | Not production ingestion; network-dependent when run |
| Source access / license docs | documentation-only | `docs/SOURCE_ACCESS_AND_LICENSES.md`, `Bibliographies.md` | n/a | Records access + license-review status | Source-specific legal/license review remains future work |
| Firestore rules contract | implemented | `tool/firestore_rules_contract_check.mjs`, `npm run rules:contract` | 13 contract checks | Enforces owner-scoped, deny-by-default rules | Static contract check, not a live pen-test |
| Public preflight | implemented | `tool/public_repo_preflight.mjs`, `npm run public:preflight` | BLOCKER/WARN/INFO findings | Gates public positioning + banned-phrase claims | Heuristic doc/scan gate, not a security audit |

## Cross-cutting boundaries

All capabilities are **educational and non-prescriptive**, use **synthetic/demo
data only**, emit **no PHI / patient / subject / encounter** fields, and make
**no FHIR conformance** or clinical-validation claim. The model is **not
clinically calibrated**. Source-quality and provenance signals affect modeled
confidence and tie-breaking only — never medical advice — and never override
conflict-overlap dominance, source-authority, or jurisdiction policy.
