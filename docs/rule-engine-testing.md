# Rule Engine Testing

ParkinSUM's food-drug awareness flow is designed around deterministic rule
evaluation. The app may later use local AI to polish wording, but conflict
logic, score inputs, severity labels, evidence references, and actions must be
created before any wording polish happens.

This document explains the current test strategy for the deterministic rule
engine and evidence-oriented explanation layer. It does not claim clinical
validation, treatment guidance, medication timing guidance, or medical-device
status.

## What Is Tested

- Rule predicates are evaluated from structured runtime context, not free-text
  inference.
- Synthetic trigger scenarios match the expected baseline rule IDs.
- Synthetic non-trigger scenarios remain non-triggering.
- Rule metadata remains stable where user-facing behavior depends on it:
  decision, severity, output tags, and evidence source references.
- Locale message lookup keeps exact-tag, language-family, and fallback behavior
  working.
- Response copy is checked for structure and safety framing without asserting
  fragile full paragraphs.

## Main Code Paths

- `lib/domain/usecases/runtime_rule_engine.dart` evaluates declarative rule
  predicates and resolves priority.
- `lib/domain/usecases/rule_registry_compiler.dart` validates and compiles rule
  registry JSON into typed rule entries.
- `lib/domain/usecases/clinical_decision_support_service.dart` converts matched
  rules into runtime alerts, audit entries, evidence references, and human
  explanation strings.
- `lib/domain/usecases/database_backed_meal_check_usecase.dart` bridges legacy
  meal, drug, and intake models into the unified runtime context used by the
  CDSS engine.
- `lib/core/copy/response_copy_service.dart` turns machine-oriented output into
  user-facing wording while preserving the deterministic facts.

## Focused Tests

The focused confidence tests live in
`test/rule_engine_confidence_test.dart`. They use only synthetic data and cover:

1. A levodopa plus high-protein meal scenario that triggers
   `pd.ldopa.protein.window.v1`.
2. A low-protein levodopa scenario that does not trigger the protein timing
   rule.
3. A levodopa plus iron coevent scenario that triggers `pd.ldopa.iron.v1`.
4. A rasagiline plus high-tyramine context that is intentionally bound to the US
   jurisdiction rule.
5. Baseline rule message localization fallback behavior.
6. Explanation-copy structure for a synthetic warning result.

The scenario pack tests in `test/synthetic_demo_scenarios_test.dart` also check
that `docs/assets/demo/synthetic-scenarios.json` can be parsed by the current
`Meal` and `Intake` models and that documented baseline rule expectations remain
deterministic.

## How To Run

```sh
flutter pub get
flutter analyze
flutter test
```

For a narrower rule-engine pass:

```sh
flutter test test/rule_engine_confidence_test.dart
flutter test test/synthetic_demo_scenarios_test.dart
```

## Safety Boundary

Tests use fictional demo meals, drugs, intakes, and user profiles. They are
engineering checks for deterministic behavior only. A passing test means the
implemented rule logic and explanation structure behaved as expected for the
synthetic fixture; it does not mean the app can diagnose, treat, recommend
medication changes, recommend dietary changes, or support patient-care
decisions.
