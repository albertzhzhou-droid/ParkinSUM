# Contributing

Contributions are welcome when they respect the public prototype boundary.
ParkinSUM is an educational and research prototype, not clinical software.

## Data Rules

- Use only synthetic or sample data.
- Do not include personal health information.
- Do not include Firebase tokens, service account keys, user exports, raw audit
  logs, real emails, full UIDs, credential paths, or private screenshots.
- Do not add claims that ParkinSUM has completed clinical validation, legal
  approval, privacy certification, or real-world health suitability.
- Do not write text that sounds like diagnosis, treatment, medication timing
  advice, individualized dietary guidance, patient care, or emergency support.

## Good First Issue Areas

Start with the public [contribution backlog](docs/contribution-backlog.md) or
copy a draft issue from [docs/issues/](docs/issues/).

- Improve multilingual UI strings or documentation wording.
- Add synthetic sample food-medication interaction examples.
- Improve accessibility for older users, including contrast, tap targets, and
  plain-language copy.
- Add or refine dark-mode UI checks.
- Refactor conflict-checking service tests.
- Design caregiver-oriented onboarding copy or screen flow notes.
- Add README screenshots or demo video captured with synthetic data only.

## Pull Request Expectations

Every pull request should state whether it touches:

- CDSS-style rule logic or result copy.
- Firebase rules, Auth, Firestore paths, or operator tooling.
- Privacy, disclaimer, support, or security text.
- Public demo behavior.
- Importers, provenance, or release evidence.
- Screenshots, demo media, sample data, or documentation claims.

Run before submitting:

```sh
npm run public:preflight
node tool/firestore_rules_contract_check.mjs
flutter analyze
flutter test --concurrency=1
```

If your change is documentation-only and local tooling is unavailable, say so in
the PR and list the files you reviewed manually.

## Secondary Creator Token Flow

If you are remixing the project or testing a classmate or mentor contribution,
use the fork-first GitHub token sequence in
[docs/secondary-creator-token-flow.md](docs/secondary-creator-token-flow.md).
Scope the token to your fork, push your branch there, and open a pull request
back to `albertzhzhou-droid/ParkinSUM:main`. The repository provides permission
guidance and a machine-readable sequence, not real token values. Store personal
access tokens locally through GitHub CLI or a system credential manager, never
in source files.

## Public Demo Media

Screenshots and videos must use synthetic/sample data only. Before adding media,
check [docs/assets/screenshots/README.md](docs/assets/screenshots/README.md) and
[docs/assets/demo/README.md](docs/assets/demo/README.md).
