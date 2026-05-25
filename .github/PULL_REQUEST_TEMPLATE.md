## Summary

Describe the change and why it is needed.

## Public Prototype Boundary

- [ ] This PR does not include personal health information.
- [ ] This PR does not include real medication schedules, symptoms, private health records, Firebase tokens, service account keys, raw audit logs, user exports, real emails, full UIDs, signing files, or local credential paths.
- [ ] This PR uses synthetic or sample data only for examples, screenshots, tests, and docs.
- [ ] This PR does not claim clinical validation, legal approval, privacy certification, medical-device status, treatment guidance, or real-world health suitability.

## Touched Areas

- [ ] CDSS-style rule logic or result copy
- [ ] Firebase rules, Auth, Firestore paths, or operator tooling
- [ ] Privacy, disclaimer, support, or security text
- [ ] Public demo behavior
- [ ] Importers, provenance, or release evidence
- [ ] GitHub Pages, release notes, issue templates, or contributor docs
- [ ] Synthetic data, demo media, screenshots, or accessibility

## Validation

- [ ] `npm run public:preflight`
- [ ] `node tool/firestore_rules_contract_check.mjs`
- [ ] `flutter analyze`
- [ ] `flutter test --concurrency=1`
- [ ] Documentation-only/manual review: explain below if local tooling was not run.

## Notes For Reviewers

List any files, screenshots, docs pages, or rule evidence that need close review.
