# Source Version Drift Check

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

> **Provenance / release-hygiene drift checking only.** It does **not** fetch or
> update live source data, is **not** legal/license clearance, **not** clinical
> validation, **not** clinical calibration, and **does not** prove medical
> correctness. It only detects metadata/version drift from the local files
> available.

## 1. Purpose

`SourceVersionDriftChecker` (P3) detects stale, missing, inconsistent, or
ambiguous source/version metadata across ParkinSUM's evidence and metadata
layers — the source-access registry, model-assumption registry, bibliography,
source adapters, and generated build artifacts. It is a deterministic
release-hygiene tool that surfaces *provenance drift* before it reaches a
reviewer.

## 2. Safety boundary

The checker adds no medical advice, no diagnosis, no dose/timing/diet guidance,
and no patient-care workflow. It introduces no patient/subject/encounter
semantics and uses no LLM or network. It is deterministic and reports only what
the local files say.

## 3. What "drift" means

Drift is any disagreement or gap between the metadata layers, for example: a
source referenced in code but missing from the registry; a registry record with
no `last_policy_reviewed`; a generated artifact that is missing, undated, or
older than a threshold; or a record claiming production readiness for a source
the registry marks fixture-only.

## 4. What records are checked

| Record type | Source |
| --- | --- |
| `source_access_registry` | `config/source_access_registry.json` |
| `bibliography_entry` | `Bibliographies.md` (`src.*` tokens) |
| `model_assumption` | `lib/domain/usecases/model_assumption_registry.dart` |
| `source_adapter` | `lib/data/datasources/remote/source_adapter_registry.dart` |
| `generated_artifact` | `build/**/latest.json` (all optional) |
| `source_document` / `documentation` | docs (collector/tests) |

The pure checker takes injectable `SourceVersionRecord`s; the CLI collector does
the file/artifact reading.

## 5. Finding categories

`missing_source_id`, `missing_version`, `missing_effective_date`,
`missing_last_checked`, `missing_policy_review_date`,
`generated_artifact_missing`, `generated_artifact_stale`, `bibliography_missing`,
`bibliography_mismatch`, `source_registry_mismatch`, `fixture_status_mismatch`,
`unknown_implementation_status`, `deprecated_source_used`,
`projection_version_missing`, `assumption_registry_unreferenced`,
`documentation_claim_mismatch`.

## 6. Severity model

- **BLOCKER** (fails the gate): a record claims production-ready while the
  registry marks the source fixture-only (`fixture_status_mismatch`); a
  documentation claim of production readiness contradicts the registry
  (`documentation_claim_mismatch`); a missing source id on a registry/source
  document; a deprecated source used in a mechanism role.
- **WARN**: missing dates/versions, stale or undated artifacts, registry or
  bibliography mismatches, unknown implementation status, deprecated source in a
  non-mechanism role.
- **INFO**: uncertain parses recorded rather than fabricated.

`--strict` escalates a selected subset of WARN findings to BLOCKER
(missing policy-review date, unknown status, bibliography/registry mismatch,
stale artifact, unreferenced assumption).

## 7. Generated artifact staleness

A source id counts as bibliography-linked when it appears in `Bibliographies.md`,
is catalogued in the source-access registry, or carries its own
`bibliographyRefs`. Staleness is **only** computed when a reference timestamp is
supplied (`--now=ISO`); by default the CLI is fully deterministic and skips the
time comparison, so the same repo state always produces the same report. When
`--now` is given, an artifact whose `generated_at` is older than
`--staleness-days` (default 180) is flagged WARN.

## 8. Source registry / bibliography consistency

A model assumption or source adapter that references a `src.*` id not present in
the registry (and not otherwise bibliography-linked) is flagged
`bibliography_missing` / `source_registry_mismatch` (WARN). This keeps the
machine-readable registry and the human-readable bibliography aligned.

## 9. Fixture vs production status mismatch

The strongest check: ParkinSUM has **no production-ready sources today** (all are
fixture-tested / spec / documentation only). Any record that claims production
readiness while the registry marks the source fixture-only is a BLOCKER — the
tool refuses to let a fixture-only source be presented as production-ready.

## 10. How to run

```sh
# deterministic (no staleness):
dart run tool/run_source_version_drift_check.dart       # or: npm run source:drift
# with staleness against a fixed reference date:
dart run tool/run_source_version_drift_check.dart --now=2026-06-01 --staleness-days=180
# strict mode:
dart run tool/run_source_version_drift_check.dart --strict
```

Exit code is `0` when there are zero BLOCKER findings, non-zero otherwise.

## 11. How to inspect the report

Reports are written under `build/source_version_drift/`:
`latest.json` (full records + findings + counts) and `latest.md` (a summary
table plus limitations and the safety boundary).

## 12. How to fix findings

- **BLOCKER** — remove the production-ready claim, or record + review the source
  in the registry before claiming it.
- **WARN** — add the missing date/version, regenerate the stale/undated
  artifact, or add the missing registry/bibliography record.

## 13. What it does not prove

It does not prove a source is current, licensed, legally cleared, clinically
valid, or medically correct. A clean report means only that the local metadata
layers are internally consistent and dated.

## 14. Limitations

- Local files only; no network fetch and no source update.
- Conservative documentation-claim checks (no broad NLP); subtle drift may be
  missed.
- Staleness depends on the supplied reference timestamp; default runs skip it.
- Optional build artifacts that are absent are WARN, never fabricated as
  present.

## 15. Reviewer checklist

- [ ] No fixture-only source is described or recorded as production-ready.
- [ ] Registry records carry `last_policy_reviewed`.
- [ ] Generated artifacts carry a deterministic `generated_at`.
- [ ] Model-assumption / adapter source ids resolve to the registry or
      bibliography.
- [ ] No deprecated source is used in a mechanism role.
- [ ] Report JSON is deterministic and emits no patient/subject/encounter keys.
