"""What-if explorer prototype: one synthetic dose, a meal at different offsets.

  python3 -I tool/physiology_reference/whatif.py [--draws 200] [--svg PATH] [--json PATH]

Prints modeled, population-typical values with 5th-95th percentile bands from
seeded between-person variability. It deliberately produces no ranking, no
"best" offset and no recommendation: the comparison is educational, every
number belongs to a synthetic scenario, and none is a prediction for a person.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from model import (Component, Dose, Meal, Scenario, area, load_parameters, peak,  # noqa: E402
                   percentile, sample_population, simulate, trough, values)

SEED = 20261020
OFFSETS = (None, -120, -60, -30, 0, 30, 60, 120)  # meal start relative to dose (min)
WINDOW = (0.0, 240.0)


def lunch():
    """Synthetic ~600 kcal mixed meal with 30 g protein."""
    return [Component("mixed meal", "solid", kcal=520.0, protein_g=27.0),
            Component("drink", "liquid", kcal=80.0, protein_g=3.0, water_ml=250.0),
            Component("water", "water", water_ml=250.0)]


def scenario(offset):
    t0 = 150.0  # dose time; leaves room for meals up to 120 min earlier
    meals = [] if offset is None else [Meal(t0 + offset, lunch())]
    return Scenario(meals=meals, doses=[Dose(t0, 100.0)], t_end_min=t0 + 360.0), t0


def summarize(v, offset, reference=None):
    sc, t0 = scenario(offset)
    s = simulate(sc, v)
    s = {k: list(x) for k, x in s.items()}
    s["t"] = [t - t0 for t in s["t"]]
    tmax, cmax = peak(s, "levodopa_mg_per_l", 0, 360)
    _, bmin = trough(s, "brain_entry_index", *WINDOW)
    delivery = area(s, "brain_delivery_index", *WINDOW)
    plasma = area(s, "levodopa_mg_per_l", *WINDOW)
    out = {"tmax": tmax, "cmax": cmax, "bmin": bmin, "delivery": delivery, "plasma": plasma, "series": s}
    if reference:
        out["delivery_rel"] = delivery / reference["delivery"]
        out["plasma_rel"] = plasma / reference["plasma"]
    return out


def label(offset):
    if offset is None:
        return "no meal"
    if offset == 0:
        return "meal with dose"
    return f"meal {abs(offset)} min {'before' if offset < 0 else 'after'} dose"


def run(draws):
    params = load_parameters()
    central = values(params)
    population = sample_population(params, draws, SEED)
    rows = []
    central_series = {}
    for offset in OFFSETS:
        ref_c = summarize(central, None) if offset is not None else None
        c = summarize(central, offset, ref_c)
        central_series[label(offset)] = c["series"]
        per = []
        for v in population:
            ref = summarize(v, None) if offset is not None else None
            per.append(summarize(v, offset, ref))

        def band(key):
            xs = [p[key] for p in per]
            return [percentile(xs, 0.05), percentile(xs, 0.5), percentile(xs, 0.95)]

        row = {"scenario": label(offset), "tmax_min": band("tmax"), "cmax_mg_per_l": band("cmax"),
               "brain_entry_index_min_0_4h": band("bmin")}
        if offset is not None:
            row["plasma_area_vs_no_meal"] = band("plasma_rel")
            row["brain_delivery_area_vs_no_meal"] = band("delivery_rel")
        rows.append(row)
    return rows, central_series


def fmt(b, pct=False, digits=2):
    if pct:
        return f"{b[1]:.0%} ({b[0]:.0%}-{b[2]:.0%})"
    return f"{b[1]:.{digits}f} ({b[0]:.{digits}f}-{b[2]:.{digits}f})"


def svg(central_series, path):
    """Two panels from the central parameter set: plasma levodopa and the
    brain-entry index. Self-contained, theme-aware, no script."""
    # "no meal" is drawn last and dashed so it stays visible where curves coincide.
    keys = ["meal 60 min before dose", "meal with dose", "meal 60 min after dose", "no meal"]
    colors = ["var(--c1)", "var(--c2)", "var(--c3)", "var(--c0)"]
    w, h, pad_l, pad_r, top, ph, gap = 760, 540, 56, 16, 72, 160, 72
    x0, x1 = pad_l, w - pad_r
    tmin, tmax = 0.0, 360.0

    def sx(t):
        return x0 + (t - tmin) / (tmax - tmin) * (x1 - x0)

    def sy(y, y_top, y_min, y_max):
        return y_top + ph - (y - y_min) / (y_max - y_min) * ph

    def path_for(s, key, y_top, y_min, y_max):
        pts = [(sx(t), sy(y, y_top, y_min, y_max)) for t, y in zip(s["t"], s[key]) if tmin <= t <= tmax]
        return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts[::3])

    ld_max = max(max(central_series[k]["levodopa_mg_per_l"]) for k in keys) * 1.1
    panels = [("Plasma levodopa (mg/L)", "levodopa_mg_per_l", 0.0, ld_max,
               [0, round(ld_max / 2, 1), round(ld_max, 1)]),
              ("Brain-entry index, levodopa relative to the fasting state (axis starts at 0.6)",
               "brain_entry_index", 0.6, 1.05, [0.6, 0.8, 1.0])]
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" role="img" '
             'aria-label="Modeled plasma levodopa and brain-entry index for a synthetic 100 mg dose with a meal at different times">',
             "<style>svg{--fg:#2b2622;--muted:#7a7068;--grid:#e6dfd5;--bg:#fbf8f3;"
             "--c0:#2f6f5e;--c1:#b5562b;--c2:#5b4fa3;--c3:#a07a17;font-family:system-ui,sans-serif}"
             "@media (prefers-color-scheme:dark){svg{--fg:#ece6de;--muted:#a59b90;--grid:#3a342e;--bg:#1d1a17;"
             "--c0:#6cc3a8;--c1:#f08a5d;--c2:#a99cf0;--c3:#e0b84a}}"
             "text{fill:var(--fg);font-size:12px}.m{fill:var(--muted)}.g{stroke:var(--grid);stroke-width:1}"
             "path.l{fill:none;stroke-width:2}</style>",
             f'<rect width="{w}" height="{h}" fill="var(--bg)"/>',
             f'<text x="{x0}" y="24" style="font-size:14px;font-weight:600">'
             'Synthetic 100 mg IR levodopa dose at minute 0; ~600 kcal, 30 g protein meal</text>',
             f'<text x="{x0}" y="42" class="m">Educational reference model, central parameters. '
             'Not a prediction for any person and not timing advice.</text>']
    for i, (title, key, ymin, ymax, ticks) in enumerate(panels):
        y_top = top + i * (ph + gap)
        parts.append(f'<text x="{x0}" y="{y_top - 12}" class="m">{title}</text>')
        for tk in ticks:
            y = sy(tk, y_top, ymin, ymax)
            parts.append(f'<line class="g" x1="{x0}" x2="{x1}" y1="{y:.1f}" y2="{y:.1f}"/>'
                         f'<text x="{x0 - 8}" y="{y + 4:.1f}" text-anchor="end" class="m">{tk:g}</text>')
        for t in range(0, 361, 60):
            parts.append(f'<text x="{sx(t):.1f}" y="{y_top + ph + 16}" text-anchor="middle" class="m">{t}</text>')
        for k, col in zip(keys, colors):
            dash = ' stroke-dasharray="6 4"' if k == "no meal" else ""
            parts.append(f'<path class="l" stroke="{col}"{dash} '
                         f'd="{path_for(central_series[k], key, y_top, ymin, ymax)}"/>')
    ly = h - 30
    lx = x0
    for k, col in zip(keys, colors):
        dash = ' stroke-dasharray="6 4"' if k == "no meal" else ""
        parts.append(f'<line x1="{lx}" x2="{lx + 22}" y1="{ly - 4}" y2="{ly - 4}" stroke="{col}" stroke-width="3"{dash}/>'
                     f'<text x="{lx + 28}" y="{ly}">{k}</text>')
        lx += 28 + 6.6 * len(k) + 22
    parts.append(f'<text x="{x0}" y="{h - 8}" class="m" style="font-size:11px">'
                 'Minutes after the dose. Brain-entry index: uptake at the blood-brain barrier vs the same plasma '
                 'level when fasting.</text>')
    parts.append("</svg>")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(parts) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--draws", type=int, default=200)
    ap.add_argument("--svg")
    ap.add_argument("--json")
    args = ap.parse_args()
    rows, central = run(args.draws)
    print(f"Synthetic 100 mg IR dose; ~600 kcal / 30 g protein meal. Median (5th-95th percentile), "
          f"{args.draws} seeded draws (seed {SEED}). Areas over 0-4 h after the dose.\n")
    print(f"{'scenario':<26} {'peak time min':<18} {'peak mg/L':<20} {'min brain-entry':<20} "
          f"{'plasma area':<20} {'brain delivery area'}")
    for r in rows:
        print(f"{r['scenario']:<26} {fmt(r['tmax_min'], digits=0):<18} {fmt(r['cmax_mg_per_l']):<20} "
              f"{fmt(r['brain_entry_index_min_0_4h']):<20} "
              f"{fmt(r['plasma_area_vs_no_meal'], pct=True) if 'plasma_area_vs_no_meal' in r else 'reference':<20} "
              f"{fmt(r['brain_delivery_area_vs_no_meal'], pct=True) if 'brain_delivery_area_vs_no_meal' in r else 'reference'}")
    if args.svg:
        svg(central, args.svg)
        print("\nwrote", args.svg)
    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({"seed": SEED, "draws": args.draws, "rows": rows}, fh, indent=2)


if __name__ == "__main__":
    main()
