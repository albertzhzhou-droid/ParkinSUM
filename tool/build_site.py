"""Builds the static website for https://parkinsum.com from docs/.

Usage (from the repository root, Python 3 standard library only):
  python3 tool/build_site.py [--out build/website] [--origin https://parkinsum.com]

The sources stay where GitHub Pages already serves them (docs/site/,
docs/wiki/, docs/assets/). This script copies them into a root-relative
layout for a custom domain:

  /            <- docs/site/index.html (the Paper showcase)
  /guide/      <- docs/wiki/index.html (the visual project guide)
  /assets/...  <- only the files the pages reference

and adds canonical and social metadata, a 404 page, robots.txt, sitemap.xml,
and Cloudflare Pages `_headers` / `_redirects`. The pages use no JavaScript,
so the content security policy allows no scripts at all.

Cloudflare Pages settings: build command `python3 tool/build_site.py`,
build output directory `build/website`, no framework preset.
"""

import argparse
import datetime
import html
import os
import re
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS = os.path.join(ROOT, "docs")

ASSET_RE = re.compile(r'(?:href|src)="(/assets/[^"#?]+)"')

HEADERS = """/*
  Content-Security-Policy: default-src 'none'; img-src 'self'; style-src 'self'; style-src-attr 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()
  Cross-Origin-Opener-Policy: same-origin
  X-Frame-Options: DENY

/assets/*
  Cache-Control: public, max-age=604800

/*.css
  Cache-Control: public, max-age=3600, must-revalidate
"""

REDIRECTS = """/site /  301
/site/ /  301
/site/index.html /  301
/wiki /guide/  301
/wiki/ /guide/  301
/wiki/index.html /guide/  301
/guide /guide/  301
"""

NOT_FOUND = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="robots" content="noindex" />
    <meta name="theme-color" content="#f6f1e6" />
    <title>Page not found · ParkinSUM Companion</title>
    <link rel="icon" href="/assets/brand/parkinsum-icon-warm-32.png" sizes="32x32" />
    <link rel="stylesheet" href="/styles.css" />
  </head>
  <body>
    <main id="main" class="not-found">
      <p class="eyebrow">404 · Not in the archive</p>
      <h1>This page isn't<br /><em>on the shelf.</em></h1>
      <p class="lead">The address may have changed when the showcase moved to its own domain.</p>
      <div class="action-row">
        <a class="button primary" href="/">Back to the showcase</a>
        <a class="button" href="/guide/">Open the project guide</a>
      </div>
      <p class="boundary">Educational prototype. Not medical advice; no clinical validation is claimed.</p>
    </main>
  </body>
</html>
"""


def meta_block(origin, path, title, description, image):
    url = origin + path
    esc = html.escape
    return "\n".join([
        f'    <link rel="canonical" href="{url}" />',
        '    <meta property="og:type" content="website" />',
        '    <meta property="og:site_name" content="ParkinSUM Companion" />',
        f'    <meta property="og:title" content="{esc(title)}" />',
        f'    <meta property="og:description" content="{esc(description)}" />',
        f'    <meta property="og:url" content="{url}" />',
        f'    <meta property="og:image" content="{origin}{image}" />',
        '    <meta property="og:image:width" content="1440" />',
        '    <meta property="og:image:height" content="1000" />',
        '    <meta name="twitter:card" content="summary_large_image" />',
    ])


def transform(text, *, origin, path, own_dir, other_links):
    """Rewrites a docs/ page into the root-relative layout."""
    text = text.replace('href="../assets/', 'href="/assets/')
    text = text.replace('src="../assets/', 'src="/assets/')
    text = text.replace('href="styles.css"', f'href="{own_dir}styles.css"')
    for old, new in other_links.items():
        text = text.replace(f'href="{old}"', f'href="{new}"')
    title = html.unescape(re.search(r"<title>(.*?)</title>", text, re.S).group(1))
    description = html.unescape(
        re.search(r'<meta name="description" content="([^"]*)"', text).group(1))
    block = meta_block(origin, path, title, description,
                       "/assets/screenshots/paper-today.png")
    return text.replace("    <title>", block + "\n    <title>", 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=os.path.join(ROOT, "build", "website"))
    parser.add_argument("--origin", default="https://parkinsum.com")
    args = parser.parse_args()
    out, origin = os.path.abspath(args.out), args.origin.rstrip("/")
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(os.path.join(out, "guide"))

    pages = {
        "index.html": transform(
            open(os.path.join(DOCS, "site", "index.html"), encoding="utf-8").read(),
            origin=origin, path="/", own_dir="/", other_links={"../wiki/": "/guide/"}),
        "guide/index.html": transform(
            open(os.path.join(DOCS, "wiki", "index.html"), encoding="utf-8").read(),
            origin=origin, path="/guide/", own_dir="/guide/",
            other_links={"../site/": "/", "../site/#try": "/#try"}),
        "404.html": NOT_FOUND,
    }
    for name, text in pages.items():
        leftover = re.findall(r'(?:href|src)="\.\./[^"]*"', text)
        if leftover:
            raise SystemExit(f"{name}: unresolved relative links {leftover}")
        with open(os.path.join(out, name), "w", encoding="utf-8") as fh:
            fh.write(text)

    shutil.copy(os.path.join(DOCS, "site", "styles.css"), os.path.join(out, "styles.css"))
    with open(os.path.join(out, "styles.css"), "a", encoding="utf-8") as fh:
        fh.write("\n.not-found { width: min(760px, calc(100% - 40px)); margin: 18vh auto 12vh; }\n")
    guide_css = open(os.path.join(DOCS, "wiki", "styles.css"), encoding="utf-8").read()
    guide_css = guide_css.replace('@import url("../site/styles.css");',
                                  '@import url("/styles.css");')
    if "../" in guide_css:
        raise SystemExit("guide/styles.css: unresolved relative reference")
    with open(os.path.join(out, "guide", "styles.css"), "w", encoding="utf-8") as fh:
        fh.write(guide_css)

    assets = sorted({a for text in pages.values() for a in ASSET_RE.findall(text)}
                    | {"/assets/screenshots/paper-today.png"})
    for asset in assets:
        src = os.path.join(DOCS, asset.lstrip("/"))
        if not os.path.isfile(src):
            raise SystemExit(f"missing asset {asset}")
        dst = os.path.join(out, asset.lstrip("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy(src, dst)

    today = datetime.date.today().isoformat()
    with open(os.path.join(out, "sitemap.xml"), "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                 '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                 + "".join(f"  <url><loc>{origin}{p}</loc><lastmod>{today}</lastmod></url>\n"
                           for p in ("/", "/guide/"))
                 + "</urlset>\n")
    with open(os.path.join(out, "robots.txt"), "w", encoding="utf-8") as fh:
        fh.write(f"User-agent: *\nAllow: /\nSitemap: {origin}/sitemap.xml\n")
    with open(os.path.join(out, "_headers"), "w", encoding="utf-8") as fh:
        fh.write(HEADERS)
    with open(os.path.join(out, "_redirects"), "w", encoding="utf-8") as fh:
        fh.write(REDIRECTS)
    total = sum(os.path.getsize(os.path.join(d, f))
                for d, _, fs in os.walk(out) for f in fs)
    print(f"Built {out}: {len(pages)} pages, {len(assets)} assets, {total / 1024:.0f} KiB")


if __name__ == "__main__":
    main()
