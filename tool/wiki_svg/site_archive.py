"""Regenerates the CSS-only archive selectors on the Paper showcase site.

Usage (from the repository root):
  python3 tool/wiki_svg/site_archive.py

Rewrites the marked regions of docs/site/ (the GitHub Pages showcase) and
docs/website/ (the parkinsum.com site) from one set of records. Both pages stay
free of JavaScript: radio inputs choose a record and `:has()`
carries the choice to an isometric field drawn in inline SVG. Each card's
transition delay grows with its distance from the chosen card, so changes
ripple outward; neighbours in the same column settle as shoulders, other
columns recede and the chosen card is lifted out. Changing the keyframe name
per choice restarts a travelling crest. The site's reduced-motion rule turns
every transition and animation off; the choice still changes instantly.

docs/website/ draws the same records as a 3D library: designed books (box
file, booklet, journal or ledger binder) stand among anonymous files on an
isometric base, and scrolling extracts them to a reading shelf. Each book is the
radio's label; choosing one opens its reading copy like a physical book. Its hero also gets
an ambient card field, drawn with one <use> per card, idling out of phase and
swept by a recurring crest.
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
WEB_HTML = os.path.join(ROOT, "docs", "website", "index.html")
WEB_CSS = os.path.join(ROOT, "docs", "website", "styles.css")

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

KIND = {"Reference dataset": "dataset", "Consensus standard": "standard",
        "Primary human study": "study", "Analytical study": "analytical"}

# --- parkinsum.com: a 3D library -------------------------------------------
# World units are CSS px on the archive floor: x along lanes, y toward the
# viewer, z up. The page rotates the floor into an orthographic isometric view,
# so every face here is a flat element placed with one matrix3d.

FILE_W, FILE_H, LANE_PITCH, ROW_PITCH = 64, 86, 78, 12
FIELD_X, FIELD_Y, FRONT_GAP, BOOK_PITCH, MARGIN = 34, 26, 56, 66, 30
# thickness (spine width), cover width, height
BOOK = {"dataset": (28, 70, 126), "standard": (14, 60, 104), "study": (22, 64, 118),
        "analytical": (20, 62, 112), "ledger": (26, 66, 120)}

# Declarations for the chosen record: the book steps out of the shelf and its
# reading copy opens. Everything in the archive reads these custom properties.
OPEN = ("--open: 1; --vis: visible; --step-dur: 640ms; "
        "--arrive: rb-arrive; --rb-dur: 760ms; --rb-delay: 60ms; "
        "--cover-anim: cover-open; --pshade-anim: page-shadow; "
        "--cover-dur: 1250ms; --cover-delay: 700ms; "
        "--leaf1-anim: leaf-turn-1; --leaf2-anim: leaf-turn-2; --title-anim: title-in; "
        "--leaf-dur: 1150ms; --leaf-delay: 1660ms;")


def m3d(p, u, v):
    """matrix3d placing an element's top-left at p, its x-axis along u and its
    y-axis along v (so its front faces u x v)."""
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2],
         u[0] * v[1] - u[1] * v[0])
    vals = [*u, 0, *v, 0, *n, 0, *p, 1]
    return "matrix3d(" + ",".join(f"{x:g}" for x in vals) + ")"


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
NX, NY, NZ = (-1, 0, 0), (0, -1, 0), (0, 0, -1)


def face(cls, w, h, transform, inner=""):
    return (f'<span class="face {cls}" style="width:{w}px;height:{h}px;'
            f'transform:{transform}">{inner}</span>')


def book_faces(kind, it, number):
    t, c, h = BOOK[kind]
    title = escape(it["spine"])
    hole = ('<span class="spine-stamp">Blocked</span>' if kind == "ledger"
            else '<span class="spine-hole"></span>')
    spine = (f'<span class="spine-n">{number}</span><span class="spine-title">{title}</span>'
             f'{hole}<span class="spine-meta">{escape(it["meta"])}</span>')
    cover = (f'<span class="cover-n">{number}</span><span class="cover-title">{title}</span>'
             f'<span class="cover-meta">{escape(it["meta"])}</span>')
    return "".join([
        face("f-top", t, c, m3d((-t / 2, -c / 2, h), X, Y)),
        face("f-fore", t, h, m3d((t / 2, -c / 2, h), NX, NZ)),
        face("f-back", c, h, m3d((t / 2, c / 2, h), NY, NZ)),
        face("f-cover", c, h, m3d((-t / 2, -c / 2, h), Y, NZ), cover),
        face("f-spine", t, h, m3d((-t / 2, c / 2, h), X, NZ), spine),
    ])


def library_block(name, title, legend, items, note, lanes, rows):
    """The parkinsum.com archive. Record books stand among anonymous files on a
    3D base; scrolling extracts them to a reading shelf at the front. Each book
    is the radio's label: choosing one steps it forward and opens its reading
    copy, a two-page book, beside the scene. The catalogue points at the same
    radios."""
    field_d = rows * ROW_PITCH
    front_y = FIELD_Y + field_d + FRONT_GAP + 40
    width = max(FIELD_X * 2 + lanes * LANE_PITCH, len(items) * BOOK_PITCH + 2 * MARGIN)
    depth = front_y + 40 + MARGIN
    slots = {(it["lane"], it["row"]) for it in items}

    out = [f'<div class="archive library-archive" data-archive="{name}">']
    out.append(f'<div class="library"><div class="lib-world" style="--w:{width}px;--d:{depth}px">')
    out.append('<span class="lib-base" aria-hidden="true">'
               + face("base-front", width, 18, m3d((0, depth, 0), X, NZ))
               + face("base-side", depth, 18, m3d((0, 0, 0), Y, NZ))
               + f'<span class="lib-shelf" style="top:{front_y - 52}px;height:104px"></span>'
               + "</span>")
    files = []
    for row in range(rows):
        for lane in range(lanes):
            if (lane, row) in slots:
                continue
            x = FIELD_X + lane * LANE_PITCH
            y = FIELD_Y + row * ROW_PITCH
            files.append(f'<span class="lib-file" style="--r:{row};--c:{lane};'
                         f'transform:{m3d((x, y, FILE_H), X, NZ)}"></span>')
    out.append('<span class="lib-files" aria-hidden="true">' + "".join(files) + "</span>")
    start = (width - len(items) * BOOK_PITCH) / 2 + BOOK_PITCH / 2
    for i, it in enumerate(items):
        kind = "ledger" if "num" in it else KIND[it["tag"]]
        number = it.get("num", f"{i + 1:02d}")
        sx = FIELD_X + it["lane"] * LANE_PITCH + FILE_W / 2
        sy = FIELD_Y + it["row"] * ROW_PITCH
        fx, fy = start + i * BOOK_PITCH, front_y
        out.append(
            f'<label class="lib-book" for="{name}-{i}" data-k="{name}-{i}" data-kind="{kind}" '
            f'style="--i:{i};--sx:{sx:g}px;--sy:{sy:g}px;--fx:{fx:g}px;--fy:{fy:g}px">'
            f'<span class="lb-body" aria-hidden="true">{book_faces(kind, it, number)}</span>'
            "</label>")
    out.append("</div></div>")

    out.append('<div class="catalogue" aria-hidden="true">'
               f'<p class="catalogue-title">{escape(title)}</p><ol>')
    for i, it in enumerate(items):
        out.append(f'<li><label for="{name}-{i}"><span>{it.get("num", f"{i + 1:02d}")}'
                   f'</span>{escape(it["short"])}</label></li>')
    out.append("</ol></div>")

    # The radios live at the top of the reading stand, so focusing one (by
    # clicking a book or the catalogue) scrolls the open book into view, not
    # the 3D scene.
    out.append('<div class="reader">')
    out.append(f'<fieldset class="rb-inputs"><legend class="sr-only">{escape(legend)}</legend>')
    for i, it in enumerate(items):
        number = it.get("num", f"{i + 1:02d}")
        checked = " checked" if i == 0 else ""
        out.append(f'<input type="radio" name="{name}" id="{name}-{i}" value="{i}"{checked} '
                   f'aria-label="{number} {escape(it["spine"])}, {escape(it["tag"])}, '
                   f'{escape(it["meta"])}" />')
    out.append("</fieldset>")
    for i, it in enumerate(items):
        kind = "ledger" if "num" in it else KIND[it["tag"]]
        number = it.get("num", f"{i + 1:02d}")
        left_rows = [(k, v) for k, v in it["rows"] if k == "Source id"]
        right_rows = [(k, v) for k, v in it["rows"] if k != "Source id"]
        dl = lambda rows_: "".join(f"<dt>{escape(k)}</dt><dd>{escape(v)}</dd>"
                                   for k, v in rows_)
        head = (f'<p class="eyebrow">{escape(it["tag"])}</p>'
                f'<h3>{escape(it["heading"])}</h3>')
        out.append(
            f'<div class="rb-slot" data-k="{name}-{i}"><div class="rb-stage">'
            f'<article class="rbook" data-kind="{kind}">'
            f'<div class="rb-page rb-right"><div class="rb-mhead">{head}</div>'
            f'<dl>{dl(right_rows)}</dl><span class="rb-folio">{number}</span></div>'
            '<div class="rb-leaf l2" aria-hidden="true"><div class="seg"><div class="seg">'
            '<div class="seg"></div></div></div></div>'
            '<div class="rb-leaf l1" aria-hidden="true"><div class="seg"><div class="seg">'
            f'<span class="rb-half">{escape(it["spine"])}</span><div class="seg"></div>'
            '</div></div></div>'
            f'<div class="rb-title">{head}'
            f'{"<dl>" + dl(left_rows) + "</dl>" if left_rows else ""}</div>'
            '<div class="rb-cover"><div class="rb-face rb-front" aria-hidden="true">'
            f'<span class="cover-n">{number}</span><span class="cover-title">'
            f'{escape(it["spine"])}</span><span class="cover-meta">{escape(it["meta"])}'
            '</span></div><div class="rb-face rb-back" aria-hidden="true"></div></div>'
            "</article></div></div>")
    out.append("</div>")
    out.append(f'<p class="archive-note">{note}</p>')
    out.append("</div>")
    return "\n".join(out)


def library_css(name, items):
    rules = []
    for i in range(len(items)):
        sel = f'.archive:has(#{name}-{i}:checked)'
        rules.append(f'{sel} [data-k="{name}-{i}"] {{ {OPEN} }}')
        rules.append(f'{sel} label[for="{name}-{i}"] {{ --on: 1; }}')
        rules.append(f'.archive:has(#{name}-{i}:focus-visible) .lib-book[for="{name}-{i}"] '
                     "{ --focus: 1; }")
    return "\n".join(rules)


def ambient_svg(lanes, rows):
    """Decorative hero field: one card shape, placed with <use> per slot."""
    p = lambda x, y, z: proj(0, 0, x, y, z)
    top = [p(0, 0, H), p(W, 0, H), p(W, D, H), p(0, D, H)]
    front = [p(0, D, 0), p(W, D, 0), p(W, D, H), p(0, D, H)]
    side = [p(W, 0, 0), p(W, D, 0), p(W, D, H), p(W, 0, H)]
    sx, sy = p(0.25, D, H - 0.28)
    ex, ey = p(W * 0.52, D, H - 0.28)
    # Presentation attributes, not classes: document selectors do not reach
    # into the <use> shadow copies.
    edge = 'stroke="#3e3025" stroke-opacity=".14" stroke-width=".6"'
    face = lambda pts, fill: (
        f'<polygon points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" '
        f'fill="{fill}" {edge}/>')
    shape = (face(front, "#ebe2d3") + face(side, "#e1d5c2") + face(top, "#f6f0e6")
             + f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" '
               'stroke="#c2b39d" stroke-width="1.2" stroke-linecap="round"/>')
    order = sorted(((l, r) for l in range(lanes) for r in range(rows)),
                   key=lambda lr: (lr[0] * LANE_GAP + lr[1] * ROW_GAP, lr[0]))
    xs, ys, uses = [], [], []
    for lane, row in order:
        dx, dy = p(lane * LANE_GAP, row * ROW_GAP, 0)
        xs.append(dx)
        ys.append(dy)
        uses.append(f'<g class="a-card" style="--c:{lane};--r:{row}">'
                    f'<use href="#a-shape" x="{dx:.1f}" y="{dy:.1f}"/></g>')
    min_x, max_x = min(xs) - 30, max(xs) + 110
    min_y, max_y = min(ys) - 90, max(ys) + 70
    return (f'<svg class="ambient-field" viewBox="{min_x:.0f} {min_y:.0f} '
            f'{max_x - min_x:.0f} {max_y - min_y:.0f}" aria-hidden="true" '
            f'focusable="false" preserveAspectRatio="xMidYMid meet">'
            f'<defs><g id="a-shape">{shape}</g></defs>' + "".join(uses) + "</svg>")


EVIDENCE = [
    {"lane": 2, "row": 9, "short": "FDC 2025", "tag": "Reference dataset",
     "spine": "FoodData Central", "meta": "2025",
     "heading": "USDA FoodData Central, release 2025-04-24",
     "rows": [("Supports", "Official nutrient ids, units and conversion factors; "
                            "26,995 SR Legacy rows for 280 foods, each re-read from "
                            "the source CSV in tests."),
              ("Does not support", "Personal intake, tolerance or a food choice "
                                   "for any specific person."),
              ("Source id", "src.usda.fdc.full_download.2025_04_24")]},
    {"lane": 1, "row": 5, "short": "SR Legacy", "tag": "Reference dataset",
     "spine": "SR Legacy", "meta": "2018",
     "heading": "USDA SR Legacy, April 2018",
     "rows": [("Supports", "Paired raw/cooked, whole/part and fresh/dried records "
                            "for consistency checks between foods."),
              ("Does not support", "Every food a person eats: values are sample "
                                   "averages that describe foods, not people."),
              ("Source id", "src.usda.sr_legacy.2018")]},
    {"lane": 3, "row": 4, "short": "FAO 2003", "tag": "Consensus standard",
     "spine": "FAO Paper 77", "meta": "2003",
     "heading": "FAO Food and Nutrition Paper 77",
     "rows": [("Supports", "General energy factors used to reconcile reported "
                            "energy with the macronutrients."),
              ("Does not support", "Proof of an error: a residual only flags a "
                                   "record for review within a tolerance."),
              ("Source id", "src.fao.food_energy.2003")]},
    {"lane": 2, "row": 13, "short": "Nutt 1989", "tag": "Primary human study",
     "spine": "Nutt et al.", "meta": "1989",
     "heading": "Nutt et al. 1989, plasma LNAAs",
     "rows": [("Supports", "Naming LNAA competition as a studied mechanism in "
                            "the competition trace."),
              ("Does not support", "A universal penalty or a predictor. On a normal "
                                   "diet most participants showed no important "
                                   "LNAA effect, and the trace keeps that negative "
                                   "finding."),
              ("Source id", "src.nutt.lnaa.1989")]},
    {"lane": 4, "row": 8, "short": "Duan 2021", "tag": "Analytical study",
     "spine": "Duan et al.", "meta": "2021",
     "heading": "Duan et al. 2021, faba bean L-dopa",
     "rows": [("Supports", "Food-borne L-dopa shown as presence and variability "
                            "context."),
              ("Does not support", "A cooked-serving amount, an absorbed amount or "
                                   "any dose equivalent."),
              ("Source id", "src.duan.faba_ldopa_thermal.2021")]},
    {"lane": 1, "row": 11, "short": "Hallberg 1991", "tag": "Primary human study",
     "spine": "Hallberg et al.", "meta": "1991",
     "heading": "Hallberg et al. 1991, calcium and iron",
     "rows": [("Supports", "A co-consumption context note: single-meal isotope "
                            "studies of calcium and non-heme iron."),
              ("Does not support", "Long-term iron status or an instruction about "
                                   "food or medicines."),
              ("Source id", "src.hallberg.calcium_iron.1991")]},
]

LEDGER = [
    {"lane": 1, "row": 3, "short": "Record 01", "tag": "Record 01 · 2026-08-18",
     "spine": "Initial baseline", "num": "01", "meta": "v52",
     "heading": "Initial governed baseline",
     "rows": [("Change", "The v52 release refresh adopted as the first governed "
                          "configuration."),
              ("Disposition", "Blocked pending evidence · no approval")]},
    {"lane": 0, "row": 8, "short": "Record 25", "tag": "Record 25 · v76",
     "spine": "Restore performance", "num": "25", "meta": "v76",
     "heading": "Browser restore performance",
     "rows": [("Change", "Digest reuse only for the exact same canonical string; "
                          "canonical bytes and calculations unchanged."),
              ("Disposition", "Blocked pending evidence · no approval")]},
    {"lane": 2, "row": 6, "short": "Record 26", "tag": "Record 26 · v77",
     "spine": "LNAA calibration", "num": "26", "meta": "v77",
     "heading": "LNAA load calibration",
     "rows": [("Change", "Competing-LNAA fraction of protein calibrated on official "
                          "amino-acid rows: 0.45 → 0.2667."),
              ("Disposition", "Blocked pending evidence · no approval")]},
    {"lane": 2, "row": 10, "short": "Record 27", "tag": "Record 27 · v78",
     "spine": "Record identities", "num": "27", "meta": "v78",
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


EV_NOTE = ("Every model assumption points to one of these records. A record "
           "states what it supports <em>and</em> what it does not.")
LG_NOTE = ("Matching hashes prove software identity only. No record claims "
           "scientific validation, review or clinical qualification.")


def write_regions(html_path, css_path, shelf):
    if shelf:
        evidence = library_block("ev", "Catalogue", "Choose a source", EVIDENCE,
                                 EV_NOTE, 6, 14)
        ledger = library_block("lg", "Ledger", "Choose a ledger record", LEDGER,
                               LG_NOTE, 4, 11)
    else:
        evidence = block("ev", "Evidence archive", "Choose a source", 6, 16,
                         EVIDENCE, EV_NOTE)
        ledger = block("lg", "Governance ledger", "Choose a ledger record", 4, 13,
                       LEDGER, LG_NOTE)
    html = open(html_path, encoding="utf-8").read()
    html = replace_region(
        html, "<!-- archive:evidence:start -->", "<!-- archive:evidence:end -->", evidence)
    html = replace_region(
        html, "<!-- archive:ledger:start -->", "<!-- archive:ledger:end -->", ledger)
    if shelf:
        html = replace_region(
            html, "<!-- archive:ambient:start -->", "<!-- archive:ambient:end -->",
            ambient_svg(6, 16))
    open(html_path, "w", encoding="utf-8").write(html)

    count = max(len(EVIDENCE), len(LEDGER))
    if shelf:
        generated = [library_css("ev", EVIDENCE), library_css("lg", LEDGER)]
    else:
        keyframes = "\n".join(
            f"@keyframes archive-crest-{i} {{ 0% {{ transform: translateY(0); }} "
            f"35% {{ transform: translateY(-16px); }} 62% {{ transform: translateY(4px); }} "
            f"100% {{ transform: translateY(0); }} }}"
            for i in range(count))
        generated = [selection_css("ev", EVIDENCE), selection_css("lg", LEDGER), keyframes]
    css = open(css_path, encoding="utf-8").read()
    css = replace_region(
        css, "/* archive:generated:start */", "/* archive:generated:end */",
        "\n".join(generated))
    open(css_path, "w", encoding="utf-8").write(css)


def main():
    write_regions(HTML, CSS, shelf=False)
    write_regions(WEB_HTML, WEB_CSS, shelf=True)
    print("site archives written")


if __name__ == "__main__":
    main()
