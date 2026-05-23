# Contributing

Contributions are welcome when they respect the public prototype boundary.

## Data Rules

- Use only synthetic or sample data.
- Do not include personal health information.
- Do not include Firebase tokens, service account keys, user exports, raw audit
  logs, real emails, full UIDs, or credential paths.
- Do not add claims that ParkinSUM has completed clinical validation, legal approval, or
  suitable for real health decisions.

## Pull Request Expectations

Every pull request should state whether it touches:

- CDSS-style rule logic or result copy.
- Firebase rules, Auth, Firestore paths, or operator tooling.
- Privacy, disclaimer, support, or security text.
- Public demo behavior.
- Importers, provenance, or release evidence.

Run before submitting:

```sh
npm run public:preflight
node tool/firestore_rules_contract_check.mjs
flutter analyze
flutter test --concurrency=1
```
