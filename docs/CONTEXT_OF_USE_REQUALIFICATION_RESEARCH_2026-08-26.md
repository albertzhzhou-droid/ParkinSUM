# Context-of-use requalification and prospective credibility planning

Reviewed: 2026-09-02

## Product boundary

ParkinSUM is an education and research prototype. The controls described here
are engineering and evidence-governance controls. They do not establish model
qualification, clinical validity, regulatory review, external approval, or a
basis for medication, diet, or timing decisions.

## Source triage

The [FDA final CM&S credibility guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions)
uses a question-of-interest and context-of-use-specific, risk-informed
framework. Its worked framework separates model risk, prospective credibility
goals, planned evidence, prospective adequacy assessment, evidence generation,
and post-study adequacy assessment. Code verification or a matching digest is
therefore not a substitute for scientific validation or an adequacy decision.

The [ASME V&V 40-2018 official summary](https://www.asme.org/codes-standards/find-codes-standards/assessing-credibility-of-computational-modeling-through-verification-and-validation-application-to-medical-devices)
says credibility should be commensurate with model reliance and the consequence
of an incorrect decision. The public summary also says the standard is a
framework, not a step-by-step validation method or universal numerical score.
The full standard is licensed; ParkinSUM reviewed only the public official
summary and does not claim conformance.

The [EMA PBPK reporting guideline](https://www.ema.europa.eu/en/reporting-physiologically-based-pharmacokinetic-pbpk-modelling-simulation-scientific-guideline)
ties platform qualification to an intended use and a specific platform
version. Its reporting boundary motivates explicit version and intended-use
identity, but it does not qualify ParkinSUM and it does not make the current
heuristic trace a PBPK model.

These sources are used by inference as governance design inputs. None is
scientific evidence for ParkinSUM's gastric, absorption-opportunity, amino-acid
competition, conflict, or candidate-scoring equations.

## Current implementation

The schema-v1 context-of-use requalification ledger now binds the current
applicability manifest, complete algorithm configuration identity, initial
semantic diff, affected providers and predicates, evidence registries, evidence
lane decisions, release artifact, disposition, and record digest.

The current record pins configuration identity
`56cf755398784e7067c32bc1eb1d197f2b2c737868b6b015aaa431018959ceaf`
(`2026.09.02-v40`) and registered source-bundle digest
`fc9eebdaa016136f558f4a07c7c0b70254092633a25ca1bf26312a104a9d4bdf`.
Ledger version `2026.09.02-v37` records exact completeness witnesses
for gastric emptying and levodopa absorption opportunity, while retaining the
legacy scorer's incomplete status in the governed source chain. It does not
convert prototype parameters, structures, heuristic weights or thresholds into
scientific or clinical validity. The release gate now proves two independent
facts:

1. ledger identity and structure match the exact current governed runtime; and
2. promotion remains blocked while required evidence is incomplete.

The v39 change adds a fixed, black-box production check for the
catalog-to-candidate truth boundary. Under the USDA
[Foundation Foods](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/),
[Global Branded Foods](https://fdc.nal.usda.gov/GBFPD_Documentation/), and
[FDC API](https://fdc.nal.usda.gov/api-spec/fdc_api.html) source contract plus
the [BIPM SI Brochure](https://www.bipm.org/en/publications/si-brochure/), it
tests missing-marker precedence, true-zero preservation, and
`N=(V×W)/100` only for an exact grams-per-100-g basis. It holds
`per_100mL`, unknown unit/basis, and invalid source or serving values because no
density is declared. This expands internal code/calculation evidence to 23/23
specifications and 22/63 mathematical/unit algorithm coverage; together with
8/63 direct executable-contract coverage, the deduplicated result is 30/63 and
33 remain uncovered. It does not establish that upstream metadata is always
correct, provide an external reproduction or typed quantity algebra, or
requalify biological or clinical validity.

The Algorithm Observatory renders those facts independently. `LEDGER INTEGRITY
VERIFIED` must never be presented as scientific validity or promotion approval.

## Known limits

- The ledger is an immutable in-code baseline, not yet a durable append-only
  multi-release store.
- Reviewer identity is descriptive and not backed by a governed authority,
  signature, key-rotation, or compromise-recovery system.
- Five required lanes remain incomplete: uncertainty assessment, human
  factors, scientific validation, model qualification, and independent review.
- There is no governed equivalence decision allowing old evidence to carry to
  a changed formulation, route, population, observable, provider graph,
  parameter source, or decision influence.
- Rollback and revocation semantics are represented but are not yet exercised
  through durable partial-deployment and offline-recovery workflows.

## Future P0: prospective credibility plan and adequacy gate

The current evidence matrix is retrospective status metadata. A complete
credibility workflow also needs a versioned plan created before evidence is
generated. The new queue item
`prospective_model_credibility_plan_and_post_study_adequacy_gate` requires:

- an explicit question of interest, context of use, model influence, decision
  consequence, overall model risk, and release identity;
- per-factor prospective credibility goals with gradation, rationale, planned
  activity, acceptance criterion, observable, dataset identity, independence,
  reviewer, expiry, and applicability boundary;
- a signed prospective adequacy decision before evidence collection and a
  separate post-study adequacy decision after results are available;
- preservation of unmet, contradictory, failed, stale, or out-of-scope results
  without averaging them into a score;
- fail-closed linkage from every changed provider, predicate, parameter,
  formulation, population, observable, or decision-influence claim to the exact
  plan revision that governs it;
- UI and release reports that show planned, executed, passed, failed, held, and
  not-applicable states separately from validation, qualification, regulatory
  review, and approval.

Until that item is implemented and backed by real independent evidence, the
correct outcome remains an inspectable research trace with explicit abstention
and promotion disabled.

## 2026-09-28 configuration-identity hold

At the 2026-09-28 checkpoint, the default algorithm configuration identified version
`2026.09.28-v51` with SHA-256
`547c92ae42945b10f91b484e194973f8701fb57f2fb1018bcfca0d31ac71978a` and
registered source bundle
`8f203376fadadb6fb5edb05c26f51bd0225f8a3741b7c991d0a18ba72fd49758`. This
identity adds an explicit prototype-heuristic provenance record for the
dosage-note grammar. It does not change the parser's output contract, a clinical
formula, or an algorithm result.
The v51 manifest records both the `protein_trend` provider and its effective-time,
protein-value, ordering, and per-meal mean contract, with meal and output-point
sources directly bound. It also binds a standalone synthetic `dosage_note_parser`
trace provider; the syntax probe is not the medication context for downstream
Observatory traces. The immutable ledger remains on its original v41 pin and
continues to fail closed against current identity.

On 2026-09-29 the default identity advanced to `2026.09.29-v52`
(`77d2a1d030443c12f125e0ee9606f25a085dab76ef73d7a20fb62d7c9019a99d`, source
bundle `15a293f7efa3501b0d206570d651b1abecc828e2d796751debd5225cece4bd6d`).
This identity adds an offline evidence-currency gate and per-result receipt
binding the registry and snapshot digests, as-of time, providers, claims, and
disposition. The receipt is unsigned; it does not close the ledger's missing
append-only transition or independent-review evidence.

The immutable ledger still records configuration
`918baef0e5864928bcd20b8e8e855280f8fc1a306b956110498f9d7b06997940` at
`2026.09.21-v41`. The current evidence-synthesis registry digest is
`3c64c10bc76d1307bf7bdaf16abf8e33b21028929c369cf660cb6296f3f9292c`, while
the initial record pins
`b875cc6686bf56bb12822495ea538977304554d5044a7b83177198c215d431f7`.
The current default therefore reports four findings:
`ledger.current_configuration_identity_mismatch` and
`ledger.latest_configuration_mismatch`, plus
`ledger.evidence_synthesis_registry_identity_mismatch` and
`ledger.latest_evidence_synthesis_registry_mismatch`. This is an intentional
hold: no append-only transition record or independent review has been supplied
for these current identity shifts. The original pins are preserved as
historical evidence, and the current ledger must not be called
integrity-verified until a proper transition record binds the exact prior and
new identities and review state. This increment adds parser grammar identity
and provenance without changing a clinical formula or algorithm output; the
evidence-registry transition's provenance remains unresolved. Promotion stays
blocked, and the missing scientific, model-qualification, human-factors,
uncertainty, and independent-review evidence is unchanged.
