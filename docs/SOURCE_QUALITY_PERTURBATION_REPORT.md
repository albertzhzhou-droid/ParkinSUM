# Source-Quality Perturbation Report

Educational/research prototype only. Synthetic inputs only. **Not medical
advice. Not clinically calibrated. Not a clinical dashboard.**

## Purpose

A deterministic, test-backed analysis artifact that shows **how candidate
scoring moves when only source/provenance quality changes**, holding the
meal / conflict / model input constant. It makes the engine's
provenance-sensitivity auditable without any UI and without changing the
scoring algorithm.

## Run it

```sh
dart run tool/run_source_quality_perturbation_report.dart
# or
npm run source:quality
```

Outputs (deterministic):

- `build/source_quality_perturbation/latest.json`
- `build/source_quality_perturbation/latest.md`

The runner reuses `MechanisticNextMealScorer` (it does **not** re-implement
scoring): it fixes one synthetic base context + candidate composition and sweeps
the source/provenance perturbation variables, recording the resulting scores.

## Perturbation families

1. **Provenance / source quality** (meal held constant): official
   in-jurisdiction, official out-of-jurisdiction, synthetic/demo, missing
   sourceRefs, complete vs partial metadata. Only the `CandidateMetadata`
   (`authorityScore` / `jurisdictionMatchScore` / `provenanceQuality` /
   `completeness`) changes.
2. **Amino-acid confidence tier** (metadata held neutral): analytical /
   calculated / imputed-or-assumed / unknown, plus a missing-nutrient-basis
   case. Only the candidate's amino-acid provenance tier changes.
3. **Source authority × nutrient provenance tier** (P5): a synthetic source with
   analytical nutrient provenance vs an official source with imputed provenance —
   demonstrating that *who published the value* (authority) and *how the value
   was derived* (FDC tier) are distinct axes that do not collapse into each
   other.

## Row fields

`case_id`, `input_changed`, `source_system`, `jurisdiction_match`,
`source_authority_score`, `metadata_completeness` (+ `metadata_completeness_score`),
`amino_acid_confidence_tier`, `nutrient_confidence_tier` (P5),
`nutrient_provenance_quality` (P5), `provenance_quality_score` (P5),
`confidence_band` (P5), `nutrient_completeness`, `final_candidate_score`,
`conflict_overlap_score`, `uncertainty_penalty`, `competition_uncertainty_band`,
`lnaa_uncertainty_widened`, `ranker_used`, `explanation`, `safety_boundary`,
`not_clinically_calibrated`.

`nutrient_provenance_quality` is a deterministic 0..1 **source-quality** signal
mapped from the FDC tier (analytical 1.0 / calculated 0.7 / imputed 0.4 /
unknown 0.2) — it describes how the value was derived, **not** clinical or
biological accuracy.

## Invariants (enforced by tests)

- **Deterministic**: identical inputs → identical report.
- **Authority ordering**: official in-jurisdiction scores ≥ a synthetic
  equivalent when the meal/conflict input matches.
- **Missing provenance is recorded, not fabricated**: missing sourceRefs lowers
  provenance quality (and the final score), holding conflict overlap constant.
- **Weaker amino-acid provenance widens uncertainty**: an imputed/assumed (or
  calculated/unknown) tier widens the modeled competition uncertainty band
  relative to analytical (`lnaa_uncertainty_widened = true`).
- **Conflict overlap stays dominant**: the provenance-driven score swing (best
  vs worst provenance on an identical composition) is bounded by the summed
  provenance weights, which the scorer's `conflictRemainsDominant` invariant
  keeps strictly below the conflict-overlap weight. Provenance can break a tie
  when conflict scores are close, but can never overpower a substantial conflict
  gap.
- **No advice**: the report (JSON + markdown) is scanned for banned prescriptive
  substrings; every row carries the shared safety boundary and
  `not_clinically_calibrated = true`.

## Boundary summary

Deterministic educational analysis over synthetic inputs. No PHI, no
patient/subject/encounter, no diagnosis/treatment/medication-timing/dose
guidance, no live ingestion, no UI dashboard. The scoring algorithm is
unchanged; this report only *observes* it.
