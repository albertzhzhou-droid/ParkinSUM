# Source Access & Licensing

Machine-readable companion and deterministic checker:
[`SOURCE_ACCESS_CONTRACT.md`](SOURCE_ACCESS_CONTRACT.md) and
`config/source_access_registry.json`.

Educational prototype documentation. ParkinSUM is **not** a clinical product
and does **not** perform production ingestion of any external source. Offline
import adapters are **fixture-validated** (deterministic parsers over
synthetic payloads modeled on public schema shapes). An optional, **opt-in**
live smoke harness exists for metadata-shape validation only (see below); it is
disabled by default, never runs in normal tests, and never stores its raw
response. One separate research view can perform a bounded, explicitly
confirmed openFDA label-text lookup, and an independently consented RxNav
action can show active RxNorm lexical name candidates for two manually entered
generic names. After that candidate list appears, a second consent and a
candidate-specific action can request current RxNorm concept properties for
one selected RxCUI; the follow-up sends the selected identifier rather than
the original search term. A third separate consent and candidate-specific
action can request historical status for one recent RxCUI. Any replacement
RxCUIs stay unselected candidates and are never followed automatically. A
separate user choice can select one exact display
name from each candidate list and, after another consent, search FDA labels
with only those two display strings. That flow has its own egress purpose and
data class; FDA receives neither RxCUIs nor the original typed names. These
actions do not read saved medication data, write or retain results beyond the
screen, or generate a clinical interaction conclusion or confirmed medication
identity.

**Source-specific legal / license / terms-of-use review remains future work
and is required before any production use of any source below.**

## Implementation status legend

- `fixture_tested` — deterministic parser validated against a synthetic
  fixture; no live ingestion.
- `opt_in_live_smoke` — reachable by the opt-in smoke harness for shape checks
  only.
- `implemented_user_initiated_live_lookup` — a bounded public API lookup that
  requires in-app consent for the manually entered query and keeps results in
  memory only; not production ingestion or clinical evidence.
- `production_parser` — real-schema, license-reviewed production ingestion
  (**none today**).
- `spec_only` — registry metadata only, no concrete parser.

## Medication sources

| Source | Owner | Jurisdiction | Access method | Key/account/license review | Status | Data type | Mechanism evidence alone? | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DailyMed | U.S. NLM | US | SPL download / web service | No key; public domain (review terms) | `fixture_tested` + `opt_in_live_smoke` | Official SPL label | Yes (label text) | Live smoke hits a metadata listing endpoint only. |
| openFDA Drug Label API | U.S. FDA | US | `drug/label.json`, explicit user action | No key for low-volume use; terms/license review open | `implemented_user_initiated_live_lookup` | Up to five harmonized label rows per manually entered generic name | **No** for patient-specific interaction conclusions | Two names are sent to the public API in separate requests; only returned interaction-section text is searched locally. Missing matches are not evidence of safety. No saved medication context is read or retained. A valid Set ID and label version can be copied as a DailyMed exact-version URL; copying makes no request, and DailyMed opens only through a separate user action. |
| Health Canada DPD | Health Canada | CA | DPD API / monograph | Open data terms review | `fixture_tested` | Official DB + monograph | Partial (monograph) | Food-effect text often in monograph PDFs. |
| EMA / ePI | European Medicines Agency | EU | EPAR / ePI (FHIR) download | Reuse-terms review | `fixture_tested` | EPAR / SmPC / ePI | Yes (SmPC text) | Centralized products. |
| EU national registers | National competent authorities (EMA index) | EU/EEA member states | Web page / register index | Per-member-state terms review | `fixture_tested` | Register identity + PI link | **No** unless SmPC/ePI text present | Identity/register source; distinguish from full SmPC. |
| NHS dm+d | NHSBSA / NHS England | GB | TRUD XML download / NHS Terminology Server (FHIR API) | dm+d licence + SNOMED CT licensing review | `fixture_tested` | Drug dictionary (SNOMED CT) | **No** | Identity/coding-strong; not a complete food-effect label source. |
| PMDA | PMDA | JP | Web page (package insert / review report) | PMDA terms review | `fixture_tested` | Package insert | Yes (Japanese authoritative) | English index is reference-only. |
| NMPA | National Medical Products Administration | CN | Web page (approval / label) | NMPA terms review | `fixture_tested` (**NOT live-verified**) | Drug approval / label | Reference-only | Chinese-language authoritative; English mapping reference-only; fixture/prototype only. |
| RxNorm | U.S. NLM | US | RxNav `/REST/approximateTerm.json`, manually selected `/REST/rxcui/{rxcui}/properties.json`, and separately selected `/REST/rxcui/{rxcui}/historystatus.json` | No API key for RxNorm API; NLM attribution requested; API terms reviewed | `implemented_user_initiated_live_lookup` | Named active RXNORM lexical candidates, current concept properties, and historical concept status with replacement candidates | No | Source id `src.rxnorm.rxnav.api`. Two manually entered terms are sent only after separate consent. `option=1` requests active concepts; only named `source=RXNORM` rows are shown. Separate candidate-specific consents send one recent RxCUI to the current-properties or history endpoint. Remapped RxCUIs remain unselected candidates and are not followed. Rank is lexical ordering, not confidence; restricted-source names, API score, saved medication data, caching, and persistence are excluded. |

## Food composition sources

| Source | Owner | Jurisdiction | Access method | Key/account/license review | Status | Data type | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| USDA FoodData Central | USDA ARS | US | REST API | **API key required** for live | `fixture_tested` + `opt_in_live_smoke` (skips without key) | Food composition incl. amino acids | Amino-acid nutrient numbers extracted when present, using the verified FDC mapping (501 Trp, 502 Thr, 503 Ile, 504 Leu, 506 Met, 508 Phe, 509 Tyr, 510 Val, 512 His). |
| Ciqual | ANSES | FR | Download | Reuse-terms review | `fixture_tested` | Food composition | French-language codes. |
| China CDC food platform | China CDC | CN | Web page | Terms review | `fixture_tested` | Food composition | No amino-acid fields captured today. |
| FAO/INFOODS (standard) | FAO | Global | Download | Open-access guidelines | `spec_only` | Component identifiers (tagnames) + matching/conversion guidelines | The official tagname page reports a 2022-10-20 update, published additions through 2010, and a consolidated Excel list still coming soon. A content-addressed page-status pin is metadata only; there is no complete current vocabulary, parser, or tag mapping. |
| Canadian Nutrient File | Health Canada | CA | Download | Open-data terms review | `spec_only` | Food composition | Citation/fixture candidate; not yet wired. |
| app seed / synthetic demo | ParkinSUM | — | manual | n/a | `fixture_tested` | Seed/synthetic | Never authoritative. |

## API / license review checklist (required before any production ingestion)

FAIR-aligned (Wilkinson et al. 2016) governance gate. **No source may move from
`fixture_tested` / `spec_only` to `production_parser` until every box is
checked and recorded here.** This is documentation only; it does not enable any
live ingestion.

- [ ] License / terms-of-use reviewed and recorded (owner, license, attribution
      requirements, redistribution limits).
- [ ] Access method confirmed (public domain / public API / API key /
      account / download) — secrets are **never** committed.
- [ ] Rate limits + caching policy documented; no bulk scraping.
- [ ] Provenance fields captured (source id, version, effective/publication
      date, retrieval date) — FAIR Findable/Reusable.
- [ ] Identifiers + schema mapped to internal metadata (FAIR Interoperable);
      missing fields preserved as missing (never 0).
- [ ] No PHI / patient data / credentials in fixtures or payloads.
- [ ] Mechanism evidence vs identity/coding role recorded (a coding source is
      not a food-effect source).
- [ ] Opt-in flag + skip-without-network behavior verified (see live smoke).
- [ ] Safety note recorded (educational; non-prescriptive; not calibrated).

See `docs/BIOMEDICAL_ENGINEERING_OPPORTUNITY_MAP.md` and
`docs/BIOMEDICAL_ENGINEERING_BACKLOG.md` for the surveyed future sources and the
issue-ready tasks that would exercise this checklist.

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

The optional RxNav candidate screen is limited to two user-entered terms per
action, spaces requests by at least one second within the screen instance, and
bounds each response to 256 KiB. A separate consent and candidate-specific
button are required before the exact numeric RxCUI is sent to the no-query
properties endpoint; those responses are limited to 16 KiB and current page
memory. A third candidate-specific action has separate consent, sends one
recent RxCUI to the exact no-query history/status endpoint, and limits that
response to 64 KiB; remapped RxCUIs are never followed or selected. NLM's
history API reports monthly status metadata, and its 2023 status definitions
describe `NotCurrent` as covering more than one condition; the UI preserves
the source statuses without turning them into medication-presence or
substitution conclusions ([history/status API](https://lhncbc.nlm.nih.gov/RxNav/APIs/api-RxNorm.getRxcuiHistoryStatus.html),
[status changes](https://lhncbc.nlm.nih.gov/RxNav/news/HistoryStatus-Changes-202303.html)).
NLM's API terms permit RxNorm API use without
a license, request an attribution statement in applications, limit traffic to
20 requests per second per IP address, and recommend 12–24 hour caching. This
screen displays NLM attribution but intentionally does not cache drug-name
queries or results; the local delay does not enforce a shared-IP limit across
devices. See the official [RxNorm approximate-match API documentation](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/APIs/api-RxNorm.getApproximateMatch.html)
and [RxNav Terms of Service](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/TermsofService.html).

## Public-demo allowance column

Each registry record now carries `allowed_for_public_demo` (default `false`).
It must be set to `true` — after a license/terms review — before a source may be
cited in public-demo material (walkthroughs, public docs). The contract checker
(`npm run source:access`) warns on `public_demo_not_allowed` when a source is
cited in public-demo paths without the flag, and blocks on
`missing_required_fields` when a record omits the core matrix fields
(`source_id`, `display_name`, `owner`, `jurisdiction`, `access_method`,
`implementation_status`). This is governance bookkeeping, not legal advice or
license clearance.
