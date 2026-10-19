# Architecture

> See [[Conflict-Engine]] for the layer pipeline and [[Food-Data]] for data provenance.

ParkinSUM Companion separates the user interface, local state, seeded data, deterministic rules, and evidence-oriented output so reviewers can inspect behavior without treating the app as a clinical product.

## Layer Map

| Layer | Role | Review entry point |
| --- | --- | --- |
| Flutter UI | Dashboard, next meal, timeline, medication, and catalog/search flows. | `lib/features/` |
| App state | Coordinates catalog data, meals, intakes, recommendations, and copy. | `lib/core/state/app_state.dart` |
| Local-first data | Stores public-demo state locally; Firebase paths are retained for internal operator validation. | `lib/core/db/`, `lib/core/services/` |
| Catalog and metadata | Food and medication records with jurisdiction/source metadata. | `lib/core/analysis/`, `lib/domain/entities/` |
| Deterministic rule engine | Evaluates educational interaction rules and mechanistic replay assumptions. | `lib/domain/usecases/` |
| Conflict engine | Layered mechanistic trace: composition, gastric emptying, absorption window, LNAA competition, interdependency. | `lib/domain/usecases/mechanistic_conflict_engine.dart` |
| Reference food data | Official FDC 2025-04-24 rows, generated tables, identity audit. | `lib/core/constants/`, `tool/data/fdc_2025-04-24/` |
| Governance | Configuration identity, context-of-use ledger, attestations. | `lib/algorithm_sdk/`, `lib/domain/entities/` |
| Evidence explanation | Produces traceable copy with limitations, provenance, and not-advice language. | `docs/EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md` |

## Review Flow

```text
Flutter UI
  -> AppState
  -> local data and catalog repositories
  -> deterministic rule / mechanistic scorer
  -> evidence-linked explanation copy
  -> educational awareness output
```

## Important Design Choices

- The app does not put an LLM inside the interaction engine.
- Missing nutrient/source fields are preserved as missing, not silently converted into fake certainty.
- Medication context must be explicit enough before dose-dependent interpretation is attempted.
- Evidence artifacts are deterministic synthetic-data demonstrations, not clinical validation.

## Useful Links

- Rule engine overview: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/RULE_ENGINE.md
- Conflict engine model: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/CONFLICT_ENGINE_MODEL.md
- Importer metadata flow: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/IMPORTER_METADATA_FLOW.md
- Evidence trace bundle: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/EVIDENCE_TRACE_BUNDLE.md

