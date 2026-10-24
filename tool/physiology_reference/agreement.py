"""Cross-runtime agreement fixture for the Dart port of the reference model.

  python3 -I tool/physiology_reference/agreement.py            # write the fixture
  python3 -I tool/physiology_reference/agreement.py --check \
      [--json build/physiology_reference/fixture_freshness.json]

Writes test/fixtures/physiology_reference_agreement.json: scenario
specifications, sampled curves, the reality-check quantities derived from
them, and seeded population bands for the timing comparisons the app shows.
test/physiology_reference_agreement_test.dart and
tool/run_physiology_reference_agreement.dart require the Dart port
(lib/domain/usecases/physiology_reference_model.dart) to reproduce every
number within the tolerance stored in the fixture. `--check` recomputes the
fixture and fails when the committed copy no longer matches this model.

The timing-comparison convention (dose time, horizon, window, seed, draws)
mirrors lib/domain/usecases/physiology_reference_trace_provider.dart. Every
output is a population-typical curve for a synthetic scenario; none is a
prediction for any person or dosing, timing or dietary advice.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from model import (SERIES_KEYS, Component, Dose, Meal, Scenario, area, at, competing_lnaa_load,  # noqa: E402
                   load_parameters, meal_response, peak, percentile, sample_population, simulate, trough, values)
import scenarios  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
FIXTURE = os.path.join(ROOT, "test", "fixtures", "physiology_reference_agreement.json")
SCHEMA = "parkinsum.physiology-reference-agreement/1"
SEED = 20261020
DRAWS = 100
DOSE_MG = 100.0
WINDOW_END = 240.0
# Python (CPython 3.9 plain sums, 3.12+ compensated sums) and Dart (IEEE
# doubles, same operation order) agree to ~1e-12 relative; the stated
# tolerance leaves three orders of margin while staying far below any
# displayed precision.
TOLERANCE = {"relative": 1e-9, "absolute": 1e-12}


def lunch():
    """The what-if meal: ~600 kcal mixed meal with 30 g protein."""
    return [Component("mixed meal", "solid", kcal=520.0, protein_g=27.0),
            Component("drink", "liquid", kcal=80.0, protein_g=3.0, water_ml=250.0),
            Component("water", "water", water_ml=250.0)]


def dose_time(offset):
    return 150.0 if offset is None else max(150.0, -offset)


def timing_scenario(meal, offset, horizon=360.0):
    t0 = dose_time(offset)
    meals = [] if offset is None else [Meal(t0 + offset, meal)]
    return Scenario(meals=meals, doses=[Dose(t0, DOSE_MG)], t_end_min=t0 + horizon)


def shifted(series, origin):
    out = {k: list(x) for k, x in series.items()}
    out["t"] = [t - origin for t in out["t"]]
    return out


def summarize(v, meal, offset, reference=None, horizon=360.0):
    s = shifted(simulate(timing_scenario(meal, offset, horizon), v), dose_time(offset))
    tmax, cmax = peak(s, "levodopa_mg_per_l", 0, 360)
    _, bmin = trough(s, "brain_entry_index", 0, WINDOW_END)
    _, energy_peak = peak(s, "energy_out_kcal_per_min", -math.inf)
    out = {"tmax_min": tmax, "cmax_mg_per_l": cmax, "brain_entry_index_min_0_4h": bmin,
           "brain_delivery_area": area(s, "brain_delivery_index", 0, WINDOW_END),
           "plasma_area": area(s, "levodopa_mg_per_l", 0, WINDOW_END),
           "peak_energy_out_kcal_per_min": energy_peak}
    if reference is not None:
        out["brain_delivery_area_vs_no_meal"] = out["brain_delivery_area"] / reference["brain_delivery_area"]
        out["plasma_area_vs_no_meal"] = out["plasma_area"] / reference["plasma_area"]
    return out


def band(xs):
    return [percentile(xs, 0.05), percentile(xs, 0.5), percentile(xs, 0.95)]


# ------------------------------------------------------------ serialization

def component_spec(c):
    return {"name": c.name, "form": c.form, "kcal": c.kcal, "protein_g": c.protein_g,
            "amino_acids_g": c.amino_acids_g, "water_ml": c.water_ml, "carbohydrate_g": c.carbohydrate_g,
            "fat_g": c.fat_g, "protein_type": c.protein_type}


def scenario_spec(sc):
    return {"meals": [{"time_min": m.time_min, "components": [component_spec(c) for c in m.components]}
                      for m in sc.meals],
            "doses": [{"time_min": d.time_min, "levodopa_mg": d.levodopa_mg} for d in sc.doses],
            "infusions": [{"start_min": i.start_min, "end_min": i.end_min, "mg_per_min": i.mg_per_min}
                          for i in sc.infusions],
            "t_end_min": sc.t_end_min, "dt_min": sc.dt_min, "record_every_min": sc.record_every_min,
            "habitual_protein_g_per_kg_day": sc.habitual_protein_g_per_kg_day}


NUTRITION_HORIZON_MIN = 240.0


def nutrition_meals():
    """Synthetic servings and plates for the nutrition-only outputs."""
    return [
        ("whey_shake", [Component("whey shake", "liquid", kcal=110.0, protein_g=25.0, carbohydrate_g=3.0,
                                  fat_g=1.0, water_ml=300.0, protein_type="whey")]),
        ("steak_plate", [Component("beef steak", "solid", kcal=300.0, protein_g=40.0, fat_g=15.0, carbohydrate_g=0.0,
                                   protein_type="meat"),
                         Component("potatoes", "solid", kcal=200.0, protein_g=4.0, carbohydrate_g=42.0, fat_g=0.5),
                         Component("water", "water", water_ml=250.0)]),
        ("oatmeal_bowl", [Component("oatmeal", "solid", kcal=300.0, protein_g=10.0, carbohydrate_g=54.0, fat_g=5.0,
                                    protein_type="cereal"),
                          Component("milk", "liquid", kcal=50.0, protein_g=5.0, carbohydrate_g=7.0, fat_g=0.2,
                                    water_ml=140.0, protein_type="casein")]),
        ("egg_toast", [Component("two eggs", "solid", kcal=143.0, protein_g=12.6, fat_g=9.5, carbohydrate_g=0.7,
                                 protein_type="egg"),
                       Component("toast", "solid", kcal=160.0, protein_g=5.0, carbohydrate_g=30.0, fat_g=2.0,
                                 protein_type="cereal")]),
        ("mixed_lunch", lunch()),
    ]


def nutrition_summary(v, meal):
    s = simulate(Scenario(meals=[Meal(0.0, meal)], t_end_min=NUTRITION_HORIZON_MIN), v)
    return meal_response(s, 0.0, NUTRITION_HORIZON_MIN)


def curve_case(case_id, sc, sample_every_min, v):
    s = simulate(sc, v)
    stride = max(1, int(round(sample_every_min / sc.record_every_min)))
    return {"id": case_id, "scenario": scenario_spec(sc), "sample_stride": stride,
            "samples": {k: s[k][::stride] for k in SERIES_KEYS}}, s


def build():
    params = load_parameters()
    v = values(params)
    cases, derived = [], {}

    def add(case_id, sc, every):
        case, s = curve_case(case_id, sc, every, v)
        cases.append(case)
        return s

    fasting, fed = scenarios.nutt_meal_scenarios()
    sf = add("fasting_dose", fasting, 5.0)
    sm = add("meal_with_dose", fed, 5.0)
    for offset in (-60.0, 60.0):
        add(f"lunch_{'before' if offset < 0 else 'after'}_dose_60", timing_scenario(lunch(), offset), 5.0)
    st = add("tougas_meal", scenarios.tougas_meal(), 5.0)
    sg = add("brener_glucose", scenarios.glucose_drink(), 5.0)
    carter = {d: add(f"carter_{d}", scenarios.carter_day(d), 30.0) for d in ("high", "even", "evening")}
    nutt = {aa: add(f"nutt_infusion_{aa}", scenarios.nutt_infusion_amino_acid_load(aa), 10.0)
            for aa in ("phe", "leu", "gly")}
    whey, casein = scenarios.boirie_proteins()
    sw, sc = add("boirie_whey", whey, 5.0), add("boirie_casein", casein, 5.0)
    sg = add("shaham_glucose", scenarios.shaham_glucose(), 5.0)
    carb_b, prot_b = scenarios.wurtman_breakfasts()
    swc, swp = add("wurtman_carbohydrate", carb_b, 5.0), add("wurtman_protein", prot_b, 5.0)
    tang = {k: add(f"tang_{k}", sc_t, 5.0) for k, sc_t in zip(("whey", "soy", "casein"), scenarios.tang_drinks())}
    soy_b, milk_b = scenarios.bos_mixed_meals()
    sbs, sbm = add("bos_soy", soy_b, 10.0), add("bos_milk", milk_b, 10.0)
    smoore = add("moore_633", scenarios.moore_meal(633.0), 5.0)

    # Reality-check quantities, defined exactly as in reality_checks.py.
    tmax_f, cmax_f = peak(sf, "levodopa_mg_per_l")
    tmax_m, cmax_m = peak(sm, "levodopa_mg_per_l")
    y0, y1 = at(sf, "levodopa_mg_per_l", 180), at(sf, "levodopa_mg_per_l", 360)
    derived["nutt.fasting_tmax_min"] = tmax_f
    derived["nutt.meal_delay_min"] = tmax_m - tmax_f
    derived["nutt.meal_peak_reduction"] = 1 - cmax_m / cmax_f
    derived["levodopa.half_life_min"] = 180 * math.log(2) / math.log(y0 / y1)
    for t in (60, 120, 240):
        derived[f"tougas.retention_{t}_min"] = at(st, "stomach_retention_solid", t)
    derived["brener.energy_rate_kcal_per_min"] = (at(sg, "stomach_kcal", 20) - at(sg, "stomach_kcal", 90)) / 70.0
    for diet, s in carter.items():
        n = len(scenarios.CARTER_SAMPLE_TIMES)
        derived[f"carter.{diet}_lnaa6_daytime_mean_umol_per_l"] = sum(
            at(s, "lnaa6_umol_per_l", t) for t in scenarios.CARTER_SAMPLE_TIMES) / n
        derived[f"carter.{diet}_levodopa_daytime_mean_mg_per_l"] = sum(
            at(s, "levodopa_mg_per_l", t) for t in scenarios.CARTER_SAMPLE_TIMES) / n
    for aa, s in nutt.items():
        derived[f"nutt.infusion_{aa}_brain_entry_index_min"] = trough(s, "brain_entry_index", 240, 600)[1]
    for name, s in (("whey", sw), ("casein", sc)):
        t, y = peak(s, "leu_umol_per_l")
        derived[f"boirie.{name}_leu_peak_min"] = t
        derived[f"boirie.{name}_leu_peak_umol_per_l"] = y

    base_leu = float(v["aa.fasting_plasma_umol_per_l"]["leu"])
    derived["shaham.leucine_fall_120_min"] = 1 - at(sg, "leu_umol_per_l", 120.0) / base_leu
    for t in scenarios.WURTMAN_SAMPLE_TIMES:
        for key in ("tyr_umol_per_l", "trp_umol_per_l"):
            own_c, own_p = at(swc, key, t), at(swp, key, t)
            derived[f"wurtman.{key[:3]}_ratio_difference_{int(t)}_min"] = (
                (own_c / (at(swc, "lnaa6_umol_per_l", t) - own_c)) / (own_p / (at(swp, "lnaa6_umol_per_l", t) - own_p)) - 1)
    for k, s_t in tang.items():
        derived[f"tang.{k}_leu_peak_umol_per_l"] = peak(s_t, "leu_umol_per_l")[1]
    derived["bos.soy_lnaa6_peak_min"] = peak(sbs, "lnaa6_umol_per_l")[0]
    derived["bos.milk_lnaa6_peak_min"] = peak(sbm, "lnaa6_umol_per_l")[0]
    derived["moore.633_kcal_solid_retention_60_min"] = at(smoore, "stomach_retention_solid", 60.0)

    # Seeded population bands, as the trace provider computes them.
    population = sample_population(params, DRAWS, SEED)
    ref_c = summarize(v, [], None)
    refs = [summarize(p, [], None) for p in population]
    rows = []
    for offset in (None, -60.0, 0.0, 60.0):
        c = ref_c if offset is None else summarize(v, lunch(), offset, ref_c)
        per = refs if offset is None else [summarize(p, lunch(), offset, r) for p, r in zip(population, refs)]
        keys = ["tmax_min", "cmax_mg_per_l", "brain_entry_index_min_0_4h"]
        if offset is not None:
            keys += ["plasma_area_vs_no_meal", "brain_delivery_area_vs_no_meal"]
        rows.append({"meal_offset_min": offset, "central": {k: c[k] for k in keys + [
            "brain_delivery_area", "plasma_area", "peak_energy_out_kcal_per_min"]},
            "bands_p05_p50_p95": {k: band([p[k] for p in per]) for k in keys}})

    shake = [Component("protein shake", "liquid", kcal=300.0, protein_g=25.0, water_ml=300.0)]
    rice = [Component("rice bowl", "solid", kcal=400.0, protein_g=2.0),
            Component("water", "water", water_ml=200.0)]
    effect_cases = [("shake_30_before", shake, -30.0), ("shake_30_after", shake, 30.0),
                    ("tougas_meal_120_before", [Component("egg-substitute meal", "solid", kcal=255.0,
                                                          protein_g=20.0)], -120.0),
                    ("lunch_200_before", lunch(), -200.0), ("lunch_120_after", lunch(), 120.0),
                    ("low_protein_with_dose", rice, 0.0)]
    effects = []
    for case_id, meal, offset in effect_cases:
        central = summarize(v, meal, offset, ref_c, horizon=WINDOW_END)["brain_delivery_area_vs_no_meal"]
        per = [summarize(p, meal, offset, r, horizon=WINDOW_END)["brain_delivery_area_vs_no_meal"]
               for p, r in zip(population, refs)]
        effects.append({"id": case_id, "meal": [component_spec(c) for c in meal], "meal_offset_min": offset,
                        "central": central, "band_p05_p50_p95": band(per)})

    nutrition = []
    for case_id, meal in nutrition_meals():
        central = nutrition_summary(v, meal)
        per = [nutrition_summary(p, meal) for p in population]
        nutrition.append({"id": case_id, "meal": [component_spec(c) for c in meal],
                          "competing_lnaa_load": competing_lnaa_load(meal, v), "central": central,
                          "bands_p05_p50_p95": {k: band([r[k] for r in per]) for k in central}})

    with open(os.path.join(HERE, "parameters.json"), encoding="utf-8") as fh:
        version = json.load(fh)["parameter_set_version"]
    return {
        "schema": SCHEMA,
        "parameter_set_version": version,
        "generator": "tool/physiology_reference/agreement.py",
        "boundary": "Synthetic scenarios and population-typical curves for cross-runtime agreement only; "
                    "not predictions for any person and not dosing, timing or dietary advice.",
        "tolerance": TOLERANCE,
        "timing_convention": {"dose_mg": DOSE_MG, "dose_time_min": "150, or minus the meal offset when the "
                              "meal starts earlier", "window_min": [0.0, WINDOW_END], "seed": SEED, "draws": DRAWS},
        "curves": cases,
        "derived": derived,
        "timing_rows": rows,
        "meal_timing_effects": effects,
        "nutrition_convention": {"horizon_min": NUTRITION_HORIZON_MIN, "meal_time_min": 0.0, "seed": SEED,
                                 "draws": DRAWS},
        "nutrition_outputs": nutrition,
    }


# ----------------------------------------------------------------- checking

def compare(expected, actual, path="$", failures=None, worst=None):
    """Numeric leaves within TOLERANCE; everything else exactly equal."""
    failures = [] if failures is None else failures
    worst = {"relative": 0.0} if worst is None else worst
    if isinstance(expected, dict) and isinstance(actual, dict):
        if set(expected) != set(actual):
            failures.append(f"{path}: keys differ")
        for k in expected:
            if k in actual:
                compare(expected[k], actual[k], f"{path}.{k}", failures, worst)
    elif isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            failures.append(f"{path}: length {len(actual)} != {len(expected)}")
        for i, (e, a) in enumerate(zip(expected, actual)):
            compare(e, a, f"{path}[{i}]", failures, worst)
    elif isinstance(expected, (int, float)) and isinstance(actual, (int, float)) \
            and not isinstance(expected, bool) and not isinstance(actual, bool):
        diff = abs(expected - actual)
        scale = max(abs(expected), abs(actual))
        if scale > 0:
            worst["relative"] = max(worst["relative"], diff / scale)
        if diff > TOLERANCE["absolute"] + TOLERANCE["relative"] * scale:
            failures.append(f"{path}: {actual!r} != {expected!r}")
    elif expected != actual:
        failures.append(f"{path}: {actual!r} != {expected!r}")
    return failures, worst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--json")
    args = ap.parse_args()
    fresh = build()
    if not args.check:
        with open(FIXTURE, "w", encoding="utf-8") as fh:
            json.dump(fresh, fh, indent=1, sort_keys=True)
            fh.write("\n")
        print("wrote", os.path.relpath(FIXTURE, ROOT))
        return
    with open(FIXTURE, encoding="utf-8") as fh:
        committed = json.load(fh)
    failures, worst = compare(committed, fresh)
    print(f"fixture freshness: {'pass' if not failures else 'FAIL'}; "
          f"max relative difference {worst['relative']:.2e}")
    for f in failures[:20]:
        print("  ", f)
    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({"schema": "parkinsum.physiology-reference-fixture-freshness/1", "pass": not failures,
                       "fixture": os.path.relpath(FIXTURE, ROOT), "tolerance": TOLERANCE,
                       "max_relative_difference": worst["relative"], "failures": failures[:50]}, fh, indent=2)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
