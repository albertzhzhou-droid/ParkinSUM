# ParkinSUM Paper Showcase

`index.html` and `styles.css` form the public landing page for the September
2026 development update. The page introduces the Paper chapters, Algorithm
Observatory, synthetic workbench, source run, and evidence boundaries. It uses
plain HTML/CSS, system font stacks, no JavaScript, no analytics, and no remote
font requests. The Flutter app itself bundles its licensed Paper typefaces.

### Archive selectors

The evidence archive (section II) and the governance ledger (section III) are
CSS-only: hidden radio inputs choose a record, and `:has()` carries the choice to
an inline-SVG field of isometric cards. Each card's transition delay grows with
its distance from the chosen card, so a change ripples outward; neighbours in the
same column settle, other columns recede, and the chosen card lifts out while its
record opens. The motion is adapted from the Learning Radar archive array. The
records come from the source registry and the context-of-use ledger and state
what each source supports and what it does not. Under reduced motion the choice
switches instantly. Without `:has()` the first record stays visible.

The favicon, touch icon and 34 px logo use 32, 180 and 96 px copies of
`parkinsum-icon-warm.png` (2–34 KB instead of 908 KB).

Regenerate the fields, records and per-choice rules (between the `archive:`
markers in `index.html` and `styles.css`) with:

```sh
python3 tool/wiki_svg/site_archive.py
```

The visual wiki at `../wiki/` shares the landing page's design tokens and
provides a longer guided architecture/demo route. Markdown pages under
`../github-wiki/` are source material for the separate GitHub Wiki service;
editing them does not itself publish the repository Wiki.

## Preview locally

From the repository root:

```sh
python3 -m http.server 8000
```

Open `http://localhost:8000/docs/site/` and `http://localhost:8000/docs/wiki/`.
Review desktop and narrow widths, image loading, keyboard focus, skip links,
and the reduced-motion preference before publishing a layout change.

The static site explains the app; it is not a hosted Flutter runtime. The
README gives the local Flutter launch command.

## Publish

If GitHub Pages uses the `main` branch's `/docs` directory, the routes are:

- `https://albertzhzhou-droid.github.io/ParkinSUM/site/`
- `https://albertzhzhou-droid.github.io/ParkinSUM/wiki/`

Verify repository Pages settings and the deployed build before describing a
source update as live. All repository-document links in the HTML point to
GitHub explicitly, so a `/docs` deployment does not need files outside its
published root. Assets and the shared stylesheet use relative paths inside
`docs/`.

## Custom domain (Cloudflare)

`https://parkinsum.com` serves a separate page, the Evidence Atlas, from
`docs/website/`. It uses the Atlas site's typefaces (Geist, Geist Mono and Source
Serif 4 italic, bundled under `docs/website/fonts/` with their OFL licences),
palette and copy. Its motion comes from this showcase and the Learning Radar
archive array. It also needs no JavaScript:

- **Paged scrolling.** The page scrolls, but in whole pages. Each of the 15
  pages fills one screen and is a snap point that a scroll cannot pass, so one
  wheel step, swipe, arrow key or Page Down shifts exactly one page. A page
  index on the right marks the current page and links to every page.
  - **Shift.** While a page shifts, the old one recedes and dims toward the
    paper and the new one rises into place. This is scroll-driven, on each
    page's view timeline.
  - **Landing.** In browsers that can query snapped scroll state, a page that
    has not landed waits in its starting state: content faint and lowered,
    books in their archive slots, curves undrawn. When it lands, its content
    builds in, an archive page extracts its books and the model curves draw.
  - **Fit.** Shorter screens scale a page down so it still fits one screen.
  - **Phones.** Snapping is loose and the shift and landing effects are off,
    because pages are taller than the screen.
- **Friction, not glides.** Motion uses friction profiles (stick, slip,
  constant deceleration, a dead stop) instead of smooth easing. Chapter and
  evidence panels switch in place.
- **Archive libraries.** The archive is an isometric 3D base of standing files.
  Its record books are designed objects: box files, a booklet, clothbound
  journals and ledger binders, built from CSS 3D faces.
  - When an archive page lands, each book is worked loose from its slot,
    lifted, turned spine-out and set down on a reading shelf.
  - Each book is the control. Choosing one lifts it off the shelf. Its reading
    copy is carried to a stand and opened like a physical book: the cover
    resists at the hinge, then swings open, and two leaves curl over, the second
    clinging to the first.
  - On narrow screens the book opens to a single page.
- **Hero.** An ambient card field idles behind the hero.
- **Motion off.** A pause control and reduced-motion both stop all of it, and
  everything rests in its finished state.
- **Opacity rule.** Opacity is never animated on or around a 3D book. Chrome
  flattens or stops painting such subtrees.

`python3 tool/wiki_svg/site_archive.py` regenerates both archives on both
pages from one set of records. `python3 tool/build_site.py` (standard library
only) writes `build/website/`:

- the page at `/`, its stylesheet and fonts, and only the assets it references
- canonical and Open Graph tags, a 404 page, `robots.txt` and `sitemap.xml`
- `_redirects`: the old `/site/` path goes home, and `/guide/` and `/wiki/` go
  to the visual guide on GitHub Pages
- `_headers`: a content security policy that allows no scripts, plus `nosniff`,
  `frame-ancestors 'none'` and caching

The script stops if a page keeps an unresolved relative link or references a
missing asset or font.

The domain is served by the `parkinsum` Cloudflare Worker as static assets.
There is no Worker script. `wrangler.jsonc` at the repository root names the
asset directory, the 404 page and both custom domains. Deploys are manual:

```sh
python3 tool/build_site.py
npx wrangler@4 deploy
```

`wrangler login` is needed once per machine. Pushing to `main` does not
redeploy the domain. The GitHub Pages routes above keep working.

## Screenshot and claim boundaries

The current landing page embeds `paper-today.png`, `paper-timeline.png`,
`paper-next-meal.png`, and `paper-library.png`, captured on 2026-09-29 at
1440 × 1000. These are development-worktree Chrome captures, not a final-commit
binary attestation. A fresh synthetic profile contains one banana meal,
zero medications, and no AI consent. The media index records exact provenance,
SHA-256 values, visible state, and review scope.

Use only actual reviewed captures from `docs/assets/screenshots/`. Record their
source revision or worktree state, capture date, viewport, synthetic fixture
state, and review scope in the [media index](../assets/screenshots/README.md).
Historical August captures remain historical; retired unsafe captures must
never be restored or relinked. Do not use generated mockups as runtime proof.

A browser capture demonstrates visible UI at its recorded state. It does not
establish physical-device or native-platform behavior, complete workflow
functionality, accessibility conformance, security, or clinical validation.
Public preflight scans text and known artifact patterns, not screenshot pixels.
Follow the [media checklist](../media-capture-checklist.md) for image review.

Deterministic rules own classifications, scores, evidence, and safety gates.
Mechanistic traces are `trace_only`. Optional consent-gated loopback AI may
rerank only rule-screened, non-BLOCK candidates or polish existing copy; it
cannot override rule-owned results. Public content must preserve these
boundaries and the educational-only intended use.
