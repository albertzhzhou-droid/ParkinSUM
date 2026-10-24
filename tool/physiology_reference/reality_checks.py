"""Reality checks: does the reference model reproduce published human data?

  python3 -I tool/physiology_reference/reality_checks.py [--json build/physiology_reference/report.json]

Each check names its source and its kind:
  calibrated   the target was used to fit a parameter; passing shows the fit
               held, not that the model is validated
  independent  the target was not used for fitting; this is the real test
  structural   true by construction; guards against regressions
  known_gap    an expected failure kept visible; an unexpected pass fails the
               run so the classification gets revisited
Exit status is non-zero when any non-gap check fails or a gap unexpectedly
passes. Passing proves only the stated assertion under the stated scenario
assumptions (see scenarios.py); it is not clinical validation.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from model import (Component, Meal, Scenario, area, at, competing_lnaa_load, load_parameters,  # noqa: E402
                   meal_response, peak, simulate, trough, values)
import scenarios  # noqa: E402

CHECKS = []


def check(cid, kind, claim, source, observed, target, ok):
    CHECKS.append({"id": cid, "kind": kind, "claim": claim, "source": source,
                   "observed": observed, "target": target, "pass": bool(ok)})


def half_life(series, key, t0, t1):
    y0, y1 = at(series, key, t0), at(series, key, t1)
    return (t1 - t0) * math.log(2) / math.log(y0 / y1)


def run(v):
    # 1. Brener 1983: calorie-limited emptying of a glucose drink.
    s = simulate(scenarios.glucose_drink(), v)
    rate = (at(s, "stomach_kcal", 20) - at(s, "stomach_kcal", 90)) / 70.0
    check("brener.glucose_energy_rate", "structural",
          "A 300 kcal glucose drink leaves the stomach at ~2.13 kcal/min in its linear phase",
          "Brener 1983, PMID 6852464", f"{rate:.2f} kcal/min", "2.13 +/- 10%",
          abs(rate - 2.13) <= 0.213)

    # 2. Tougas 2000: solid retention medians.
    s = simulate(scenarios.tougas_meal(), v)
    obs = {t: at(s, "stomach_retention_solid", t) for t in (60, 120, 240)}
    med = {60: 0.69, 120: 0.24, 240: 0.012}
    upper = {60: 0.90, 120: 0.60, 240: 0.10}
    check("tougas.solid_retention", "calibrated",
          "Standard low-fat solid meal retention at 1, 2, 4 h is near the healthy medians",
          "Tougas 2000, DOI 10.1111/j.1572-0241.2000.02076.x",
          ", ".join(f"{t} min {obs[t]:.0%}" for t in obs),
          "69% / 24% / 1.2% within 5 points, and under the 95th percentile",
          all(abs(obs[t] - med[t]) <= 0.05 and obs[t] <= upper[t] for t in obs))

    # 3. Fasting levodopa: rapid absorption, ~1.5 h half-life with carbidopa.
    fasting, fed = scenarios.nutt_meal_scenarios()
    sf, sm = simulate(fasting, v), simulate(fed, v)
    tmax_f, cmax_f = peak(sf, "levodopa_mg_per_l")
    tmax_m, cmax_m = peak(sm, "levodopa_mg_per_l")
    hl = half_life(sf, "levodopa_mg_per_l", 180, 360)
    check("levodopa.fasting_tmax", "independent",
          "A fasting immediate-release dose peaks within 30-60 min",
          "Contin & Martinelli 2010, DOI 10.1007/s00415-010-5728-8; Othman & Dutta 2014, DOI 10.1111/bcp.12324",
          f"{tmax_f:.0f} min", "30-60 min", 30 <= tmax_f <= 60)
    check("levodopa.half_life", "structural",
          "Terminal half-life with a decarboxylase inhibitor is ~1.5 h",
          "Contin & Martinelli 2010, DOI 10.1007/s00415-010-5728-8",
          f"{hl:.0f} min", "80-100 min", 80 <= hl <= 100)

    # 4-5. Nutt 1984: meals delay absorption by 34 min and cut the peak by 29%.
    delay = tmax_m - tmax_f
    drop = 1 - cmax_m / cmax_f
    check("nutt.meal_delay", "calibrated",
          "A meal at dosing delays the levodopa peak by ~34 min",
          "Nutt 1984, DOI 10.1056/NEJM198402233100802", f"{delay:.0f} min", "34 +/- 5 min",
          abs(delay - 34) <= 5)
    check("nutt.meal_peak_reduction", "independent",
          "The same meal lowers the levodopa peak by ~29% (not used for fitting)",
          "Nutt 1984, DOI 10.1056/NEJM198402233100802", f"{drop:.0%}", "29% +/- 12 points",
          abs(drop - 0.29) <= 0.12)

    # 6. Nutt 1984 infusion arm: amino-acid loads act at the brain, not plasma.
    # The abstract reports direction and specificity, not an effect size, so the
    # check asserts a material drop (index < 0.85) for phenylalanine and leucine
    # and none for glycine, each against a no-load infusion control.
    control = simulate(scenarios.nutt_infusion_amino_acid_load("gly"), v)
    control_ld = {t: at(control, "levodopa_mg_per_l", t) for t in range(240, 601, 10)}
    for aa, kind, expect_effect in (("phe", "independent", True), ("leu", "independent", True),
                                    ("gly", "structural", False)):
        s = simulate(scenarios.nutt_infusion_amino_acid_load(aa), v)
        ld_change = max(abs(at(s, "levodopa_mg_per_l", t) / control_ld[t] - 1) for t in control_ld)
        _, b_min = trough(s, "brain_entry_index", 240, 600)
        ok = ld_change < 0.05 and ((b_min < 0.85) if expect_effect else (b_min > 0.98))
        check(f"nutt.infusion_{aa}_load", kind,
              (f"Oral {aa} 100 mg/kg lowers brain entry of infused levodopa; plasma levodopa matches control"
               if expect_effect else "Glycine (not a carrier substrate) leaves brain entry unchanged"),
              "Nutt 1984, DOI 10.1056/NEJM198402233100802; Smith 1987, DOI 10.1111/j.1471-4159.1987.tb01039.x",
              f"plasma levodopa vs control {ld_change:.1%}, brain-entry index minimum {b_min:.2f}",
              "plasma within 5% of control; index < 0.85 (direction only)" if expect_effect
              else "plasma within 5% of control; index > 0.98",
              ok)

    # 7-9. Carter 1989: daytime plasma LNAA by diet; plasma levodopa unchanged.
    means, ld_means = {}, {}
    for diet in ("high", "even", "evening"):
        s = simulate(scenarios.carter_day(diet), v)
        means[diet] = sum(at(s, "lnaa6_umol_per_l", t) for t in scenarios.CARTER_SAMPLE_TIMES) / len(
            scenarios.CARTER_SAMPLE_TIMES)
        ld_means[diet] = sum(at(s, "levodopa_mg_per_l", t) for t in scenarios.CARTER_SAMPLE_TIMES) / len(
            scenarios.CARTER_SAMPLE_TIMES)
    check("carter.even_diets", "calibrated",
          "Daytime mean plasma LNAA on 1.6 and 0.8 g/kg/day evenly distributed diets",
          "Carter 1989, DOI 10.1212/wnl.39.4.552",
          f"{means['high']:.0f} / {means['even']:.0f} umol/L", "732 / 640 within 3%",
          abs(means["high"] / 732 - 1) <= 0.03 and abs(means["even"] / 640 - 1) <= 0.03)
    check("carter.evening_restricted", "independent",
          "Daytime mean plasma LNAA when protein is restricted to the evening meal (v2 known gap; closes with "
          "insulin action calibrated on Shaham 2008 and habitual-intake disposal from Price 1994)",
          "Carter 1989, DOI 10.1212/wnl.39.4.552",
          f"{means['evening']:.0f} umol/L", "542 within 5%",
          abs(means["evening"] / 542 - 1) <= 0.05)
    spread = max(ld_means.values()) / min(ld_means.values()) - 1
    check("carter.levodopa_unchanged", "structural",
          "Daytime plasma levodopa does not differ between protein diets of equal energy",
          "Carter 1989, DOI 10.1212/wnl.39.4.552", f"spread {spread:.1%}", "< 10%", spread < 0.10)

    # 10. Boirie 1997: whey gives a fast, short rise; casein a prolonged plateau.
    whey, casein = scenarios.boirie_proteins()
    sw, sc = simulate(whey, v), simulate(casein, v)
    tw, pw = peak(sw, "leu_umol_per_l")
    tc, pc = peak(sc, "leu_umol_per_l")
    base = float(v["aa.fasting_plasma_umol_per_l"]["leu"])

    def above(s, frac):
        return sum(1 for y in s["leu_umol_per_l"] if y > base + frac * (pw - base))

    check("boirie.fast_slow_protein", "independent",
          "Whey: earlier, higher, shorter leucine rise; casein: lower prolonged plateau",
          "Boirie 1997, DOI 10.1073/pnas.94.26.14930",
          f"whey +{pw - base:.0f} umol/L at {tw:.0f} min; casein +{pc - base:.0f} at {tc:.0f} min "
          f"(rise ratio {(pw - base) / (pc - base):.2f}); minutes above 25% of the whey rise: "
          f"whey {above(sw, .25)}, casein {above(sc, .25)}",
          "direction only (the abstract reports no magnitudes): whey earlier and higher, casein longer",
          tw < tc and pw > pc and above(sc, .25) > above(sw, .25))

    # 11. Regression guards for the two errors found in the shipped model.
    def lnaa_peak_time(components):
        s = simulate(Scenario(meals=[Meal(0.0, components)], t_end_min=360.0), v)
        return peak(s, "lnaa6_umol_per_l")[0]

    oat = Component("oatmeal", "solid", kcal=250.0, protein_g=8.0)
    t_alone = lnaa_peak_time([oat])
    t_water = lnaa_peak_time([oat, Component("water", "water", water_ml=240.0)])
    check("regression.water_does_not_move_protein", "structural",
          "Adding 240 mL water to oatmeal does not move the plasma LNAA peak",
          "Shipped-model finding (mass-weighted arrival)", f"{t_alone:.0f} vs {t_water:.0f} min",
          "identical", t_alone == t_water)
    s = simulate(Scenario(meals=[Meal(0.0, [Component("shake", "liquid", kcal=300.0, protein_g=25.0,
                                                        water_ml=300.0)])], t_end_min=300.0), v)
    half = next(t for t, k in zip(s["t"], s["stomach_kcal"]) if k <= 150.0)
    check("regression.nutrient_liquid_half_emptying", "structural",
          "A 300 kcal protein shake takes 50-90 min to half-empty (shipped model: 13.5 min)",
          "Brener 1983, PMID 6852464", f"{half:.0f} min", "50-90 min", 50 <= half <= 90)
    run_nutrition(v)
    return CHECKS


def ratio_to_others(s, key, t):
    """Plasma amino acid divided by the sum of the other five competing LNAAs."""
    own = at(s, key, t)
    return own / (at(s, "lnaa6_umol_per_l", t) - own)


def half_emptying(s, total_kcal):
    return next(t for t, k in zip(s["t"], s["stomach_kcal"]) if k <= total_kcal / 2)


def run_nutrition(v):
    """v3 nutrition-side checks: gastric emptying of foods, protein digestion
    by type, insulin action, habitual-intake disposal, and composition
    fidelity."""
    base = float(v["aa.fasting_plasma_umol_per_l"]["leu"])

    # Gastric emptying of foods and meals.
    s = simulate(scenarios.blackburn_glucose(), v)
    t_half = half_emptying(s, 200.0)
    check("blackburn.glucose_drink_half_emptying", "known_gap",
          "250 mL of 200 g/L glucose half-empties in ~73 min (control arm; planned as independent; the "
          "calorie-constant Brener rate empties it faster)",
          "Blackburn 1984, DOI 10.1079/bjn19840088", f"{t_half:.0f} min", "73 min +/- 16 (2 SE)",
          abs(t_half - 73) <= 16)
    check("blackburn.guar_slowing", "known_gap",
          "Guar gum at 36 g/L slows that drink to a 115 min half-emptying (22.5 and 5 g/L: no change)",
          "Blackburn 1984, DOI 10.1079/bjn19840088; Morgan 1985, DOI 10.1079/bjn19850056",
          f"{t_half:.0f} min (viscous fibre is not a model input)", "115 min +/- 30",
          abs(t_half - 115) <= 30)
    fat = simulate(Scenario(meals=[Meal(0.0, [Component("fat-rich", "solid", kcal=500.0, protein_g=15.0, fat_g=40.0)])],
                            t_end_min=300.0), v)
    carb = simulate(Scenario(meals=[Meal(0.0, [Component("carb-rich", "solid", kcal=500.0, protein_g=15.0, fat_g=5.0)])],
                             t_end_min=300.0), v)
    check("hunt.isocaloric_nutrients_empty_alike", "structural",
          "Isocaloric fat-rich and carbohydrate-rich meals empty alike (fat acts through its energy)",
          "Hunt & Stubbs 1975, DOI 10.1113/jphysiol.1975.sp010841",
          f"half-emptying {half_emptying(fat, 500.0):.0f} vs {half_emptying(carb, 500.0):.0f} min", "identical",
          fat["stomach_kcal"] == carb["stomach_kcal"])
    retention = {}
    water_half = {}
    for kcal in (68.0, 208.0, 633.0):
        sm = simulate(scenarios.moore_meal(kcal), v)
        retention[kcal] = at(sm, "stomach_retention_solid", 60.0)
        water_half[kcal] = next(t for t, w in zip(sm["t"], sm["water_ml"]) if w <= sm["water_ml"][0] / 2)
    check("moore.energy_slows_solids", "structural",
          "Adding energy (salad oil) to a lettuce meal slows solid emptying",
          "Moore 1984, DOI 10.1007/BF01296271",
          "solid retained at 60 min: " + ", ".join(f"{int(k)} kcal {r:.0%}" for k, r in retention.items()),
          "increases with energy", retention[68.0] < retention[208.0] < retention[633.0])
    check("moore.liquid_unaffected_by_energy", "known_gap",
          "Liquid emptying of the same meals does not change with their energy",
          "Moore 1984, DOI 10.1007/BF01296271",
          "water half-emptying: " + ", ".join(f"{int(k)} kcal {t:.0f} min" for k, t in water_half.items()),
          "within 25% of each other", max(water_half.values()) <= 1.25 * min(water_half.values()))

    # Protein digestion by type.
    soy, milk = scenarios.bos_mixed_meals()
    ss, sm = simulate(soy, v), simulate(milk, v)
    t_soy, t_milk = peak(ss, "lnaa6_umol_per_l")[0], peak(sm, "lnaa6_umol_per_l")[0]
    check("bos.soy_before_milk_timing", "known_gap",
          "In a ~770 kcal mixed meal, dietary amino acids peak at 2.5 h after soy and 3.9 h after milk protein "
          "(planned as independent; the order holds but the model peaks too late and too close together)",
          "Bos 2003, DOI 10.1093/jn/133.5.1308", f"plasma LNAA peak {t_soy / 60:.1f} vs {t_milk / 60:.1f} h",
          "2.5 h and 3.9 h, each within 45 min", abs(t_soy - 150) <= 45 and abs(t_milk - 234) <= 45)
    pk = {}
    for name, sc_t in zip(("whey", "soy", "casein"), scenarios.tang_drinks()):
        pk[name] = peak(simulate(sc_t, v), "leu_umol_per_l")[1] - base
    check("tang.whey_soy_casein", "structural",
          "Blood leucine rises most after whey hydrolysate, then soy, then micellar casein",
          "Tang 2009, DOI 10.1152/japplphysiol.00076.2009",
          ", ".join(f"{k} +{x:.0f} umol/L" for k, x in pk.items()), "whey > soy > casein",
          pk["whey"] > pk["soy"] > pk["casein"])
    egg = [Component("cooked egg", "solid", kcal=200.0, protein_g=25.0, fat_g=5.0, protein_type="egg")]
    se = simulate(Scenario(meals=[Meal(0.0, egg)], t_end_min=720.0), v)
    load = competing_lnaa_load(egg, v)
    tid = float(v["aa.true_ileal_digestibility_by_protein_type"]["egg"])
    appeared = area(se, "lnaa6_appearance_umol_per_min", 0, 720)
    grams = egg[0].aa_grams(v)
    expected = sum(grams[a] / 1.0 * 1e6 / {"leu": 131.17, "ile": 131.17, "val": 117.15, "phe": 165.19, "tyr": 181.19,
                                            "trp": 204.23}[a] * tid * float(v["aa.systemic_fraction"][a])
                   for a in ("leu", "ile", "val", "phe", "tyr", "trp"))
    check("evenepoel.digestibility_mass_balance", "structural",
          "Over 12 h, LNAA appearing in plasma equals ingested x true ileal digestibility (cooked egg 90.9%) "
          "x splanchnic escape",
          "Evenepoel 1998, DOI 10.1093/jn/128.10.1716; Matthews 1993, DOI 10.1152/ajpendo.1993.264.1.E109",
          f"{appeared:.0f} of {expected:.0f} umol (ingested {load['ingested_umol']:.0f})", "within 2%",
          abs(appeared / expected - 1) <= 0.02)

    # Carbohydrate / insulin action on plasma amino acids.
    sg = simulate(scenarios.shaham_glucose(), v)
    falls = [(t, 1 - y / base) for t, y in zip(sg["t"], sg["leu_umol_per_l"]) if t <= 120]
    fall120 = falls[-1][1]
    check("shaham.leucine_fall", "calibrated",
          "75 g oral glucose lowers plasma leucine/isoleucine by 33% at 2 h",
          "Shaham 2008, DOI 10.1038/msb.2008.50", f"{fall120:.1%}", "33% +/- 2 points", abs(fall120 - 0.33) <= 0.02)
    t_hm = next(t for t, f in falls if f >= fall120 / 2)
    check("shaham.half_maximal_time", "independent",
          "The amino-acid fall reaches half its 2-h value at 50-72 min (not used for fitting)",
          "Shaham 2008, DOI 10.1038/msb.2008.50", f"{t_hm:.0f} min", "50-72 min", 50 <= t_hm <= 72)
    carb_b, prot_b = scenarios.wurtman_breakfasts()
    sc_, sp_ = simulate(carb_b, v), simulate(prot_b, v)
    diff = {key: max(ratio_to_others(sc_, key, t) / ratio_to_others(sp_, key, t) - 1
                     for t in scenarios.WURTMAN_SAMPLE_TIMES) for key in ("tyr_umol_per_l", "trp_umol_per_l")}
    check("wurtman.ratio_difference", "independent",
          "Carbohydrate- vs protein-rich breakfast: tryptophan:LNAA and tyrosine:LNAA ratios differ within the "
          "reported subject ranges",
          "Wurtman 2003, DOI 10.1093/ajcn/77.1.128",
          f"tryptophan {diff['trp_umol_per_l']:.0%}, tyrosine {diff['tyr_umol_per_l']:.0%}",
          "tryptophan 36-88%, tyrosine 10-64% (medians 54% / 28%)",
          0.36 <= diff["trp_umol_per_l"] <= 0.88 and 0.10 <= diff["tyr_umol_per_l"] <= 0.64)
    pf = Scenario(meals=[Meal(clock, [Component("protein-free meal", "solid", kcal=kc, protein_g=0.0)])
                         for clock, kc in ((0.0, 450.0), (240.0, 650.0))], t_end_min=600.0)
    s_pf = simulate(pf, v)
    lnaa_base = sum(float(v["aa.fasting_plasma_umol_per_l"][a]) for a in ("leu", "ile", "val", "phe", "tyr", "trp"))
    late = [at(s_pf, "lnaa6_umol_per_l", t) / lnaa_base - 1 for t in (180.0, 360.0, 480.0)]
    check("fernstrom.protein_free_meals_lower_lnaa", "independent",
          "Protein-free meals lower plasma LNAA below fasting in the late morning and afternoon",
          "Fernstrom 1979, DOI 10.1093/ajcn/32.9.1912", ", ".join(f"{x:+.0%}" for x in late),
          "all below fasting (direction only)", all(x < 0 for x in late))

    # Composition fidelity: missing is not zero.
    measured = Component("m", "solid", kcal=200.0, protein_g=20.0, amino_acids_g={a: 1.0 for a in
                                                                                  ("leu", "ile", "val", "phe", "tyr", "trp", "met", "his")},
                         protein_type="whey")
    typed = Component("t", "solid", kcal=200.0, protein_g=20.0, protein_type="whey")
    plain = Component("p", "solid", kcal=200.0, protein_g=20.0)
    bases = [c.profile_basis() for c in (measured, typed, plain)]
    no_carb = plain.carbohydrate_grams(float(v["insulin.default_carbohydrate_energy_share"]))
    check("composition.missing_is_not_zero", "structural",
          "A measured profile takes precedence over the protein-type table, which takes precedence over the mixed "
          "default; omitted carbohydrate uses the stated energy share, not 0 g",
          "Model boundary; USDA FDC SR Legacy profiles", f"{', '.join(bases)}; carbohydrate {no_carb:.1f} g",
          "measured, protein_type_table, mixed_default; carbohydrate > 0",
          bases == ["measured", "protein_type_table", "mixed_default"] and no_carb > 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    args = ap.parse_args()
    params = load_parameters()
    checks = run(values(params))
    failed = []
    for c in checks:
        if c["kind"] == "known_gap":
            status = "UNEXPECTED PASS" if c["pass"] else "known gap"
            if c["pass"]:
                failed.append(c["id"])
        else:
            status = "pass" if c["pass"] else "FAIL"
            if not c["pass"]:
                failed.append(c["id"])
        print(f"[{status:>15}] {c['kind']:<11} {c['id']}\n"
              f"                  {c['claim']}\n"
              f"                  observed {c['observed']}; target {c['target']}  ({c['source']})")
    counts = {}
    for c in checks:
        counts[c["kind"]] = counts.get(c["kind"], 0) + 1
    print(f"\n{len(checks)} checks {counts}; failing: {failed or 'none'}")
    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({"schema": "parkinsum.physiology-reference-reality-checks/1", "pass": not failed,
                       "parameter_set_version": json.load(open(os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "parameters.json")))["parameter_set_version"],
                "checks": checks, "failing": failed}, fh, indent=2)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
