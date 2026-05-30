# ParkinSUM Companion — Documentation Index

Educational/research prototype. Synthetic/demo data only. Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.

This index groups the documentation by purpose so reviewers can find the right
file quickly. For a guided end-to-end walkthrough start with the demo guide; for
exact commands use the public verification guide.

## Start here

- [Evidence & Traceability Demo Guide](EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md) — end-to-end reviewer walkthrough of the evidence artifacts.
- [Capability Matrix](CAPABILITY_MATRIX.md) — what is implemented, fixture-tested, report-only, or future work.
- [Public Verification Guide](PUBLIC_VERIFICATION.md) — exact commands, expected output, and what each check does (and does not) establish.
- [Public Demo Boundary](PUBLIC_DEMO_BOUNDARY.md) — what the public prototype may and may not be used for.

## Architecture

- [Architecture Overview](ARCHITECTURE.md) — app layering (UI, state, data, rules, evidence).
- [Rule Engine](RULE_ENGINE.md) — medication-context gate + structured rule-explanation template.

## Evidence and traceability

- [Evidence Trace Bundle](EVIDENCE_TRACE_BUNDLE.md) — the local (non-FHIR) artifact pairing the two inspired views.
- [Source-Quality Perturbation Report](SOURCE_QUALITY_PERTURBATION_REPORT.md) — deterministic report of how source quality moves scoring.
- [Replay Runner](REPLAY_RUNNER.md) — the deterministic synthetic replay suite + CLI.

## Algorithm / mechanistic model

- [Conflict Engine Model](CONFLICT_ENGINE_MODEL.md) — the layered, literature-informed educational simulation (not clinically calibrated).

## Source / importer metadata

- [Importer & Metadata Flow](IMPORTER_METADATA_FLOW.md) — canonical metadata, source-authority policy, completeness gate, FDC provenance tier, FHIR-inspired views.

## Safety and release guardrails

- [Public Showcase Readiness](../PUBLIC_SHOWCASE_READINESS.md) — public-repository readiness controls.
- [Known Risks](known_risks.md) — recorded risk register.
- [Release Evidence Index](RELEASE_EVIDENCE_INDEX.md) — release-evidence pointers.

## Roadmap (peripheral support algorithms)

- [Peripheral Algorithm Upgrade Plan](PERIPHERAL_ALGORITHM_UPGRADE_PLAN.md) — prioritized roadmap (P1–P12) for input-quality, source-governance, evidence, testing, privacy, localization, contribution-safety, and release-automation algorithms. Branch base: `peripheral-algorithm-integration`.

## Biomedical standards / roadmap

- [Biomedical Standards Conformance Scorecard](BIOMEDICAL_STANDARDS_CONFORMANCE_SCORECARD.md) — code-grounded posture vs FHIR/LOINC/FDC/FAIR (inspired, never conformant).
- [Biomedical Traceability Matrix](BIOMEDICAL_TRACEABILITY_MATRIX.md) — opportunity → source → implementation → test traceability.
- [Biomedical Engineering Opportunity Map](BIOMEDICAL_ENGINEERING_OPPORTUNITY_MAP.md) / [Backlog](BIOMEDICAL_ENGINEERING_BACKLOG.md) — roadmap.

## Manual validation

- [Manual Validation](MANUAL_VALIDATION.md) — hands-on synthetic-data walkthrough.

## Source access and licenses

- [Source Access & Licenses](SOURCE_ACCESS_AND_LICENSES.md) — per-source access method + license-review status (review remains future work).
- [Bibliographies](../Bibliographies.md) — MLA citations behind the educational model.

> Operator/release runbooks (Firebase operations, production acceptance, IAM
> governance, rollback) live alongside these files in `docs/` but are internal
> validation material, not part of the public showcase surface.
