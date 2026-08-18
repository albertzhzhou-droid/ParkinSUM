# Local AI Scenario Replay — Reviewer Report

Dataset version: `local-ai-replay.2026-06.v1`

Educational prototype; synthetic fixtures only. This replay runs the same conservative + hybrid recommendation orchestrators the app uses, with an offline scripted Local AI stand-in. It is engineering review material, not medical advice and not a clinical evaluation.

## How to read this report

- **Invariant checked:** the Local AI path may only *reorder* the deterministic candidate whitelist. "AI preserved candidate set: yes" means no candidate was invented or dropped; a "NO" means the safety invariant was violated and the run fails.
- **Gate reasons:** when present, the deterministic safety gate held the conservative ranking and Local AI was limited to wording polish.
- **Drift:** this artifact is timestamp-free and deterministic. The committed baseline is `test/goldens/recommendation_scenario_replay.md`, checked on every run by `flutter test test/goldens_test.dart` (also part of `npm run verify:all`). If a regenerated report differs from it, engine/gate/scenario behaviour changed and the diff should be reviewed, not regenerated away.

Candidate-set invariant held for all cases: **yes**

## replay_missing_medication_time_or_dose

**Missing medication time/dose keeps the conservative path**

_Archetype:_ A medication intake is logged without a parsable dose and the meal has no next-meal window. The data-quality gate keeps the conservative ranking, so Local AI may polish wording but must not rerank.

| Field | Value |
| --- | --- |
| Focus tags | missing_medication_time_or_dose |
| Deterministic ranking | food_oats → food_banana → food_apple |
| AI ranking | food_oats → food_banana → food_apple |
| Decision path | `conservative_safety_gate` |
| Local AI used | no |
| Gate reasons | The expected next-meal time window is missing. Add the earliest and latest next-meal time in Add/Edit Meal. |
| AI preserved candidate set | yes |
| Expected top ids matched | food_banana |
| Expected top ids missing | food_apple |

_Local AI was limited to wording polish here: the deterministic gate held the conservative ranking._

_Safety note: synthetic educational fixture. Deterministic rules remain the source of truth; this report is engineering review material and not medical advice._

## replay_low_risk_next_meal

**Low-risk next meal allows safe Local AI reranking**

_Archetype:_ No medications and a clear next-meal window. Safety checks permit Local AI reranking, limited to the already-safe candidate whitelist (and nothing else).

| Field | Value |
| --- | --- |
| Focus tags | low_risk_next_meal |
| Deterministic ranking | food_banana → food_blueberry → food_apple |
| AI ranking | food_apple → food_blueberry → food_banana |
| Decision path | `hybrid_local_ai` |
| Local AI used | yes |
| Gate reasons | none |
| AI preserved candidate set | yes |
| Expected top ids matched | food_apple |
| Expected top ids missing | food_banana |

_Local AI was allowed to reorder the safe whitelist only; the deterministic candidate set and decisions stayed authoritative._

_Safety note: synthetic educational fixture. Deterministic rules remain the source of truth; this report is engineering review material and not medical advice._

## replay_source_fallback_partial_provenance

**Source fallback keeps a transparent conservative ranking**

_Archetype:_ Candidates resolve through jurisdiction fallback with capped synthetic provenance, and Local AI consent is off. The deterministic conservative path is recorded unchanged.

| Field | Value |
| --- | --- |
| Focus tags | source_fallback_partial_provenance |
| Deterministic ranking | food_banana → food_tofu → food_brown_rice |
| AI ranking | food_banana → food_tofu → food_brown_rice |
| Decision path | `conservative_cdss` |
| Local AI used | no |
| Gate reasons | 用户尚未启用本地 AI 重排。 |
| AI preserved candidate set | yes |
| Expected top ids matched | food_banana |
| Expected top ids missing | none |

_Local AI was limited to wording polish here: the deterministic gate held the conservative ranking._

_Safety note: synthetic educational fixture. Deterministic rules remain the source of truth; this report is engineering review material and not medical advice._

## replay_safety_gate_blocks_local_ai

**Low-quality meal time blocks Local AI reranking**

_Archetype:_ The only meal time is a legacy-migrated value of unknown precision. The gate treats it as too low-quality to rerank against, so Local AI reranking is blocked even though the user consented.

| Field | Value |
| --- | --- |
| Focus tags | safety_gate_blocks_local_ai |
| Deterministic ranking | food_oats → food_banana → food_tofu |
| AI ranking | food_oats → food_banana → food_tofu |
| Decision path | `conservative_safety_gate` |
| Local AI used | no |
| Gate reasons | The latest meal still uses migrated legacy timing; edit it to the real eating time. |
| AI preserved candidate set | yes |
| Expected top ids matched | none |
| Expected top ids missing | food_banana |

_Local AI was limited to wording polish here: the deterministic gate held the conservative ranking._

_Safety note: synthetic educational fixture. Deterministic rules remain the source of truth; this report is engineering review material and not medical advice._

## replay_medication_catalog_selection_context

**Medication catalog selection flows into a safe AI path**

_Archetype:_ An active medication catalog selection with low-risk candidates and consent enabled. The medication context flows into the safe AI path; the rerank is still whitelist-bound.

| Field | Value |
| --- | --- |
| Focus tags | medication_catalog_selection_context |
| Deterministic ranking | food_banana → food_blueberry → food_apple |
| AI ranking | food_apple → food_blueberry → food_banana |
| Decision path | `hybrid_local_ai` |
| Local AI used | yes |
| Gate reasons | none |
| AI preserved candidate set | yes |
| Expected top ids matched | food_apple |
| Expected top ids missing | food_banana |

_Local AI was allowed to reorder the safe whitelist only; the deterministic candidate set and decisions stayed authoritative._

_Safety note: synthetic educational fixture. Deterministic rules remain the source of truth; this report is engineering review material and not medical advice._

