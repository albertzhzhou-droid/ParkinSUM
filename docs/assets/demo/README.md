# Demo Media Checklist

Add a 1-2 minute demo video or GIF before a public showcase release. Use only
synthetic or sample data.

This directory also contains the synthetic demo scenario pack:
`synthetic-scenarios.json`. The pack is fictional, educational-only, and not
medical advice. It is intended for manual walkthroughs and future loader tests;
do not mix it with real patient data or real accounts.

## Target Asset

- `parkinsum-demo.gif` for a local README asset, or
- an external YouTube/Loom link documented in `README.md`.

## Suggested Demo Flow

1. Open the app in local mode.
2. Show onboarding and the public prototype boundary.
3. Enter a synthetic meal from `synthetic-scenarios.json`.
4. Add medication context with synthetic values from the same pack.
5. Run the conflict check.
6. Show the evidence/explanation layer and safety wording.

## Safety Review

Do not record real accounts, real health information, medication schedules,
symptoms, Firebase credentials, service account keys, user exports, raw operator
audit logs, browser password managers, terminal tokens, or private file paths.
