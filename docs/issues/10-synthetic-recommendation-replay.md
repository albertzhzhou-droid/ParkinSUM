# Add synthetic recommendation replay example

Labels: `synthetic data`, `testing`, `rule-engine`

## Problem

Recommendation behavior is easier to review when there is a small, safe replay
scenario.

## Expected output

Add or document one synthetic replay case that demonstrates educational output
and expected safety wording.

## Files likely involved

- `test/recommendation_replay_runner_test.dart`
- `test/recommendation_benchmark_dataset_test.dart`
- `docs/release/synthetic-demo-data.md`

## Difficulty

Intermediate to advanced.

## Safety notes

Use fake inputs only. The output must not imply a real user should change
medication timing or diet.
