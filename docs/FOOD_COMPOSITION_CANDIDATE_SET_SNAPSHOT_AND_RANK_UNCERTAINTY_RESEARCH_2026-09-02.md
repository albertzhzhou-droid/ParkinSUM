# Food-composition candidate-set snapshot and rank-uncertainty research

Reviewed: 2026-09-27
Product mode: education and research prototype

## Decision

Add `food_composition_candidate_set_snapshot_and_rank_uncertainty_gate` as a
separate P0 research item and make it a dependency of prospective legacy-ranker
utility work. Parameter identity and deterministic arithmetic are necessary,
but they cannot make a ranking reproducible when the food catalog, food match,
preparation state, portion basis, missingness semantics, or eligible candidate
set can drift independently.

This item is deliberately separate from ranker retirement and utility
validation:

- configuration identity asks which scorer and parameters ran;
- the new gate asks which foods and measurements were eligible and whether
  supported input uncertainty can change their order;
- prospective utility asks whether a frozen ranking strategy has useful and
  acceptable outcomes in its prespecified context of use.

## Primary and official evidence map

### Reproducible model identity is not clinical truth

The FDA PBPK reporting guidance asks for enough material to duplicate and
evaluate a model: parameter names, values, units, sources, estimation methods,
algorithms, assumptions, software identity, and uncertainty or sensitivity
analysis. It also states that acceptance depends on intended use plus the
quality, relevance, and reliability of the result. This supports explicit
parameter and input-artifact identity; it does not validate ParkinSUM's
heuristic weights or authorize patient-specific decisions.

Source: [FDA PBPK Analyses—Format and Content](https://www.fda.gov/media/101469/download)

The FDA computational-model credibility guidance separates code verification,
calibration, validation evidence, calculation verification, and uncertainty
quantification. Calibration against development data cannot be relabeled as
independent validation, and deterministic replay establishes implementation
agreement rather than predictive credibility.

Source: [FDA Assessing the Credibility of Computational Modeling and Simulation](https://www.fda.gov/media/154985/download)

The IMDRF SaMD framework similarly separates a valid clinical association,
analytical validation, and clinical validation. It is used here only as a
governance analogy; this document makes no claim about ParkinSUM's regulatory
classification.

Source: [IMDRF SaMD Clinical Evaluation](https://www.imdrf.org/documents/software-medical-device-samd-clinical-evaluation)

### Food composition is a versioned measurement artifact

USDA Foundation Foods retain acquisition, sample, analytical-method, and
individual-value context. Nutrient values can be measured or calculated,
fields may be not yet analyzed, portions differ by data type, and below-limit
handling can differ from a true measured zero. Therefore `0`, missing, not
analyzed, below quantification, calculated, and imputed must remain distinct.

Source: [USDA FoodData Central Foundation Foods documentation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)

USDA FoodData Central's field help describes `min` and `max` as the smallest
and largest nutrient amounts found in analyzed samples; `median`,
`data_points`, and `standard_error` are separately reported fields. These
observed extrema describe the source's sample values. They are not confidence
limits or a probability distribution. The importer therefore preserves the
source's exact `amount` as the point projection and may expose `min`/`max` as a
separate range for deterministic stress replay; it retains the other statistics
as source audit metadata and does not turn standard error into a synthetic
interval.

Sources: [USDA FDC Help](https://fdc.nal.usda.gov/help/) and [USDA FDC data dictionary](https://fdc.nal.usda.gov/portal-data/external/dataDictionary)

FAO/INFOODS food-matching guidance requires source/version and food identity,
plus review of preparation, component definition, analytical method, unit,
denominator, edible portion, brand, country, and match quality. A plausible
name match is not automatically composition-equivalent.

Source: [FAO/INFOODS Guidelines for Food Matching](https://www.fao.org/docrep/017/ap805e/ap805e.pdf)

### Human levodopa/protein evidence is context-specific and heterogeneous

- Nutt and colleagues studied protein-containing meals and amino-acid effects
  in a small fluctuating Parkinson's population; this supports a possible
  context-dependent interaction, not a universal single-food weight. Source:
  [PMID 6694694](https://pubmed.ncbi.nlm.nih.gov/6694694/).
- A study of 11 fluctuating patients found levodopa fluctuations were two to
  three times larger than LNAA fluctuations and that LNAA did not uniformly
  explain clinical response. Source:
  [PMID 2738591](https://pubmed.ncbi.nlm.nih.gov/2738591/).
- A randomized study in eight healthy volunteers found that a 30.5 g
  high-protein meal did not significantly reduce levodopa absorption rate or
  extent. The population and endpoint cannot be generalized to clinical
  benefit in Parkinson's disease. Source:
  [PMID 2049250](https://pubmed.ncbi.nlm.nih.gov/2049250/).

These studies differ in population, fed state, formulation, intervention, and
endpoint. They do not identify ParkinSUM's 0–100 ranking coefficients,
thresholds, or utility function.

## Required future artifact

The gate should bind these layers into one reviewable package:

1. An immutable catalog snapshot with owner, license, release, record identity,
   jurisdiction, data type, description, brand, preparation, edible portion,
   basis, serving conversion, match method, and match quality.
2. Per-nutrient state that preserves measured, calculated, imputed, borrowed,
   user-entered, true zero, not analyzed, missing, and below-quantification,
   plus original unit, denominator, derivation, sample context, range, and only
   source-supported uncertainty.
3. A candidate-set digest over the exact query, filters, exclusions,
   deduplication, fallback path, stable identities, and tie policy.
4. Independent matching and conversion fixtures, followed by perturbation that
   reports threshold crossings, ties, candidate swaps, and rank stability.
5. A visible hold or unordered state when supported uncertainty makes the
   apparent order materially unstable.
6. Observatory rows for catalog snapshot, food match, preparation and portion
   basis, missing/LOQ state, and rank stability. Ranking points remain labelled
   heuristic and cannot override applicability, medication, abstention, or
   safety gates.

## Current implementation boundary

The 2026-09-26 candidate snapshot schema v5 records the six local
`queryTable` reads, returned row IDs/order and row-set hashes, and the
projection's implemented selection/last-wins rules. It also records that the
reads are sequential rather than transaction-scoped and that the orchestrator
API does not receive the caller's original query or filters. This improves
local candidate assembly replayability; it is not an atomic database snapshot
or an upstream catalog release identity.

FDC `foodPortions` now projects into a separate `FoodPortionEvidence` list on
each linked food. It retains the FDC portion sequence, amount, measure-unit ID
and labels, description/modifier, gram weight, data-point count, footnote,
minimum year, record locator, source-document ID, and supplied portion fields.
The candidate snapshot digest therefore changes when this portion evidence
changes. These records are source evidence only: no user serving is selected,
no portion is matched across foods, and no per-100-g nutrient is converted or
rescaled. The portion records add no database table and do not affect legacy
ranking inputs.

The food detail view now labels the nutrient observation selected for the
current legacy point-value projection separately from observations retained as
evidence only. This reflects the stored projection-selection metadata; it does
not claim that a nutrient changes candidate ranking.

The existing parameter-contract iteration makes selected weights, bounds,
thresholds, Top-K, and tie ordering explicit and UI-visible. Neither artifact
freezes an upstream food catalog, validates food matching or general
serving/unit conversion, estimates measurement uncertainty, proves rank robustness,
validates a coefficient, or establishes clinical utility.

The next-meal result now carries an in-memory
`parkinsum.food-rank-sensitivity-assessment/1` report bound to its candidate
snapshot digest. For protein and fiber only, the bounded stress service accepts
source ranges when the selected exact point and interval share the same
nutrient, entity, source document, scope, numeric value type, unit, basis, and
method, and when the point falls inside the reported interval. It enumerates
range endpoints, production score/decision/reason thresholds, and values between
adjacent breakpoints, then invokes the same deterministic ranker and
next-meal-window transform. The report can expose possible order swaps,
display-set membership changes, and changed scores, breakdowns, decisions,
reasons, or feature snapshots. It fails closed on conflicting evidence,
unsupported types or scopes, candidate identity mismatches, and scenario-budget
overflow; AI reranking is left unassessed. No probability distribution is
inferred, and the report always leaves full rank stability unassessed.

The card distinguishes detected changes in these tested scenarios from the
still-unassessed ranking question. Only strictly bound protein/fiber source
ranges enter this replay. The checked-in P0 bootstrap seed currently contains
no `range` qualifier for protein or fiber; brewed coffee's protein value is
`<0.5`, which this service does not perturb. The FDC importer now preserves
the exact source `amount` and, when finite `min`/`max` are supplied with an
absent or positive `data_points` value, adds a separate unselected range
observation. A zero `data_points` value does not produce a range. JSON and CSV
fixtures verify the mapping; no live Foundation Foods catalog import was
verified in this iteration. `data_points`, `median`, `standard_error`,
derivation/source codes, footnote, and minimum-year metadata remain in the
source-document audit. Standard error is not converted into a probability or
interval. This import path does not change the checked-in seed catalog or the
legacy point projection, so default-seed ranking can still remain unassessed.
Real scenario results depend on separately populated projected source
intervals.
Catalog release and caller query, food matching, validated serving selection
and portion conversion, sample and measurement uncertainty,
other nutrient inputs, and prospective utility remain open. A no-change result
in this bounded replay is not evidence of general rank stability. The explicit
NextMeal result and dashboard now withhold score-ordered candidate cards when
the assessment is missing, belongs to another snapshot, or detects a pair-order
or display-set change. The explicit page also withholds its rank-related
explanations and position-aligned model-trace rows. The baseline result and
audit remain available internally; upstream safety decisions are unchanged.
When a matching report observes no order or membership change, the existing
heuristic order remains visible with the full-stability boundary. This display
hold is not a ranker retirement decision or prospective utility evidence, and
the broader rank-uncertainty acceptance criteria remain open.

### Bounded Foundation portion-conversion preview

The opt-in `FoodPortionCompositionProjectionService` now produces a separate,
non-persisted preview for one caller-named portion record and nutrient. It
requires the candidate's captured content to match the supplied `FoodItem`,
the source data type to be Foundation, the portion and selected exact nutrient
observation to share the FDC food and source-document identifiers, and the
linked source-document evidence to resolve to USDA/FDC with a stored payload
digest. The observation's nutrient, unit, scope, method and
`per_100g_edible_part` basis must also be internally consistent. It applies the USDA Foundation Foods formula
`nutrient per portion = nutrient per 100 g × portion gram weight / 100` and
preserves the original nutrient unit. An available source min/max pair is
converted only when it matches the selected observation's identity and scope
and contains the point value; the output labels those endpoints as observed
source extrema, not confidence or probability limits. Portion-weight
uncertainty remains unquantified. USDA documents this per-100-g portion
calculation and defines the distinct `food_portion` gram-weight fields in its
[Foundation Foods documentation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)
and [FoodData Central data dictionary](https://fdc.nal.usda.gov/portal-data/external/dataDictionary).

Shared synthetic JSON vectors run through the Dart service and a separately
implemented JavaScript oracle. They cover an exact-plus-range conversion,
true zero, non-Foundation data type, mismatched FDC food identity, invalid
weight, incompatible basis/scope, a range excluding the point, and arithmetic
overflow. The preview has no production caller and changes no `FoodItem`,
ranking, display order, or safety gate. It does not select an appropriate user
serving, perform food matching, interpret Foundation sample counts as portion
weight uncertainty, or extend to Branded, Survey, SR Legacy, per-100-ml, or
other source bases. Those broader behaviors and the queue acceptance criteria
remain open.

Each serialized preview now includes its own SHA-256 digest. It sorts object
keys and encodes every numeric value as an explicit IEEE-754 binary64
hexadecimal tag before hashing, allowing an independent runtime to reproduce
the digest without depending on whether JSON spells an integral value as `91`
or `91.0`. The digest covers the candidate-snapshot digest, explicit portion
locator, source observations, calculated values, hold state, and uncertainty
labels, so changing the selected portion or result content changes the preview
identity without modifying the candidate snapshot or production rank.

### Candidate-level rank uncertainty labels (CDSS-224)

The next-meal result keeps its existing deterministic baseline order and adds a
localized per-candidate label when that candidate participates in a pairwise
order reversal or a displayed-set membership change found by the bounded
source-range scenarios. The label appears only when the sensitivity report's
candidate-set digest matches the displayed snapshot digest; stale or mismatched
evidence produces the existing `not assessed` state and no candidate badge.
This makes the affected candidate visible at the point of use without
converting a bounded scenario into an overall rank-stability claim. The
candidate list, scores, decisions, reasons, and safety gates remain unchanged.

Widget tests cover order-affected candidates, display-membership candidates,
unaffected candidates, stale snapshot rejection, and translation resolution
in all 13 shipped language families. The feature-page smoke test also renders
the NextMeal page at standard and large text scale. Candidates are annotated,
not held or literally grouped as unordered; complete rank uncertainty,
catalog/match identity, preparation/portion uncertainty, and prospective
utility remain open.
