"""Reference physiology model (v2 prototype) for ParkinSUM.

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
             water and dissolved drug: first-order, slowed by the energy
             still in the stomach  k = k_fast / (1 + F / F50)
  levodopa   tablet -> dissolved in gastric liquid -> absorptive gut segment
             -> one plasma compartment (apparent CL/F, V/F)
  amino acids  duodenal delivery follows each component's emptied energy;
             digestion/absorption first-order; splanchnic first-pass fraction;
             one plasma pool per amino acid relaxing to its fasting value
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


def load_parameters(path: Optional[str] = None) -> Dict[str, dict]:
    with open(path or os.path.join(HERE, "parameters.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    return {p["id"]: p for p in data["parameters"]}


def values(params: Dict[str, dict]) -> Dict[str, object]:
    return {k: v["value"] for k, v in params.items()}


@dataclass
class Component:
    """One food component of a meal. Amounts are for the portion eaten."""

    name: str
    form: str  # "solid" | "liquid" | "water" | "coagulating"
    kcal: float = 0.0
    protein_g: float = 0.0
    # grams of each amino acid in the portion; defaults to a mixed-protein
    # composition scaled by protein_g when omitted.
    amino_acids_g: Optional[Dict[str, float]] = None
    water_ml: float = 0.0

    def aa_grams(self, composition: Dict[str, float]) -> Dict[str, float]:
        if self.amino_acids_g is not None:
            return {a: self.amino_acids_g.get(a, 0.0) for a in BBB_SET}
        return {a: self.protein_g * composition[a] for a in BBB_SET}


@dataclass
class Meal:
    time_min: float
    components: List[Component]


@dataclass
class Dose:
    time_min: float
    levodopa_mg: float
    formulation: str = "ir"  # only immediate release is executable in v0


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


@dataclass
class _ComponentState:
    e0: float
    s1: float
    s2: float
    p: float
    aa_umol: Dict[str, float]


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
    k_dig = math.log(2) / float(v["aa.digestion_absorption_half_time_min"])
    v_aa = float(v["aa.plasma_distribution_volume_l"])
    k_out = math.log(2) / float(v["aa.plasma_relaxation_half_time_min"])
    f_sys = v["aa.systemic_fraction"]
    c_base = v["aa.fasting_plasma_umol_per_l"]
    km = v["bbb.km_umol_per_l"]
    composition = v["aa.mixed_protein_composition_g_per_g"]

    comps: List[_ComponentState] = []
    water_ml = 0.0
    tablet = dissolved = gut = plasma_mg = 0.0
    gut_aa = {a: 0.0 for a in BBB_SET}
    conc = {a: float(c_base[a]) for a in BBB_SET}
    denom_base = 1.0 + sum(float(c_base[a]) / float(km[a]) for a in BBB_SET)

    meals = sorted(scenario.meals, key=lambda m: m.time_min)
    doses = sorted(scenario.doses, key=lambda d: d.time_min)
    mi = di = 0

    out: Dict[str, List[float]] = {k: [] for k in (
        "t", "stomach_kcal", "stomach_retention_solid", "energy_out_kcal_per_min",
        "water_ml", "levodopa_mg_per_l", "lnaa6_umol_per_l", "brain_entry_index",
        "brain_delivery_index", "leu_umol_per_l", "phe_umol_per_l",
    )}
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
                aa = {a: g / MW[a] * 1e6 for a, g in c.aa_grams(composition).items()}
                kcal = max(c.kcal, 1e-9)
                if c.form in ("solid", "coagulating"):
                    comps.append(_ComponentState(kcal, kcal, 0.0, 0.0, aa))
                    solid_e0 += kcal
                else:
                    comps.append(_ComponentState(kcal, 0.0, 0.0, kcal, aa))
                water_ml += c.water_ml
            mi += 1
        while di < len(doses) and doses[di].time_min <= t + 1e-9:
            if doses[di].formulation != "ir":
                raise ValueError("only immediate-release levodopa is executable in v0")
            tablet += doses[di].levodopa_mg
            di += 1

        p_tot = sum(c.p for c in comps)
        fed = sum(c.s1 + c.s2 + c.p for c in comps)
        out_tot = r_max * p_tot / (p_tot + e50) if p_tot > 0 else 0.0
        k_liq = k_fast / (1.0 + fed / f50)

        delivery = {a: 0.0 for a in BBB_SET}
        for c in comps:
            out_c = out_tot * (c.p / p_tot) if p_tot > 0 else 0.0
            frac = out_c / c.e0
            for a in BBB_SET:
                delivery[a] += frac * c.aa_umol[a]
            d_s1 = -k_t * c.s1
            d_s2 = k_t * c.s1 - k_t * c.s2
            d_p = k_t * c.s2 - out_c
            c.s1 += d_s1 * dt
            c.s2 += d_s2 * dt
            c.p = max(0.0, c.p + d_p * dt)

        infusion = sum(i.mg_per_min for i in scenario.infusions if i.start_min <= t < i.end_min)
        d_tab = -k_dis * tablet
        d_dis = k_dis * tablet - k_liq * dissolved
        d_gut = k_liq * dissolved - ka * gut
        d_pl = ka * gut - k_el * plasma_mg + infusion
        tablet += d_tab * dt
        dissolved += d_dis * dt
        gut += d_gut * dt
        plasma_mg += d_pl * dt
        water_ml += -k_liq * water_ml * dt

        for a in BBB_SET:
            absorbed = k_dig * gut_aa[a]
            gut_aa[a] += (delivery[a] - absorbed) * dt
            conc[a] += (float(f_sys[a]) * absorbed / v_aa
                        - k_out * (conc[a] - float(c_base[a]))) * dt

        if step % rec_stride == 0:
            denom = 1.0 + sum(conc[a] / float(km[a]) for a in BBB_SET)
            b = denom_base / denom
            c_ld = plasma_mg / vd
            solid_left = sum(c.s1 + c.s2 + c.p for c in comps if c.e0 > 0)
            out["t"].append(t)
            out["stomach_kcal"].append(fed)
            out["stomach_retention_solid"].append(solid_left / solid_e0 if solid_e0 else 0.0)
            out["energy_out_kcal_per_min"].append(out_tot)
            out["water_ml"].append(water_ml)
            out["levodopa_mg_per_l"].append(c_ld)
            out["lnaa6_umol_per_l"].append(sum(conc[a] for a in LNAA_SIX))
            out["brain_entry_index"].append(b)
            out["brain_delivery_index"].append(c_ld * b)
            out["leu_umol_per_l"].append(conc["leu"])
            out["phe_umol_per_l"].append(conc["phe"])
    return out


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
    """Seeded log-normal draws for parameters that declare `iiv_cv`.

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
