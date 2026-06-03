# Demo Path

Use this page when showing ParkinSUM Companion to a reviewer, classmate, mentor, or open-source contributor.

## Before the Demo

- Use local mode unless a safe synthetic demo account is explicitly required.
- Use synthetic/sample data only.
- Do not show real health information, medication schedules, Firebase tokens, service accounts, logs, full UIDs, emails, credential paths, or machine-specific paths.
- Keep the educational boundary visible.

## Walkthrough

1. Start the Flutter app locally.
2. Complete onboarding with synthetic context.
3. Open the catalog/search page to inspect food and medication records.
4. Enter a synthetic meal.
5. Add explicit synthetic medication context.
6. Run the deterministic check.
7. Open the evidence-oriented explanation and trace details.
8. Point reviewers to the public verification commands.

## Demo Media Rules

Public media must follow the media checklist:

https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/media-capture-checklist.md

Recommended public media slots:

| Slot | Target path |
| --- | --- |
| Dashboard | `docs/assets/screenshots/dashboard.png` |
| Meal entry | `docs/assets/screenshots/meal-entry.png` |
| Medication context | `docs/assets/screenshots/medication-context.png` |
| Conflict explanation | `docs/assets/screenshots/conflict-result.png` |
| Search/catalog showcase | `docs/assets/screenshots/catalog-search.png` |
| Short demo video | External link or future verified local asset |

Only embed screenshots or videos after the real files exist, render correctly on
GitHub, and have been checked for demo safety.

## Verification Commands

```sh
flutter analyze
flutter test
npm run public:preflight
npm run rules:contract
npm run mechanistic:replay
npm run source:quality
```

See: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/PUBLIC_VERIFICATION.md

