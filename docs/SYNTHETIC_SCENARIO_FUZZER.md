# Synthetic Scenario Fuzzer

Educational/research prototype. Synthetic data only. **Not medical advice, not
clinically calibrated, not patient simulation, and carries no clinical-validation
claim.**

## 1. Purpose

The SyntheticScenarioFuzzer generates **deterministic synthetic boundary-case
scenarios** and checks that ParkinSUM's existing deterministic gates respond in a
stable, non-prescriptive way. It protects against boundary regressions in dosage
validation, nutrient missingness, release-type uncertainty, source-quality
provenance, ranker eligibility, and safety-copy / no-PHI behavior.

## 2. Safety boundary

This is **synthetic regression/stress testing**, not a clinical simulator and not
patient generation. It produces **no** real patient data, medication schedules,
diagnosis, treatment, timing/diet instructions, or clinical prediction. It emits
**no** PHI and no patient/subject/encounter keys. It does not modify the core
mechanistic engine, importers, scoring, Firebase rules, or UI.

## 3. What "fuzzing" means here

Inspired by fuzz testing, but adapted to ParkinSUM's safe synthetic-data setting:
invalid / boundary inputs are generated, then the system is checked for
*unacceptable behavior*. "Unacceptable" is **not** "wrong medical answer" — it is:
hidden dosage defaults, missing nutrient treated as zero, an unsafe phrase
emitted, an unexpected ranker switch, source quality ignored, unknown provenance
treated as high confidence, a PHI-like key emitted, or a missing fallback reason.

## 4. What the fuzzer tests

Every generated case is evaluated with **real existing code** (the medication
validator, completeness gate, source-authority scorer, absorption model,
next-meal scorer, the banned-phrase scanner, and a recursive no-PHI key scan).

## 5. What it does not test

It does not assert clinical correctness, patient outcomes, or PK/PD accuracy. It
does not run the full Flutter test suite, fetch the network, or use real data.

## 6. Scenario families

- **A — medication dosage**: unitless, missing, valid explicit, slash-format,
  product-strength-but-unitless. Invariants: unitless/missing stays not-valid; no
  hidden default; product strength is not a user intake dose; valid only with an
  explicit value + unit.
- **B — meal nutrient missingness**: complete, true 0 g protein, missing
  protein/calories/portion. Invariants: missing lowers completeness; **true 0 g is
  not missing**.
- **C — release-type / timeline**: IR baseline, ER/CR wider, unknown widens
  uncertainty, non-levodopa isolated. Invariants: ER/CR window wider than IR;
  unknown widens uncertainty / records limited interpretation; a non-levodopa
  event gets a degenerate passthrough window (no levodopa contamination).
- **D — source quality / provenance**: tier ordering (analytical > calculated >
  imputed > unknown), missing sourceRefs, official-vs-synthetic authority.
  Invariants: tier ordering preserved; missing sourceRefs lower the grade;
  official in-jurisdiction ≥ synthetic.
- **E — window / ranking**: no window → fallback; valid window → scored;
  provenance tie-break with bounded swing. Invariants: no window →
  insufficient context; provenance can break a near-tie; the provenance swing
  stays below the dominant conflict-overlap weight.
- **F — safety-copy / no-PHI**: shared safety copy is clean; the unsafe-phrase
  detector flags injected unsafe text; the key-level scan permits safety-policy
  *values* but flags forbidden *keys*.

## 7. Invariant categories (failure types)

`unexpected_ranker_switch`, `missingness_regression`, `dosage_regression`,
`source_quality_regression`, `unsafe_phrase_hit`, `phi_key_hit`,
`missing_artifact`, `unexpected_exception`.

## 8. How to run

```sh
dart run tool/run_synthetic_scenario_fuzzer.dart           # or: npm run scenario:fuzz
# options:
dart run tool/run_synthetic_scenario_fuzzer.dart --seed=7 --case-count=10 \
  --family=source_quality,medication_dosage
```

Deterministic; no network. Exits non-zero iff a must-pass invariant fails.

## 9. How to inspect output

`build/synthetic_scenario_fuzzer/latest.json` (full report) and `latest.md` (a
table of scenario / family / passed / failed invariants / observed signals plus
seed, case count, and passed/failed totals).

## 10. How failures should be interpreted

A failed case means a **boundary regression** in an existing gate — e.g. a
unitless dose now validates as complete, a missing nutrient is treated as zero, a
weaker provenance tier no longer lowers completeness, or banned/advice copy
leaked. The report names the failed invariant and the observed signal so the
regression can be located. It is **not** a clinical finding.

## 11. Limitations

Deterministic for a given seed; not exhaustive boundary coverage. Synthetic data
only. Not clinical validation; the model is not clinically calibrated. The fuzzer
observes existing gates; it does not change scoring.

## 12. Reviewer checklist

- [ ] `dart run tool/run_synthetic_scenario_fuzzer.dart` exits 0 (all must-pass
      invariants hold).
- [ ] Same seed → identical report JSON; different seed → reordered, still
      deterministic.
- [ ] Unitless/missing dose never validates; product strength never rescues it.
- [ ] Missing nutrient lowers completeness; true 0 g is not missing.
- [ ] Unknown release widens uncertainty; non-levodopa event stays isolated.
- [ ] Tier ordering + official ≥ synthetic hold.
- [ ] No window → fallback; provenance swing bounded below conflict weight.
- [ ] No banned phrases; no forbidden patient/subject/encounter keys emitted.
