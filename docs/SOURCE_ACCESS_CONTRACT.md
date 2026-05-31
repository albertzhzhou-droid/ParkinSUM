# Source Access Contract

## Purpose

`SourceAccessContractChecker` is a deterministic source-governance and release-
hygiene tool. It verifies that source IDs used by ParkinSUM have explicit
access, license-review, implementation-status, and evidence-role metadata.

This checker complements `public:preflight`, `privacy:preflight`,
`localization:lint`, `scenario:fuzz`, `evidence:graph`, and `source:quality`.
It does not replace them.

## Safety Boundary

ParkinSUM Companion is an educational/research prototype. This checker is not
legal advice, license clearance, clinical validation, or proof of medical
correctness. It fetches no live data and does not make fixture-tested sources
production-ready.

## Registry

The machine-readable contract lives at
`config/source_access_registry.json`. The human-readable companion remains
[`SOURCE_ACCESS_AND_LICENSES.md`](SOURCE_ACCESS_AND_LICENSES.md).

Each source record declares:

- identity: source ID, owner, jurisdiction, family, and domain
- access: method, API-key requirement, and account requirement
- governance: license-review and legal-review flags
- status: fixture, opt-in live smoke, production allowance, or future work
- capability: mechanism evidence, identity/coding, and source-quality roles
- traceability: limitations, documentation refs, bibliography refs, and review
  date

## Status Model

Fixture validation, optional live smoke, and production use are separate states.
A parser tested against fixtures is not production-ready. A live smoke checks
shape only and does not establish full ingestion, license clearance, or
clinical correctness.

API keys and account credentials must never be committed. Sources requiring
them remain explicitly flagged in the registry. License or legal review flags
remain visible until a separate human review is recorded.

Identity and coding sources such as NHS dm+d cannot be used as mechanism
evidence alone. Synthetic and app-seed sources are never authoritative
mechanism evidence.

## Run

```sh
dart run tool/run_source_access_contract_check.dart
npm run source:access
```

Add `--strict` to escalate unknown access status to a blocker.

The checker writes:

- `build/source_access_contract/latest.json`
- `build/source_access_contract/latest.md`

It exits non-zero when blocker findings exist.

## Fix Findings

- Add missing IDs to the registry or correct invalid `sourceRefs`.
- Keep fixture-only sources disallowed for production.
- Record API-key/account constraints without storing secrets.
- Route terminology sources to identity/coding roles.
- Retain review flags until separate legal or license review is completed.

## Limitations

The collector is conservative and may require human review for ambiguous
references. The checker does not fetch source data, validate licenses, inspect
external terms changes, certify production readiness, or validate clinical
correctness.

## Reviewer Checklist

- Run `npm run source:access`.
- Confirm zero blockers.
- Review warnings for access and license constraints.
- Confirm no source is marked production-ready without an explicit review.
- Confirm terminology and synthetic sources are not used as standalone
  mechanism evidence.
