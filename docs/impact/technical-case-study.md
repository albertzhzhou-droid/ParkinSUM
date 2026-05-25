# Technical Case Study

ParkinSUM Companion is a Flutter-based educational prototype that explores how
local-first app design, deterministic rules, synthetic data, and conservative
explanations can support public discussion of Parkinson's disease
diet-medication awareness.

The key design choice is restraint: the app is built to demonstrate a technical
pattern, not to make personal medical decisions.

## Local-First Design

The public showcase is intended to run in local mode with synthetic or sample
data. Local-first behavior is useful for a public prototype because it:

- reduces the need for accounts during demonstrations;
- avoids collecting real patient records for education;
- makes the demo easier for teachers, mentors, and reviewers to reproduce;
- keeps public screenshots and walkthroughs free of private identifiers;
- supports offline-first and reviewable app behavior.

Firebase-backed paths exist for internal operator validation and governance
review, but the public-facing story stays centered on local synthetic demos.

## Flutter App Architecture

The app uses Flutter to keep the prototype portable across local development
and future mobile/web demos. At a high level, the user-facing flow is:

1. Meal and medication context entry.
2. Local app state and model normalization.
3. Rule-engine runtime context construction.
4. Deterministic conflict evaluation.
5. Evidence-oriented explanation and result display.

For a deeper map, see the [architecture overview](../ARCHITECTURE.md).

## Deterministic Rule Engine

The rule engine evaluates structured context rather than asking a language model
to decide whether a conflict exists. Rules are compiled from declarative rule
registry data and evaluated against fields such as active ingredients, meal
protein context, timing, coevents, and jurisdiction.

This keeps the engine testable:

- trigger scenarios can assert expected rule IDs;
- non-trigger scenarios can assert that a rule stays silent;
- severity labels and output tags can be checked as stable metadata;
- evidence references can be tied back to rule provenance;
- localized rule messages can be tested without fragile full-text snapshots.

See [rule engine testing](../rule-engine-testing.md) for the focused confidence
tests.

## Synthetic Demo Data

The public demo pack lives at
[`../assets/demo/synthetic-scenarios.json`](../assets/demo/synthetic-scenarios.json)
and is explained in [synthetic demo scenarios](../demo-scenarios.md). It uses
fictional meals, fictional user context, and synthetic medication context.

The pack currently supports manual walkthroughs and tests. It is not a real
patient seed file and should not be imported into a real user account.

## Evidence-Oriented Explanations

ParkinSUM's explanation layer is designed to show why a deterministic result was
produced. The app separates:

- machine-readable rule IDs and output tags;
- user-facing explanation text;
- severity labels;
- evidence source references;
- safety copy that reminds users the result is educational.

This separation helps reviewers evaluate the logic without turning internal
machine codes into public advice.

## Why Medical Claims Are Intentionally Limited

ParkinSUM does not claim clinical validation, treatment impact, diagnostic use,
or regulatory approval. The prototype has not been evaluated as a medical
device, and it does not know a real person's clinical context.

Limiting claims is part of the design. The project is strongest when presented
as:

- an educational digital-health prototype;
- a local-first Flutter software architecture example;
- a deterministic rule-engine and evidence-explanation demonstration;
- a portfolio artifact for responsible health-technology communication.

It should not be presented as a tool for real patient-care decisions.

## Related Materials

- [One-page summary](one-page-summary.md)
- [Project pitch](project-pitch.md)
- [FAQ](faq.md)
- [Safety and ethics](safety-and-ethics.md)
