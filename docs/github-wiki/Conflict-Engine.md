# Conflict engine

<p align="center"><img src="https://raw.githubusercontent.com/albertzhzhou-droid/ParkinSUM/main/docs/github-wiki/assets/pipeline.svg" width="960" alt="Five layers in order: meal composition, gastric emptying, absorption window, LNAA competition, result. A separate interdependency layer lowers confidence from high to medium while the score stays unchanged."></p>

The engine answers one narrow, educational question: in this synthetic timeline, how much do a meal's modelled stomach residence and amino-acid load overlap the modelled absorption window of a logged levodopa event? The answer is a **unitless overlap proxy** with a confidence band and a trace. It is not an absorbed fraction or a prediction for a person, and it is not a timing suggestion.

## Layers

| # | Layer | Records in the trace |
| --- | --- | --- |
| 1 | Meal composition | Completeness, missing fields, physical form |
| 2 | Gastric emptying | Per-component lag and half-time; liquids with energy are calorie-regulated (2.13 kcal/min); overlap with earlier meals |
| 3 | Absorption window | Openness profile around the logged event |
| 4 | LNAA competition | Load factor, data mode (actual / hybrid / proxy), coverage, pressure curve shaped by protein arrival (water cannot move it) |
| 5 | Interdependency | Food-borne L-dopa, dry vs cooked state, energy identity, **source-record identities** |

## Confidence is capped, the score is not touched

The interdependency layer can only add uncertainty. Each case adds a machine-readable reason and, when it affects a scored meal, caps *high* confidence at *medium*:

- `food_intrinsic_levodopa_unquantified`: broad beans or Mucuna in the timeline. The model never converts food L-dopa into a dose equivalent.
- `food_preparation_state_ambiguous`: a logged protein amount whose dry/cooked state is unstated (×2–5 difference).
- `food_reference_record_identity_finding`: the official record of a scored reference food breaks a definitional identity on an engine input (energy, proximates, carbohydrate fractions, lipid classes, nitrogen). Twelve catalog foods are affected, e.g. whole milk (sugars as lactose monohydrate).

## LNAA trace detail

With complete amino-acid fields for the whole meal, the LNAA summary also lists each component's competing-LNAA grams and its share of the total, an extended sum that adds methionine and histidine, and, only when a dose was explicitly logged, the molar LNAA : levodopa ratio. These values are descriptive only. They never feed the score and are not thresholds.

<p align="center"><img src="https://raw.githubusercontent.com/albertzhzhou-droid/ParkinSUM/main/docs/github-wiki/assets/identities.svg" width="960" alt="Three identity checks: energy from macronutrients, parts within a whole with a pinned milk-sugar finding, and vitamin A retinol activity equivalents."></p>

Read more: [docs/CONFLICT_ENGINE_MODEL.md](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/CONFLICT_ENGINE_MODEL.md)
