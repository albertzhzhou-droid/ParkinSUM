"""Regenerates the CSS-only archive selectors on the Paper showcase site.

Usage (from the repository root):
  python3 tool/wiki_svg/site_archive.py

Rewrites the marked regions of docs/site/index.html and docs/site/styles.css.
The page stays free of JavaScript: radio inputs choose a record and `:has()`
carries the choice to an isometric field drawn in inline SVG. Each card's
transition delay grows with its distance from the chosen card, so changes
ripple outward; neighbours in the same column settle as shoulders, other
columns recede and the chosen card is lifted out. Changing the keyframe name
per choice restarts a travelling crest. The site's reduced-motion rule turns
every transition and animation off; the choice still changes instantly.
"""

import os
import re
import sys
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from archive import proj, poly  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
HTML = os.path.join(ROOT, "docs", "site", "index.html")
CSS = os.path.join(ROOT, "docs", "site", "styles.css")

LANE_GAP, ROW_GAP, W, D, H = 3.3, 0.44, 2.9, 0.2, 2.0
LIFT_ROOM = 92  # px above the field kept free for an extracted card


def field_svg(name, lanes, rows, picks, label):
    """Inline SVG of the card field; picks maps (lane, row) -> record key."""
    ox, oy = 0.0, 0.0
    corners = []
    for lane in range(lanes):
        for row in range(rows):
            X, Y = lane * LANE_GAP, row * ROW_GAP
            for x, y, z in ((X, Y, H), (X + W, Y, 0), (X, Y + D, 0),
                            (X + W, Y + D, 0), (X, Y, 0)):
                corners.append(proj(ox, oy, x, y, z))
    min_x = min(c[0] for c in corners) - 12
    max_x = max(c[0] for c in corners) + 12
    min_y = min(c[1] for c in corners) - LIFT_ROOM
    max_y = max(c[1] for c in corners) + 12
    width, height = max_x - min_x, max_y - min_y

    order = sorted(((l, r) for l in range(lanes) for r in range(rows)),
                   key=lambda lr: (lr[0] * LANE_GAP + lr[1] * ROW_GAP, lr[0]))
    cards = []
    for lane, row in order:
        X, Y = lane * LANE_GAP, row * ROW_GAP
        p = lambda x, y, z: proj(ox, oy, x, y, z)
        top = [p(X, Y, H), p(X + W, Y, H), p(X + W, Y + D, H), p(X, Y + D, H)]
        front = [p(X, Y + D, 0), p(X + W, Y + D, 0), p(X + W, Y + D, H),
                 p(X, Y + D, H)]
        side = [p(X + W, Y, 0), p(X + W, Y + D, 0), p(X + W, Y + D, H),
                p(X + W, Y, H)]
        sx, sy = p(X + 0.25, Y + D, H - 0.28)
        ex, ey = p(X + W * 0.52, Y + D, H - 0.28)
        dx, dy = p(X + W - 0.32, Y + D, H - 0.3)
        key = picks.get((lane, row))
        parts = [poly(front, "cf"), poly(side, "cs"), poly(top, "ct")]
        if key:
            parts.append(poly(front, "cf-hot"))
        parts.append(f'<line class="spine" x1="{sx:.1f}" y1="{sy:.1f}" '
                     f'x2="{ex:.1f}" y2="{ey:.1f}"/>')
        if key:
            parts.append(f'<line class="spine-hot" x1="{sx:.1f}" y1="{sy:.1f}" '
                         f'x2="{ex:.1f}" y2="{ey:.1f}"/>')
        parts.append(f'<circle class="hole" cx="{dx:.1f}" cy="{dy:.1f}" r="2.1"/>')
        data = f' data-k="{key}"' if key else ""
        cards.append(f'<g class="card" style="--c:{lane};--r:{row}"{data}>'
                     f'<g class="lift"><g class="crest">{"".join(parts)}'
                     f'</g></g></g>')
    return (f'<svg class="archive-field" viewBox="{min_x:.1f} {min_y:.1f} '
            f'{width:.1f} {height:.1f}" role="img" aria-label="{escape(label)}">'
            + "".join(cards) + "</svg>")


def block(name, title, legend, lanes, rows, items, note):
    picks = {(it["lane"], it["row"]): f"{name}-{i}"
             for i, it in enumerate(items)}
    out = [f'<div class="archive" data-archive="{name}">']
    out.append(field_svg(name, lanes, rows, picks,
                         f"{title}: an isometric field of archive cards; "
                         "the chosen card is lifted out."))
    out.append('<div class="archive-panel">')
    out.append(f'<fieldset class="archive-index"><legend>{escape(legend)}</legend>')
    for i, it in enumerate(items):
        checked = " checked" if i == 0 else ""
        out.append(f'<label class="pick"><input type="radio" name="{name}" '
                   f'id="{name}-{i}" value="{i}"{checked} />'
                   f'<span class="pick-n">{i + 1:02d}</span>'
                   f'<span class="pick-t">{escape(it["short"])}</span></label>')
    out.append("</fieldset>")
    for i, it in enumerate(items):
        rows_html = "".join(
            f'<dt>{escape(k)}</dt><dd>{escape(v)}</dd>' for k, v in it["rows"])
        out.append(f'<article class="rec" data-k="{name}-{i}">'
                   f'<p class="eyebrow">{escape(it["tag"])}</p>'
                   f'<h3>{escape(it["heading"])}</h3><dl>{rows_html}</dl></article>')
    out.append(f'<p class="archive-note">{note}</p>')
    out.append("</div></div>")
    return "\n".join(out)


def selection_css(name, items):
    rules = []
    for i, it in enumerate(items):
        sel = f'.archive:has(#{name}-{i}:checked)'
        rules.append(f"{sel} {{ --sc: {it['lane']}; --sr: {it['row']}; }}")
        rules.append(f"{sel} .crest {{ animation-name: archive-crest-{i}; }}")
        rules.append(f'{sel} .card[data-k="{name}-{i}"] {{ --pick: 1; }}')
        rules.append(f'{sel} .rec[data-k="{name}-{i}"] {{ display: block; }}')
    return "\n".join(rules)


EVIDENCE = [
    {"lane": 2, "row": 9, "short": "FDC 2025", "tag": "Reference dataset",
     "heading": "USDA FoodData Central, release 2025-04-24",
     "rows": [("Supports", "Official nutrient ids, units and conversion factors; "
                            "26,995 SR Legacy rows for 280 foods, each re-read from "
                            "the source CSV in tests."),
              ("Does not support", "Personal intake, tolerance or a food choice "
                                   "for any specific person."),
              ("Source id", "src.usda.fdc.full_download.2025_04_24")]},
    {"lane": 1, "row": 5, "short": "SR Legacy", "tag": "Reference dataset",
     "heading": "USDA SR Legacy, April 2018",
     "rows": [("Supports", "Paired raw/cooked, whole/part and fresh/dried records "
                            "for consistency checks between foods."),
              ("Does not support", "Every food a person eats: values are sample "
                                   "averages that describe foods, not people."),
              ("Source id", "src.usda.sr_legacy.2018")]},
    {"lane": 3, "row": 4, "short": "FAO 2003", "tag": "Consensus standard",
     "heading": "FAO Food and Nutrition Paper 77",
     "rows": [("Supports", "General energy factors used to reconcile reported "
                            "energy with the macronutrients."),
              ("Does not support", "Proof of an error: a residual only flags a "
                                   "record for review within a tolerance."),
              ("Source id", "src.fao.food_energy.2003")]},
    {"lane": 2, "row": 13, "short": "Nutt 1989", "tag": "Primary human study",
     "heading": "Nutt et al. 1989, plasma LNAAs",
     "rows": [("Supports", "Naming LNAA competition as a studied mechanism in "
                            "the competition trace."),
              ("Does not support", "A universal penalty or a predictor. On a normal "
                                   "diet most participants showed no important "
                                   "LNAA effect, and the trace keeps that negative "
                                   "finding."),
              ("Source id", "src.nutt.lnaa.1989")]},
    {"lane": 4, "row": 8, "short": "Duan 2021", "tag": "Analytical study",
     "heading": "Duan et al. 2021, faba bean L-dopa",
     "rows": [("Supports", "Food-borne L-dopa shown as presence and variability "
                            "context."),
              ("Does not support", "A cooked-serving amount, an absorbed amount or "
                                   "any dose equivalent."),
              ("Source id", "src.duan.faba_ldopa_thermal.2021")]},
    {"lane": 1, "row": 11, "short": "Hallberg 1991", "tag": "Primary human study",
     "heading": "Hallberg et al. 1991, calcium and iron",
     "rows": [("Supports", "A co-consumption context note: single-meal isotope "
                            "studies of calcium and non-heme iron."),
              ("Does not support", "Long-term iron status or an instruction about "
                                   "food or medicines."),
              ("Source id", "src.hallberg.calcium_iron.1991")]},
]

LEDGER = [
    {"lane": 1, "row": 3, "short": "Record 01", "tag": "Record 01 · 2026-08-18",
     "heading": "Initial governed baseline",
     "rows": [("Change", "The v52 release refresh adopted as the first governed "
                          "configuration."),
              ("Disposition", "Blocked pending evidence · no approval")]},
    {"lane": 0, "row": 8, "short": "Record 25", "tag": "Record 25 · v76",
     "heading": "Browser restore performance",
     "rows": [("Change", "Digest reuse only for the exact same canonical string; "
                          "canonical bytes and calculations unchanged."),
              ("Disposition", "Blocked pending evidence · no approval")]},
    {"lane": 2, "row": 6, "short": "Record 26", "tag": "Record 26 · v77",
     "heading": "LNAA load calibration",
     "rows": [("Change", "Competing-LNAA fraction of protein calibrated on official "
                          "amino-acid rows: 0.45 → 0.2667."),
              ("Disposition", "Blocked pending evidence · no approval")]},
    {"lane": 2, "row": 10, "short": "Record 27", "tag": "Record 27 · v78",
     "heading": "Reference-record identities",
     "rows": [("Change", "Every official nutrient mapped; source-record findings "
                          "cap confidence only; LNAA trace detail."),
              ("Disposition", "Blocked pending evidence · no approval"),
              ("Prior records", "All 26 earlier records stay byte-exact.")]},
]


def replace_region(text, start, end, content):
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
    if not pattern.search(text):
        raise SystemExit(f"marker {start!r} not found")
    return pattern.sub(lambda _: f"{start}\n{content}\n{end}", text)


def main():
    html = open(HTML, encoding="utf-8").read()
    html = replace_region(
        html, "<!-- archive:evidence:start -->", "<!-- archive:evidence:end -->",
        block("ev", "Evidence archive", "Choose a source", 6, 16, EVIDENCE,
              "Every model assumption points to one of these records. A record "
              "states what it supports <em>and</em> what it does not."))
    html = replace_region(
        html, "<!-- archive:ledger:start -->", "<!-- archive:ledger:end -->",
        block("lg", "Governance ledger", "Choose a ledger record", 4, 13, LEDGER,
              "Matching hashes prove software identity only. No record claims "
              "scientific validation, review or clinical qualification."))
    open(HTML, "w", encoding="utf-8").write(html)

    keyframes = "\n".join(
        f"@keyframes archive-crest-{i} {{ 0% {{ transform: translateY(0); }} "
        f"35% {{ transform: translateY(-16px); }} 62% {{ transform: translateY(4px); }} "
        f"100% {{ transform: translateY(0); }} }}"
        for i in range(max(len(EVIDENCE), len(LEDGER))))
    css = open(CSS, encoding="utf-8").read()
    css = replace_region(
        css, "/* archive:generated:start */", "/* archive:generated:end */",
        "\n".join([selection_css("ev", EVIDENCE), selection_css("lg", LEDGER),
                   keyframes]))
    open(CSS, "w", encoding="utf-8").write(css)
    print("site archives written")


if __name__ == "__main__":
    main()
