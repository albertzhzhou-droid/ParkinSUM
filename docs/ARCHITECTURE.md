# Architecture Overview

ParkinSUM Companion is organized as a Flutter prototype with deterministic
rule execution, provenance-aware data ingestion, and Firebase-backed governance
paths.

## App Layers

- Flutter UI for onboarding, timeline, import views, analytics, and privacy
  disclaimer surfaces.
- Domain use cases for CDSS-style rule execution, recommendation replay,
  provenance projection, and meal interaction analysis.
- Data services for local mode and Firebase mode.
- Importer tooling for curated official-source seed generation and audit
  metadata.

## Firebase Governance

- `users/{uid}` records are private to the authenticated owner.
- Shared catalog rows are readable by signed-in users.
- Catalog writes are reserved for admin/importer operator identities.
- Rules are validated by `tool/firestore_rules_contract_check.mjs`.

## Operator Tooling

The repository includes scripts for release manifests, backup evidence,
monitoring checks, audit summaries, Firestore live probes, and public repository
preflight scanning. These scripts are retained as production-architecture
evidence and are not required for public demo users.

## Extension Points

- Backend adapter: local mode, Firebase mode, or future backend provider.
- Rule engine adapter: deterministic local rules or future external rules
  service.
- Evidence provider: curated seed today, future versioned evidence registry.
- Audit sink: local/operator audit today, future centralized logging.
- AI explanation provider: optional copy-polish layer that must not replace the
  deterministic rule/audit core.
