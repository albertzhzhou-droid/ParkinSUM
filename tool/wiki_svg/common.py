"""Shared tokens and helpers for the ParkinSUM wiki SVG animations.

Every SVG is self-contained: inline CSS only, no scripts, no external fonts
(GitHub serves wiki images through a sandboxed image context). Colour tokens
follow the app's Paper theme and switch with prefers-color-scheme; every
animation stops under prefers-reduced-motion and a static frame stays legible.
"""

from xml.sax.saxutils import escape

SANS = ("ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, "
        "'Helvetica Neue', Arial, sans-serif")
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

# Paper theme (lib/core/theme/paper_theme.dart) and a matching dark set.
TOKENS = """
:root {
  color-scheme: light dark;
  --paper: #F6F1E6; --sheet: #FFFDF8; --sunken: #EEE6D6;
  --ink: #2A2420; --ink2: #453D35; --muted: #6E655A; --faint: #A39888;
  --line: #CBBFA8; --hair: #E2D9C8;
  --accent: #A84B2A; --accent-soft: #F3E2D6; --gilt: #A8874A; --ok: #4E7A4A;
  --top: #F2EBDD; --left: #DED3BF; --right: #CDBFA6; --dot: #2A2420;
}
@media (prefers-color-scheme: dark) {
  :root {
    --paper: #1C1916; --sheet: #26211D; --sunken: #2E2823;
    --ink: #F1E9DC; --ink2: #D9CFC0; --muted: #B3A795; --faint: #7F7568;
    --line: #5A4F44; --hair: #3A332C;
    --accent: #E38D66; --accent-soft: #4A2E22; --gilt: #CDAE72; --ok: #8DBA86;
    --top: #4A4138; --left: #3A322B; --right: #2E2822; --dot: #F1E9DC;
  }
}
"""

BASE_CSS = f"""
.bg {{ fill: var(--paper); }}
.ink {{ fill: var(--ink); }} .ink2 {{ fill: var(--ink2); }}
.muted {{ fill: var(--muted); }} .faint {{ fill: var(--faint); }}
.accent {{ fill: var(--accent); }}
text {{ font-family: {SANS}; }}
.mono {{ font-family: {MONO}; }}
.cap {{ font-size: 11px; letter-spacing: .14em; text-transform: uppercase; }}
.h1 {{ font-size: 30px; font-weight: 650; letter-spacing: .02em; }}
.h2 {{ font-size: 19px; font-weight: 600; }}
.body {{ font-size: 13px; }}
.small {{ font-size: 11.5px; }}
.stroke-ink {{ stroke: var(--ink); fill: none; }}
.stroke-line {{ stroke: var(--line); fill: none; }}
.stroke-accent {{ stroke: var(--accent); fill: none; }}
"""

# Easing taken from the reference archive animation: an expressive enter
# curve, a quick exit curve and a smootherstep approximation.
ENTER = "cubic-bezier(0.22, 1, 0.36, 1)"
EXIT = "cubic-bezier(0.4, 0, 1, 1)"
SMOOTH = "cubic-bezier(0.65, 0, 0.35, 1)"
# Damped spring for settling shoulders; linear() with a cubic fallback.
SPRING_FALLBACK = "cubic-bezier(0.34, 1.56, 0.64, 1)"
SPRING = ("linear(0, 0.06 1.5%, 0.23 3.5%, 0.86 9%, 1.12 13%, 1.2 15.5%, "
          "1.19 18%, 1.08 23%, 0.97 29%, 0.94 33%, 0.96 38%, 1.01 46%, "
          "1.02 52%, 1 64%, 0.995 78%, 1)")


def spring_tf():
    """Two declarations: browsers without linear() keep the cubic curve."""
    return (f"animation-timing-function: {SPRING_FALLBACK}; "
            f"animation-timing-function: {SPRING};")


def svg(width, height, title, desc, css, body, extra_reduced=""):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="t d">
<title id="t">{escape(title)}</title>
<desc id="d">{escape(desc)}</desc>
<style>{TOKENS}{BASE_CSS}{css}
@media (prefers-reduced-motion: reduce) {{
  *, *::before, *::after {{ animation: none !important; transition: none !important; }}
  {extra_reduced}
}}
</style>
<rect class="bg" width="{width}" height="{height}" rx="14"/>
{body}
</svg>
"""


def text(x, y, s, cls="body ink", anchor="start", extra=""):
    return (f'<text x="{x:.1f}" y="{y:.1f}" class="{cls}" '
            f'text-anchor="{anchor}"{extra}>{escape(s)}</text>')


def pct(x):
    return f"{x:.3f}".rstrip("0").rstrip(".") + "%"
