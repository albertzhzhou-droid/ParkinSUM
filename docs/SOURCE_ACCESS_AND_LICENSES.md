# Source Access & Licensing

Educational prototype documentation. ParkinSUM is **not** a clinical product
and does **not** perform production ingestion of any external source. All
adapters listed here are **fixture-validated** (deterministic parsers over
synthetic payloads modeled on public schema shapes). An optional, **opt-in**
live smoke harness exists for shape validation only (see below); it is
disabled by default, never runs in normal tests, fetches official **metadata
only** (never clinical advice), and never stores raw payloads.

**Source-specific legal / license / terms-of-use review remains future work
and is required before any production use of any source below.**

## Implementation status legend

- `fixture_tested` — deterministic parser validated against a synthetic
  fixture; no live ingestion.
- `opt_in_live_smoke` — reachable by the opt-in smoke harness for shape checks
  only.
- `production_parser` — real-schema, license-reviewed production ingestion
  (**none today**).
- `spec_only` — registry metadata only, no concrete parser.

## Medication sources

| Source | Owner | Jurisdiction | Access method | Key/account/license review | Status | Data type | Mechanism evidence alone? | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DailyMed | U.S. NLM | US | SPL download / web service | No key; public domain (review terms) | `fixture_tested` + `opt_in_live_smoke` | Official SPL label | Yes (label text) | Live smoke hits a metadata listing endpoint only. |
| Health Canada DPD | Health Canada | CA | DPD API / monograph | Open data terms review | `fixture_tested` | Official DB + monograph | Partial (monograph) | Food-effect text often in monograph PDFs. |
| EMA / ePI | European Medicines Agency | EU | EPAR / ePI (FHIR) download | Reuse-terms review | `fixture_tested` | EPAR / SmPC / ePI | Yes (SmPC text) | Centralized products. |
| EU national registers | National competent authorities (EMA index) | EU/EEA member states | Web page / register index | Per-member-state terms review | `fixture_tested` | Register identity + PI link | **No** unless SmPC/ePI text present | Identity/register source; distinguish from full SmPC. |
| NHS dm+d | NHSBSA / NHS England | GB | TRUD XML download / NHS Terminology Server (FHIR API) | dm+d licence + SNOMED CT licensing review | `fixture_tested` | Drug dictionary (SNOMED CT) | **No** | Identity/coding-strong; not a complete food-effect label source. |
| PMDA | PMDA | JP | Web page (package insert / review report) | PMDA terms review | `fixture_tested` | Package insert | Yes (Japanese authoritative) | English index is reference-only. |
| NMPA | National Medical Products Administration | CN | Web page (approval / label) | NMPA terms review | `fixture_tested` (**NOT live-verified**) | Drug approval / label | Reference-only | Chinese-language authoritative; English mapping reference-only; fixture/prototype only. |
| RxNorm | U.S. NLM | US | API | Review terms | `spec_only` | Concept normalization | No | Identity normalization only. |

## Food composition sources

| Source | Owner | Jurisdiction | Access method | Key/account/license review | Status | Data type | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| USDA FoodData Central | USDA ARS | US | REST API | **API key required** for live | `fixture_tested` + `opt_in_live_smoke` (skips without key) | Food composition incl. amino acids | Amino-acid nutrient numbers (e.g. 507 leucine) extracted when present. |
| Ciqual | ANSES | FR | Download | Reuse-terms review | `fixture_tested` | Food composition | French-language codes. |
| China CDC food platform | China CDC | CN | Web page | Terms review | `fixture_tested` | Food composition | No amino-acid fields captured today. |
| app seed / synthetic demo | ParkinSUM | — | manual | n/a | `fixture_tested` | Seed/synthetic | Never authoritative. |

## Optional live smoke harness

```sh
# Disabled by default — safely skips, no network:
dart run tool/run_live_source_smoke.dart            # or: npm run live:smoke
# Opt-in (NOT run in CI / normal tests):
PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE=1 dart run tool/run_live_source_smoke.dart --source=dailymed
```

- Validates fetch **shape** + parser ability on a small public **metadata**
  query. It does **not** validate production ingestion, real-schema
  completeness, licensing compliance, or clinical accuracy.
- `--source=fdc` requires an API key; without one the smoke reports
  `requires_api_key_not_supplied` and exits without embedding any secret.
- Raw payloads are never written to the repo; only a redacted shape summary is
  printed.

## Reminder

Nothing here is medical advice, a diagnosis, a dosing/timing recommendation,
or a claim of clinical validation. The mechanistic model is **not clinically
calibrated** (see `docs/CONFLICT_ENGINE_MODEL.md`).
