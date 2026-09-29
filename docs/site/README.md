# ParkinSUM Paper Showcase

`index.html` and `styles.css` form the public landing page for the September
2026 development update. The page introduces the Paper chapters, Algorithm
Observatory, synthetic workbench, source run, and evidence boundaries. It uses
plain HTML/CSS, system font stacks, no JavaScript, no analytics, and no remote
font requests. The Flutter app itself bundles its licensed Paper typefaces.

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
