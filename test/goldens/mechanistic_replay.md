# Mechanistic Replay Report

Deterministic reference instant: 2026-01-01T08:00:00.000Z (fixed anchor, not the time this report was produced)

**41 / 41 scenarios passed.**

## s01_low_protein_far — Valid catalog-backed levodopa context + small low-protein meal far from medication
- pass: true
- interaction_score: 0.020
- severity_band: low
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=15min uncertainty=narrow
- banned_phrase_hits: 0

## s02_high_protein_close — Valid catalog-backed levodopa context + high-protein solid meal close to medication
- pass: true
- interaction_score: 0.204
- severity_band: moderate
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=16min uncertainty=moderate
- banned_phrase_hits: 0

## s03_high_fat_before — Valid catalog-backed levodopa context + high-fat mixed meal before medication
- pass: true
- interaction_score: 0.201
- severity_band: moderate
- confidence_band: medium
- amino_acid_competition_band: low
- gastric_emptying: lag=20min uncertainty=wide
- banned_phrase_hits: 0

## s04_overlapping_meals — Valid catalog-backed levodopa context + overlapping meals
- pass: true
- interaction_score: 0.204
- severity_band: moderate
- confidence_band: low
- amino_acid_competition_band: low
- gastric_emptying: lag=16min uncertainty=veryWide
- banned_phrase_hits: 0

## s04b_multidose_ir — Two IR levodopa doses; the dose overlapping the high-protein meal drives the score (max-overlap, not averaged)
- pass: true
- interaction_score: 0.204
- severity_band: moderate
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=16min uncertainty=moderate
- banned_phrase_hits: 0

## s05_liquid_meal — Liquid-only meal scenario
- pass: true
- interaction_score: 0.020
- severity_band: low
- confidence_band: high
- amino_acid_competition_band: none
- gastric_emptying: lag=0min uncertainty=narrow
- banned_phrase_hits: 0

## s06_missing_protein — Missing meal protein data
- pass: true
- interaction_score: 0.200
- severity_band: unknown
- confidence_band: low
- amino_acid_competition_band: unknown
- gastric_emptying: lag=16min uncertainty=moderate
- banned_phrase_hits: 0

## s07_missing_meal_time — Missing meal start time
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s08_bare_numeric — Invalid unitless medication entry "100"
- pass: true
- interaction_score: 0.000
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s09_levodopa_no_unit — "levodopa 100" without unit
- pass: true
- interaction_score: 0.000
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s10_slashed_no_unit — "25/100" without catalog normalization
- pass: true
- interaction_score: 0.000
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s11_mixed_solid_liquid — Mixed meal with liquid + solid components
- pass: true
- interaction_score: 0.100
- severity_band: low
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=7min uncertainty=narrow
- banned_phrase_hits: 0

## s12_high_fat_plus_protein — High-fat component + protein component in the same meal
- pass: true
- interaction_score: 0.203
- severity_band: moderate
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=21min uncertainty=moderate
- banned_phrase_hits: 0

## s13_user_window_candidates — User-defined next-meal window with several candidates
- pass: true
- interaction_score: 0.100
- severity_band: low
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=15min uncertainty=narrow
- banned_phrase_hits: 0

## s14_user_window_missing_nutrients — Next-meal recommendation with missing nutrient values and high uncertainty
- pass: true
- interaction_score: 0.100
- severity_band: low
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=15min uncertainty=narrow
- banned_phrase_hits: 0

## s15_multi_point_window_variation — User-defined window that straddles the levodopa absorption window — multi-point sampling should produce varying overlap across the window
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s16_daytime_high_overlap_high_protein — Daytime high-overlap window + high-protein candidate → overlap penalty (NOT a "protein is bad" penalty)
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s17_evening_low_overlap_high_protein — Evening low-overlap window + high-protein candidate → not globally penalized
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s18_zero_vs_moderate_protein_low_overlap — Zero-protein vs moderate-protein in a low-overlap window → zero-protein does not automatically win
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s19_missing_protein_unknown_competition — Candidate missing protein → unknown amino-acid competition
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s20_invalid_medication_no_window_scoring — Invalid medication context → candidate scoring returns insufficient context (no pretended optimization)
- pass: true
- interaction_score: 0.000
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s21_no_user_window_mechanistic_primary_unavailable — No user-defined window → mechanistic-primary unavailable; candidates return insufficient context with a visible reason
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s22_amino_acid_actual_fields_mode — Candidate with actual amino-acid fields → LNAA uses actual-fields mode (preferred over protein-source proxy)
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s23_amino_acid_proxy_mode — Candidate without amino-acid fields → LNAA falls back to protein-source proxy mode
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s24_levodopa_no_unit_invalid — "levodopa 100" without unit → invalid medication context, candidates insufficient
- pass: true
- interaction_score: 0.000
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s25_slashed_no_unit_invalid — "25/100" without catalog normalization → invalid context
- pass: true
- interaction_score: 0.000
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s26_eligible_overwrites_legacy_order — Mechanistic-primary eligible (window + scored candidates) → mechanistic ordering, not legacy heuristic
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s27_amino_acid_food_far_window_actual_mode — Amino-acid-profiled candidate in a far low-overlap window → actual amino-acid mode, redistribution-compatible
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s28_mixed_aa_and_proxy_candidates — Mixed candidate set (amino-acid-profiled + proxy + missing nutrients) → each scored with its own data mode
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s29_bare_numeric_invalid_with_window — Bare numeric "100" with a window → invalid medication context, candidates insufficient (no pretended optimization)
- pass: true
- interaction_score: 0.000
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s30_no_window_fallback_visible — No user-defined window with amino-acid candidate → mechanistic-primary unavailable, fallback reason visible
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s31_daytime_overlap_amino_acid_food — Daytime high-overlap window + amino-acid-profiled candidate → overlap penalty (not a protein-is-bad penalty)
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s32_partial_amino_acid_profile — Candidate with a PARTIAL amino-acid profile → partial data flag + widened uncertainty (not treated as fully narrow)
- pass: true
- interaction_score: 0.000
- severity_band: none
- confidence_band: medium
- amino_acid_competition_band: unknown
- gastric_emptying: no_profile
- banned_phrase_hits: 0

## s33_high_calorie_high_fat_meal — Large high-calorie/high-fat meal close to a dose → gastric uncertainty widened (educational simulation; magnitudes heuristic)
- pass: true
- interaction_score: 0.202
- severity_band: moderate
- confidence_band: medium
- amino_acid_competition_band: low
- gastric_emptying: lag=28min uncertainty=wide
- banned_phrase_hits: 0

## s34_explicit_dose_dose_relative_lnaa — Explicit user-entered dose + actual amino-acid meal → dose-relative LNAA proxy available in the trace (never an invented dose)
- pass: true
- interaction_score: 0.202
- severity_band: moderate
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=16min uncertainty=narrow
- banned_phrase_hits: 0

## s35_missing_calories_and_portion — Protein present but calories + portion missing → lower composition completeness + capped confidence (missing ≠ zero)
- pass: true
- interaction_score: 0.203
- severity_band: moderate
- confidence_band: medium
- amino_acid_competition_band: low
- gastric_emptying: lag=20min uncertainty=wide
- banned_phrase_hits: 0

## s36_missing_all_macros_unknown_competition — All macronutrients missing → unknown competition + insufficient/low confidence (never fabricated)
- pass: true
- interaction_score: 0.200
- severity_band: unknown
- confidence_band: insufficient
- amino_acid_competition_band: unknown
- gastric_emptying: lag=14min uncertainty=veryWide
- banned_phrase_hits: 0

## s37_enteral_continuous_low_protein — Continuous enteral-style feed (low-protein liquid, sustained) — educational context only, no schedule or timing advice
- pass: true
- interaction_score: 0.020
- severity_band: low
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=0min uncertainty=narrow
- banned_phrase_hits: 0

## s38_enteral_bolus_protein — Bolus enteral-style feed (protein-containing liquid) near a dose — educational context only, no schedule or timing advice
- pass: true
- interaction_score: 0.023
- severity_band: low
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=0min uncertainty=narrow
- banned_phrase_hits: 0

## s39_spl_ir_section_provenance — SPL-style IR carbidopa/levodopa with section provenance + 2 components bridged into the mechanistic context (educational)
- pass: true
- interaction_score: 0.204
- severity_band: moderate
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=16min uncertainty=moderate
- banned_phrase_hits: 0

## s40_spl_er_section_provenance — SPL-style ER carbidopa/levodopa with section provenance → wider absorption window from source-backed release type (educational)
- pass: true
- interaction_score: 0.202
- severity_band: moderate
- confidence_band: high
- amino_acid_competition_band: low
- gastric_emptying: lag=16min uncertainty=moderate
- banned_phrase_hits: 0

