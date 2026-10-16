# W17 public field corpus and W14 nutrient evidence adjudication

The fixture corpus contains 18 manually transcribed field cases: eight SPL and
ten FDC. They were checked against bounded, official per-document responses on
2026-09-30. The responses were read in memory; complete raw responses and exact
request timestamps were not retained. Every source is explicitly
`extracted_field_excerpt`, `raw_response_sha256: null`, and
`complete_samples_verified: false`. The local hashes identify our excerpts and
expectations, never a complete USDA/NLM response or a frozen dataset release.

The corpus is in `test/fixtures/public_source_small_corpus/`. Its manual field
expectations were saved and the independent Node check passed before W14
production edits. `tool/public_source_small_corpus_check.mjs` checks structural
paths, product NDC/route/strength groups, decimal comparisons and per-100-g
portion arithmetic using BigInt rational arithmetic without production imports.
The four companion Node tests include five data mutations and three future-schema
rejections. The exact
receipt is `build/public_source_small_corpus/latest.json`. Field checks pass;
complete sample means, acquisition mapping and clinical calibration remain HOLD.

## Sources and case scope

| Cases | Official document | Verified field scope |
| --- | --- | --- |
| D01–D03 | [DHIVY SPL](https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/39d79ade-8ee0-40ba-9fdd-13045b8ddbdf.xml) | Set ID/version/effective date; product 75854-701 oral tablet, 25/100 mg label strengths; qualitative protein statement and healthy-adult food-effect fields |
| D04 | [SINEMET SPL](https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/9b17b028-964a-473c-823d-81423535bd66.xml) | Four product NDC groups, oral tablet form and their separate ingredient strengths |
| D05–D06 | [RYTARY SPL](https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/6c1f7cd4-de56-45c1-a734-5e77b4aeb6f7.xml) | Four oral extended-release product strengths and healthy-adult food-effect fields; no immediate-release model promotion |
| D07–D08 | [INBRIJA SPL](https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/077c0f39-a3a2-4b2b-a184-09131889dcfb.xml) | Capsule with respiratory inhalation route; 42 mg levodopa label strength; active/inactive ingredient distinction |
| F01–F03 | [Broccoli 747447](https://api.nal.usda.gov/fdc/v1/food/747447) | Protein 2.57 g and iron 0.69 mg reported summaries, sample statistics and 76 g chopped-cup portion; 2.57×76/100=1.9532 g is arithmetic on the reported summary |
| F04 | [Lowfat milk 746772](https://api.nal.usda.gov/fdc/v1/food/746772), [whole milk 746782](https://api.nal.usda.gov/fdc/v1/food/746782) | Distinct food identities and protein summaries 3.38/3.27 g; no inferred comparability |
| F05 | [Whole milk 746782](https://api.nal.usda.gov/fdc/v1/food/746782) | Iron amount zero with absent LOQ; observed tyramine-item absence; precision remains unknown |
| F06–F07 | [Oat milk 2257046](https://api.nal.usda.gov/fdc/v1/food/2257046) | Fiber reported zero/LOQ 0.75 g and an explicit sample; tryptophan **reported summary 0.00875 g/LOQ 0.01 g**, eight data points; full mean not recomputed |
| F08 | [Oat flour 2261421](https://api.nal.usda.gov/fdc/v1/food/2261421) | Sodium summary 3.619 mg/LOQ 2.49 mg differs from explicit sample 2261492 amount zero/LOQ 2.47 mg and method; these fields are kept separate |
| F09–F10 | [Extra light olive oil 1750351](https://api.nal.usda.gov/fdc/v1/food/1750351) | Beta summary and explicit sample with distinct LOQs; gamma **reported summary 1.779 mg/LOQ 2.44 mg**; protein/fat nutrient items and portions absent in the inspected response |

Requests used the official public API's documented DEMO_KEY. URLs above omit the
query key. A 429 was received during the earlier bounded investigation; requests
stopped. No whole data download, alternate key or quota bypass was used.

USDA's [Foundation Foods documentation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)
explains that below-LOQ amounts can be stored as zero, calculations of totals and
averages use these zeros, and earlier data may lack LOQ fields. Therefore a
positive **aggregate** below the displayed LOQ does not independently establish
a malformed **sample measurement**. It also distinguishes calculated protein,
sample ranges and per-100-g edible-portion arithmetic. [FDC help](https://fdc.nal.usda.gov/help/)
defines summary statistics; a food publication date is not an entire dataset
snapshot. [The API guide](https://fdc.nal.usda.gov/api-guide/) documents public
access, licensing and rate limits. USDA fields are CC0; NLM's
[web policies](https://www.nlm.nih.gov/web_policies.html#copyright) do not grant a
blanket CC0 license to contributed labels. SPL fixtures retain minimal factual
fields rather than whole label text or images. [DailyMed web services](https://dailymed.nlm.nih.gov/dailymed/app-support-web-services.cfm)
provide the exact source documents.

## W14 production policy

The shared point selector still requires finite, non-negative, exact values and
compatible units/per-100-g basis. Primary missing, censored or ambiguous rows
compete with a point and prevent fallback. Only explicitly tagged source sample
ranges may accompany a point, and their ordered bounds must contain it.

Repeated exact evidence may share one arithmetic point only when source
document, entity, attribute, scope, unit, basis, method, locator and either an
explicit sample or an explicitly identified food-summary record agree. All
occurrence indexes and source records remain available; the representative is
chosen by observation ID, independent of row order. Legacy single rows with
omitted metadata remain compatible, but omitted metadata cannot prove a duplicate.
Different samples, methods, sources or values are retained without averaging.

The FDC importer additionally requires the same source food-nutrient ID, a
present derivation code and identical source row fields for duplicate proof.
Unresolved repeated source rows receive an `unresolved` locator so a later shared
selector cannot erase differences in sample details or source statistics merely
because their point scalars agree. Identical source occurrences retain distinct
observation IDs and one resolved fact. Unsupported nutrient fields also retain
their reported summary/LOQ/explicit sample fields in source-document audit.

An unresolved locator withholds a point even when only one valid observation
survives. Invalid peer amounts or units remain in the source audit; their
exclusion from the observation table does not prove that the survivor is unique.
Regression cases cover null, negative, non-finite text and wrong-unit peers,
including the actual catalog and meal-checker consumers.

A positive reported summary below LOQ is retained as source evidence with
`quantification_scope_unverified`; its arithmetic point and resolved point fact
are HOLD. Its original amount, LOQ and observed sample identifiers are preserved.
It is not labeled malformed solely on that comparison. A reported zero without
LOQ retains the legacy numerical adapter value while provenance explicitly says
`reported_zero_precision_unverified`; it is not claimed to be a measurement zero.
No complete sample mean or aggregate interval is inferred from partial samples.

`test/nutrient_evidence_adjudication_test.dart` uses preauthored expectations for
proven duplicates, each incompatible provenance field, missing proof,
primary-qualifier competition, source-sample differences, the real F07/F09
counterexamples and F08 summary/sample separation. It exercises the actual
catalog projection and database-backed meal checker. Incompatible protein
evidence cannot fall back to the cached item number or create a protein timing
score. `tool/nutrient_evidence_adjudication_check.mjs` records the actual Flutter
test exit status, input hashes and output hash; its receipt is
`build/nutrient_evidence_adjudication/latest.json`. No expected values are derived
from production output and no clinical claim is promoted by a passing receipt.

The final targeted receipt records 48/48 passing tests and binds all 485 current
`lib/**/*.dart` sources, including production consumers, models and configuration,
plus the checker tools, fixtures and tests. Its input identity is
`e646da1c7a42be122c8e1f975ae2463fa0e0ee2c9e13bff35ec03fd1c7c9dbdb`.
The earlier narrow-scope 47-test receipt with report digest
`b4a27c55a2ec9ad59f049ea7612bf1965acf08b312448df4a2192613eabfc5aa`
is superseded: it cannot attest the newer snapshot consumers or surviving-peer
guard. Any subsequent source/configuration change requires another receipt;
final configuration pins remain the root integration lane's responsibility.


Integration identity boundary: hashes and targeted receipts quoted above identify the module-check snapshot before the final v54 configuration and source rebind. They are retained without restamping. Current whole-candidate receipts are regenerated by the final verification run and listed in [MEGA results](MEGA_UPGRADE_RESULTS_2026-09-30.md). Module PASS alone does not establish current whole-worktree acceptance.
