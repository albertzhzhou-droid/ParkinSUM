"""Fits the parameters marked `calibrated` in parameters.json.

  python3 -I tool/physiology_reference/calibrate.py           # print fits
  python3 -I tool/physiology_reference/calibrate.py --write   # store them

Each fit uses only its declared calibration target. The remaining published
results are left for reality_checks.py, so they test rather than tune.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from model import at, load_parameters, peak, simulate, values  # noqa: E402
import scenarios  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TOUGAS = {60.0: 0.69, 120.0: 0.24, 240.0: 0.012}
NUTT_DELAY_MIN = 34.0
CARTER = {"high": 732.0, "even": 640.0}
SHAHAM_LEU_FALL = 0.33  # fraction at 120 min after 75 g glucose


def golden(f, lo, hi, iters=40):
    g = (math.sqrt(5) - 1) / 2
    a, b = lo, hi
    c, d = b - g * (b - a), a + g * (b - a)
    fc, fd = f(c), f(d)
    for _ in range(iters):
        if fc < fd:
            b, d, fd = d, c, fc
            c = b - g * (b - a)
            fc = f(c)
        else:
            a, c, fc = c, d, fd
            d = a + g * (b - a)
            fd = f(d)
    return (a + b) / 2


def fit_trituration(v):
    sc = scenarios.tougas_meal()

    def loss(k):
        vv = dict(v, **{"stomach.solid_trituration_rate_per_min": k})
        s = simulate(sc, vv)
        return sum((at(s, "stomach_retention_solid", t) - y) ** 2 for t, y in TOUGAS.items())

    return golden(loss, 0.005, 0.5)


def shaham_fall(v):
    s = simulate(scenarios.shaham_glucose(), v)
    base = float(v["aa.fasting_plasma_umol_per_l"]["leu"])
    return 1.0 - at(s, "leu_umol_per_l", 120.0) / base


def fit_insulin(v):
    lo, hi = 0.0, 1.0  # the fall grows with the maximal reduction
    for _ in range(50):
        mid = 0.5 * (lo + hi)
        if shaham_fall(dict(v, **{"insulin.max_lnaa_target_reduction": mid})) < SHAHAM_LEU_FALL:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def fed_delay(v, f50):
    vv = dict(v, **{"stomach.fed_liquid_slowing_half_kcal": f50})
    fasting, fed = scenarios.nutt_meal_scenarios()
    t0, _ = peak(simulate(fasting, vv), "levodopa_mg_per_l")
    t1, _ = peak(simulate(fed, vv), "levodopa_mg_per_l")
    return t1 - t0


def fit_fed_slowing(v):
    lo, hi = 10.0, 5000.0  # delay decreases as f50 grows
    for _ in range(40):
        mid = math.sqrt(lo * hi)
        if fed_delay(v, mid) > NUTT_DELAY_MIN:
            lo = mid
        else:
            hi = mid
    return math.sqrt(lo * hi)


def carter_daytime_mean(v, diet):
    s = simulate(scenarios.carter_day(diet), v)
    return sum(at(s, "lnaa6_umol_per_l", t) for t in scenarios.CARTER_SAMPLE_TIMES) / len(
        scenarios.CARTER_SAMPLE_TIMES)


def fit_amino_acid_pool(v):
    """Least-squares fit of the effective plasma volume V to Carter's two
    evenly distributed diets.

    Each daytime mean is  M(V) = M_inf + R / V: absorbed amino acids raise
    plasma linearly in 1/V, while the insulin term lowers the relaxation
    target independently of V. M_inf comes from a run with no absorbed rise,
    R from a run with V = 1 L. One parameter, two diets: the residual is a
    genuine test. The evening-restricted diet stays independent.

    The relaxation half-time is NOT fitted: two daily means of evenly spread
    diets cannot identify it, so it stays a declared physiological prior.
    """
    m_inf = {d: carter_daytime_mean(dict(v, **{"aa.plasma_distribution_volume_l": 1e12}), d) for d in CARTER}
    rise = {d: carter_daytime_mean(dict(v, **{"aa.plasma_distribution_volume_l": 1.0}), d) - m_inf[d]
            for d in CARTER}
    target = {d: CARTER[d] - m_inf[d] for d in CARTER}
    if min(target.values()) <= 0:
        raise ValueError("insulin-lowered baseline exceeds a Carter target")
    inv_v = sum(rise[d] * target[d] for d in CARTER) / sum(rise[d] ** 2 for d in CARTER)
    err = sum((rise[d] * inv_v - target[d]) ** 2 for d in CARTER)
    return float(v["aa.plasma_relaxation_half_time_min"]), 1.0 / inv_v, err


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    params = load_parameters()
    v = values(params)

    k_t = fit_trituration(v)
    v["stomach.solid_trituration_rate_per_min"] = k_t
    s = simulate(scenarios.tougas_meal(), v)
    print(f"trituration rate {k_t:.4f}/min; retention " + ", ".join(
        f"{int(t)} min {at(s, 'stomach_retention_solid', t):.1%} (target {y:.1%})"
        for t, y in TOUGAS.items()))

    e_max = fit_insulin(v)
    v["insulin.max_lnaa_target_reduction"] = e_max
    print(f"insulin max target reduction {e_max:.4f}; leucine fall at 120 min {shaham_fall(v):.1%} "
          f"(target {SHAHAM_LEU_FALL:.0%})")

    f50 = fit_fed_slowing(v)
    v["stomach.fed_liquid_slowing_half_kcal"] = f50
    print(f"fed liquid slowing half {f50:.1f} kcal; delay {fed_delay(v, f50):.1f} min (target {NUTT_DELAY_MIN})")

    half, vol, err = fit_amino_acid_pool(v)
    v["aa.plasma_distribution_volume_l"] = vol
    print(f"amino-acid pool: relaxation half-time {half:.0f} min (prior), volume {vol:.1f} L (sq err {err:.1f})")
    for d in ("high", "even", "evening"):
        print(f"  Carter {d}: daytime mean six-LNAA {carter_daytime_mean(v, d):.0f} umol/L")

    if args.write:
        path = os.path.join(HERE, "parameters.json")
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        fitted = {
            "stomach.solid_trituration_rate_per_min": round(k_t, 4),
            "stomach.fed_liquid_slowing_half_kcal": round(f50, 1),
            "aa.plasma_distribution_volume_l": round(vol, 1),
            "insulin.max_lnaa_target_reduction": round(e_max, 4),
        }
        for p in data["parameters"]:
            if p["id"] in fitted:
                p["value"] = fitted[p["id"]]
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        print("wrote", path)


if __name__ == "__main__":
    main()
