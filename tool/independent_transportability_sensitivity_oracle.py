#!/usr/bin/env python3
"""Independent stdlib oracle for synthetic transportability sensitivity cases.

This script deliberately imports no ParkinSUM production module or golden file.
It independently restates the manufactured bias-function sign convention and
the complete finite parameter grid used by the release gate.
"""

import json


NAIVE_EFFECT = 0.18
DECISION_THRESHOLD = 0.10
U0_VALUES = (-0.08, 0.0, 0.08)
DELTA_VALUES = (-0.12, -0.08, -0.04, 0.0, 0.04, 0.08, 0.12)
SLOPE_VALUES = (-0.06, -0.03, 0.0, 0.03, 0.06)
MEASUREMENT_VALUES = (-0.04, -0.02, 0.0, 0.02, 0.04)
CORRELATION_VALUES = (-0.75, -0.375, 0.0, 0.375, 0.75)


def weighted_bias(delta, slope, measurement, correlation):
    return delta + 0.5 * slope + measurement * (1.0 + 0.25 * correlation)


def adjusted_effect(delta, slope=0.0, measurement=0.0, correlation=0.0):
    return NAIVE_EFFECT - weighted_bias(delta, slope, measurement, correlation)


def admissible(u0, delta, slope, measurement, correlation):
    bias = weighted_bias(delta, slope, measurement, correlation)
    u1 = u0 + delta
    return abs(u1) <= 0.18 + 1e-12 and abs(bias) <= 0.20 + 1e-12


def main():
    cases = {
        "no_violation": adjusted_effect(0.0),
        "decision_tipping": adjusted_effect(0.08),
        "null_crossing": adjusted_effect(0.12, 0.06, 0.04, 0.75),
        "protective_shift": adjusted_effect(-0.08),
        "measurement_only": adjusted_effect(0.0, 0.0, 0.04, 0.0),
        "dependent_modifiers": adjusted_effect(0.04, 0.06, 0.02, 0.75),
    }
    effects = []
    total = 0
    excluded = 0
    decision_tipping = 0
    null_crossing = 0
    for u0 in U0_VALUES:
        for delta in DELTA_VALUES:
            for slope in SLOPE_VALUES:
                for measurement in MEASUREMENT_VALUES:
                    for correlation in CORRELATION_VALUES:
                        total += 1
                        if not admissible(
                            u0, delta, slope, measurement, correlation
                        ):
                            excluded += 1
                            continue
                        value = adjusted_effect(
                            delta, slope, measurement, correlation
                        )
                        effects.append(value)
                        if value <= DECISION_THRESHOLD + 1e-12:
                            decision_tipping += 1
                        if value <= 1e-12:
                            null_crossing += 1
    output = {
        "cases": cases,
        "grid": {
            "total_points": total,
            "admissible_points": len(effects),
            "excluded_points": excluded,
            "lower_effect": min(effects),
            "upper_effect": max(effects),
            "decision_tipping_points": decision_tipping,
            "null_crossing_points": null_crossing,
        },
        "imports_production_code": False,
        "imports_golden_outputs": False,
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
