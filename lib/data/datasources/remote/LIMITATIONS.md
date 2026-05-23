# Importer limitations (importer-local notes)

This file documents the conservative boundaries of each official-source
importer in `lib/data/datasources/remote/`. It is intentionally scoped to the
importer surface and does not describe product-level governance, release
readiness, or downstream CDSS behavior.

Every limitation listed here is also asserted by tests in
`test/p0_importers_test.dart` and surfaced at runtime via either:

- `mapping_payload_json.parser_limitation` on the affected
  `ConceptVariantCrosswalkRecord`, or
- `source_document.raw_payload.audit_gaps[]` entries with `field`,
  `reason`, and `observed_count`.

## DailyMed
- `package_description` (free-text NDC packaging text) is **not** parsed into
  size / count / unit fields. It is retained verbatim on `DrugProductCodeRecord`
  and surfaced as an `audit_gap` in `source_document.raw_payload`.
- SPL section bodies are stored verbatim on `DrugLabelSectionRecord`. Only
  known fact patterns (food effect, iron, tyramine, thickener, enteral feeding,
  meal-window, high-fat delay, with-or-without-food) are structured. All other
  section text remains free text.

## Health Canada DPD
- The `info?code=...` HTML page is parsed conservatively: heading-delimited
  text only. No monograph-body schema parsing.
- Linked resources are tagged by URL suffix (`.pdf` vs other). Bodies are not
  fetched or parsed.

## EMA
- `condition_indication`, `procedure_type`, and the full upstream row JSON are
  preserved in `source_document.raw_payload` only. They are **not** normalized
  into structured indication / regulatory-action facts.
- EPAR / SmPC / leaflet URLs are exposed as crosswalks, not as parsed bodies.

## PMDA
- English-translated package-insert URLs are emitted as `reference_only`
  crosswalks. They do not become structured drug variants.
- Japanese product detail emits authoritative crosswalks (product code, detail
  URL, per-document URL).
- `route` and `dosage_form` are held as the literal value `"unspecified"` when
  the upstream landing page does not expose machine-readable values. The
  importer does **not** OCR linked PDFs to recover these fields.

## FDC
- `foodPortions` are kept inside `source_document.raw_payload.food_portions_audit`
  with `source_object_count`, `unparsed_count`, `observed_field_names`, and a
  reason. They are **not** promoted into a structured portion table.
- `dataType` (Foundation / SR Legacy / Survey / Branded) is exposed as a
  crosswalk row with an explicit audit note that it is metadata, not a per-food
  identifier.

## Ciqual
- `sources.xml` is summarized into `provenance_summary` (with `source_count`,
  `first_source_ids`, `first_source_titles`, `entries`) inside
  `source_document.raw_payload`. The importer does **not** decompose
  methodology into a separate table.

## China CDC food query platform
- The page identifier is derived from the official `/foodinfo/{id}.html` URL
  path. It is explicitly tagged as `page_identifier` in
  `mapping_payload_json.source_identifier_type` and is **not** a national food
  code.

## FAO FBDG
- Only country-level crosswalks are emitted. `region_or_city_identifier` is
  always recorded as `null` with an explicit audit note. The importer refuses
  to fabricate subnational identifiers.

## Secondary source tier registry (P1 / P2 / P3)

In addition to the eight parsed sources above (which sit at P0/P1 with full
parsing), the importer surface registers a small set of *secondary* sources
declared in `secondary_source_registry.dart` and integrated via
`P0IngestionOrchestrator.importSecondarySourceCatalog()`. These are
**registry entries only** — the importer records the landing URL, organization,
license, and a tier rationale, but does **not** fetch or parse upstream body
content.

| Source | Tier | Why this tier |
|---|---|---|
| WHO ATC/DDD index | P1 | Authoritative drug classification used to cross-walk DailyMed / EMA / PMDA / DPD. |
| NICE NG71 (Parkinson's in adults) | P1 | UK clinical guideline; landing-page reference only, body never parsed. |
| MedlinePlus drug information | P1 | Consumer cross-reference target; SPL still authoritative. |
| Open Food Facts | P2 | Community-curated branded-product catalog; supportive only. |
| USDA Dietary Guidelines for Americans | P2 | US nutrition reference; landing page only. |
| AUSNUT 2011-13 | P3 | Regional Australia/New Zealand legacy composition table. |
| Japan MEXT Food Composition | P3 | Regional JP composition table; PMDA remains authoritative for drugs. |
| Korea MFDS | P1 | Korean drug + food regulator landing. |
| Korea RDA-NIAS food composition | P2 | Authoritative Korean food composition portal. |
| India CDSCO | P1 | Indian drug regulator landing. |
| India NIN-ICMR / IFCT | P2 | Indian food composition reference. |
| Spain AEMPS | P1 | Spanish drug regulator (EMA still authoritative for centralised products). |
| Spain BEDCA | P2 | Spanish food composition database (Mediterranean diet pattern). |
| Mexico COFEPRIS | P1 | Mexican drug + food regulator landing. |
| Latin America INCAP | P2 | Central America + Panama regional food composition. |
| ASEAN Food Composition Database | P2 | Southeast Asia regional food composition. |
| Thai FDA | P1 | Representative SEA national drug regulator. |
| Russia Roszdravnadzor | P1 | Russian drug regulator landing. |
| Russia FRC Nutrition | P2 | Russian food composition (Skurikhin tradition). |
| Poland NIZP-PZH | P2 | Eastern European Polish food + nutrition reference. |
| Saudi SFDA | P1 | Saudi/Gulf MENA drug + food regulator landing. |
| Egypt NRC food composition | P2 | North African Egyptian food composition reference. |

Boundary guarantees:

- Each entry produces exactly one `SourceDocumentRecord` with
  `data_tier` set to `KnowledgeDataTier.p1` / `p2` / `p3` and
  `ingestion_strategy = SourceIngestionStrategy.officialReference`.
- `raw_payload` always carries `tier`, `tier_rationale`, `landing_url`,
  a `parser_limitation` string, and an `audit_gaps[]` entry for the
  unparsed `upstream_body`.
- The bundle never contains `drugConcepts`, `foodConcepts`, or
  `conceptVariantCrosswalks` — registry rows are pointers to authoritative
  sources, not parsed facts.
- `secondary_source_registry.dart` is the only allowed place to add or
  retire a tiered source. Tier classifications are reviewed alongside
  the importer changelog.

## Built-in seed catalog (`LOCAL_SEED_CATALOG`)

`seed_catalog_importer.dart` provides a broad built-in food + drug catalog so
the App search index can cover realistic meals/medications even before any
external (FDC / Ciqual / DailyMed / DPD / EMA / PMDA / China-CDC / FAO) import
has run. It is opt-in via
`P0IngestionOrchestrator.importSeedCatalog()`.

What it emits:
- `projectedFoods` (~70+ items spanning grains, proteins, dairy, vegetables,
  fruits, fats/nuts, beverages, and common ready meals);
- `projectedDrugs` (~35+ items: every Parkinson's-relevant generic plus
  common comorbid medications such as statins, antihypertensives, PPIs,
  anticoagulants, NSAIDs, sleep aids, mineral supplements, and laxatives);
- exactly one `SourceDocumentRecord` with `sourceFamily =
  LOCAL_SEED_CATALOG`, `dataTier = P2`, and `ingestionStrategy =
  controlledExport`.

Conservative boundaries:
- Per-100g protein/carbs/fat/fiber/sodium values are **rough generic
  estimates** intended for UX/search and the conservative recommendation
  scoring path. They are **never** promoted into `ObservationRecord` or
  `ResolvedFactRecord` rows. Authoritative composition still comes from
  FDC/Ciqual/China CDC etc.
- Drug entries are catalog metadata only. `interactionSummary` is the empty
  string. The runtime interaction engine continues to evaluate **only** the
  curated rule registry — adding a drug to the seed catalog does NOT add a
  rule.
- Every seed row carries `sourceSystem = LOCAL_SEED_CATALOG` so downstream
  consumers can filter or prioritize authoritative ETL imports over seeds.
- The emitted source document records explicit `audit_gaps[]` entries for
  `food_nutrition_values` and `drug_interaction_summary` plus a top-level
  `parser_limitation` string.
- IDs are stable (`seed_*`) so re-running `importSeedCatalog()` is
  idempotent through the existing AppRepository merge-by-id path.

## Regional seed catalog (`LOCAL_SEED_CATALOG_REGIONAL`)

`regional_seed_catalog_importer.dart` extends the global seed catalog with
region-specific foods and comorbid medications, so users in different
countries can log realistic meals out-of-the-box. It is invoked
automatically by `P0IngestionOrchestrator.importSeedCatalog()` (which now
composes both the global and regional bundles) and can also be called
directly via `importRegionalSeedCatalog()`.

Region coverage:

| Region tag | Examples |
|---|---|
| `CN` | Red dates (红枣), goji (枸杞), white/black fungus, lotus root, hawthorn, longan, lychee, bitter melon, baozi, zongzi, mooncake, black rice, jiaozi |
| `JP` | Sea bream (鯛), saba, yellowtail, natto, miso, soy sauce, nori, kombu, wakame, hijiki, daikon, shiitake, gobo, mochi, udon, soba, umeboshi, matcha |
| `KR` | Kimchi, tteok, gochujang, doenjang, miyeok soup, bibimbap, japchae, kimbap |
| `IN` | Dal, chapati, naan, paneer, ghee, basmati, idli, dosa, chana masala, biryani, raita, lassi, paratha, tandoori chicken |
| `MED` | Hummus, falafel, pita, tabbouleh, baba ganoush, tzatziki, feta, olives, dolma, shakshuka |
| `MX` | Corn tortilla, refried beans, guacamole, salsa, tamale, taco, quesadilla |
| `SEA` | Pho, bánh mì, pad thai, satay, nasi goreng, rendang, laksa, tom yum, sticky rice |
| `EE` | Borscht, pelmeni, blini, kasha |
| `MENA` | Couscous tagine, harira, shawarma, kibbeh |

The drug list adds internationally-used generics commonly co-prescribed
with Parkinson's medications: donepezil, galantamine, memantine,
clonazepam, lorazepam, zolpidem, mirtazapine, trazodone, gabapentin,
pregabalin, baclofen, tizanidine, tramadol, domperidone, ondansetron,
losartan, bisoprolol, rosuvastatin, furosemide, levothyroxine, vitamin D3,
vitamin B12.

Conservative boundaries (same as the global seed catalog):

- Per-100g values are rough generic estimates for UX/search; never promoted
  into `ObservationRecord`.
- Drug entries are catalog metadata only; the interaction engine still
  evaluates only the curated rule registry.
- Each row carries `sourceSystem = LOCAL_SEED_CATALOG_REGIONAL` and a
  per-row `jurisdiction` tag so authoritative ETL imports can override.
- Native-language aliases (zh / ja / ko / etc.) are search hints, not an
  authoritative localization contract — captured under the
  `cultural_aliases` audit gap.
- Combined seed + regional catalog has globally unique IDs (`seed_*` /
  `seed_<region>_*`), making `importSeedCatalog()` idempotent through the
  AppRepository merge-by-id path.

## Catalog ↔ interaction-engine reconciliation

`catalog_interaction_audit.dart` reconciles the seed + regional catalogs
against the runtime interaction engine's `DrugTag` enum. It is opt-in via
`P0IngestionOrchestrator.auditCatalogAgainstInteractionEngine()` and emits
exactly one `SourceDocumentRecord` (`sourceFamily = CATALOG_INTERACTION_AUDIT`)
with a structured report — it never modifies catalog rows or rule-registry
entries.

The audit produces three sections:

- `missing_tag_gaps`: catalog rows whose generic name implies a `DrugTag`
  (via the same `inferDrugTag()` heuristic used by the official-source
  importers) but which do not carry that tag. The seed + regional catalogs
  ship with **zero** such gaps; the test
  `Catalog ↔ interaction-engine reconciliation: every taggable drug is
  tagged` enforces this invariant.
- `schema_coverage_gaps`: catalog rows whose interaction class the current
  `DrugTag` enum cannot represent. These are surfaced explicitly so
  reviewers can route them through the curated rule registry or
  meal-context tags rather than silently miss them. Patterns currently
  covered:
  - PPIs / H2 blockers (omeprazole, pantoprazole, esomeprazole, famotidine)
    — pH-dependent levodopa absorption.
  - Multivalent-cation antacids (calcium carbonate, magnesium hydroxide)
    — chelation of levodopa.
  - SSRIs / SNRIs / atypical serotonergic antidepressants (sertraline,
    fluoxetine, paroxetine, citalopram, escitalopram, venlafaxine,
    duloxetine, mirtazapine, trazodone) — serotonin-syndrome risk with
    MAOI-B.
  - Serotonergic opioids (tramadol, meperidine / pethidine) —
    contraindicated with MAOI-B.
  - Central D2 antagonists (haloperidol, risperidone, olanzapine,
    metoclopramide, prochlorperazine) — may worsen Parkinsonism.
  - **Excluded by design**: domperidone is a *peripheral* D2 antagonist
    used to counter dopamine-agonist nausea and must NOT be flagged as a
    Parkinsonism-worsening agent.
- `iron_supplement_check`: every catalog row whose generic name contains
  iron / ferrous / ferric / 硫酸亚铁 must carry `DrugTag.mineralSupplement`
  so the existing iron–levodopa rule fires.

The audit deliberately does NOT invent new `DrugTag` values; that is a
core enum change owned by the interaction-engine team. It also does not
promote any food into a structured "iron-rich" or "high-tyramine" facts
table — meal-context tags (`coeventSubstanceTags`) remain user-supplied
at meal-log time.

## Locale resource seed (KR/IN/ES/MX/SEA/EE/RU/MENA)

`locale_resource_seed_importer.dart` extends the `locale_resource_bundle`
table beyond the project's original four built-in locales (`zh-CN`, `en`,
`ja`, `fr`) to cover the regions whose authoritative databases we now
register through `secondary_source_registry.dart`:

```
ko-KR, hi-IN, es-ES, es-MX, vi-VN, th-TH, id-ID, ru-RU, pl-PL, ar-SA
```

Each locale receives selected UI namespaces:
- `food_categories` — eight `FoodCategory` enum values translated.
- `meal_slots` — breakfast / lunch / dinner / snack.
- `texture_classes` — liquid / soft / regular.
- `nav` — bottom-navigation labels.
- `common` — shared UI verbs and status labels.
- `recommend.path` — recommendation engine path labels.

Invocation: `P0IngestionOrchestrator.seedLocaleResourceBundles()`. Every
row is written through the existing
`cdssService.database.insertLocaleResourceBundle()` channel, then a single
`SourceDocumentRecord` (`sourceFamily = LOCALE_RESOURCE_SEED`) records the
rollout with explicit `audit_gaps` for `translation_quality_review`,
`plural_rules`, and `ui_string_catalog_coverage`.

Conservative boundaries:

- The seed is a **database-backed UI enrichment** for selected namespaces.
  It does not guarantee complete app string coverage for a locale.
- `pluralRule` is null on every row; plural handling is a UI concern.
- Translations are seed values for app UX labels only; native reviewers
  must QA every locale before public release. The
  `translation_quality_review` audit gap makes this explicit.
- The seed does NOT cover the full UI string catalog; only the namespaces
  above. The `ui_string_catalog_coverage` audit gap records this scope.

## Importer smoke-test execution

Run the importer smoke suite sequentially to keep audit/log determinism easy
to reason about:

```
flutter test test/p0_importers_test.dart --concurrency=1
```

Notes:

- The importer suite does not share any cache, file, or temp-path resources
  between tests; every test constructs its own `FakeSourceFetchClient`,
  `_CountingCdssDatabase`, and `P0IngestionOrchestrator`. Running with the
  default concurrency is safe but `--concurrency=1` keeps test interleaving
  out of failure stack traces, which makes intermittent regressions easier
  to triage.
- `P0IngestionOrchestrator` uses a per-instance monotonic counter
  (`_runSequence`) appended to every `baseRunId`, so back-to-back imports of
  the same source within the same microsecond cannot collide on
  `_pendingBundles` / `_completedReports` / `_inputDescriptors` keys. A
  dedicated repeatability test (`back-to-back same-source imports on one
  orchestrator never collide on resume tokens`) guards this.
- `Crosswalk generation > ingestion smoke bundles are repeatable across two
  constructions` proves the audit-key signature for every importer is stable
  across two consecutive builds in the same process.

## Resumable ingestion (orchestrator)
- `ingestion_run.notes_json` carries a stable set of keys for both local-bytes
  and remote-fetch imports: `source_key`, `importer_id`, `input_kind`,
  `local_path` / `remote_url(s)`, `checksum`, `etag`, `last_modified`,
  `last_completed_stage`, `cached_bundle_available`, `attempt`,
  `retry_attempt`, `max_attempts`, `resume_supported`, `resume_token`,
  `checkpoint`, and (on failure) `error_message`.
- A failed parse on attempt 1 retries on attempt 2; promote failure caches the
  parsed bundle so attempt 2 only re-promotes; `resumeImportTask` on an
  already-promoted token is a no-op.
