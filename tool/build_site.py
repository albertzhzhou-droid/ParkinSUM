"""Builds the static website for https://parkinsum.com from docs/website/.

Usage (from the repository root, Python 3 standard library only):
  python3 tool/build_site.py [--out build/website] [--origin https://parkinsum.com]

The source stays inside docs/ so GitHub Pages can preview it too. This script
copies it into a root-relative layout for the custom domain:

  /            <- docs/website/index.html (the Evidence Atlas)
  /styles.css  <- docs/website/styles.css
  /fonts/...   <- docs/website/fonts/ (Geist, Geist Mono, Source Serif 4; OFL)
  /assets/...  <- only the docs/assets/ files the page references

and adds canonical and social metadata, a 404 page, robots.txt, sitemap.xml,
and Cloudflare `_headers` / `_redirects`. The old /site/ path redirects home;
/guide/ and /wiki/ redirect to the visual guide on GitHub Pages. The pages use
no JavaScript, so the content security policy allows no scripts at all.

Deploy with `npx wrangler@4 deploy` (see wrangler.jsonc).
"""

import argparse
import datetime
import hashlib
import html
import os
import re
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS = os.path.join(ROOT, "docs")

ASSET_RE = re.compile(r'(?:href|src)="(/assets/[^"#?]+)"')

HEADERS = """/*
  Content-Security-Policy: default-src 'none'; img-src 'self'; font-src 'self'; style-src 'self'; style-src-attr 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()
  Cross-Origin-Opener-Policy: same-origin
  X-Frame-Options: DENY

/assets/*
  Cache-Control: public, max-age=604800

/fonts/*
  Cache-Control: public, max-age=2592000

/*.css
  Cache-Control: public, max-age=3600, must-revalidate
"""

REDIRECTS = """/site /  301
/site/ /  301
/site/index.html /  301
/wiki https://albertzhzhou-droid.github.io/ParkinSUM/wiki/  301
/wiki/ https://albertzhzhou-droid.github.io/ParkinSUM/wiki/  301
/wiki/index.html https://albertzhzhou-droid.github.io/ParkinSUM/wiki/  301
/guide https://albertzhzhou-droid.github.io/ParkinSUM/wiki/  301
/guide/ https://albertzhzhou-droid.github.io/ParkinSUM/wiki/  301
/guide/index.html https://albertzhzhou-droid.github.io/ParkinSUM/wiki/  301
"""

NOT_FOUND = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="robots" content="noindex" />
  <meta name="theme-color" content="#f5f2eb" />
  <title>Page not found · ParkinSUM</title>
  <link rel="icon" href="/assets/brand/parkinsum-icon-warm-32.png" sizes="32x32" />
  <link rel="stylesheet" href="/styles.css" />
</head>
<body>
  <main class="not-found">
    <p class="eyebrow"><span class="eyebrow-line"></span> 404 / NOT IN THE ARCHIVE</p>
    <h1>This page isn’t<br /><span class="serif">on the shelf.</span></h1>
    <p>The address may have changed when the showcase moved to its own domain.</p>
    <div class="hero-actions"><a class="button primary" href="/">Back to the atlas</a><a class="text-link" href="https://github.com/albertzhzhou-droid/ParkinSUM/wiki">Explore the wiki</a></div>
    <p class="scope-note">Educational prototype · Synthetic demonstrations · Not medical advice</p>
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
    os.makedirs(out)
    src = os.path.join(DOCS, "website")

    css = open(os.path.join(src, "styles.css"), encoding="utf-8").read()
    # A content hash in the stylesheet URL, so a cached copy never outlives it.
    css_url = "/styles.css?v=" + hashlib.sha256(css.encode("utf-8")).hexdigest()[:10]

    pages = {
        "index.html": transform(
            open(os.path.join(src, "index.html"), encoding="utf-8").read(),
            origin=origin, path="/", own_dir="/", other_links={}),
        "404.html": NOT_FOUND,
    }
    pages = {name: text.replace('href="/styles.css"', f'href="{css_url}"')
             for name, text in pages.items()}
    for name, text in pages.items():
        leftover = re.findall(r'(?:href|src)="\.\./[^"]*"', text)
        if leftover:
            raise SystemExit(f"{name}: unresolved relative links {leftover}")
        with open(os.path.join(out, name), "w", encoding="utf-8") as fh:
            fh.write(text)

    if "../" in css:
        raise SystemExit("styles.css: unresolved relative reference")
    shutil.copy(os.path.join(src, "styles.css"), os.path.join(out, "styles.css"))
    fonts = sorted(set(re.findall(r'url\("(fonts/[^"]+)"\)', css)))
    os.makedirs(os.path.join(out, "fonts"))
    for font in fonts + [f"fonts/{n}" for n in os.listdir(os.path.join(src, "fonts"))
                         if n.startswith("OFL-")]:
        if not os.path.isfile(os.path.join(src, font)):
            raise SystemExit(f"missing font {font}")
        shutil.copy(os.path.join(src, font), os.path.join(out, font))

    assets = sorted({a for text in pages.values() for a in ASSET_RE.findall(text)}
                    | {"/assets/screenshots/paper-today.png"})
    for asset in assets:
        asset_src = os.path.join(DOCS, asset.lstrip("/"))
        if not os.path.isfile(asset_src):
            raise SystemExit(f"missing asset {asset}")
        dst = os.path.join(out, asset.lstrip("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy(asset_src, dst)

    today = datetime.date.today().isoformat()
    with open(os.path.join(out, "sitemap.xml"), "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                 '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                 f"  <url><loc>{origin}/</loc><lastmod>{today}</lastmod></url>\n"
                 "</urlset>\n")
    with open(os.path.join(out, "robots.txt"), "w", encoding="utf-8") as fh:
        fh.write(f"User-agent: *\nAllow: /\nSitemap: {origin}/sitemap.xml\n")
    with open(os.path.join(out, "_headers"), "w", encoding="utf-8") as fh:
        fh.write(HEADERS)
    with open(os.path.join(out, "_redirects"), "w", encoding="utf-8") as fh:
        fh.write(REDIRECTS)
    total = sum(os.path.getsize(os.path.join(d, f))
                for d, _, fs in os.walk(out) for f in fs)
    print(f"Built {out}: {len(pages)} pages, {len(fonts)} fonts, {len(assets)} assets, "
          f"{total / 1024:.0f} KiB")

if __name__ == "__main__":
    main()
