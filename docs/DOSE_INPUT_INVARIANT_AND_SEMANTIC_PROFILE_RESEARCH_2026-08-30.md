# Dose-input invariant and structured semantic profile research

Date reviewed: 2026-08-30

## Decision

ParkinSUM will keep its current local administration-dose grammar and confirmation gate fail closed while a separate P0 semantic-profile lane investigates FHIR R5, UCUM, and RxNorm interoperability. The current implementation is intentionally narrower: a parseable quantity is not result-eligible until an exact owner-scoped confirmation receipt, a conflict-free medication-assertion graph, and the requested as-of boundary all agree.

This is an engineering input-safety and provenance boundary. It does not establish that a dose is prescribed, appropriate, clinically correct, actually administered, adhered to, or suitable for an individual.

## 2026-09-23 implementation update

Parse-result schema v2 / grammar v3 now attaches a reviewed, ParkinSUM-local
unit-mapping record to each accepted dose token. The record preserves source
and canonical systems, codes, displays, versions, grammar source revision,
mapping type, explicitly non-applicable local jurisdiction, review date,
license disposition, dimensions and exact rational factor to mg or mL. The
confirmation receipt and portable package bind the record; canonical algorithm
configuration includes its unit-vocabulary version and digest, which the event
ledger carries as its configuration identity. The gate keeps mass and volume
separate and holds stale, unknown, approximate, ambiguous, unlicensed,
dimensionally invalid or revision-drifted mappings. This work does not add or
copy UCUM terminology assets and makes no UCUM conformance claim.

The existing 28 fixed dose-expression vectors are now supplemented by 2,304
deterministic adversarial mutations from seed `0x5eedc0de`, executed against
both the independent JavaScript reference and production Dart parser. The
18 mutation families cover comparators, ranges, rates, ratios, hidden second
quantities, duplicate or unsupported units, locale commas, scientific
notation, signs, a Unicode unit confusable, oversized text, and control
characters. The ignored local report binds the fixed fixture, generated
corpus, Dart parser, local unit-mapping source, JavaScript checker, and grammar
digests. The differential projection now also checks transient annotations
for exact, fully anchored comparator quantities and same-unit closed ranges.
Those annotations preserve lexical numbers, normalized-source spans, and the
reviewed local unit mapping for display. The parser still marks both forms
`held`, leaves the accepted expression null, and omits the annotation from
parse-result JSON, receipts, portable packages, and algorithm inputs. Rates
and malformed, mixed-unit, descending, or prose-embedded ranges receive no
annotation. This does not add FHIR/UCUM parsing or claim terminology or clinical
conformance.

### 2026-09-27 CDSS-225 — Unicode unit-token boundary hardening

The current parser is grammar v4. Unit-token boundaries now reject a recognized
unit immediately adjacent to a Unicode letter, combining mark, or Unicode
Other-category code point. This closes the prior ASCII-only boundary case in
which “100 mgℊ” could be accepted as “100 mg”. Fixed vectors also cover a
letterlike confusable before the unit, an attached combining mark, zero-width
format character, bidi control, and narrow no-break space between amount and
unit. Accepted text and mapping
evidence retain the same schema; the grammar digest changes because its
versioned boundary contract changed. A structurally valid grammar-v3
confirmation receipt now evaluates as grammar drift, so prior result
authorization remains held until a fresh explicit confirmation under v4.

The fixed corpus now has 34 vectors. The deterministic generator now exercises
3,584 mutations from seed 0x5eedc0de across 28 families, adding locale comma
and whitespace grouping, Arabic and fullwidth decimal separators,
Arabic-Indic digits, and the Unicode unit-boundary cases. Both the production
Dart parser and the separate JavaScript reference matched all declared
outcomes. This is bounded negative-input and syntax evidence, not full-domain
property generation, terminology validation, or clinical evidence. The P0
queue item remains research_required.

### Development-only FHIR R5 quantity preview (2026-09-24)

Schema `parkinsum.fhir-r5-dose-quantity-preview/2` projects one exact,
owner-confirmed local administration amount into the FHIR R5
`Dosage.doseAndRate.doseQuantity` fragment. Its content-addressed profile
manifest carries an element-path ledger with `mapped`, partial, unsupported,
and not-projected dispositions. The ledger records the single-entry
`doseAndRate` limit, the exact `doseQuantity` fields, and the omitted or
unsupported dose Range, rate Ratio/Range/Quantity, Timing, PRN, route, site,
method, dose maxima, extensions, and other Dosage elements. `Dosage.text` is
only a partial dosage token; it is not a complete SIG. Four code identifiers
are named (`mg`, `g`, `ug`, and `mL`). The preview does not emit a
`Medication` resource, validate a FHIR profile, query RxNorm, export or
exchange data, or interpret the dose clinically. Ingredient strength, product
identity, form, release, and confirmation provenance remain unmapped and
visible by path. The manifest marks every result
`resource_or_exchange_eligible=false`.

The ledger accounts for the bounded Dosage fragment's FHIR element paths; it
is not a complete resource/profile inventory or a nested datatype validator.
No independent FHIR R5 validator ran because the pinned HL7 Validator JAR was
not available in this environment. This schema change therefore adds
traceability about represented and omitted Dosage semantics, not evidence of
FHIR structural conformance.

This is not a complete or independently reviewed UCUM subset. UCUM 2.2 and
license 1.1 are recorded for provenance only; no UCUM table, parser, or unit
description is copied; the Quantity display remains the ParkinSUM-local unit
display, and license review remains open. The official FHIR
definitions distinguish per-administration `Dosage.doseAndRate.dose[x]` from
ingredient strength in `Medication`, and represent quantity value, display
unit, system, and code as separate fields ([Dosage](https://hl7.org/fhir/R5/dosage-definitions.html),
[Quantity](https://hl7.org/fhir/R5/datatypes-definitions.html#Quantity)).
See also the [UCUM specification](https://ucum.org/ucum) and
[UCUM license](https://ucum.org/license). The P0 queue item remains
`research_required`; the preview satisfies none of the outstanding
terminology, complete-profile, independent-validator, clinical, or release
gates.

## Implemented local boundary

- Parse-result schema v2 / grammar v4 accepts one explicit positive finite mass-or-volume administration quantity and preserves the raw expression. Unicode-letter, combining-mark, and Unicode Other-category code points may not touch a recognized unit token. Exact comparator quantities and same-unit closed ranges may carry transient, syntax-only display annotations while remaining held and result-ineligible.
- The 34-vector Dart/JavaScript differential corpus plus 3,584 deterministic mutations holds leading decimals, scientific notation, ranges, rates, ratios, locale grouping and ambiguity, hidden second numbers, Unicode/fullwidth signs and unit confusables, non-finite values, unsupported units, bidi and format controls, and other control characters.
- Product or ingredient strength, package count, single administration quantity, and daily regimen dose remain separate fields. A single Intake never becomes `dailyDoseMg` without independent regimen-frequency evidence.
- Result-affecting paths re-evaluate the confirmation receipt, assertion graph, and as-of observation time. Unconfirmed, stale, conflicted, or future evidence yields typed absence rather than zero.
- Mass units may be converted only within the reviewed local mass subset. Volume remains volume; mL cannot become mg without an explicit governed concentration ratio and package context.
- The Algorithm Observatory exposes all five dose invariant specifications and the coverage status of every registered algorithm. Data-integrity UI distinguishes parseable text from result-eligible dose evidence.

## Official structural evidence

### FHIR R5

FHIR R5 `Dosage.doseAndRate.dose[x]` is the amount of the specified medication per administration event. The specification explicitly distinguishes that medication amount from the amount of each active ingredient, which belongs in `Medication`.

- [FHIR R5 Dosage detailed definitions](https://hl7.org/fhir/R5/dosage-definitions.html)

`Medication.ingredient.strength[x]` may be a ratio such as 250 mg per tablet, or a quantity when the denominator is assumed to be one unit. This supports an explicit derivation graph for confirmed package count × ingredient strength; it does not authorize treating strength alone as the administered dose.

- [FHIR R5 Medication detailed definitions](https://hl7.org/fhir/R5/medication-definitions.html)

### Development-only FHIR R5 Medication product preview (2026-09-24)

Schema `parkinsum.fhir-r5-medication-product-preview/1` projects only a
product display, dose-form display, and known ingredient names into a local
FHIR R5 Medication text fragment. It does not invent RxNorm, SNOMED, or other
terminology codes. Source ingredient-strength values and units remain in a
separate local product-metadata evidence list; no strength is placed in
`Medication.ingredient.strength[x]`, `Dosage`, a confirmation receipt, or an
algorithm input. Missing and incomplete strengths remain explicit. The
content-addressed preview also retains the source system, jurisdiction,
source-document identity/version/date, and source references outside the
Medication fragment. Its manifest lists the mapped and omitted Medication
paths and marks both resource exchange and algorithm use ineligible.

The preview does not represent package quantity, batch, medication status,
authorization holder, prescription, patient, administration, or clinical
decision. It is not a complete FHIR Medication resource/profile, terminology
mapping, validator result, or interoperability claim. FHIR R5 defines
Medication as product identity and ingredient content, including ingredient
strength, while Dosage separately describes the amount per administration
([Medication definitions](https://hl7.org/fhir/R5/medication-definitions.html),
[Dosage definitions](https://hl7.org/fhir/R5/dosage-definitions.html)).

### Exact tablet strengthQuantity subset (CDSS-119/121; 2026-09-25)

Schema `parkinsum.fhir-r5-medication-product-preview/3` adds a separate,
opt-in projection from `MedicationProductPack`. A row enters
`Medication.ingredient.strengthQuantity` only if its preserved raw decimal
lexeme exactly matches the parsed positive numerator, the unit is exactly
`g`, `mg`, or `ug`, the product source is identified as the supported
openFDA/Health Canada API host and has a product identifier, the dosage form
is exactly `tablet`, and the denominator is absent or a unitless numeric one.
On the openFDA path, the same snapshot bytes also produce a local source
manifest with one exact matching NDC, ingredient index, ingredient name, and
raw-strength row. The manifest binds the asset SHA-256, product ID, SPL ID,
parser-result digest, and row digest into preview evidence. The diagnostics UI
builds both the catalog and manifest from the same loaded byte sequence. This
is local identity evidence; it does not verify FDA source truth or currentness.
The Health Canada path keeps the existing host and identifier checks because
this iteration adds no corresponding local snapshot manifest.
The Quantity carries `system` and `code` from the
bounded UCUM 2.2 reference subset; the raw lexeme, source numeric fields,
assumed-one-tablet basis, and source identity remain in the separately hashed
evidence. The existing FhirInspired view path remains text-only. Other forms,
unit aliases, concentrations, explicit denominator units, malformed or
mismatched lexemes, and unknown source hosts remain local evidence.

The schema-v3 profile manifest pins FHIR Core 5.0.0, links UCUM 2.2 and
license 1.1, and identifies the openFDA source-row manifest contract;
it does not copy a UCUM table/parser or establish redistribution clearance.
UCUM's own specification uses `{tbl}` only as a non-normative non-unit
example, so this projection does not invent a tablet code. The importer does
not provide a full upstream response hash; neither a host check nor a local
asset/row digest is source verification. The fragment still has no ingredient terminology codes, full
resource/profile validation, RxNorm mapping, exchange eligibility, dose
derivation, or algorithm eligibility. FHIR-shaped strength remains product
metadata, not evidence of a person's administration.

### openFDA NDC strength-expression lexical capture (2026-09-24)

The versioned `parkinsum.openfda-strength-expression-parse-result/1` parser
preserves the exact source string and exposes only anchored decimal and unit
lexemes. The regression corpus is bound to the checked-in openFDA snapshot
retrieved on 2026-08-17 (SHA-256
`8b2e38710abe34567414c66bd5c1a197e74b256da1b16d7d7a947fad554f063c`): all 213
ingredient-strength rows across 157 records are lexically recognized, and
every result remains held. `100 mg/1` keeps the denominator numeral without a
unit. `50 mg/5mL` and `1 mg/24h` preserve `mL` and `h` as text tokens without
classifying a concentration or rate, mapping UCUM, or producing a numeric
quantity. The result digest binds the parser version and exact expression. A
companion `parkinsum.openfda-strength-expression-source-manifest/1` binds each
result to the snapshot digest, product NDC/product ID, SPL ID, ingredient
index, and ingredient name, while keeping source and parser digests distinct.

The openFDA NDC field reference defines `active_ingredients[].strength` as a
string for active medicinal ingredient strength. FDA separately documents the
NDC strength/unit fields and states that directory inclusion does not denote
approval; the openFDA API warns that results are unvalidated and should not
guide medical-care decisions ([openFDA NDC field reference](https://open.fda.gov/fields/drugndc_reference.pdf),
[NDC database background](https://www.fda.gov/drugs/development-approval-process-drugs/national-drug-code-database-background-information),
[openFDA API result guidance](https://open.fda.gov/apis/drug/ndc/understanding-the-api-results/),
[FDA NDC verification limitation](https://www.fda.gov/drugs/enforcement-activities-fda/unapproved-drugs)).
The CDSS-121 preview uses the parser result's exact raw source string and
digest only to require a unique local openFDA row match; those lexical tokens
still assign no UCUM or FHIR strength semantics and do not feed algorithms.
The P0 profile remains open for denominator governance, terminology mapping,
standards validation, complete source binding, and independent derivation
verification.

### Bounded local package-strength derivation (2026-09-25)

The editor now stores the optional
`parkinsum.medication-package-dose-derivation/1` trace inside the selected
product snapshot. It binds source system/URL/retrieval time, exact ingredient
strength text, parsed numerator and denominator, denominator disposition,
confirmed discrete unit count, formula identity and calculated amount. The
existing administration-dose receipt binds the full product snapshot digest.
The user interface shows the source and equation and calls out when an absent
source denominator is assumed to mean one tablet, capsule, or caplet. Editing
the dose text clears this trace.

The calculation only handles recognized discrete tablet/capsule/caplet forms
with a one-unit denominator; it holds liquids, volume denominators, unsupported
forms, and mismatched denominator units. This does not validate the source
record, assign UCUM semantics, compute a concentration conversion, or qualify
the derived value for clinical use. The source fields lack a digest over the
full raw network response, and the openFDA lexical parser remains a separate
research artifact. The P0 profile stays open.

FHIR R5 allows `Medication.ingredient.strength[x]` to be represented as a
`Quantity` when its denominator is assumed to be one tablet. FDA's strength
listing guidance distinguishes oral-solid strengths expressed per `each`
from oral-liquid strengths expressed per volume. These definitions support a
bounded discrete-unit path but do not establish the correctness of any one
source listing or authorize converting concentration to mass
([FHIR R5 Medication definitions](https://hl7.org/fhir/R5/medication-definitions.html),
[FDA strength conversion guidance](https://www.fda.gov/drugs/electronic-drug-registration-and-listing-system-edrls/strength-conversion-drug-listing)).

FHIR `Quantity` keeps numeric value and comparator separate from the human-readable `unit`, terminology `system`, and machine-processable `code`; if a code exists, the system must also exist. ParkinSUM must therefore never compute from display text alone.

- [FHIR R5 Quantity detailed definitions](https://hl7.org/fhir/R5/datatypes-definitions.html#Quantity)

FHIR R5 is still only a structural source for this roadmap. A future implementation requires a pinned `hl7.fhir.core#5.0.0` package, explicit local profiles, a pinned validator/runtime, complete mapped/held/loss manifests, and independent round-trip evidence before any conformance claim.

### UCUM

UCUM defines distinct case-sensitive and case-insensitive symbols, and separates print symbols from normative coded representations and canonical form. The micro prefix illustrates the distinction: the print symbol may be `μ`, while a case-sensitive code uses `u`. A display alias or case-insensitive match is therefore insufficient computation evidence.

- [UCUM specification](https://ucum.org/ucum)
- [UCUM license](https://ucum.org/license)

Any future UCUM use must pin a reviewed version or bounded subset, record license disposition, preserve original display plus system/code, validate commensurability independently, and bind conversion identity into configuration, replay, event-ledger, and export digests.

### RxNorm

NLM now lists the September 8, 2026 Current Prescribable Content release as RxNorm_full_prescribe_09082026.zip with publisher-published MD5 88bbe4cefabd8e71f58651c1c3188646. Its dated release notes enumerate active RXNORM term-type and NDC counts. The release is U.S.-centric; the active subset does not provide evidence that an absent concept is retired.

A local schema-v1 manifest pins this release filename, date, MD5, release-note scope, and terms and computes a SHA-256 digest over its own sorted-json-v1 metadata. The archive was not downloaded, so the publisher MD5 is not locally verified. No RxNorm rows or product mappings are shipped, and this metadata pin is not bound into algorithm or export identity. The NLM release listing says no license is required to download this Current Prescribable Content file; NLM requests attribution, and the broader full monthly release has a separate UMLS-license and source-vocabulary boundary. This is metadata review only, not clearance for future data redistribution.

The diagnostics-only RxNav flow now permits a separately consented, user-selected candidate properties request. The exact candidate RxCUI receives one current name/TTY/synonym/language/suppression preview from the active-concept endpoint; an empty properties element is described only as not present in that API's current active dataset, not as retired or absent from RxNorm. The response remains in screen memory and is not a mapping, release pin, product match, or algorithm input. See the [RxNorm concept properties endpoint](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/APIs/api-RxNorm.getRxConceptProperties.html).

- [RxNorm release files and checksums](https://www.nlm.nih.gov/research/umls/rxnorm/docs/rxnormfiles.html)
- [RxNorm Current Prescribable Content September 8, 2026 release notes](https://www.nlm.nih.gov/research/umls/rxnorm/docs/2026/rxnorm_releasenotes_prescribe_09082026.html)
- [RxNorm release organization and schedule](https://www.nlm.nih.gov/research/umls/rxnorm/overview.html)

The full dataset contains NLM-created public-domain normalized names/codes and content from source vocabularies with separate restrictions. A UMLS license is required for full releases, while the smaller Current Prescribable Content download has a different scope. Release, source vocabulary, term type, active/retired history, granularity, jurisdiction, and license state must remain explicit.

- [RxNorm Terms of Service](https://www.nlm.nih.gov/research/umls/rxnorm/docs/termsofservice.html)

An RXCUI or successful lookup is an identifier result, not proof of prescription validity, administration, adherence, semantic correctness, or clinical appropriateness.

## Required semantic model

The queued profile must represent these concepts independently:

1. raw human instructions and provenance;
2. medication amount per administration, including quantity or range;
3. timing/frequency, duration, rate, and maximum-dose constraints;
4. product, ingredient, ingredient strength, denominator, total package amount, count, dose form, route, method, and release identity;
5. original and canonical quantity values, implicit precision, comparator, display unit, system, code, dimension, conversion identity, and held reason;
6. terminology identity including RXCUI, term type, source vocabulary, exact release, active/retired state, mapping granularity, jurisdiction, and license boundary;
7. derivation edges showing exactly when a confirmed package count and strength or concentration produce an administration quantity; and
8. confirmation receipt, assertion/source graph, reconciliation decision, observation time, and result-eligibility state.

Unknown, unsupported, lossy, stale, ambiguous, non-finite, non-positive, overflow, dimensionally invalid, or conflict-bearing states must remain enumerable and result-ineligible. No import/export adapter may silently discard `Range`, `Ratio`, `Timing`, rate, maximum, route, form, release, extension, terminology, or provenance fields.

## UI and verification contract

The Algorithm Observatory and record-review UI must eventually show raw and canonical quantities, unit system/code, RxNorm identity/release, derivation graph, confirmation status, assertion conflicts, as-of holds, unsupported/lossy fields, and the exact reason a value cannot affect a result. Accessibility evidence must cover keyboard, screen reader, 200% zoom, 320 CSS-pixel reflow, and every shipped locale.

Independent differential, property, round-trip, restart, cross-account, cross-release, and mutation suites must cover at least strength-as-dose, display-as-code, UCUM case confusion, missing system, package-denominator drift, mass-volume substitution, concentration omission, terminology retirement/merge, stale confirmation, future evidence, conflicting assertions, and dropped Range or Timing.

Passing those gates would prove a bounded engineering profile and deterministic implementation only. It would not be clinical validation, prescription checking, evidence that medication was taken, or regulatory clearance.

## Queue disposition

`structured_medication_dose_semantics_ucum_rxnorm_fhir_profile` is P0, `research_required`, impact 5, risk 5, effort 4, score 20 under `(impact + risk) × (6 - effort)`. It depends on the dose grammar, confirmation receipt, assertion reconciliation, typed quantity kernel, and terminology firewall without merging their distinct acceptance boundaries.
