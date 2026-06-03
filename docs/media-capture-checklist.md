# Media Capture Checklist

Use this checklist before adding screenshots, GIFs, or videos to the public README. Capture only synthetic or sample data. Do not show real health information, real medication schedules, symptoms, Firebase tokens, service account keys, private user exports, raw audit logs, real email addresses, full UIDs, credential paths, or local machine paths.

## General Rules

- Use local mode unless a safe synthetic demo account is required.
- Confirm the visible copy says the app is an educational awareness prototype.
- Keep all examples synthetic and obviously non-clinical.
- Do not imply diagnosis, treatment, medication timing advice, dietary guidance, clinical decision-making, patient care, or emergency support.
- Review each asset against [DISCLAIMER.md](../DISCLAIMER.md) and [docs/PUBLIC_DEMO_BOUNDARY.md](PUBLIC_DEMO_BOUNDARY.md) before committing.
- Prefer PNG for screenshots and GIF or an external hosted video link for short demos.
- Keep text readable at GitHub README size.

## Required Screenshots

| Asset | Target path | What to capture | Safety check |
| --- | --- | --- | --- |
| Dashboard | `docs/assets/screenshots/dashboard.png` | The main dashboard or home view showing the ParkinSUM Companion identity and local-first prototype context. | No real account, personal data, or clinical-use language. |
| Meal entry | `docs/assets/screenshots/meal-entry.png` | A synthetic meal entry flow with sample foods. | Use clearly synthetic food data and avoid real patient notes. |
| Medication context | `docs/assets/screenshots/medication-context.png` | The medication-context screen or medication fields used for the educational interaction check. | Use sample medication context only; do not show a real schedule. |
| Conflict explanation | `docs/assets/screenshots/conflict-result.png` | A deterministic conflict explanation with rule/evidence-oriented copy visible. | The screen should read as educational awareness, not clinical advice. |
| Import/evidence explanation flow | `docs/assets/screenshots/import-evidence-flow.png` | The import or evidence explanation flow, if the current build exposes it cleanly. | Do not show operator credentials, raw audit logs, private paths, or non-public imports. |

## Current Real-Device README Set

| Asset | Target path | Feature represented | Safety check |
| --- | --- | --- | --- |
| Account entry | `docs/assets/screenshots/auth-sign-in.png` | Sign-in shell and privacy/disclaimer entry point. | Use no real credential values. |
| Next-meal setup | `docs/assets/screenshots/next-meal-setup.png` | Planned next-meal time, timing window, optional local-AI wording polish, and conservative CDSS path. | Replace visible real account identifiers. |
| Next-meal results | `docs/assets/screenshots/next-meal-results.png` | Ranked synthetic food candidates with allow badges and rationale bullets. | Use synthetic candidate foods only. |
| Timeline overview | `docs/assets/screenshots/timeline-overview.png` | Meal-medication chronology and nearest-event context. | Do not show a real medication schedule. |
| Timeline action state | `docs/assets/screenshots/timeline-action-state.png` | Floating add-meal and log-medication actions. | Do not show a real medication schedule. |
| Medication catalog | `docs/assets/screenshots/medications-catalog.png` | Medication source labels, selected context, and educational catalog entries. | Keep the copy educational and non-prescriptive. |
| Search/catalog showcase | `docs/assets/screenshots/catalog-showcase.png` | Branded GitHub-style showcase module plus searchable food catalog. | Show synthetic/sample catalog data only. |
| Conflict explanation | `docs/assets/screenshots/conflict-explanation.png` | Rule weights, conservative explanation, model trace, and safety-boundary wording. | Must not read as diagnosis, treatment, medication timing advice, or dietary guidance. |
| Analytics and local AI | `docs/assets/screenshots/analytics-local-ai.png` | Localization status, local model configuration, endpoint fields, and conservative recommendation path. | Do not expose private endpoints beyond localhost demo values. |

## Suggested Demo Video

Prefer an external YouTube/Loom link documented in `README.md`. If a local GIF
or video is added later, verify it renders correctly on GitHub before linking
it from the public README.

Recommended 30-60 second flow:

1. Open the app in local mode.
2. Show the dashboard or public prototype boundary.
3. Enter a synthetic meal.
4. Add synthetic medication context.
5. Run the deterministic conflict check.
6. Show the evidence-oriented explanation and safety wording.

## README Update Rules

- Embed media in `README.md` only after the real files exist.
- Do not add broken image links as placeholders.
- If a screenshot is not ready, keep it listed as a planned slot in the README table.
- If an external demo video is used, link to the public video and note that it uses synthetic data.
