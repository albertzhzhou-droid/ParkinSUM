## Summary

Describe the change and why it is needed.

## Public Prototype Boundary

- [ ] This PR does not include personal health information.
- [ ] This PR does not include Firebase tokens, service account keys, raw audit logs, user exports, real emails, or full UIDs.
- [ ] This PR does not claim clinical validation, legal approval, privacy certification, or real-world health suitability.

## Touched Areas

- [ ] CDSS-style rule logic or result copy
- [ ] Firebase rules, Auth, Firestore paths, or operator tooling
- [ ] Privacy, disclaimer, support, or security text
- [ ] Public demo behavior
- [ ] Importers, provenance, or release evidence

## Validation

- [ ] `npm run public:preflight`
- [ ] `node tool/firestore_rules_contract_check.mjs`
- [ ] `flutter analyze`
- [ ] `flutter test --concurrency=1`
