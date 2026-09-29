#!/usr/bin/env python3
"""Independent stdlib-only manufactured transportability calculations.

This file intentionally imports neither ParkinSUM production code nor golden
outputs.  It restates a finite synthetic stratified problem so the Dart
implementation can be checked by a separately authored calculation.
"""

import json


TRIAL_COUNTS = (80, 70, 50, 30, 20, 10)
TARGET_COUNTS = (60, 60, 60, 60, 60, 60)
CONTROL_MEANS = (0.20, 0.23, 0.26, 0.29, 0.32, 0.35)
TREATMENT_EFFECTS = (0.08, 0.12, 0.16, 0.20, 0.24, 0.28)


def weighted_mean(values, weights):
    return sum(value * weight for value, weight in zip(values, weights)) / sum(weights)


def estimate(*, sampling_correct, outcome_correct):
    target_truth = weighted_mean(TREATMENT_EFFECTS, TARGET_COUNTS)
    trial_effect = weighted_mean(TREATMENT_EFFECTS, TRIAL_COUNTS)
    outcome_effects = TREATMENT_EFFECTS if outcome_correct else (trial_effect,) * 6
    sampling_weights = (
        tuple(target / trial for target, trial in zip(TARGET_COUNTS, TRIAL_COUNTS))
        if sampling_correct
        else (1.0,) * 6
    )
    weighted_trial_counts = tuple(
        count * weight for count, weight in zip(TRIAL_COUNTS, sampling_weights)
    )
    outcome_regression = weighted_mean(outcome_effects, TARGET_COUNTS)
    inverse_odds = weighted_mean(TREATMENT_EFFECTS, weighted_trial_counts)
    residual_effects = tuple(
        truth - modeled for truth, modeled in zip(TREATMENT_EFFECTS, outcome_effects)
    )
    augmented = outcome_regression + weighted_mean(residual_effects, weighted_trial_counts)
    return {
        "truth": target_truth,
        "trial_only": trial_effect,
        "outcome_regression": outcome_regression,
        "inverse_odds_sampling": inverse_odds,
        "augmented_inverse_odds": augmented,
    }


def main():
    cases = {
        "both_models_correct": estimate(sampling_correct=True, outcome_correct=True),
        "sampling_model_misspecified": estimate(
            sampling_correct=False, outcome_correct=True
        ),
        "outcome_model_misspecified": estimate(
            sampling_correct=True, outcome_correct=False
        ),
        "both_models_misspecified": estimate(
            sampling_correct=False, outcome_correct=False
        ),
    }
    print(
        json.dumps(
            {
                "schema": "parkinsum.independent-target-transportability-oracle/1",
                "language": "python-stdlib-only",
                "imports_production_code": False,
                "imports_golden_outputs": False,
                "cases": cases,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )


if __name__ == "__main__":
    main()
