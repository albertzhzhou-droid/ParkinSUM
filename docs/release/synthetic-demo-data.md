# Synthetic Demo Data

ParkinSUM Companion v0.1.0-alpha includes a small committed synthetic demo
scenario pack at `docs/assets/demo/synthetic-scenarios.json`. Public demos
should use the app's local mode and manually entered synthetic examples from
that pack, or screenshots/videos captured from those synthetic examples.

The current app does not expose a public one-click demo-data loader. Treat the
JSON pack as copy-ready demo input, a manual walkthrough guide, and a future
loader fixture.

Do not use real patient data, real medication schedules, symptoms, private
notes, real user accounts, real email addresses, private Firebase exports, or
raw operator logs in public release assets.

## Safe Demo Scenario

Use obviously synthetic values such as:

| Field | Synthetic example |
| --- | --- |
| Demo person | `Demo User A` |
| Region | `United States` or another non-identifying demo region |
| Meal | `Oatmeal with milk and berries` |
| Protein context | `Moderate protein` |
| Medication context | `Sample levodopa-containing medication context` |
| Timing | `Example morning intake` |
| Output framing | `Educational awareness result` |

The medication context should be presented as a sample app input, not as a real
prescription or recommended schedule.

## Demo Flow

1. Run the app in local mode.
2. Complete onboarding with synthetic profile choices.
3. Enter a synthetic meal.
4. Add synthetic medication context.
5. Review the deterministic educational rule explanation.
6. Capture screenshots or GIFs only after confirming no real identifiers,
   credentials, local machine paths, Firebase tokens, or raw operator logs are
   visible.

## Release Asset Rules

- Screenshots and videos must use synthetic or sample data only.
- APKs must be labeled as alpha/demo artifacts unless production signing is
  explicitly configured in a separate release goal.
- Do not attach local build logs if they include machine paths, account names,
  tokens, UIDs, or private project details.
- Do not attach Firebase exports, real user exports, service-account files, or
  operator audit artifacts.

See `docs/media-capture-checklist.md` and
`docs/PUBLIC_DEMO_BOUNDARY.md` before adding public media. See
`docs/demo-scenarios.md` for the complete scenario walkthrough.
