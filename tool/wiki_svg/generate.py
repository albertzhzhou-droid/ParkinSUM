"""Regenerates the animated SVGs of the GitHub wiki.

Usage (from the repository root):
  python3 tool/wiki_svg/generate.py

Writes docs/github-wiki/assets/*.svg. The wiki pages in docs/github-wiki/
mirror the GitHub wiki; publish by copying that folder into a clone of
ParkinSUM.wiki.git and pushing. Every SVG is self-contained (inline CSS, no
scripts), follows the Paper palette, switches with prefers-color-scheme and
stops animating under prefers-reduced-motion.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from archive import build  # noqa: E402
from common import svg, text, ENTER, EXIT, SMOOTH, spring_tf  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                   "docs", "github-wiki", "assets")

def write(name, content):
    open(os.path.join(OUT, name), "w").write(content)
    print(name, len(content))


# ---------------------------------------------------------------- hero
def hero():
    W, H = 960, 300
    cx, cy = 742, 150
    css = f"""
.ring {{ stroke: var(--ink); stroke-width: 1.3; fill: none; }}
.ring2 {{ stroke: var(--line); stroke-width: 6; fill: none; }}
.draw {{ stroke-dasharray: 760; stroke-dashoffset: 760;
  animation: draw 9s {SMOOTH} infinite; }}
@keyframes draw {{ 0% {{ stroke-dashoffset: 760; }} 22%, 78% {{ stroke-dashoffset: 0; }}
  96%, 100% {{ stroke-dashoffset: -760; }} }}
.spin {{ transform-origin: {cx}px {cy}px; animation: spin 14s linear infinite; }}
.spin-r {{ transform-origin: {cx}px {cy}px; animation: spin 9s linear infinite reverse; }}
@keyframes spin {{ to {{ transform: rotate(360deg); }} }}
.orbit {{ transform-origin: {cx}px {cy}px; animation: spin 6s {SMOOTH} infinite; }}
.word {{ opacity: 0; animation: word 9s linear infinite; }}
.word.b {{ animation-delay: 3s; }} .word.c {{ animation-delay: 6s; }}
@keyframes word {{ 0% {{ opacity: 0; transform: translateY(6px); animation-timing-function: {ENTER}; }}
  6%, 28% {{ opacity: 1; transform: translateY(0); animation-timing-function: {EXIT}; }}
  33%, 100% {{ opacity: 0; transform: translateY(-4px); }} }}
.stat {{ opacity: 0; animation: stat .9s {ENTER} forwards; }}
.stat.s2 {{ animation-delay: .25s; }} .stat.s3 {{ animation-delay: .5s; }}
@keyframes stat {{ from {{ opacity: 0; transform: translateY(8px); }} to {{ opacity: 1; transform: none; }} }}
.tick {{ stroke: var(--accent); stroke-width: 2; }}
"""
    b = []
    b.append(text(48, 64, "Educational prototype · local-first · synthetic data", "cap muted"))
    b.append(text(48, 112, "PARKINSUM", "h1 ink", extra=' style="font-size:44px;letter-spacing:.06em"'))
    b.append(text(48, 140, "COMPANION", "cap ink", extra=' style="font-size:14px;letter-spacing:.42em"'))
    b.append(text(48, 176, "Meal and medication records, deterministic and traceable", "body ink2"))
    b.append(text(48, 196, "conflict reasoning, evidence you can inspect.", "body ink2"))
    stats = [("65", "registered algorithms"), ("26,995", "official FDC rows"),
             ("0", "clinical claims")]
    for i, (v, l) in enumerate(stats):
        x = 48 + i * 168
        b.append(f'<g class="stat s{i + 1}"><line class="tick" x1="{x}" y1="226" x2="{x + 18}" y2="226"/>'
                 f'{text(x, 254, v, "h2 ink")}{text(x, 274, l, "small muted")}</g>')
    b.append(f'<circle class="ring2" cx="{cx}" cy="{cy}" r="104"/>')
    b.append(f'<circle class="ring draw" cx="{cx}" cy="{cy}" r="120"/>')
    b.append(f'<g class="spin"><path class="ring" d="M {cx - 96} {cy - 28} A 100 100 0 0 1 {cx + 30} {cy - 95}"/>'
             f'<path class="ring" d="M {cx + 96} {cy + 28} A 100 100 0 0 1 {cx - 30} {cy + 95}"/></g>')
    b.append(f'<g class="spin-r"><path class="ring" d="M {cx - 52} {cy + 10} A 53 53 0 0 1 {cx + 30} {cy - 44}"/>'
             f'<path class="ring" d="M {cx + 50} {cy - 6} A 53 53 0 0 1 {cx - 20} {cy + 50}"/></g>')
    b.append(f'<g class="orbit"><circle class="ink" cx="{cx + 74}" cy="{cy - 84}" r="4.5"/>'
             f'<circle class="accent" cx="{cx - 74}" cy="{cy + 84}" r="4.5"/></g>')
    for cls, word in (("a", "DETERMINISTIC"), ("b", "TRACEABLE"), ("c", "NON-CLINICAL")):
        b.append(f'<g class="word {cls}">{text(cx, cy + 5, word, "cap ink", "middle", " style=\"font-size:13px\"")}</g>')
    reduced = ".word.a, .stat { opacity: 1; } .draw { stroke-dashoffset: 0; }"
    return svg(W, H, "ParkinSUM Companion",
               "Title card: an educational, local-first prototype with deterministic and "
               "traceable conflict reasoning. Rings draw and orbit around the words "
               "deterministic, traceable and non-clinical.", css, "\n".join(b), reduced)


# ---------------------------------------------------------------- pipeline
def pipeline():
    W, H = 960, 380
    T = 10.0
    nodes = [("Meal composition", "macros, form, portion"),
             ("Gastric emptying", "per-component lag"),
             ("Absorption window", "openness profile"),
             ("LNAA competition", "load × arrival"),
             ("Result", "score + confidence")]
    xs = [40 + i * 182 for i in range(5)]
    y0, wN, hN = 92, 158, 74
    css = [f"""
.node {{ fill: var(--sheet); stroke: var(--line); stroke-width: 1; }}
.wire {{ stroke: var(--line); stroke-width: 1.4; }}
.pulse {{ fill: var(--accent); }}
.rail {{ stroke: var(--gilt); stroke-width: 1.4; stroke-dasharray: 5 5; fill: none;
  animation: march 1.2s linear infinite; }}
@keyframes march {{ to {{ stroke-dashoffset: -20; }} }}
.chip {{ fill: var(--sunken); stroke: var(--line); }}
"""]
    b = [text(40, 44, "Conflict engine · one deterministic pass", "cap muted"),
         text(40, 70, "Every layer leaves a trace; interdependency findings only lower confidence", "h2 ink")]
    for i, (a, s) in enumerate(nodes):
        x = xs[i]
        start, end = i * 1.4, i * 1.4 + 1.6
        f0, f1 = start / T * 100, min(end / T * 100, 99)
        css.append(f".n{i} {{ animation: n{i} {T}s linear infinite; }}"
                   f"@keyframes n{i} {{ 0%, {f0:.1f}% {{ stroke: var(--line); stroke-width: 1; }} "
                   f"{f0 + 2:.1f}%, {f1:.1f}% {{ stroke: var(--accent); stroke-width: 2; }} "
                   f"{min(f1 + 4, 100):.1f}%, 100% {{ stroke: var(--line); stroke-width: 1; }} }}")
        b.append(f'<rect class="node n{i}" x="{x}" y="{y0}" width="{wN}" height="{hN}" rx="10"/>')
        b.append(text(x + 14, y0 + 26, f"{i + 1:02d}", "small mono muted"))
        b.append(text(x + 14, y0 + 46, a, "body ink", extra=' style="font-weight:600"'))
        b.append(text(x + 14, y0 + 63, s, "small muted"))
        if i < 4:
            x1, x2 = x + wN, xs[i + 1]
            ym = y0 + hN / 2
            b.append(f'<line class="wire" x1="{x1}" y1="{ym}" x2="{x2}" y2="{ym}"/>')
            t0, t1 = (i * 1.4 + 0.9) / T * 100, (i * 1.4 + 1.5) / T * 100
            css.append(f".p{i} {{ opacity: 0; animation: p{i} {T}s linear infinite; }}"
                       f"@keyframes p{i} {{ 0%, {t0:.1f}% {{ opacity: 0; transform: translateX(0); animation-timing-function: {SMOOTH}; }} "
                       f"{t0 + .1:.1f}% {{ opacity: 1; transform: translateX(0); animation-timing-function: {SMOOTH}; }} "
                       f"{t1:.1f}% {{ opacity: 1; transform: translateX({x2 - x1}px); }} "
                       f"{t1 + .5:.1f}%, 100% {{ opacity: 0; transform: translateX({x2 - x1}px); }} }}")
            b.append(f'<circle class="pulse p{i}" cx="{x1}" cy="{ym}" r="4"/>')
    # Interdependency rail.
    ry = 262
    b.append(f'<rect class="node" x="40" y="{ry - 26}" width="520" height="56" rx="10"/>')
    b.append(text(56, ry - 4, "Food-composition interdependency", "body ink", extra=' style="font-weight:600"'))
    b.append(text(56, ry + 15, "food-borne L-dopa · dry vs cooked · energy identity · source-record identities", "small muted"))
    rx = xs[4] + wN - 10
    b.append(f'<path class="rail" d="M 560 {ry} H {rx} V {y0 + hN}"/>')
    b.append(text(574, ry - 8, "lowers confidence · never the score", "small", extra=' style="fill:var(--gilt)"'))
    # Result chips.
    css.append(f".conf-hi {{ animation: hi {T}s linear infinite; }} .conf-md {{ opacity: 0; animation: md {T}s linear infinite; }}"
               f"@keyframes hi {{ 0%, 70% {{ opacity: 1; }} 74%, 96% {{ opacity: 0; }} 100% {{ opacity: 1; }} }}"
               f"@keyframes md {{ 0%, 70% {{ opacity: 0; transform: translateY(6px); animation-timing-function: {ENTER}; }} 76%, 94% {{ opacity: 1; transform: none; }} 98%, 100% {{ opacity: 0; }} }}"
               f".lock {{ animation: lock {T}s linear infinite; }}"
               f"@keyframes lock {{ 0%, 70% {{ opacity: .55; }} 74%, 94% {{ opacity: 1; }} 100% {{ opacity: .55; }} }}")
    cx = xs[4]
    b.append(f'<rect class="chip" x="{cx - 6}" y="{y0 + hN + 14}" width="72" height="26" rx="13"/>')
    b.append(text(cx + 30, y0 + hN + 31, "score 0.34", "small mono ink", "middle"))
    b.append(f'<g class="lock">{text(cx + 30, y0 + hN + 54, "unchanged", "small muted", "middle")}</g>')
    b.append(f'<rect class="chip" x="{cx + 70}" y="{y0 + hN + 14}" width="68" height="26" rx="13"/>')
    b.append(f'<g class="conf-hi">{text(cx + 104, y0 + hN + 31, "conf high", "small mono ink", "middle")}</g>')
    b.append(f'<g class="conf-md">{text(cx + 104, y0 + hN + 31, "conf med", "small mono accent", "middle")}</g>')
    b.append(f'<line class="stroke-line" x1="40" y1="{H - 40}" x2="{W - 40}" y2="{H - 40}"/>')
    b.append(text(40, H - 18, "Synthetic replay values. The output is an educational trace, not a prediction for a person or a timing suggestion.", "small muted"))
    reduced = ".conf-hi { opacity: 0; } .conf-md { opacity: 1; } .lock { opacity: 1; }"
    return svg(W, H, "Conflict engine pipeline",
               "Five layers in order: meal composition, gastric emptying, absorption window, "
               "LNAA competition, result. A pulse travels through them. A separate "
               "interdependency layer feeds the result and lowers confidence from high to "
               "medium while the score stays unchanged.", "".join(css), "\n".join(b), reduced)


# ---------------------------------------------------------------- lnaa
def lnaa():
    W, H = 960, 450
    data = [("Dairy", 0.3381, 0.3293, 0.3451, 21, 15),
            ("Egg", 0.3154, 0.3070, 0.3444, 6, 5),
            ("Meat", 0.2643, 0.2147, 0.2660, 13, 9),
            ("Fish", 0.2637, 0.2583, 0.2670, 18, 7),
            ("Grain", 0.2634, 0.2385, 0.2927, 27, 24),
            ("Soy", 0.2566, 0.2346, 0.2787, 14, 14),
            ("Legume", 0.2484, 0.2439, 0.2670, 13, 10)]
    lo, hi = 0.18, 0.47
    x0, x1 = 170, 860
    sx = lambda v: x0 + (v - lo) / (hi - lo) * (x1 - x0)
    y0, step = 112, 34
    css = [f"""
.bar {{ fill: var(--left); stroke: var(--line); }}
.iqr {{ stroke: var(--ink); stroke-width: 1.4; }}
.ref {{ stroke: var(--accent); stroke-width: 1.6; }}
.old {{ stroke: var(--faint); stroke-width: 1.4; stroke-dasharray: 4 4; }}
.grow {{ transform-box: fill-box; transform-origin: left center; transform: scaleX(0);
  animation: grow 8s {ENTER} infinite; }}
@keyframes grow {{ 0%, 4% {{ transform: scaleX(0); }} 22%, 90% {{ transform: scaleX(1); animation-timing-function: {EXIT}; }} 98%, 100% {{ transform: scaleX(0); }} }}
.fade {{ opacity: 0; animation: fade 8s linear infinite; }}
@keyframes fade {{ 0%, 20% {{ opacity: 0; }} 28%, 90% {{ opacity: 1; }} 97%, 100% {{ opacity: 0; }} }}
.slide {{ animation: slide 8s linear infinite; }}
@keyframes slide {{ 0%, 6% {{ transform: translateX({sx(0.45) - sx(0.2667):.1f}px); animation-timing-function: {SMOOTH}; }}
  20%, 92% {{ transform: translateX(0); }} 100% {{ transform: translateX({sx(0.45) - sx(0.2667):.1f}px); }} }}
"""]
    b = [text(40, 44, "LNAA load calibration · official FDC 2025-04-24 amino-acid rows", "cap muted"),
         text(40, 70, "Competing-LNAA fraction of protein, median per protein source", "h2 ink")]
    for v in (0.2, 0.25, 0.3, 0.35, 0.4, 0.45):
        b.append(f'<line class="stroke-line" x1="{sx(v):.1f}" y1="{y0 - 18}" x2="{sx(v):.1f}" y2="{y0 + step * 7}" stroke-dasharray="2 4"/>')
        b.append(text(sx(v), y0 + step * 7 + 18, f"{v:.2f}", "small mono muted", "middle"))
    for i, (name, med, q1, q3, n, pat) in enumerate(data):
        y = y0 + i * step
        b.append(text(40, y + 14, name, "body ink"))
        b.append(text(108, y + 14, f"{n}/{pat}", "small mono faint"))
        b.append(f'<rect class="bar grow" style="animation-delay:{i * 0.08:.2f}s" x="{x0}" y="{y + 2}" width="{sx(med) - x0:.1f}" height="16" rx="3"/>')
        b.append(f'<g class="fade" style="animation-delay:{i * 0.08:.2f}s">'
                 f'<line class="iqr" x1="{sx(q1):.1f}" y1="{y + 10}" x2="{sx(q3):.1f}" y2="{y + 10}"/>'
                 f'<line class="iqr" x1="{sx(q1):.1f}" y1="{y + 5}" x2="{sx(q1):.1f}" y2="{y + 15}"/>'
                 f'<line class="iqr" x1="{sx(q3):.1f}" y1="{y + 5}" x2="{sx(q3):.1f}" y2="{y + 15}"/>'
                 f'{text(sx(q3) + 10, y + 14, f"×{med / 0.2667:.2f}", "small mono ink2")}</g>')
    yb = y0 + step * 7
    b.append(f'<line class="old" x1="{sx(0.45):.1f}" y1="{y0 - 22}" x2="{sx(0.45):.1f}" y2="{yb}"/>')
    b.append(text(sx(0.45), y0 - 28, "old 0.45", "small mono faint", "middle"))
    b.append(f'<g class="slide"><line class="ref" x1="{sx(0.2667):.1f}" y1="{y0 - 22}" x2="{sx(0.2667):.1f}" y2="{yb}"/>'
             f'{text(sx(0.2667), y0 - 28, "all-food median 0.2667", "small mono accent", "middle")}</g>')
    b.append(text(40, H - 42, "Bars: type median; whiskers: interquartile range over amino-acid patterns; n = records / patterns; ×: factor over the all-food median.", "small muted"))
    b.append(text(40, H - 22, "Composition of sampled foods, not people. The mapping from load to competition pressure stays a prototype heuristic.", "small muted"))
    reduced = ".grow { transform: none; } .fade { opacity: 1; } .slide { transform: none; }"
    return svg(W, H, "LNAA load calibration",
               "Bar chart of the median competing-LNAA fraction of protein per protein source "
               "from official FoodData Central rows: dairy 0.338, egg 0.315, meat 0.264, fish "
               "0.264, grain 0.263, soy 0.257, legume 0.248, with interquartile whiskers. The "
               "reference line slides from the old value 0.45 to the all-food median 0.2667.",
               "".join(css), "\n".join(b), reduced)


# ---------------------------------------------------------------- provenance
def provenance():
    W, H = 960, 330
    T = 7.0
    stages = [(40, "Official source", ["FDC 2025-04-24 CSV", "SHA-256 pinned"]),
              (270, "Generator", ["dart run tool/", "generate_…_table.dart"]),
              (500, "Generated table", ["26,995 rows · 280 foods", "derivation codes kept"]),
              (730, "Tests", ["every value == source", "identities audited"])]
    css = [f"""
.box {{ fill: var(--sheet); stroke: var(--line); }}
.row {{ fill: var(--left); }}
.flow {{ animation: flow {T}s {SMOOTH} infinite; opacity: 0; }}
@keyframes flow {{ 0% {{ transform: translateX(0); opacity: 0; }} 6% {{ opacity: 1; }}
  60% {{ transform: translateX(690px); opacity: 1; }} 66%, 100% {{ transform: translateX(690px); opacity: 0; }} }}
.check {{ stroke: var(--ok); stroke-width: 2.4; fill: none; stroke-linecap: round; stroke-linejoin: round;
  stroke-dasharray: 50; stroke-dashoffset: 50; animation: check {T}s linear infinite; }}
@keyframes check {{ 0%, 62% {{ stroke-dashoffset: 50; animation-timing-function: {ENTER}; }} 70%, 92% {{ stroke-dashoffset: 0; }} 100% {{ stroke-dashoffset: 50; }} }}
.gear {{ transform-origin: 380px 167px; animation: spin 6s linear infinite; }}
@keyframes spin {{ to {{ transform: rotate(360deg); }} }}
"""]
    b = [text(40, 44, "Data provenance · source to test", "cap muted"),
         text(40, 70, "Values are copied, never retyped; a test re-reads the source", "h2 ink")]
    for x, head, lines in stages:
        b.append(f'<rect class="box" x="{x}" y="112" width="190" height="110" rx="10"/>')
        b.append(text(x + 16, 140, head, "cap ink"))
        for j, ln in enumerate(lines):
            b.append(text(x + 16, 168 + j * 20, ln, "small mono ink2"))
    b.append('<line class="stroke-line" x1="60" y1="248" x2="900" y2="248"/>')
    for x in (250, 480, 710):
        b.append(f'<path class="stroke-line" d="M {x - 6} 242 l 6 6 l -6 6"/>')
    for i in range(7):
        b.append(f'<rect class="row flow" style="animation-delay:{i * 0.42:.2f}s" x="70" y="244" width="30" height="8" rx="2"/>')
    b.append(f'<path class="check" d="M 866 138 l 8 9 l 18 -20"/>')
    b.append(text(40, 290, "The 25 audit findings are inconsistencies inside the source records: pinned in tests, never corrected.", "small muted"))
    b.append(text(40, 310, "Retrieved through a pinned mirror; identity checks catch transcription errors, not a value that is consistent yet wrong.", "small muted"))
    reduced = ".flow { opacity: 0; } .check { stroke-dashoffset: 0; }"
    return svg(W, H, "Data provenance",
               "Four stages: the official FoodData Central CSV pinned by SHA-256, a generator, "
               "the generated table of 26,995 rows for 280 foods, and tests that compare every "
               "value with the source. Row tokens flow left to right and a check mark draws.",
               "".join(css), "\n".join(b), reduced)


# ---------------------------------------------------------------- identities
def identities():
    W, H = 960, 400
    T = 12.0
    css = [f"""
.card {{ fill: var(--sheet); stroke: var(--line); }}
.seg {{ transform-box: fill-box; transform-origin: left center; }}
.whole {{ fill: none; stroke: var(--ink); stroke-width: 1.4; }}
.over {{ fill: var(--accent); }}
.phase {{ opacity: .35; animation: phase {T}s linear infinite; }}
.phase.b {{ animation-delay: {T / 3:.1f}s; }} .phase.c {{ animation-delay: {2 * T / 3:.1f}s; }}
@keyframes phase {{ 0% {{ opacity: .35; animation-timing-function: {ENTER}; }} 4%, 30% {{ opacity: 1; animation-timing-function: {EXIT}; }} 34%, 100% {{ opacity: .35; }} }}
.fill {{ transform: scaleX(0); animation: fill {T}s infinite; }}
.fill.b {{ animation-delay: {T / 3:.1f}s; }} .fill.c {{ animation-delay: {2 * T / 3:.1f}s; }}
@keyframes fill {{ 0% {{ transform: scaleX(0); {spring_tf()} }} 12%, 30% {{ transform: scaleX(1); animation-timing-function: {EXIT}; }} 34%, 100% {{ transform: scaleX(0); }} }}
.flag {{ opacity: 0; animation: flag {T}s linear infinite; animation-delay: {T / 3:.1f}s; }}
@keyframes flag {{ 0%, 12% {{ opacity: 0; }} 15%, 30% {{ opacity: 1; }} 34%, 100% {{ opacity: 0; }} }}
"""]
    b = [text(40, 44, "Composition identities · definitional, not typical", "cap muted"),
         text(40, 70, "Values inside one record must agree with each other", "h2 ink")]
    panels = [
        ("a", "Energy", "kcal ≈ 4·P + 9·F + 4·C  (± tolerance)",
         [(0.22, "--left"), (0.48, "--right"), (0.26, "--top")], 0.96, False,
         "FAO 2003 general factors; food-specific factors when reported"),
        ("b", "Parts within whole", "sugars + starch + fibre ≤ carbohydrate",
         [(0.52, "--left"), (0.36, "--right"), (0.17, "--top")], 1.0, True,
         "Whole milk: sugars exceed carbohydrate ~5.3% (lactose monohydrate)"),
        ("c", "Vitamin A", "RAE = ret + βcar/12 + (αcar+βcrx)/24",
         [(0.62, "--left"), (0.26, "--right"), (0.12, "--top")], 1.0, False,
         "Institute of Medicine 2001; IU identity checked the same way"),
    ]
    for i, (cls, head, formula, segs, whole, over, note) in enumerate(panels):
        x = 40 + i * 300
        b.append(f'<g class="phase {cls}"><rect class="card" x="{x}" y="100" width="280" height="230" rx="12"/>')
        b.append(text(x + 18, 130, head, "cap ink"))
        b.append(text(x + 18, 154, formula, "small mono ink2", extra=' style="font-size:10.5px"'))
        bx, bw = x + 18, 228
        cur = bx
        b.append(f'<g class="fill {cls} seg">')
        for frac, tok in segs:
            wseg = bw * frac
            b.append(f'<rect x="{cur:.1f}" y="190" width="{wseg:.1f}" height="28" style="fill:var({tok});stroke:var(--line)"/>')
            cur += wseg
        b.append("</g>")
        b.append(f'<rect class="whole" x="{bx}" y="186" width="{bw * whole:.1f}" height="36" rx="3"/>')
        if over:
            b.append(f'<g class="flag"><rect class="over" x="{bx + bw:.1f}" y="186" width="{cur - bx - bw:.1f}" height="36"/>'
                     f'{text(bx + bw + 4, 180, "exceeds", "small accent", "end")}</g>')
        b.append(text(x + 18, 252, "Finding → pinned, never corrected" if over else "Holds within tolerance", "small " + ("accent" if over else "muted")))
        words = note.split(" ")
        line, y = "", 276
        for wd in words:
            if len(line) + len(wd) > 40:
                b.append(text(x + 18, y, line.strip(), "small muted")); y += 17; line = ""
            line += wd + " "
        b.append(text(x + 18, y, line.strip(), "small muted"))
        b.append("</g>")
    b.append(text(40, H - 40, "In the engine: an energy, proximate, carbohydrate, lipid or nitrogen finding on a scored reference food", "small ink2"))
    b.append(text(40, H - 22, "adds an uncertainty reason and caps confidence at medium. The score never moves.", "small ink2"))
    reduced = ".phase { opacity: 1; } .fill { transform: none; } .flag { opacity: 1; }"
    return svg(W, H, "Composition identities",
               "Three identity checks highlight in turn: energy from macronutrients, parts "
               "within a whole (milk sugars exceed carbohydrate, a pinned source finding), and "
               "vitamin A retinol activity equivalents. Bars fill with a spring.",
               "".join(css), "\n".join(b), reduced)


# ---------------------------------------------------------------- safety
def safety():
    W, H = 960, 360
    cx, cy = 250, 180
    css = f"""
.inner {{ fill: var(--sheet); stroke: var(--ink); stroke-width: 1.3; }}
.outer {{ fill: none; stroke: var(--accent); stroke-width: 1.4; stroke-dasharray: 3 7;
  transform-origin: {cx}px {cy}px; animation: spin 40s linear infinite; }}
.sweep {{ fill: none; stroke: var(--accent); stroke-width: 3; stroke-linecap: round;
  transform-origin: {cx}px {cy}px; animation: spin 7s {SMOOTH} infinite; }}
@keyframes spin {{ to {{ transform: rotate(360deg); }} }}
.pulse {{ fill: none; stroke: var(--line); transform-origin: {cx}px {cy}px;
  animation: pulse 4s {ENTER} infinite; }}
@keyframes pulse {{ from {{ transform: scale(.7); opacity: .9; }} to {{ transform: scale(1.25); opacity: 0; }} }}
.item {{ opacity: 0; animation: item 12s linear infinite; }}
@keyframes item {{ 0% {{ opacity: 0; transform: translateX(-6px); animation-timing-function: {ENTER}; }} 3%, 92% {{ opacity: 1; transform: none; }} 97%, 100% {{ opacity: 0; }} }}
.x {{ stroke: var(--accent); stroke-width: 1.8; stroke-linecap: round; }}
.okm {{ stroke: var(--ok); stroke-width: 1.8; fill: none; stroke-linecap: round; }}
"""
    b = [f'<circle class="pulse" cx="{cx}" cy="{cy}" r="110"/>',
         f'<circle class="outer" cx="{cx}" cy="{cy}" r="138"/>',
         f'<path class="sweep" d="M {cx} {cy - 138} A 138 138 0 0 1 {cx + 119.5} {cy - 69}"/>',
         f'<circle class="inner" cx="{cx}" cy="{cy}" r="96"/>',
         text(cx, cy - 18, "Educational", "cap ink", "middle"),
         text(cx, cy + 2, "prototype", "cap ink", "middle"),
         text(cx, cy + 26, "synthetic data only", "small muted", "middle")]
    allowed = ["Architecture and code review", "Deterministic rule explanations",
               "Synthetic-data walkthroughs", "Provenance and evidence inspection"]
    blocked = ["Diagnosis or treatment", "Medication timing or dose",
               "Dietary instructions", "Real patient data or PHI"]
    b.append(text(470, 64, "Inside the boundary", "cap ink"))
    b.append(text(760, 64, "Outside the boundary", "cap accent"))
    for i, a in enumerate(allowed):
        y = 98 + i * 34
        b.append(f'<g class="item" style="animation-delay:{i * .15:.2f}s"><path class="okm" d="M 470 {y - 4} l 4 4 l 8 -9"/>{text(490, y, a, "body ink")}</g>')
    for i, a in enumerate(blocked):
        y = 98 + i * 34
        b.append(f'<g class="item" style="animation-delay:{.6 + i * .15:.2f}s"><line class="x" x1="760" y1="{y - 9}" x2="769" y2="{y}"/><line class="x" x1="769" y1="{y - 9}" x2="760" y2="{y}"/>{text(780, y, a, "body ink")}</g>')
    b.append(f'<line class="stroke-line" x1="470" y1="250" x2="{W - 40}" y2="250"/>')
    b.append(text(470, 276, "Not a medical device and not clinically validated.", "body ink2"))
    b.append(text(470, 298, "Review any health question with a qualified clinician.", "body ink2"))
    reduced = ".item { opacity: 1; }"
    return svg(W, H, "Safety boundary",
               "A boundary ring around the words educational prototype, synthetic data only. "
               "Inside: architecture review, deterministic rule explanations, synthetic "
               "walkthroughs, provenance inspection. Outside: diagnosis or treatment, "
               "medication timing or dose, dietary instructions, real patient data.",
               css, "\n".join(b), reduced)


os.makedirs(OUT, exist_ok=True)
for fn, name in ((hero, "hero.svg"), (pipeline, "pipeline.svg"), (lnaa, "lnaa-calibration.svg"),
                 (provenance, "provenance.svg"), (identities, "identities.svg"),
                 (safety, "safety-boundary.svg")):
    write(name, fn())
evidence = build(
    name="evidence-archive",
    title="Evidence archive",
    desc=("An isometric archive of registered evidence sources. A wave passes "
          "through the cards, one card is drawn out and its record opens: "
          "what the source supports and what it does not. Four sources cycle: "
          "FoodData Central 2025-04-24, FAO Food and Nutrition Paper 77, "
          "Nutt et al. 1989 and Duan et al. 2021."),
    kicker="ParkinSUM · registered sources",
    selecting="Selecting source…",
    lanes=6, rows=22,
    selections=[(2, 9), (1, 14), (3, 6), (2, 16)],
    items=[
        {"tag": "Reference dataset", "heading": "USDA FoodData Central 2025-04-24",
         "rows": [("Supports", ["Official nutrient ids, units and conversion",
                                "factors; 26,995 SR Legacy rows for 280 foods."]),
                  ("Does not support", ["Personal intake, tolerance or any",
                                        "food choice for a specific person."]),
                  ("Id", ["src.usda.fdc.full_download.2025_04_24"])]},
        {"tag": "Consensus standard", "heading": "FAO Food & Nutrition Paper 77",
         "rows": [("Supports", ["General energy factors (4 / 9 / 4 kcal per g)",
                                "used to reconcile energy with macronutrients."]),
                  ("Does not support", ["Proof of an error: a residual flags a",
                                        "record for review inside a tolerance."]),
                  ("Id", ["src.fao.food_energy.2003"])]},
        {"tag": "Primary human study", "heading": "Nutt et al. 1989 · plasma LNAAs",
         "rows": [("Supports", ["Naming LNAA competition as a studied",
                                "mechanism in the competition trace."]),
                  ("Does not support", ["A universal penalty or a predictor: on a",
                                        "normal diet most participants showed no",
                                        "important LNAA effect (a negative finding)."]),
                  ("Id", ["src.nutt.lnaa.1989"])]},
        {"tag": "Analytical study", "heading": "Duan et al. 2021 · faba bean L-dopa",
         "rows": [("Supports", ["Food-borne L-dopa as presence and",
                                "variability context (dry-weight HPLC)."]),
                  ("Does not support", ["A cooked-serving amount, an absorbed",
                                        "amount or any dose equivalent."]),
                  ("Id", ["src.duan.faba_ldopa_thermal.2021"])]},
    ],
    legend=("Each source states what it supports and its limitation. Evidence "
            "is context for an educational prototype, never personal advice."),
)

ledger = build(
    name="governance-archive",
    title="Governance ledger archive",
    desc=("Context-of-use ledger records shown as an archive. A wave passes, "
          "one record is drawn out and opens: its sequence, change, "
          "configuration version and release disposition. Every record stays "
          "blocked pending evidence; none carries an approval."),
    kicker="ParkinSUM · context-of-use ledger",
    selecting="Opening record…",
    lanes=4, rows=14,
    selections=[(1, 4), (2, 9), (2, 12)],
    items=[
        {"tag": "Record 01 · 2026-08-18", "heading": "Initial governed baseline",
         "rows": [("Change", ["v52 release refresh adopted as the first",
                              "governed configuration."]),
                  ("Disposition", ["Blocked pending evidence · no approval"])]},
        {"tag": "Record 26 · v77", "heading": "LNAA load calibration",
         "rows": [("Change", ["Competing-LNAA fraction calibrated on",
                              "official FDC amino-acid rows (0.45 → 0.2667)."]),
                  ("Disposition", ["Blocked pending evidence · no approval"])]},
        {"tag": "Record 27 · v78", "heading": "Reference-record identities",
         "rows": [("Change", ["More source-record identities; findings cap",
                              "confidence only; LNAA trace detail."]),
                  ("Disposition", ["Blocked pending evidence · no approval"]),
                  ("Prior records", ["All 26 frozen whole records stay exact."])]},
    ],
    legend=("Matching hashes prove software identity only. No record claims "
            "scientific validation, review or clinical qualification."),
    height=430,
)

os.makedirs(OUT, exist_ok=True)
write("evidence-archive.svg", evidence)
write("governance-archive.svg", ledger)
