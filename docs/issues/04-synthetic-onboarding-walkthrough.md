# Add synthetic onboarding walkthrough data

Labels: `synthetic data`, `good first issue`

## Problem

Reviewers need a safe example flow for onboarding without entering real profile
or medication information.

## Expected output

Document one synthetic onboarding walkthrough with fake profile choices and
non-identifying context.

## Files likely involved

- `docs/release/synthetic-demo-data.md`
- `docs/site/index.html`
- `test/onboarding_flow_test.dart` if tests are added

## Difficulty

Beginner to intermediate.

## Safety notes

Use obvious demo values. Do not include real region-specific personal details,
patient stories, or medication schedules.
