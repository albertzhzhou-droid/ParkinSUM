#!/usr/bin/env python3
"""Independent stdlib-only conjugate oracle for synthetic ParkinSUM fixtures.

This program intentionally imports no ParkinSUM production code or golden data.
It restates the manufactured multi-source weighting and Beta-Binomial equations
in Python so the Dart release gate can compare results across implementations.
It is methodology-governance evidence only, not clinical validation.
"""

from __future__ import annotations

import json
import platform


SOURCES = (
    {
        "id": "ext-trial-a",
        "successes": 18,
        "total": 60,
        "quality": 0.94,
        "relevance": 0.93,
        "completeness": 0.96,
        "overlap": 0.91,
        "temporal_drift": 0.05,
        "missing_fraction": 0.0,
        "bias": 0.04,
        "exchangeability": 1.0,
        "dependency_group": "trial-a",
    },
    {
        "id": "ext-trial-b",
        "successes": 31,
        "total": 100,
        "quality": 0.90,
        "relevance": 0.88,
        "completeness": 0.93,
        "overlap": 0.86,
        "temporal_drift": 0.08,
        "missing_fraction": 0.10,
        "bias": 0.06,
        "exchangeability": 0.75,
        "dependency_group": "trial-b",
    },
    {
        "id": "ext-registry-a-linked",
        "successes": 10,
        "total": 32,
        "quality": 0.84,
        "relevance": 0.82,
        "completeness": 0.88,
        "overlap": 0.79,
        "temporal_drift": 0.12,
        "missing_fraction": 0.20,
        "bias": 0.12,
        "exchangeability": 0.40,
        "dependency_group": "trial-a",
    },
)


def clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def analyze(sources, current_successes: int = 16, current_total: int = 50):
    current_rate = current_successes / current_total
    dependency_sizes = {}
    for source in sources:
        group = source["dependency_group"]
        dependency_sizes[group] = dependency_sizes.get(group, 0) + 1

    rows = []
    for source in sources:
        source_rate = source["successes"] / source["total"]
        conflict = clamp(abs(source_rate - current_rate) / 0.20, 0.0, 1.0)
        conflict_discount = (1.0 - conflict) ** 2
        base = (
            source["quality"]
            * source["relevance"]
            * source["completeness"]
            * source["overlap"]
            * (1.0 - source["temporal_drift"])
            * (1.0 - source["missing_fraction"])
            * (1.0 - source["bias"])
            * source["exchangeability"]
        )
        dependency_discount = 1.0 / dependency_sizes[source["dependency_group"]]
        weight = base * conflict_discount * dependency_discount
        rows.append(
            {
                "source_id": source["id"],
                "source_rate": source_rate,
                "bias_adjusted_rate": source_rate - source["bias"] * 0.05,
                "conflict": conflict,
                "weight": weight,
                "raw_ess": source["total"] * weight,
            }
        )

    raw_total_ess = sum(row["raw_ess"] for row in rows)
    scale = min(1.0, 40.0 / raw_total_ess) if raw_total_ess else 0.0
    alpha = 1.0
    beta = 1.0
    for row in rows:
        row["ess"] = row["raw_ess"] * scale
        alpha += row["bias_adjusted_rate"] * row["ess"]
        beta += (1.0 - row["bias_adjusted_rate"]) * row["ess"]

    posterior_alpha = alpha + current_successes
    posterior_beta = beta + current_total - current_successes
    return {
        "prior_alpha": alpha,
        "prior_beta": beta,
        "prior_ess": alpha + beta - 2.0,
        "posterior_mean": posterior_alpha / (posterior_alpha + posterior_beta),
        "sources": sorted(rows, key=lambda row: row["source_id"]),
    }


def rounded(value):
    if isinstance(value, float):
        return round(value, 12)
    if isinstance(value, list):
        return [rounded(item) for item in value]
    if isinstance(value, dict):
        return {key: rounded(item) for key, item in value.items()}
    return value


def main() -> None:
    without_b = tuple(source for source in SOURCES if source["id"] != "ext-trial-b")
    payload = {
        "schema": "parkinsum.independent-bayesian-multisource-oracle/1",
        "language": "Python",
        "runtime": platform.python_version(),
        "dependency_lock": "python-stdlib-only",
        "cases": {
            "aligned": analyze(SOURCES),
            "leave_one_out_trial_b": analyze(without_b),
            "severe_current_conflict": analyze(SOURCES, current_successes=28),
            "reversed_source_order": analyze(tuple(reversed(SOURCES))),
        },
        "boundary": (
            "Independent manufactured arithmetic only; not Bayesian, scientific, "
            "clinical, causal-transportability, safety, or regulatory validation."
        ),
    }
    print(json.dumps(rounded(payload), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
