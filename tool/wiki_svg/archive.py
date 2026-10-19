"""Archive-selection animation, adapted from the Learning Radar archive array.

An isometric field of standing cards (one per archived item) idles; a crest
with a trailing trough sweeps across the field (neighbouring cards describe
one continuous surface, not independent tweens); the selected card's
neighbours settle with a damped shoulder; non-selected columns recede; the
selected card is extracted in one monotone lift while its record opens in the
side panel. The cycle repeats for each selected item.

Adaptations: English copy, ParkinSUM's Paper palette, no 3D runtime (pure
SVG + CSS), a legible static frame under reduced motion, and a panel that
states what each item does and does not support.
"""

import math
from common import (svg, text, pct, ENTER, EXIT, SMOOTH, spring_tf, escape)

K = 25.0
COS = math.cos(math.radians(30))
SIN = 0.5


def proj(ox, oy, x, y, z):
    return (ox + (x - y) * COS * K, oy + (x + y) * SIN * K - z * K)


def poly(pts, cls):
    d = " ".join(f"{px:.1f},{py:.1f}" for px, py in pts)
    return f'<polygon class="{cls}" points="{d}"/>'


def card_shapes(ox, oy, X, Y, w, d, h, accent=False):
    p = lambda x, y, z: proj(ox, oy, x, y, z)
    top = [p(X, Y, h), p(X + w, Y, h), p(X + w, Y + d, h), p(X, Y + d, h)]
    front = [p(X, Y + d, 0), p(X + w, Y + d, 0), p(X + w, Y + d, h),
             p(X, Y + d, h)]
    side = [p(X + w, Y, 0), p(X + w, Y + d, 0), p(X + w, Y + d, h),
            p(X + w, Y, h)]
    parts = [poly(front, "cf"), poly(side, "cs"), poly(top, "ct")]
    sx, sy = p(X + 0.25, Y + d, h - 0.28)
    ex, ey = p(X + w * 0.52, Y + d, h - 0.28)
    parts.append(f'<line class="spine{" hot" if accent else ""}" '
                 f'x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}"/>')
    dx, dy = p(X + w - 0.32, Y + d, h - 0.3)
    parts.append(f'<circle class="hole" cx="{dx:.1f}" cy="{dy:.1f}" r="2.1"/>')
    return "".join(parts)


def build(*, name, title, desc, kicker, selecting, items, lanes, rows,
          selections, width=960, height=470, legend, origin=(300.0, 78.0)):
    """items: list of dicts {index, heading, lines[], tag} per selection.
    selections: list of (lane, row) per segment, same length as items."""
    seg = 6.0
    px = 600
    n = len(items)
    total = seg * n
    ox, oy = origin
    lane_gap, row_gap, w, d, h = 3.3, 0.44, 2.9, 0.2, 2.0
    lift = 82

    css = [f"""
.cf {{ fill: var(--left); stroke: var(--line); stroke-width: .6; }}
.cs {{ fill: var(--right); stroke: var(--line); stroke-width: .6; }}
.ct {{ fill: var(--top); stroke: var(--line); stroke-width: .6; }}
.spine {{ stroke: var(--faint); stroke-width: 1.4; stroke-linecap: round; }}
.spine.hot {{ stroke: var(--faint); stroke-width: 2; }}
.hole {{ fill: var(--dot); }}
.w {{ animation: wave {seg}s {SMOOTH} infinite; }}
@keyframes wave {{
  0%, 30% {{ transform: translateY(0); }}
  37% {{ transform: translateY(-22px); }}
  43% {{ transform: translateY(-5px); }}
  47% {{ transform: translateY(3px); }}
  53%, 100% {{ transform: translateY(0); }}
}}
.panel-rule {{ stroke: var(--ink); stroke-width: 1; }}
.scan {{ stroke: var(--accent); stroke-width: 1.6; stroke-dasharray: 300;
  stroke-dashoffset: 300; animation: scan {seg}s linear infinite; }}
@keyframes scan {{ 0% {{ stroke-dashoffset: 300; }} 55% {{ stroke-dashoffset: 0; }}
  62%, 100% {{ stroke-dashoffset: 0; opacity: 0; }} }}
"""]

    # Per-segment windows (fractions of one segment).
    def g(s, f):
        return pct((s + f) / n * 100)

    # Selecting label: visible except while a record is open.
    sel_frames = ["0% { opacity: 1; }"]
    for s in range(n):
        sel_frames.append(f"{g(s, .60)} {{ opacity: 1; }}")
        sel_frames.append(f"{g(s, .66)}, {g(s, .90)} {{ opacity: 0; }}")
        sel_frames.append(f"{g(s, .96)} {{ opacity: 1; }}")
    css.append(f".selecting {{ animation: selecting {total}s linear infinite; }}"
               f"@keyframes selecting {{ {' '.join(sel_frames)} 100% {{ opacity: 1; }} }}")

    # Index marker moves to the active item.
    idx_frames = []
    for s in range(n):
        idx_frames.append(f"{g(s, 0)}, {g(s, .999)} {{ transform: translateX({s * 34}px); }}")
    css.append(f".idx {{ animation: idx {total}s steps(1) infinite; }}"
               f"@keyframes idx {{ {' '.join(idx_frames)} 100% {{ transform: translateX(0); }} }}")

    selected = {sel: s for s, sel in enumerate(selections)}
    sel_lane_by_seg = [lane for lane, _ in selections]

    # Column focus: other lanes recede while a record is open.
    for lane in range(lanes):
        fr = ["0% { opacity: 1; }"]
        for s in range(n):
            if sel_lane_by_seg[s] == lane:
                continue
            fr += [f"{g(s, .60)} {{ opacity: 1; animation-timing-function: {ENTER}; }}",
                   f"{g(s, .70)}, {g(s, .88)} {{ opacity: .34; animation-timing-function: {SMOOTH}; }}",
                   f"{g(s, .97)} {{ opacity: 1; }}"]
        css.append(f".lane{lane} {{ animation: lane{lane} {total}s linear infinite; }}"
                   f"@keyframes lane{lane} {{ {' '.join(fr)} 100% {{ opacity: 1; }} }}")

    # Extraction and settling shoulders.
    shoulder = {}
    for s, (lane, row) in enumerate(selections):
        for dr, amp in ((-1, 15), (1, 15), (-2, 7), (2, 7), (-3, 3), (3, 3)):
            shoulder.setdefault((lane, row + dr), []).append((s, amp))
    for s in range(n):
        fr = [f"0% {{ transform: translateY(0); }}",
              f"{g(s, .58)} {{ transform: translateY(0); animation-timing-function: {SMOOTH}; }}",
              f"{g(s, .74)} {{ transform: translateY(-{lift}px); }}",
              f"{g(s, .89)} {{ transform: translateY(-{lift}px); animation-timing-function: {ENTER}; }}",
              f"{g(s, .985)} {{ transform: translateY(0); }}"]
        css.append(f".x{s} {{ animation: x{s} {total}s linear infinite; }}"
                   f"@keyframes x{s} {{ {' '.join(fr)} 100% {{ transform: translateY(0); }} }}")
        hot = ["0% { stroke: var(--faint); }",
               f"{g(s, .62)} {{ stroke: var(--faint); }}",
               f"{g(s, .70)}, {g(s, .90)} {{ stroke: var(--accent); }}",
               f"{g(s, .97)} {{ stroke: var(--faint); }}"]
        face = ["0% { fill: var(--left); }",
                f"{g(s, .60)} {{ fill: var(--left); }}",
                f"{g(s, .70)}, {g(s, .90)} {{ fill: var(--top); }}",
                f"{g(s, .97)} {{ fill: var(--left); }}"]
        css.append(f".x{s} .cf {{ animation: face{s} {total}s linear infinite; }}"
                   f"@keyframes face{s} {{ {' '.join(face)} 100% {{ fill: var(--left); }} }}")
        css.append(f".x{s} .hot {{ animation: hot{s} {total}s linear infinite; }}"
                   f"@keyframes hot{s} {{ {' '.join(hot)} 100% {{ stroke: var(--faint); }} }}")
    for key, entries in shoulder.items():
        cls = f"sh{key[0]}_{key[1]}"
        fr = ["0% { transform: translateY(0); }"]
        for s, amp in sorted(entries):
            fr += [f"{g(s, .57)} {{ transform: translateY(0); {spring_tf()} }}",
                   f"{g(s, .72)}, {g(s, .88)} {{ transform: translateY(-{amp}px); animation-timing-function: {ENTER}; }}",
                   f"{g(s, .97)} {{ transform: translateY(0); }}"]
        css.append(f".{cls} {{ animation: {cls} {total}s linear infinite; }}"
                   f"@keyframes {cls} {{ {' '.join(fr)} 100% {{ transform: translateY(0); }} }}")

    # Record panels.
    for s in range(n):
        fr = ["0% { opacity: 0; transform: translateY(10px); }",
              f"{g(s, .63)} {{ opacity: 0; transform: translateY(10px); animation-timing-function: {ENTER}; }}",
              f"{g(s, .71)} {{ opacity: 1; transform: translateY(0); }}",
              f"{g(s, .89)} {{ opacity: 1; transform: translateY(0); animation-timing-function: {EXIT}; }}",
              f"{g(s, .95)} {{ opacity: 0; transform: translateY(6px); }}"]
        css.append(f".rec{s} {{ opacity: 0; animation: rec{s} {total}s linear infinite; }}"
                   f"@keyframes rec{s} {{ {' '.join(fr)} 100% {{ opacity: 0; }} }}")

    # Cards, back to front.
    cards = []
    order = sorted(((l, r) for l in range(lanes) for r in range(rows)),
                   key=lambda lr: (lr[0] * lane_gap + lr[1] * row_gap, lr[0]))
    for lane, row in order:
        X, Y = lane * lane_gap, row * row_gap
        phase = row + lane * 0.65
        delay = phase * 0.075
        accent = (lane, row) in selected
        inner = card_shapes(ox, oy, X, Y, w, d, h, accent)
        # Separate groups: each owns one transform animation.
        if (lane, row) in selected:
            inner = f'<g class="x{selected[(lane, row)]}">{inner}</g>'
        if (lane, row) in shoulder:
            inner = f'<g class="sh{lane}_{row}">{inner}</g>'
        cards.append(f'<g class="lane{lane}"><g class="w" style="animation-delay:{delay:.3f}s">{inner}</g></g>')

    # Side panel.
    fade = (f'<defs><linearGradient id="fadeX" x1="0" x2="1" y1="0" y2="0">'
            f'<stop offset="0" stop-color="#fff" stop-opacity="0"/>'
            f'<stop offset=".08" stop-color="#fff"/>'
            f'<stop offset=".86" stop-color="#fff"/>'
            f'<stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
            f'<linearGradient id="fadeY" x1="0" x2="0" y1="0" y2="1">'
            f'<stop offset="0" stop-color="#fff" stop-opacity="0"/>'
            f'<stop offset=".14" stop-color="#fff"/>'
            f'<stop offset=".88" stop-color="#fff"/>'
            f'<stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
            f'<mask id="fieldX" maskUnits="userSpaceOnUse" x="0" y="0" width="{px - 24}" height="{height - 50}">'
            f'<rect width="{px - 24}" height="{height - 50}" fill="url(#fadeX)"/></mask>'
            f'<mask id="fieldY" maskUnits="userSpaceOnUse" x="0" y="0" width="{px - 24}" height="{height - 50}">'
            f'<rect width="{px - 24}" height="{height - 50}" fill="url(#fadeY)"/></mask></defs>')
    body = [fade, f'<g mask="url(#fieldX)"><g mask="url(#fieldY)">{"".join(cards)}</g></g>']
    body.append(f'<rect class="bg" x="24" y="20" width="300" height="64" opacity=".86"/>')
    body.append(text(36, 44, kicker, "cap muted"))
    body.append(text(36, 70, title, "h2 ink"))
    body.append(f'<line class="panel-rule" x1="{px}" y1="96" x2="{width - 36}" y2="96"/>')
    body.append(text(px, 84, "Archive window", "cap muted"))
    for s in range(n):
        body.append(text(px + 230 + s * 34, 84, f"{s + 1:02d}", "small mono muted"))
    body.append(f'<rect class="idx accent" x="{px + 230}" y="89" width="22" height="2"/>')
    body.append(f'<g class="selecting">{text(px, 136, selecting, "cap ink")}'
                f'<line class="scan" x1="{px}" y1="146" x2="{px + 240}" y2="146"/></g>')
    for s, item in enumerate(items):
        lines = [f'<g class="rec{s}">',
                 text(px, 126, item["tag"], "cap accent"),
                 text(px, 152, item["heading"], "h2 ink", extra=' style="font-size:18px"')]
        y = 176
        for label, value in item["rows"]:
            lines.append(text(px, y, label, "cap muted"))
            y += 18
            for ln in value:
                lines.append(text(px, y, ln, "body ink2"))
                y += 18
            y += 8
        lines.append("</g>")
        body.append("".join(lines))
    body.append(f'<line class="panel-rule" x1="36" y1="{height - 46}" x2="{width - 36}" y2="{height - 46}"/>')
    body.append(text(36, height - 24, legend, "small muted"))

    first_lane, first_row = selections[0]
    reduced = (f".rec0 {{ opacity: 1; }} .selecting {{ opacity: 0; }} .x0 .hot {{ stroke: var(--accent); }} .x0 .cf {{ fill: var(--top); }} "
               f".x0 {{ transform: translateY(-{lift}px); }} "
               + " ".join(f".lane{l} {{ opacity: .34; }}" for l in range(lanes)
                          if l != first_lane))
    return svg(width, height, title, desc, "".join(css), "\n".join(body),
               reduced)
