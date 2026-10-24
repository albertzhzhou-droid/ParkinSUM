"""Reference physiology model (v3 prototype) for ParkinSUM.

Educational research artifact. Not a medical device, not a patient prediction,
and not dosing, timing or dietary advice. It simulates *population-typical*
curves in physical units so the app's educational model can be checked against
published human data (see reality_checks.py).

Standard library only (Python 3.9+). Run from the repository root, e.g.
  python3 -I tool/physiology_reference/reality_checks.py

Structure (all quantities carry units; see parameters.json for provenance):

  stomach    per food component, nutrient-tracked.
             solids:   two-stage grinding (trituration) lag, then emptiable
             liquids with energy: emptiable immediately
             the emptiable pool leaves at a calorie-limited rate
               R = R_max * P / (P + E50)        [kcal/min]
             (isocaloric fat, protein and carbohydrate slow emptying equally,
             Hunt & Stubbs 1975, so fat acts through its energy)
             water and dissolved drug: first-order, slowed by the energy
             still in the stomach  k = k_fast / (1 + F / F50)
  levodopa   tablet -> dissolved in gastric liquid -> absorptive gut segment
             -> one plasma compartment (apparent CL/F, V/F). Unchanged from
             v2; v3 extends only the nutrition side.
  amino acids  each component's amino acids (measured profile, else its
             protein type's FDC profile, else a mixed-protein default) leave
             the stomach with its emptied energy; the truly ileal-digestible
             fraction of its protein type is absorbed first order at that
             type's rate; a per-amino-acid splanchnic first-pass fraction
             reaches plasma; one plasma pool per amino acid relaxes to a
             target that insulin action lowers:
               dC/dt = f*A/V - k_out * (C - Cb * (1 - s * Emax * E))
             k_out scales with the oxidative disposal of a stated habitual
             protein intake (population reference otherwise)
  insulin    carbohydrate emptied with each component is absorbed first
             order; insulin action I follows the absorption rate with a
             first-order delay; E = I / (I + I50)
  brain entry  competitive Michaelis-Menten at the blood-brain barrier.
             The levodopa entry rate relative to the same plasma level in the
             fasting state is  B = (1 + sum Cb_i/Km_i) / (1 + sum C_i/Km_i)
             (valid while plasma levodopa << its own Km).

Intestinal transporter competition is deliberately not modeled: Carter et al.
1989 found plasma levodopa did not differ between protein diets while plasma
LNAA did. A pharmacodynamic (motor response) layer is deliberately excluded.
"""

from __future__ import annotations

import json
import math
import os
import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))

# Molecular weights (g/mol) of the free amino acids.
MW = {
    "leu": 131.17, "ile": 131.17, "val": 117.15, "phe": 165.19,
    "tyr": 181.19, "trp": 204.23, "met": 149.21, "his": 155.16,
}
LNAA_SIX = ("leu", "ile", "val", "phe", "tyr", "trp")
BBB_SET = LNAA_SIX + ("met", "his")
KCAL_PER_G = {"protein": 4.0, "carbohydrate": 4.0, "fat": 9.0}
PROTEIN_TYPES = ("mixed", "whey", "casein", "soy", "meat", "egg", "cereal")

SERIES_KEYS = ("t", "stomach_kcal", "stomach_retention_solid", "energy_out_kcal_per_min", "water_ml",
               "levodopa_mg_per_l", "lnaa6_umol_per_l", "brain_entry_index", "brain_delivery_index",
               "leu_umol_per_l", "phe_umol_per_l", "tyr_umol_per_l", "trp_umol_per_l",
               "lnaa6_appearance_umol_per_min", "insulin_effect")


def load_parameters(path: Optional[str] = None) -> Dict[str, dict]:
    with open(path or os.path.join(HERE, "parameters.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    return {p["id"]: p for p in data["parameters"]}


def values(params: Dict[str, dict]) -> Dict[str, object]:
    return {k: v["value"] for k, v in params.items()}


@dataclass
class Component:
    """One food component of a meal. Amounts are for the portion eaten.

    Missing is not zero: an omitted amino-acid profile falls back to the
    protein type's table (or the mixed default), and omitted carbohydrate to
    a stated share of non-protein energy; neither is read as 0 g.
    """

    name: str
    form: str  # "solid" | "liquid" | "water" | "coagulating"
    kcal: float = 0.0
    protein_g: float = 0.0
    # grams of each amino acid in the portion (a measured profile).
    amino_acids_g: Optional[Dict[str, float]] = None
    water_ml: float = 0.0
    carbohydrate_g: Optional[float] = None
    fat_g: Optional[float] = None
    protein_type: str = "mixed"  # one of PROTEIN_TYPES

    def profile_basis(self) -> str:
        if self.amino_acids_g is not None:
            return "measured"
        return "mixed_default" if self.protein_type == "mixed" else "protein_type_table"

    def aa_grams(self, v: Dict[str, object]) -> Dict[str, float]:
        if self.amino_acids_g is not None:
            return {a: self.amino_acids_g.get(a, 0.0) for a in BBB_SET}
        if self.protein_type == "mixed":
            composition = v["aa.mixed_protein_composition_g_per_g"]
            return {a: self.protein_g * float(composition[a]) for a in BBB_SET}
        table = v["aa.composition_by_protein_type_g_per_g"]
        return {a: self.protein_g * float(table[f"{self.protein_type}.{a}"]) for a in BBB_SET}

    def carbohydrate_grams(self, default_share: float) -> float:
        if self.carbohydrate_g is not None:
            return self.carbohydrate_g
        non_protein = max(self.kcal - KCAL_PER_G["protein"] * self.protein_g, 0.0)
        if self.fat_g is not None:
            return max(non_protein - KCAL_PER_G["fat"] * self.fat_g, 0.0) / KCAL_PER_G["carbohydrate"]
        return default_share * non_protein / KCAL_PER_G["carbohydrate"]


@dataclass
class Meal:
    time_min: float
    components: List[Component]


@dataclass
class Dose:
    time_min: float
    levodopa_mg: float
    formulation: str = "ir"  # only immediate release is executable


@dataclass
class Infusion:
    start_min: float
    end_min: float
    mg_per_min: float


@dataclass
class Scenario:
    meals: List[Meal] = field(default_factory=list)
    doses: List[Dose] = field(default_factory=list)
    infusions: List[Infusion] = field(default_factory=list)
    t_end_min: float = 360.0
    dt_min: float = 0.25
    record_every_min: float = 1.0
    # Habitual daily protein intake that sets amino-acid disposal; None uses
    # the population reference intake.
    habitual_protein_g_per_kg_day: Optional[float] = None


@dataclass
class _ComponentState:
    e0: float
    s1: float
    s2: float
    p: float
    aa_umol: List[float]  # digestible µmol of each amino acid
    carb_g: float
    k_dig: float
    gut_aa: List[float]
    solid: bool


def habitual_loss(table: Dict[str, float], intake: float) -> float:
    """Fasting nitrogen loss at a habitual intake: linear interpolation in the
    Price 1994 table, held flat beyond its ends."""
    pts = sorted((float(k), float(x)) for k, x in table.items())
    if intake <= pts[0][0]:
        return pts[0][1]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if intake <= x1:
            return y0 + (y1 - y0) * (intake - x0) / (x1 - x0)
    return pts[-1][1]


def simulate(scenario: Scenario, v: Dict[str, object]) -> Dict[str, List[float]]:
    """Explicit-Euler integration on a fixed grid. Deterministic."""

    dt = scenario.dt_min
    k_t = float(v["stomach.solid_trituration_rate_per_min"])
    r_max = float(v["stomach.energy_delivery_max_kcal_per_min"])
    e50 = float(v["stomach.energy_tail_half_kcal"])
    k_fast = math.log(2) / float(v["stomach.fasted_liquid_half_time_min"])
    f50 = float(v["stomach.fed_liquid_slowing_half_kcal"])
    k_dis = math.log(2) / float(v["levodopa.ir_dissolution_half_time_min"])
    ka = math.log(2) / float(v["levodopa.gut_absorption_half_time_min"])
    cl = float(v["levodopa.apparent_clearance_l_per_h"]) / 60.0  # L/min
    vd = float(v["levodopa.apparent_volume_l"])
    k_el = cl / vd
    v_aa = float(v["aa.plasma_distribution_volume_l"])
    k_out = math.log(2) / float(v["aa.plasma_relaxation_half_time_min"])
    if scenario.habitual_protein_g_per_kg_day is not None:
        table = v["aa.habitual_fasting_nitrogen_loss_mg_per_kg_day"]
        k_out *= habitual_loss(table, scenario.habitual_protein_g_per_kg_day) / habitual_loss(
            table, float(v["aa.reference_habitual_protein_g_per_kg_day"]))
    f_sys = [float(v["aa.systemic_fraction"][a]) for a in BBB_SET]
    c_base = [float(v["aa.fasting_plasma_umol_per_l"][a]) for a in BBB_SET]
    km = [float(v["bbb.km_umol_per_l"][a]) for a in BBB_SET]
    dig_half = v["aa.digestion_half_time_by_protein_type_min"]
    tid = v["aa.true_ileal_digestibility_by_protein_type"]
    k_carb = math.log(2) / float(v["insulin.carbohydrate_absorption_half_time_min"])
    k_ins = math.log(2) / float(v["insulin.action_half_time_min"])
    i50 = float(v["insulin.half_effect_carbohydrate_g_per_min"])
    e_max = float(v["insulin.max_lnaa_target_reduction"])
    sens = [float(v["insulin.lnaa_sensitivity"][a]) for a in BBB_SET]
    carb_share = float(v["insulin.default_carbohydrate_energy_share"])
    n = len(BBB_SET)

    comps: List[_ComponentState] = []
    water_ml = 0.0
    tablet = dissolved = gut = plasma_mg = 0.0
    gut_carb = insulin = 0.0
    conc = list(c_base)
    absorbed = [0.0] * n
    denom_base = 1.0
    for i in range(n):
        denom_base += c_base[i] / km[i]

    meals = sorted(scenario.meals, key=lambda m: m.time_min)
    doses = sorted(scenario.doses, key=lambda d: d.time_min)
    mi = di = 0

    out: Dict[str, List[float]] = {k: [] for k in SERIES_KEYS}
    solid_e0 = 0.0
    steps = int(round(scenario.t_end_min / dt))
    rec_stride = max(1, int(round(scenario.record_every_min / dt)))

    for step in range(steps + 1):
        t = step * dt
        while mi < len(meals) and meals[mi].time_min <= t + 1e-9:
            for c in meals[mi].components:
                if c.form == "water":
                    water_ml += c.water_ml
                    continue
                if c.protein_type not in PROTEIN_TYPES:
                    raise ValueError(f"unknown protein type {c.protein_type!r}")
                grams = c.aa_grams(v)
                digestible = float(tid[c.protein_type])
                aa = [grams[a] / MW[a] * 1e6 * digestible for a in BBB_SET]
                kcal = max(c.kcal, 1e-9)
                k_dig = math.log(2) / float(dig_half[c.protein_type])
                carb = c.carbohydrate_grams(carb_share)
                if c.form in ("solid", "coagulating"):
                    comps.append(_ComponentState(kcal, kcal, 0.0, 0.0, aa, carb, k_dig, [0.0] * n, True))
                    solid_e0 += kcal
                else:
                    comps.append(_ComponentState(kcal, 0.0, 0.0, kcal, aa, carb, k_dig, [0.0] * n, False))
                water_ml += c.water_ml
            mi += 1
        while di < len(doses) and doses[di].time_min <= t + 1e-9:
            if doses[di].formulation != "ir":
                raise ValueError("only immediate-release levodopa is executable")
            tablet += doses[di].levodopa_mg
            di += 1

        p_tot = 0.0
        fed = 0.0
        for c in comps:
            p_tot += c.p
            fed += c.s1 + c.s2 + c.p
        out_tot = r_max * p_tot / (p_tot + e50) if p_tot > 0 else 0.0
        k_liq = k_fast / (1.0 + fed / f50)
        effect = insulin / (insulin + i50) if insulin > 0 else 0.0

        carb_in = 0.0
        for i in range(n):
            absorbed[i] = 0.0
        for c in comps:
            out_c = out_tot * (c.p / p_tot) if p_tot > 0 else 0.0
            frac = out_c / c.e0
            carb_in += frac * c.carb_g
            for i in range(n):
                taken = c.k_dig * c.gut_aa[i]
                absorbed[i] += taken
                c.gut_aa[i] += (frac * c.aa_umol[i] - taken) * dt
            d_s1 = -k_t * c.s1
            d_s2 = k_t * c.s1 - k_t * c.s2
            d_p = k_t * c.s2 - out_c
            c.s1 += d_s1 * dt
            c.s2 += d_s2 * dt
            c.p = max(0.0, c.p + d_p * dt)

        infusion = 0.0
        for inf in scenario.infusions:
            if inf.start_min <= t < inf.end_min:
                infusion += inf.mg_per_min
        d_tab = -k_dis * tablet
        d_dis = k_dis * tablet - k_liq * dissolved
        d_gut = k_liq * dissolved - ka * gut
        d_pl = ka * gut - k_el * plasma_mg + infusion
        tablet += d_tab * dt
        dissolved += d_dis * dt
        gut += d_gut * dt
        plasma_mg += d_pl * dt
        water_ml += -k_liq * water_ml * dt

        carb_abs = k_carb * gut_carb
        gut_carb += (carb_in - carb_abs) * dt
        insulin += k_ins * (carb_abs - insulin) * dt

        appearance = 0.0
        for i in range(n):
            arriving = f_sys[i] * absorbed[i]
            if i < 6:
                appearance += arriving
            target = c_base[i] * max(0.0, 1.0 - sens[i] * e_max * effect)
            conc[i] += (arriving / v_aa - k_out * (conc[i] - target)) * dt

        if step % rec_stride == 0:
            denom = 1.0
            for i in range(n):
                denom += conc[i] / km[i]
            b = denom_base / denom
            c_ld = plasma_mg / vd
            solid_left = 0.0
            for c in comps:
                if c.solid:
                    solid_left += c.s1 + c.s2 + c.p
            lnaa6 = 0.0
            for i in range(6):
                lnaa6 += conc[i]
            out["t"].append(t)
            out["stomach_kcal"].append(fed)
            out["stomach_retention_solid"].append(solid_left / solid_e0 if solid_e0 else 0.0)
            out["energy_out_kcal_per_min"].append(out_tot)
            out["water_ml"].append(water_ml)
            out["levodopa_mg_per_l"].append(c_ld)
            out["lnaa6_umol_per_l"].append(lnaa6)
            out["brain_entry_index"].append(b)
            out["brain_delivery_index"].append(c_ld * b)
            out["leu_umol_per_l"].append(conc[0])
            out["phe_umol_per_l"].append(conc[3])
            out["tyr_umol_per_l"].append(conc[4])
            out["trp_umol_per_l"].append(conc[5])
            out["lnaa6_appearance_umol_per_min"].append(appearance)
            out["insulin_effect"].append(effect)
    return out


# ------------------------------------------------- nutrition-only outputs

def competing_lnaa_load(components: List[Component], v: Dict[str, object]) -> Dict[str, object]:
    """Competing large neutral amino acids in a serving or plate, from
    composition alone (no simulation): the six LNAAs as ingested and as
    truly ileal-digestible µmol, with the profile basis of each component.
    Water-only components carry none."""
    tid = v["aa.true_ileal_digestibility_by_protein_type"]
    rows = []
    total = digestible = 0.0
    for c in components:
        if c.form == "water":
            continue
        grams = c.aa_grams(v)
        umol = 0.0
        for a in LNAA_SIX:
            umol += grams[a] / MW[a] * 1e6
        d = umol * float(tid[c.protein_type])
        total += umol
        digestible += d
        rows.append({"name": c.name, "ingested_umol": umol, "digestible_umol": d,
                     "profile_basis": c.profile_basis()})
    return {"ingested_umol": total, "digestible_umol": digestible, "components": rows}


def meal_response(series: Dict[str, List[float]], meal_time: float, horizon: float = 240.0) -> Dict[str, float]:
    """Plasma LNAA rise and amino-acid appearance timing after a meal at
    `meal_time`, over [meal_time, meal_time + horizon]. Times are relative
    to the meal. Requires the series to start at or before the meal."""
    ts = series["t"]
    lnaa = series["lnaa6_umol_per_l"]
    appear = series["lnaa6_appearance_umol_per_min"]
    pre = at(series, "lnaa6_umol_per_l", meal_time)
    t1 = meal_time + horizon
    best_t, best = meal_time, -math.inf
    peak_t, peak_a = meal_time, -math.inf
    for t, y, a in zip(ts, lnaa, appear):
        if meal_time <= t <= t1:
            if y > best:
                best_t, best = t, y
            if a > peak_a:
                peak_t, peak_a = t, a
    rise_area = 0.0
    cum = [0.0]
    for i in range(1, len(ts)):
        a, b = max(ts[i - 1], meal_time), min(ts[i], t1)
        step = 0.0
        if b > a:
            rise_area += 0.5 * (lnaa[i - 1] + lnaa[i] - 2.0 * pre) * (b - a)
            step = 0.5 * (appear[i - 1] + appear[i]) * (b - a)
        cum.append(cum[-1] + step)
    total = cum[-1]
    half_t = math.nan
    if total > 0:
        for t, c_ in zip(ts, cum):
            if c_ >= total / 2:
                half_t = t - meal_time
                break
    return {"lnaa6_pre_umol_per_l": pre, "lnaa6_peak_rise_umol_per_l": best - pre,
            "lnaa6_peak_time_min": best_t - meal_time, "lnaa6_rise_area_umol_min_per_l": rise_area,
            "appearance_umol": total, "appearance_half_time_min": half_t,
            "appearance_peak_time_min": peak_t - meal_time}


# ---------------------------------------------------------------- summaries

def at(series: Dict[str, List[float]], key: str, t: float) -> float:
    ts = series["t"]
    i = min(range(len(ts)), key=lambda j: abs(ts[j] - t))
    return series[key][i]


def peak(series: Dict[str, List[float]], key: str, t0: float = 0.0, t1: float = 1e9):
    best_t, best = None, -math.inf
    for t, y in zip(series["t"], series[key]):
        if t0 <= t <= t1 and y > best:
            best_t, best = t, y
    return best_t, best


def trough(series: Dict[str, List[float]], key: str, t0: float = 0.0, t1: float = 1e9):
    best_t, best = None, math.inf
    for t, y in zip(series["t"], series[key]):
        if t0 <= t <= t1 and y < best:
            best_t, best = t, y
    return best_t, best


def area(series: Dict[str, List[float]], key: str, t0: float, t1: float) -> float:
    ts, ys = series["t"], series[key]
    total = 0.0
    for i in range(1, len(ts)):
        a, b = max(ts[i - 1], t0), min(ts[i], t1)
        if b > a:
            total += 0.5 * (ys[i - 1] + ys[i]) * (b - a)
    return total


# ------------------------------------------------- population variability

def sample_population(params: Dict[str, dict], n: int, seed: int) -> List[Dict[str, object]]:
    """Seeded log-normal draws for parameters that declare `iiv_cv`; a table
    shares one factor.

    Deterministic for a given seed, so replays stay byte-stable. Draws describe
    published between-person spread; they are not estimates for any person.
    """

    rng = random.Random(seed)
    base = values(params)
    draws = []
    for _ in range(n):
        v = dict(base)
        for pid, p in params.items():
            cv = p.get("iiv_cv")
            if not cv:
                continue
            sigma = math.sqrt(math.log(1.0 + float(cv) ** 2))
            if isinstance(p["value"], dict):
                factor = math.exp(rng.gauss(0.0, sigma) - sigma ** 2 / 2)
                v[pid] = {k: float(x) * factor for k, x in p["value"].items()}
            else:
                v[pid] = float(p["value"]) * math.exp(rng.gauss(0.0, sigma) - sigma ** 2 / 2)
        draws.append(v)
    return draws


def percentile(xs: List[float], q: float) -> float:
    s = sorted(xs)
    if not s:
        return float("nan")
    k = (len(s) - 1) * q
    lo, hi = math.floor(k), math.ceil(k)
    return s[lo] + (s[hi] - s[lo]) * (k - lo)
