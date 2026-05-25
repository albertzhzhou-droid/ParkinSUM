# Contribution Backlog

ParkinSUM Companion welcomes contributions that keep the project an
educational, synthetic-data prototype. Do not add personal health information,
real medication schedules, symptoms, private records, credentials, service
account files, Firebase tokens, raw operator logs, real emails, full UIDs, or
unsupported medical claims.

Use this backlog to pick a scoped task. If GitHub issues are not already open,
copy a matching draft from `docs/issues/`.

## Label Guidance

Suggested public labels:

| Label | Use for |
| --- | --- |
| `good first issue` | Small, low-risk tasks suitable for new contributors. |
| `documentation` | README, docs, GitHub Pages, release notes, and setup clarity. |
| `testing` | Unit tests, CI expectations, fixtures, and regression coverage. |
| `accessibility` | Contrast, keyboard flow, tap targets, plain-language copy, and screen-reader review. |
| `synthetic data` | Sample/demo inputs that contain no real personal or health data. |
| `rule-engine` | Deterministic rule logic, evidence mapping, or rule-copy behavior. |
| `needs evidence` | Rule or copy changes that require a citation or official source. |
| `localization` | UI strings, locale resources, translation coverage, and copy quality. |
| `demo/release` | Screenshots, GIFs, GitHub Pages, release notes, and public packaging. |
| `needs triage` | New ideas that need maintainers to confirm scope and safety. |

## Backlog Items

### 1. Add alt-text guidance for demo screenshots

- Category: good first issue, documentation, accessibility
- Problem: Demo media placeholders list planned screenshots, but contributors do
  not yet have guidance for writing useful alt text.
- Expected output: Add concise alt-text rules and examples for dashboard, meal
  entry, medication context, and conflict-result screenshots.
- Files likely involved: `docs/media-capture-checklist.md`,
  `docs/assets/screenshots/README.md`, `docs/site/index.html`.
- Difficulty: Beginner.
- Safety notes: Use synthetic examples only. Do not describe real patient
  records, symptoms, medication schedules, or clinical outcomes.

### 2. Improve GitHub Pages copy for teachers and mentors

- Category: documentation, demo/release
- Problem: The project website explains the prototype, but teacher/mentor use
  cases could be clearer for classroom review.
- Expected output: Add a short "For educators and mentors" section with safe
  discussion prompts.
- Files likely involved: `docs/site/index.html`, `docs/site/styles.css`.
- Difficulty: Beginner.
- Safety notes: Keep all prompts about software architecture, safety boundaries,
  and synthetic data. Do not ask students to use real health information.

### 3. Add documentation smoke test for public links

- Category: testing, documentation
- Problem: Public docs and the GitHub Pages site contain many internal links
  that can drift.
- Expected output: Add a lightweight script or documented command that checks
  internal Markdown/HTML links without requiring external network access.
- Files likely involved: `tool/`, `package.json`, `docs/site/README.md`,
  `README.md`.
- Difficulty: Intermediate.
- Safety notes: The checker should not upload docs, call private services, or
  scan ignored token/export folders.

### 4. Add synthetic onboarding walkthrough data

- Category: synthetic data, good first issue
- Problem: Reviewers need a safe example flow for onboarding without entering
  real profile or medication information.
- Expected output: Document one synthetic onboarding walkthrough with fake
  profile choices and non-identifying context.
- Files likely involved: `docs/release/synthetic-demo-data.md`,
  `docs/site/index.html`, `test/onboarding_flow_test.dart` if tests are added.
- Difficulty: Beginner to intermediate.
- Safety notes: Use obvious demo values. Do not include real region-specific
  personal details, patient stories, or medication schedules.

### 5. Add contrast notes for the GitHub Pages site

- Category: accessibility, testing
- Problem: The landing page is visually restrained, but there is no documented
  contrast review.
- Expected output: Add a short accessibility note covering text contrast,
  keyboard navigation, and mobile layout. Adjust CSS if a contrast issue is
  found.
- Files likely involved: `docs/site/styles.css`, `docs/site/README.md`,
  `docs/contribution-backlog.md`.
- Difficulty: Beginner to intermediate.
- Safety notes: This is a UI accessibility task only; do not add health advice
  or real user scenarios.

### 6. Add copy tests for release safety language

- Category: testing, demo/release
- Problem: Public-facing docs must avoid unsupported claims, but some checks are
  currently concentrated in the preflight script.
- Expected output: Add or extend tests/checks that verify release docs mention
  educational-only use, synthetic/demo data, and no clinical validation claimed.
- Files likely involved: `tool/public_repo_preflight.mjs`, `package.json`,
  `docs/release/`.
- Difficulty: Intermediate.
- Safety notes: The check should block overclaims without blocking correct
  negated safety language.

### 7. Map one rule explanation to explicit evidence fields

- Category: rule-engine evidence mapping
- Problem: Rule explanations are designed to be evidence-oriented, but a
  contributor-friendly example would help future rule work.
- Expected output: Pick one existing educational rule and document how its
  source reference, copy, and limitation text connect.
- Files likely involved: `docs/RULE_ENGINE.md`,
  `lib/domain/usecases/runtime_rule_engine.dart`,
  `test/runtime_rule_engine_test.dart`.
- Difficulty: Advanced.
- Safety notes: Require citation/source context. Do not introduce patient advice
  or expand a rule beyond its evidence boundary.

### 8. Add issue-template documentation screenshots

- Category: documentation, demo/release
- Problem: Visitors may not notice the structured issue templates before
  opening a new issue.
- Expected output: Add a short contribution section that explains which template
  to choose and links to the backlog.
- Files likely involved: `README.md`, `CONTRIBUTING.md`,
  `docs/contribution-backlog.md`.
- Difficulty: Beginner.
- Safety notes: Remind users not to submit personal health data, credentials, or
  unsupported medical claims.

### 9. Add localized safety-boundary copy review

- Category: UI localization, accessibility
- Problem: Safety language needs to remain clear when UI copy is localized.
- Expected output: Review existing safety-boundary strings for one locale and
  propose clearer wording while preserving meaning.
- Files likely involved: `lib/core/i18n/app_i18n.dart`,
  `lib/core/i18n/app_i18n_full_translations.dart`,
  `test/response_copy_service_test.dart`.
- Difficulty: Intermediate.
- Safety notes: Do not soften the safety boundary. Translations must still say
  educational-only, synthetic/demo data, and no medical advice.

### 10. Add synthetic recommendation replay example

- Category: synthetic data, testing, rule-engine evidence mapping
- Problem: Recommendation behavior is easier to review when there is a small,
  safe replay scenario.
- Expected output: Add or document one synthetic replay case that demonstrates
  educational output and expected safety wording.
- Files likely involved: `test/recommendation_replay_runner_test.dart`,
  `test/recommendation_benchmark_dataset_test.dart`,
  `docs/release/synthetic-demo-data.md`.
- Difficulty: Intermediate to advanced.
- Safety notes: Use fake inputs only. The output must not imply a real user
  should change medication timing or diet.

### 11. Expand CI documentation for new contributors

- Category: documentation, testing, good first issue
- Problem: CI exists, but new contributors need a short explanation of what each
  check means and how to run it locally.
- Expected output: Add a concise CI section to contribution docs with commands
  and expected outcomes.
- Files likely involved: `CONTRIBUTING.md`, `README.md`, `.github/workflows/ci.yml`.
- Difficulty: Beginner.
- Safety notes: Do not include local machine paths or private environment
  details.

### 12. Prepare first public demo checklist issue

- Category: demo/release, synthetic data, accessibility
- Problem: Public demo media is planned but not captured.
- Expected output: Create a checklist for dashboard, meal entry, medication
  context, conflict explanation, and short GIF capture using synthetic data.
- Files likely involved: `docs/media-capture-checklist.md`,
  `docs/assets/screenshots/README.md`, `docs/assets/demo/README.md`.
- Difficulty: Beginner to intermediate.
- Safety notes: Confirm no real health information, credentials, UIDs, local
  paths, or raw operator logs are visible in media.
