# Release Evidence Index

This index points to evidence generated while preparing ParkinSUM as a
production-architecture prototype. These records demonstrate governance
discipline; they do not claim real-world clinical, legal, privacy, regulatory,
or professional approval.

## Public Showcase Evidence

- Public boundary: `PUBLIC_SHOWCASE_READINESS.md`
- Disclaimer: `DISCLAIMER.md`
- Security policy: `SECURITY.md`
- Contribution policy: `CONTRIBUTING.md`
- Public preflight report: `build/public_release_preflight/latest.md`

## Evidence & Traceability (synthetic; not clinical validation)

- Documentation index: `docs/README.md`
- Demo guide: `docs/EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md`
- Capability matrix: `docs/CAPABILITY_MATRIX.md`
- Public verification guide: `docs/PUBLIC_VERIFICATION.md`
- Mechanistic replay: `docs/REPLAY_RUNNER.md`, `build/mechanistic_replay/latest.md`
- Non-numerical executable contracts: `docs/ALGORITHM_EXECUTABLE_CONTRACT_AND_METAMORPHIC_GATE_RESEARCH_2026-08-31.md`, `build/algorithm_executable_contract/latest.json`
- Independent cross-runtime relation oracle: `config/algorithm_contract_relation_registry.json`, `tool/independent_algorithm_contract_oracle.mjs`, `build/algorithm_contract_independent_oracle/latest.json`
- Relation-domain production sampling and schema-v2 calibration decision: `config/algorithm_relation_domain_sampling_plan.json`, `tool/run_algorithm_relation_production_sampling.dart`, `tool/algorithm_relation_domain_sampling.mjs`, `docs/ALGORITHM_RELATION_DOMAIN_SAMPLING_RESEARCH_2026-08-31.md`, `docs/ALGORITHM_RELATION_EVIDENCE_SCHEMA_EVOLUTION_AND_CALIBRATION_DECISION_CONTRACT_RESEARCH_2026-09-02.md`, `build/algorithm_relation_production_sampling/latest.json`, `build/algorithm_relation_domain_sampling/latest.json`
- Mechanistic input-ledger authorization: `docs/MECHANISTIC_LEDGER_AUTHORIZATION_AND_LOSSLESS_REPLAY_RESEARCH_2026-08-31.md`, `lib/domain/usecases/mechanistic_event_ledger_authorization.dart`, `tool/run_mechanistic_ledger_authorization_check.dart`, `build/mechanistic_ledger_authorization/latest.json`
- Lossless mechanistic replay capsule: `docs/MECHANISTIC_LOSSLESS_REPLAY_CAPSULE_AND_CROSS_RUNTIME_CONFORMANCE_RESEARCH_2026-08-31.md`, `lib/domain/entities/mechanistic_replay_capsule.dart`, `tool/run_mechanistic_replay_capsule_check.dart`, `tool/mechanistic_replay_capsule_conformance.mjs`, `build/mechanistic_replay_capsule/dart_vectors.json`, `build/mechanistic_replay_capsule/node_conformance.json`
- Portable-schema migration registry: `docs/PORTABLE_SCHEMA_MIGRATION_REGISTRY_AND_CROSS_RUNTIME_CONFORMANCE_RESEARCH_2026-08-31.md`, `lib/domain/entities/portable_schema_migration.dart`, `lib/domain/usecases/portable_schema_migration_registry.dart`, `tool/run_portable_schema_migration_check.dart`, `tool/portable_schema_migration_conformance.mjs`, `build/portable_schema_migration/dart_vectors.json`, `build/portable_schema_migration/node_conformance.json`
- Portable-schema differential campaign: `docs/PORTABLE_SCHEMA_DIFFERENTIAL_FUZZ_AND_CORPUS_PROMOTION_RESEARCH_2026-08-31.md`, `config/portable_schema_fuzz_plan.json`, `test/fixtures/portable_schema_regression_corpus.json`, `tool/run_portable_schema_differential_fuzz_check.dart`, `tool/portable_schema_differential_fuzz.mjs`, `build/portable_schema_fuzz/dart_campaign.json`, `build/portable_schema_fuzz/node_conformance.json`
- Transitive result-dependency bounded Analyzer preview (root identity, exact Analyzer compatibility, schema-v14 source edges, Analyzer-validated declared-part ownership, recursive local namespace candidates, per-root reachability, SCC preview, and reverse declaration/source ownership; complete closure still research-required): `config/algorithm_result_root_manifest.json`, `lib/domain/entities/algorithm_result_root_manifest.dart`, `lib/domain/entities/algorithm_dependency_compatibility.dart`, `tool/algorithm_dependency_compatibility_spike.dart`, `tool/run_algorithm_dependency_compatibility_spike.dart`, `tool/algorithm_direct_edge_probe.dart`, `tool/run_algorithm_direct_edge_probe.dart`, `test/algorithm_direct_edge_probe_test.dart`, `build/algorithm_dependency_compatibility/latest.json`, ignored `build/algorithm_direct_edge_probe/latest.json`, `docs/ALGORITHM_TRANSITIVE_RESULT_DEPENDENCY_CLOSURE_RESEARCH_2026-09-02.md`, queue item `algorithm_transitive_result_dependency_closure`
- Source-quality perturbation report: `docs/SOURCE_QUALITY_PERTURBATION_REPORT.md`, `build/source_quality_perturbation/latest.md`
- Evidence trace bundle: `docs/EVIDENCE_TRACE_BUNDLE.md`
- Standards posture: `docs/BIOMEDICAL_STANDARDS_CONFORMANCE_SCORECARD.md`

## Architecture Evidence

- Architecture overview: `docs/ARCHITECTURE.md`
- Public demo boundary: `docs/PUBLIC_DEMO_BOUNDARY.md`
- Environment and deployment guide: `docs/environment_deployment.md`
- Firebase operations runbook: `docs/firebase_operations_runbook.md`
- Rollback runbook: `docs/rollback_runbook.md`

## Local ignored development evidence

- Android reminder attestations are written below
  `build/android_reminder_attestation/` and ignored; no run ID or digest is
  pinned in tracked documentation. The current outer-v4/inner-v4 contract
  additionally binds the
  `parkinsum.android-reminder-execution-isolation/2` cooperative leases for
  build output and the selected device/application, heartbeat and process-start
  provider, nine ordered ownership checkpoints, child-process drain, and device
  cleanup while still owned. The exact private lease-evidence digest is part of
  the nested contract. Coordinator fault injection proves that release failure
  or a signal during drain/release prevents the finalizer and `latest.json`
  promotion. This is in-process ordering, not multi-file crash durability; a
  final-name artifact without a validated completion pointer is incomplete. See
  `docs/ANDROID_ATTESTATION_EXECUTION_ISOLATION_RESEARCH.md`.
- One current ignored development outer-v4/inner-v4 artifact with nested
  execution-isolation-v2 passed on a dedicated API 36 arm64 emulator. It bound
  all nine checkpoints and the exact private lease-evidence digest, promoted
  only after cleanup and successful release, proved the isolated application
  absent before and removed afterward, and observed a seven-to-zero plugin
  registry round trip without requesting permission or accessing user storage.
  Historical outer-v3/nested-v1 artifacts are rejected by current validators.
- A successful ignored local development attestation can bind a dirty source snapshot, isolated
  application ID, compiled APK manifest, debuggable integration-test APK,
  byte-identical installed `base.apk`, and observed Android Debug signature
  integrity on an emulator. The debug certificate remains
  `observedUnreviewed`; the artifact is not committed/public and is explicitly
  not release-eligible. The current run explicitly records no visible-delivery
  verification and no release eligibility. Cooperative runner isolation does not cover an
  independent Flutter build or detached Gradle daemon and does not verify
  reproducible provenance, visible delivery, a physical device, production
  signing, or a production entrypoint.

## Internal Operator Evidence

- Known risks: `docs/known_risks.md`
- Internal prerelease index: `docs/internal_prerelease_release_index_20260523.md`
- Firebase production acceptance report:
  `docs/firebase_production_acceptance_report.md`
- P0/P1 productionization reports:
  `docs/p0_completion_report_20260522.md`,
  `docs/p1_productionization_report.md`

Internal evidence may reference private operator workflows. It must not be
interpreted as permission to use the public prototype with real health data.
