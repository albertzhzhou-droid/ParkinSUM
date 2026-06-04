# ParkinSUM Demo Website

This folder contains a lightweight static demo website for ParkinSUM Companion.
It is designed to help a reviewer understand the project in about 30 seconds:
what the app does, what the core flow looks like, how the rule/explanation path
works, and which demo/release formats are appropriate.

It uses plain HTML and CSS only; no build system is required. The site reuses
the app logo, wordmark, and redacted real-device screenshots from
`docs/assets/`.

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

The animated Liquid Glass-style showcase wiki will be available at:

```text
https://albertzhzhou-droid.github.io/ParkinSUM/wiki/
```

GitHub's repository Wiki interface does not execute custom CSS animations. Use
the Markdown pages in `docs/github-wiki/` for the GitHub Wiki itself, and link
from that Wiki to the animated Pages version for the richer visual experience.

If you later want the landing page at the Pages root instead of `/site/`, move
`docs/site/index.html` and `docs/site/styles.css` to the top level of `docs/`
after checking that existing documentation links still work.

## Content Rules

- Use synthetic or sample data only.
- Do not add real patient data, real medication schedules, private user exports,
  raw operator logs, Firebase tokens, service-account files, or signing keys.
- Keep all claims conservative: educational prototype, not medical advice, not a
  medical device, and no clinical validation is claimed.
- Screenshot media should come from `docs/assets/screenshots/`.
- Short GIF or video links should be added only after following
  `docs/media-capture-checklist.md` and verifying that the media renders
  correctly on GitHub.
