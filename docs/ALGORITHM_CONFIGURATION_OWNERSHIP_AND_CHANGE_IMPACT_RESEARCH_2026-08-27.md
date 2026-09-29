# Algorithm configuration ownership and change-impact research — 2026-08-27

## Scope and boundary

This slice makes configuration-identity coverage observable for every
registered result-affecting algorithm. It is engineering provenance and replay
change detection. It is not proof that every branch is parameterized, that a
calculation is correct, that a model is biologically valid, or that an output
is clinically accurate.

## Primary and official evidence

| Source | Design implication | What it does not establish |
| --- | --- | --- |
| [FDA, *Assessing the Credibility of Computational Modeling and Simulation in Medical Device Submissions* (2023)](https://www.fda.gov/media/154985/download) | Code verification, calculation verification and comparison with real observations are separate evidence categories. Configuration identity must therefore remain separate from calculation and scientific-validation claims. | FDA review, qualification, applicability to ParkinSUM, or clinical validity. |
| [W3C PROV-O Recommendation](https://www.w3.org/TR/prov-o/) | `prov:used`, `prov:wasGeneratedBy` and `prov:wasDerivedFrom` distinguish the entity, consuming activity and derived result. ParkinSUM uses that concept to name which registered algorithm consumes each parameter or provider-binding record. | W3C PROV conformance; the local JSON manifest is PROV-inspired and does not emit RDF or a complete PROV graph. |
| [Open Systems Pharmacology qualification workflow](https://docs.open-systems-pharmacology.org/shared-tools-and-example-workflows/qualification) | Qualification plans can be rerun after model-structure, parameterization or platform-version changes. ParkinSUM therefore ships a local configuration-difference impact and requalification matrix instead of treating a changed hash as self-explanatory. | Permission to copy OSP code or assets, PBPK qualification, or evidence that ParkinSUM implements PK-Sim. |

## Implemented contract

`parkinsum.algorithm-configuration-coverage/2` creates an exhaustive partition
over the current algorithm registry:

- every registered algorithm appears exactly once;
- every explicit parameter or provider-binding record names one or more
  registered consuming algorithms;
- an orphan owner, duplicate owner, malformed identifier or invalid source
  bundle digest fails before identity construction;
- the per-algorithm structural manifest digest, owned source paths and the
  complete registered-source bundle digest are retained;
- `fieldAndSourceBound` means at least one explicit field record is present;
- `sourceBundleOnly` means only change detection is available; units,
  semantics, provenance and output impact remain unassessed; and
- an entry can claim `complete_per_field_coverage_proven: true` only when an
  exact completeness witness reconciles every declared field, runtime sink,
  implementation source, registered source bundle and dependency-contract
  digest; otherwise it remains false.

The current deterministic fixture contains 63 registered algorithms and 119
explicit parameter/provider records. Sixteen algorithms have at least one owned
field record; 47 remain source-bundle-only. The protein-trend aggregation record
binds effective occurrence time, ascending order, gram-per-meal values, the mean
formula and empty-input behavior. Its trace-provider record alone would not cover
that formula. The dose-expression parser now has
one explicit prototype-heuristic record binding its grammar ID, version, digest,
local unit-system URI, and unit-map version; this does not establish complete
parser branch coverage. Two entries have complete-per-field
coverage within their declared boundaries: gastric emptying has 17 declared
numeric and structural identities, and levodopa absorption opportunity has 13.
Their production sinks, source fingerprints, bundle and exact declared
direct-dependency digests reconcile through fail-closed witnesses. The legacy
food recommender still exposes 33 numeric leaves plus one tie policy, but helper
feature maps, categorical tokens and reason branches remain covered only by
the source bundle, so it is explicitly incomplete. The manifest is embedded
in algorithm-configuration schema v6 and shown in the Algorithm Observatory
with per-row prototype-heuristic and non-clinical labels.

At the 2026-09-28 checkpoint, the canonical identity was `2026.09.28-v51`, configuration digest
`547c92ae42945b10f91b484e194973f8701fb57f2fb1018bcfca0d31ac71978a`,
with registered source-bundle digest
`8f203376fadadb6fb5edb05c26f51bd0225f8a3741b7c991d0a18ba72fd49758`.
The v51 digest binds the `protein_trend` aggregation contract and direct meal
and output-point sources, plus the standalone `dosage_note_parser` trace-provider
binding. The parser trace is fixed synthetic syntax evidence; it does not feed
the other Observatory scenarios. These identities do not add clinical meaning
or change either calculation behavior.
The source bundle now includes the production catalog-candidate projection
probe and adapter boundary. Its fixed vectors enforce source-missing-marker
precedence, true-zero preservation, and `N=(V×W)/100` only when `V` is
declared in grams per 100 g and `W` is a valid serving mass in grams. Consistent
with USDA [Foundation Foods](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)
and [Global Branded Foods](https://fdc.nal.usda.gov/GBFPD_Documentation/), a
100 mL basis is not guessed to equal 100 g; the
[FDC API](https://fdc.nal.usda.gov/api-spec/fdc_api.html) is the transport
boundary and the [BIPM SI Brochure](https://www.bipm.org/en/publications/si-brochure/)
supplies the narrow quantity/unit rationale. The invariant report is now 23/23
with 22/63 mathematical/unit coverage, while combined direct-plus-mathematical
coverage is 30/63 and 33 algorithms remain uncovered. This extra verification
does not create a third complete-per-field witness: 61 algorithms remain
incomplete within the configuration-ownership contract.

The direct dependency declarations above are not a mechanically derived
transitive source closure. The separately researched
`algorithm_transitive_result_dependency_closure` gate would conservatively
derive those edges and fail closed on unresolved runtime or external bridges;
see
`docs/ALGORITHM_TRANSITIVE_RESULT_DEPENDENCY_CLOSURE_RESEARCH_2026-09-02.md`.

## Current shipped impact, requalification, and baseline controls

A changed digest says that bytes differ, but not what changed, which outputs
could move, whether a context of use is affected, or which credibility evidence
must be rerun. The shipped local
`algorithm_configuration_change_impact_and_requalification_matrix` now:

1. compares two schema-pinned configuration identities without accepting an
   untrusted self-declared baseline;
2. enumerates added, removed and changed field, formula, unit, transform,
   provenance, source, provider, dataset, split, estimator and structural
   identities;
3. traverses explicit parameter → algorithm → output → UI/replay-fixture links;
4. runs deterministic before/after scenarios and retains changed, unchanged,
   abstained, failed and unavailable outputs without suppressing null effects;
5. assigns required code verification, calculation verification, scientific
   validation, human-factors and context-of-use requalification work without
   treating a green replay as automatic promotion; and
6. requires independent review before accepting any claimed impact closure.

The shipped local `configuration_baseline_registry_and_reviewed_promotion_receipt`
then binds the impact package, replay, context-of-use record, obligation matrix,
environment and population scope to a versioned receipt. Its append-only hash
chain retains accepted and rejected promotion, rollback and revocation attempts,
uses expected-revision and expected-active compare-and-swap checks, and verifies
separated Ed25519 reviewer roles. The real candidate remains inactive because
its obligations and independent signatures are unresolved.

## Next P0: durable authoritative baseline and transparency witness

The next baseline-governance gap is
`configuration_baseline_durable_store_and_transparency_witness`. The current
registry is a deterministic local artifact, not a crash-atomic multi-writer
authority or an externally witnessed transparency log. The next slice must add
durable conditional append, idempotent recovery, independently witnessed
checkpoints, inclusion/consistency proofs, key lifecycle controls and explicit
UI separation between local cache, authoritative head and witnessed state.

## 2026-09-29 runtime evidence-currency identity update

The default identity is now `2026.09.29-v52`
(`77d2a1d030443c12f125e0ee9606f25a085dab76ef73d7a20fb62d7c9019a99d`), with
registered source-bundle digest
`15a293f7efa3501b0d206570d651b1abecc828e2d796751debd5225cece4bd6d`. The
mechanistic result contract now binds successful and currency-blocked traces
to the offline status snapshot, UTC assessment time, affected provider and
claim sets, and disposition. The receipt is content-addressed and unsigned;
the pre-existing v41 requalification ledger remains stale and blocks promotion.
This update changes the evidence gate and trace receipt, not the educational
calculation formulas or recommendation ranking.
