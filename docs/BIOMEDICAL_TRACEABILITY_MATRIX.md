# Biomedical Opportunity Traceability Matrix & Risk Register

> Research-and-planning artifact. Links every proposed opportunity to its
> authoritative source, the app layer it touches, the metadata it requires, the
> **test artifact** that would prove it, the **safety control** that bounds it,
> and the **acceptance signal** that closes it — then registers the risks of
> doing the work and how each is mitigated. Nothing here changes intended use.
>
> Companions: `BIOMEDICAL_ENGINEERING_OPPORTUNITY_MAP.md` (rationale),
> `BIOMEDICAL_STANDARDS_CONFORMANCE_SCORECARD.md` (baseline),
> `design/SPIKE_FDC_FOUNDATION_PROVENANCE.md` (top item),
> `BIOMEDICAL_ENGINEERING_BACKLOG.md` (issue text).

## 1. Why this document exists (gap vs. the prior pass)

The opportunity map listed *what* and the backlog listed *how*, but nothing tied
each opportunity end-to-end to a **named test** and a **named safety control**,
and there was no **risk register**. For an engineering plan to be actionable and
auditable, each row must answer: *if we build this, which test proves it works,
which control proves it stayed safe, and what does "done" look like?* This
document is that spine.

## 2. Safety boundary reminder

Educational / research prototype; **not a medical device**. No diagnosis,
treatment, timing, diet, or clinical decision support. Synthetic / public-schema
data only; dose passes through only from explicit user entry; missing ≠ zero; no
live ingestion without opt-in + license review; AI never decides inside the
conflict engine; no claim of clinical validation/calibration.

## 3. Traceability matrix

Columns: **OPP** = opportunity id (from the map) · **Source** = authoritative
basis · **Layer** = app layer touched · **Required metadata** · **Test artifact**
= the test that proves it (new or existing) · **Safety control** = the guard that
keeps it in-bounds · **Acceptance signal** = observable "done" · **State** =
shipped / ready / blocked.

| OPP | Source | Layer | Required metadata | Test artifact | Safety control | Acceptance signal | State |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **D4** clinical-calibration guardrail | FDA CDS criteria (2022 final) | replay runner (read-only) | none | `mechanistic_replay_runner_test.dart` calibration cases | every case asserts `not_clinically_calibrated` + `live_fetch_enabled==false` | all cases carry the guardrail; banned-phrase scan clean | **shipped** (prior PR) |
| **F3** FAIR source-ref traceability | FAIR (Wilkinson 2016) | mechanism layer + registry | `sourceId` per assumption | `source_ref_traceability_test.dart` (**new this pass**) | every emitted `sourceRef` resolves in `ModelAssumptionRegistry` | test passes; no unresolvable ref | **shipped (this pass)** |
| **B1** FDC FoodNutrient provenance | USDA FDC OpenAPI; Foundation Foods docs | nutrition importer → `FoodVariantMetadata` → completeness gate | derivation code, dataPoints, dataType, basis | new FDC fixture parser test (synthetic) | provenance only; missing→lower completeness, never fabricated | derivation+sample+dataType in trace for synthetic Foundation food; missing recorded missing | **ready** (spike written) |
| **B2** fuller FDC amino-acid coverage | USDA FDC OpenAPI | `AminoAcidExtractor` → `AminoAcidProfile` | nutrient number, unit, basis, partial flag | extend `amino_acid_extraction_test.dart` | missing AA stays null; partial widens uncertainty | full LNAA set parsed when present; partial flagged | **ready** |
| **A1** SPL/SmPC section provenance | DailyMed SPL WS v2; FDA SPL + LOINC | SPL adapters → `DrugProductVariantMetadata` | section LOINC, setId, version, effectiveDate | new SPL fixture parser test | metadata only; mechanism still needs label text | section LOINC+version+date in trace; missing→missing | ready |
| **A2** release/dose-form/combination extraction | DailyMed SPL WS v2; EMA ePI | importer → variant metadata → absorption model | dose form, release type, per-ingredient strength | fixtures for IR/ER/3-component combo | never default a release type; unknown→wider uncertainty | release type drives openness profile; missing→insufficient | ready |
| **A3** RxNorm/ATC identity | RxNorm RxNav/RxClass (ATCPROD) | crosswalk / authority scorer (identity) | RxCUI, ATC L1–4, tty | new RxNav fixture mapping test | identity only; explicitly not a mechanism source | synthetic RxNav JSON → RxCUI+ATC; no food-effect derived | ready |
| **C1** enteral feeding educational scenario | Leta 2023; npj/Virmani 2023; SPL | replay scenarios + enteral context | feed mode, protein g/day (synthetic), refs | replay scenario + banned-phrase scan | educational caution only; "review with a professional"; no schedule | scenario runs, carries refs + caution, no prescriptive copy | partial (placeholder) |
| **C2** iron/mineral co-event caution | Leta 2023 + a verified iron–levodopa citation | conflict engine co-event trace | co-event substance, refs, caution text | replay scenario + safety-phrase test | caution only if source-backed; no interaction score | caution appears only when cited; non-prescriptive | **blocked** (needs citation) |
| **C3** MAO-B/tyramine caution | MAO-B SmPC/SPL + verified tyramine ref | educational caution copy + scenario | refs, jurisdiction, caution text | safety-phrase + source-presence gate test | no caution without source; no diet rule implied | gated on verified source; no diet prescription | **blocked** (needs citation) |
| **C4** ER multi-dose stress tests | DailyMed ER label; Leta 2023 | replay + engine tests | release type, synthetic dose offsets | extend engine/replay tests | educational simulation only | ER widens/flattens window; max-overlap holds | ready |
| **D1** source-quality perturbation | FAIR; internal scorer | replay runner + scorer (read-only) | candidate metadata variants | new perturbation scenarios in replay test | tests only; no behavior change | lower-authority variant never outranks high-conflict; deterministic | ready |
| **D2** missingness stress suite | FDC docs; internal normalizer | replay runner | dropped nutrient fields | new missingness scenarios in replay test | tests only; missing≠zero | missing surfaces as missing + lowers confidence | ready |
| **D3** counterfactual A/B pairs | internal | replay runner | paired scenario variants | new paired scenarios | tests only | asserted directional difference per pair | ready |
| **F1** FHIR-inspired MedicationKnowledge | FHIR R5; RxNorm | serialization view over variant metadata | code(RxCUI/ATC), doseForm, ingredient, refs | mapper unit test (synthetic) | "inspired, non-conformant"; no subject/PHI | deterministic mapping to FHIR element names | ready |
| **F2** FHIR-inspired NutritionIntake/Observation | FHIR R5; INFOODS | serialization view over composition | consumedItem.type, amount, rate, ingredientLabel | mapper unit test (synthetic) | no `subject`/Patient; synthetic only | deterministic mapping; subject omitted | ready |
| **B3** INFOODS tagnames | FAO/INFOODS | nutrition metadata + provenance sidecar | tagname, expression/definition, confidence | mapping unit test | documentation/standardization only | nutrient lines carry tagname; doc'd mapping | ready |
| **B4** prepared/raw/branded + decomposition | FDC dataType; INFOODS food matching | `FoodItem.preparationState/basisType` → component | dataType, prep state, basis | fixture per data type | missing prep→unknown, not guessed | form/water flow into composition | ready |
| **E1** synthetic wearable/gait replay | Daphnet FoG (CC BY 4.0); WearGait-PD (shape only) | NEW isolated module (decoupled) | synthetic signal spec, sampling rate, window cfg | deterministic feature tests + non-diagnostic copy assertions | NO PD detection/monitoring; synthetic only; isolated from medication logic | feature pipeline runs on synthetic signals; isolation test passes | **deferred** (P3, large) |

## 4. Dependency / sequencing graph

```
Phase α (this pass, safe/doc/test)
  F3 traceability guard  ──┐
  D4 calibration guard ────┼──► baseline locked
  (scorecard, matrix, spike, biblio)

Phase β (bounded importer/test)         Phase γ (standards views)
  B1 FDC provenance ──► B2 fuller AA      A3 RxCUI/ATC ──► F1 MedKnowledge code
  D1 perturbation                         F2 NutritionIntake (no subject)
  D2 missingness                          B3 INFOODS tagnames
  C1 enteral (placeholder→full)           B4 prepared/raw/branded
  A1 SPL section ──► A2 release/combo      S8 OMOP concept demo (identity only)

Blocked (need verified citation first)   Deferred (large, isolated)
  C2 iron co-event                         E1 synthetic wearable/gait
  C3 MAO-B/tyramine
```

Critical-path notes: **F1 depends on A3** (a coded `code` needs RxCUI/ATC).
**B2 depends on B1's** basis/derivation plumbing. **C2/C3 are hard-blocked** on a
verified, non-prescriptive citation — do not implement without one.

## 5. Risk register

Likelihood / Impact scale: L = low, M = medium, H = high. "Impact" weighs the
**safety-boundary** and credibility cost, not just engineering cost.

| Risk | Likelihood | Impact | Mitigation | Residual |
| --- | --- | --- | --- | --- |
| **R1 — Overclaiming standards conformance** (someone reads "FHIR mapping" as "FHIR-conformant / clinically interoperable") | M | H | Scorecard caps at 🟢 *Inspired-Aligned*; every mapper labeled "inspired, non-conformant"; no certification language anywhere | L |
| **R2 — PHI leakage via FHIR `subject`** (NutritionIntake/Observation are patient-centric) | M | H | Mapping spec **omits `subject`/Patient**; synthetic-only tests; banned-phrase + no-PHI assertions | L |
| **R3 — Citing an unverifiable source date** (e.g., asserting an exact FDA 2026 date that secondary sources dispute) | M | M | Anchor on the verifiable 2022 final guidance; flag the 2026 revision as *reported, not independently verified here*; never assert an unconfirmed date as fact | L |
| **R4 — Fabricating missing provenance** (inventing a sample count / analytical method when FDC omits it) | L | H | "Missing ≠ zero" invariant; provenance fields nullable; tests assert missing→lower completeness, never higher confidence | L |
| **R5 — Mechanism overreach in an educational caution** (iron / tyramine becoming a de-facto diet rule) | M | H | C2/C3 hard-blocked on a verified citation; caution copy gated on source presence; safety-phrase test; "review with a qualified professional" | L (while blocked) |
| **R6 — Hidden dose default via importer realism** (release/strength extraction silently defaulting) | L | H | Dose passthrough invariant + existing `dosage_passthrough_test.dart`; unknown release/strength → wider uncertainty / insufficient, never a default | L |
| **R7 — Wearable layer implying PD detection/monitoring** | M (if built) | H | E1 deferred; if built, a **separate isolated module**, synthetic signals only, explicit "no PD detection/monitoring" copy + isolation test; never wired to medication logic | L (deferred) |
| **R8 — License/terms violation from live ingestion** | L | H | No live ingestion by default; opt-in smoke fetches metadata only, never stores raw payloads; per-source license-review gate in `SOURCE_ACCESS_AND_LICENSES.md` | L |
| **R9 — Source-ref drift** (engine emits a `sourceRef` with no registry entry → broken evidence link) | M | M | **Traceability guard test shipped this pass** fails CI on any unresolvable mechanism-layer ref | L |
| **R10 — Scope creep on a "planning" pass** (turning research into a broad refactor) | M | M | This pass ships docs + one bounded test + one stale-entry fix only; larger items stay in the backlog with explicit "not in scope" | L |

## 6. Definition of done (per opportunity type)

- **Importer field (A1/A2/B1/B2/B4):** synthetic fixture parser test green;
  new field flows into the trace; missing→recorded missing (never 0);
  `sourceRef` resolves in the registry; banned-phrase scan clean.
- **Replay/validation (C1/C4/D1/D2/D3):** scenario uses explicit synthetic data;
  asserts expected output type / severity / confidence / provenance; deterministic.
- **Standards view (F1/F2/F3):** deterministic mapper unit test on synthetic
  input; "inspired, non-conformant" label; no `subject`/PHI; no behavior change.
- **Caution (C2/C3):** **verified citation present**; copy gated on source;
  safety-phrase + source-presence tests; non-prescriptive.
- **Showcase (E1):** isolated module; synthetic signals; non-diagnostic copy +
  isolation tests; zero coupling to medication/conflict logic.
