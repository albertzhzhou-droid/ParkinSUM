# ParkinSUM GitHub Pages Site

This folder contains a lightweight static landing page for ParkinSUM Companion.
It uses plain HTML and CSS only; no build system is required.

## Local Preview

Open `docs/site/index.html` in a browser, or run a simple local server from the
repository root:

```sh
python3 -m http.server 8000
```

Then visit:

```text
http://localhost:8000/docs/site/
```

## Enable GitHub Pages

1. Open the repository on GitHub.
2. Go to `Settings` -> `Pages`.
3. Under `Build and deployment`, choose `Deploy from a branch`.
4. Set the branch to `main`.
5. Set the folder to `/docs`.
6. Save the settings.

GitHub Pages will publish the `/docs` folder. With this layout, the landing page
will be available at:

```text
https://albertzhzhou-droid.github.io/ParkinSUM/site/
```

If you later want the landing page at the Pages root instead of `/site/`, move
`docs/site/index.html` and `docs/site/styles.css` to the top level of `docs/`
after checking that existing documentation links still work.

## Content Rules

- Use synthetic or sample data only.
- Do not add real patient data, real medication schedules, private user exports,
  raw operator logs, Firebase tokens, service-account files, or signing keys.
- Keep all claims conservative: educational prototype, not medical advice, not a
  medical device, and no clinical validation is claimed.
- Demo media placeholders point to `docs/assets/screenshots/` and
  `docs/assets/demo/`; add real media only after following
  `docs/media-capture-checklist.md`.
