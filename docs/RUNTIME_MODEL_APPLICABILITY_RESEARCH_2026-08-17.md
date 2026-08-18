# Runtime Model Applicability, Abstention, and Decision-Influence Boundary

Date: 2026-08-17

Status: engineering and research boundary; not clinical validation

Applies to: gastric-emptying, levodopa absorption-opportunity, LNAA competition, mechanistic conflict, and candidate-scoring providers

## Decision

The current mechanistic stack may run only as an educational, unitless timing-overlap trace for a narrowly declared carbidopa/levodopa context. It must not predict plasma concentration, absorbed fraction, symptom response, medication timing, dose, or diet. It must not reorder candidate foods.

Passing an applicability gate means only that the input is inside the provider's declared context of use. It does not establish predictive accuracy, clinical suitability, or regulatory acceptance.

The production decision-influence ceiling is therefore:

```text
validated input structure
  -> applicability decision
      -> applicable: educational trace and sensitivity display only
      -> notApplicable: no curve, score, severity, or ranking
      -> insufficient: no curve, score, severity, or ranking
      -> blockedIntegrity: no provider execution
```

## Narrow v1 context of use

The v1 runtime boundary requires all of the following:

- exact component identity for both `carbidopa` and `levodopa`; tags, brands, substrings, and free-text similarity are not ingredient identity;
- no additional active component in the modeled product;
- route `oral`;
- conventional swallowed `tablet` dosage form;
- immediate-release formulation declared by controlled metadata;
- explicit dose and meal timestamps when the relevant provider consumes them;
- a structured meal or an explicitly labelled simulation fixture;
- finite, dimensionally valid quantities when a provider consumes dose or nutrient values.

Product identity, label revision, population, fed-state, terminology version, and provider-manifest digest are not yet fully governed. Until those predicates are implemented, the gate is an important fail-closed improvement but not a complete applicability manifest.

## Four result states

| State | Meaning | Examples | UI and wire behavior |
|---|---|---|---|
| `applicable` | All currently implemented predicates pass | exact carbidopa + levodopa, oral, tablet, immediate release | trace may render; decision influence remains `trace_only` |
| `notApplicable` | A governed value is explicitly outside the v1 domain | ER/CR/DR, capsule, inhaled, enteral, subcutaneous, extra active component | show failed predicates; no numeric result or curve |
| `insufficient` | Required metadata or context is absent, ambiguous, unknown, or unrecognized | missing/unknown route or release, typo, no meal record, unverified ingredient text | show missing predicates; no numeric result or curve |
| `blockedIntegrity` | The executable boundary cannot be trusted | missing/tampered manifest, digest mismatch, unregistered provider or terminology identity | block provider execution and identify the integrity failure |

Unknown is not zero. Missing a meal record does not establish that no food interaction occurred. An abstention must not serialize or display a zero score, `none` severity, empty-risk reassurance, or a ranked recommendation.

Until a governed ingredient terminology and product manifest can prove a non-target substance identity, an arbitrary non-levodopa string remains `insufficient` rather than being promoted to the stronger `notApplicable` claim.

## Evidence map

### Regulatory modeling guidance

- The FDA's 2023 CM&S credibility guidance describes a risk-informed credibility framework for physics-based and mechanistic models. It supports defining the question and context of use, then matching credibility activity to model influence. It does not validate ParkinSUM. [FDA CM&S credibility guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions)
- FDA PBPK reporting guidance says simulation design should specify route, dose, formulation, administration time, and fasting/fed conditions, and says verification must be appropriate for the particular drug product, population, and modeling purpose. [FDA PBPK guidance](https://www.fda.gov/files/drugs/published/Physiologically-Based-Pharmacokinetic-Analyses-%E2%80%94-Format-and-Content-Guidance-for-Industry.pdf)
- EMA PBPK guidance similarly requires documentation supporting platform qualification for an intended use. [EMA PBPK guideline](https://www.ema.europa.eu/en/reporting-physiologically-based-pharmacokinetic-pbpk-modelling-simulation-scientific-guideline)

These sources support the governance pattern. They are not evidence that the present equations are biologically or clinically valid.

### Product identity and formulation

- SINEMET is an immediate-release carbidopa/levodopa tablet. Its label states that levodopa competes with certain amino acids for transport across the gut wall and that absorption may be impaired in some patients on a high-protein diet. This is qualitative support for a possible mechanism, not for ParkinSUM's numeric windows or coefficients. [SINEMET DailyMed label](https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=9b17b028-964a-473c-823d-81423535bd66&version=5)
- RYTARY is an oral extended-release capsule and its dosages are not interchangeable one-to-one with other carbidopa/levodopa products. [RYTARY DailyMed label](https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=6c1f7cd4-de56-45c1-a734-5e77b4aeb6f7)
- CREXONT is also an extended-release capsule but uses a different immediate/extended pellet design. A single generic ER curve cannot truthfully represent both products. [CREXONT DailyMed label](https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=095a08b6-b0b8-4f88-b759-67e8b87287a0)
- DUOPA is enteral suspension administered through a PEG-J system. [DUOPA DailyMed label](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7066d371-dc6a-0d6f-7bed-e5dd4ee912da)
- INBRIJA is an inhaled powder; its capsules are not swallowed. [INBRIJA DailyMed label](https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=077c0f39-a3a2-4b2b-a184-09131889dcfb&type=display)
- VYALEV is a subcutaneous foscarbidopa/foslevodopa infusion and is outside the current compound and route domain. [VYALEV DailyMed label](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=28e806e4-951c-40a9-9f0c-d0929caf054c)
- Stalevo contains entacapone in addition to carbidopa and levodopa, so mere presence of the two target ingredients is insufficient. [Stalevo EMA overview](https://www.ema.europa.eu/en/medicines/human/EPAR/stalevo)

These product differences require exact formulation and component predicates. A substring such as `levodopaLike`, a generic `extended` flag, or a first-medication fallback is not a safe model binding.

### Human evidence and its limits

- Nutt et al. (1984) studied nine selected patients. Food affected plasma levodopa peaks, while high protein could affect clinical response without a corresponding plasma decrease. Absorption and blood-brain-barrier competition therefore cannot be collapsed into one validated coefficient. [PubMed 6694694](https://pubmed.ncbi.nlm.nih.gov/6694694/)
- Doi et al. (2012) reported an association between delayed gastric emptying and delayed levodopa peak in 31 patients. It does not supply an individual prediction equation. [PubMed 22632782](https://pubmed.ncbi.nlm.nih.gov/22632782/)
- Robertson et al. (1991) studied eight healthy volunteers and did not find that a protein meal reduced the rate or extent of levodopa absorption. Population and experimental context materially affect interpretation. [PubMed 2049250](https://pubmed.ncbi.nlm.nih.gov/2049250/)

The current five-minute lag, 90-minute duration, 34-minute illustrative shift, gastric weights, LNAA factors, and conflict/scoring thresholds remain engineering hypotheses unless separately tied to governed calibration data for the declared use.

## Open-source pattern review

No upstream code was copied.

- PK-Sim separates compound, administration protocol, and formulation/dissolution into explicit model building blocks. This supports binding route and formulation as identity, not treating them as loose hints. [PK-Sim administration protocols](https://docs.open-systems-pharmacology.org/working-with-pk-sim/pk-sim-documentation/pk-sim-administration-protocols) and [PK-Sim formulations](https://docs.open-systems-pharmacology.org/working-with-pk-sim/pk-sim-documentation/pk-sim-formulations)
- rxode2 events explicitly carry amount, time, compartment, rate/duration, and units. This supports a typed event boundary before simulation. [rxode2 event types](https://nlmixr2.github.io/rxode2/articles/rxode2-event-types.html)

PK-Sim is GPL-2.0 and rxode2 is GPL-3.0. Only architectural patterns were reviewed; their licenses and scientific claims are not imported into ParkinSUM.

## Git and implementation truth

The public GitHub snapshot and the local worktree must be described separately:

- public GitHub commit `c5f4c894c2c7c05f59f8deed0f99e0c4cb0318f5` still contains the former first-non-levodopa fallback and unknown-release-to-IR behavior;
- the local uncommitted worktree adds exact ingredient tokenization, a narrow IR-tablet policy, fail-closed provider behavior, trace-only ranking influence, and invariant/mutation coverage;
- these local changes are not public until intentionally committed and pushed;
- ignored build outputs and local evidence are not public release evidence.

## Implemented locally in this slice

- exact component tokenization; tags and substrings cannot create levodopa identity;
- exact carbidopa + levodopa combination predicate, including rejection of extra active components;
- oral, tablet, immediate-release-only runtime path;
- unknown and unsupported release types no longer receive an IR-shaped curve;
- non-levodopa timelines no longer fall back to the first medication;
- missing route no longer defaults to oral when a `DrugDefinition` is deserialized;
- the generic built-in carbidopa/levodopa seed no longer claims immediate
  release; it remains `unspecified`, so a package selection without a governed
  formulation snapshot cannot accidentally authorize the IR model;
- the DailyMed importer no longer turns missing release wording into IR or
  matches arbitrary `er` substrings; only explicit immediate-release wording
  can emit `immediate_release`, otherwise the value remains unknown or an
  explicit unsupported formulation;
- DailyMed, Health Canada DPD, EMA, CDSS projection, variant resolution, and
  native legacy-row decoding no longer turn a missing route into `oral`; route
  and dosage form remain separate evidence predicates;
- a concrete package selection that lacks a governed formulation snapshot
  forces route, form, and release back to `unspecified` for modeling, even when
  its parent catalog entry claims IR;
- non-finite strength is rejected;
- attached medication provenance must bind to the same product variant,
  source document, jurisdiction, component set, route, form, and release type
  as the structured model entry; missing bindings or contradictions are
  invalid rather than alternate evidence;
- an unrecorded dose-time meal context is not treated as documented fasting;
  no current started meal evidence means `insufficient` and no curve, and a
  meal older than its explicit gastric-residence horizon cannot unlock one;
- a future candidate meal can contribute to future competition but cannot be
  used as gastric residue to delay an earlier dose's absorption window;
- mixed contexts aggregate conservatively: any unknown, unbound, or
  insufficient predicate takes precedence over a separately known
  out-of-domain predicate, so the whole timeline is not mislabeled as fully
  `notApplicable`;
- empty compositions, missing protein, incomplete timeline events, or a
  missing composition for any contributing meal fail closed instead of
  entering a numeric composite as zero;
- gastric, absorption, LNAA competition, conflict, and candidate providers
  propagate typed availability and serialize abstention numeric fields as
  null with no curve;
- partial amino-acid-profile coverage is explicit hybrid evidence: covered
  components use their profile, uncovered positive-protein components use the
  disclosed source proxy, uncertainty widens, and whole-meal LNAA totals stay
  unavailable rather than falsely precise;
- the competition integral is normalized over the full validated absorption
  openness grid, with zero competition outside the pressure intersection; an
  empty or structurally invalid available curve is `blockedIntegrity`, not a
  flat fallback;
- mechanistic candidate scores remain inspectable trace data but cannot reorder recommendations;
- registry/UI coverage includes the applicability gate as a result-affecting algorithm;
- invariant, unit, metamorphic, and mutation tests exercise the production model boundary.

## Still open

- a versioned, digest-bound provider manifest with product code, label revision, jurisdiction, population, fed-state, time, dose, unit, terminology, and review predicates;
- governed product/component identity instead of synthetic or unspecified source metadata;
- end-to-end persistence of verified product ingredients, route, dosage form,
  release type, label revision, and terminology identity from product picker to
  intake snapshot and model input;
- an explicit, governed fasting-state input if fasting traces are ever needed;
- formulation-specific models backed by appropriate data, if any are added;
- independent mathematical oracles and prospective external validation;
- a live Observatory predicate matrix for every provider and composite;
- complete localization and accessibility review of all abstention states;
- release blocking when a registered provider lacks inside/outside/unknown/integrity fixtures.

Until those items are closed, the correct product claim is an inspectable
educational model trace with explicit abstention. It has not undergone the
clinical validation required for a patient-specific recommendation engine.
