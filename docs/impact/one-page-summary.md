# ParkinSUM One-Page Summary

ParkinSUM Companion is a local-first Flutter prototype for educational
diet-medication awareness demonstrations in Parkinson's disease contexts. It is
designed for GitHub visitors, teachers, mentors, application reviewers, and
digital-health audiences who want to understand the project without reading the
source code first.

This is not medical advice, not a medical device, and not a clinical decision
tool. Public examples use synthetic/demo data only.

## Problem

Food-drug interaction topics can be hard to explain because they combine meal
composition, medication context, timing, evidence sources, and safety warnings.
Many demo projects either hide the reasoning behind the result or overstate what
the software can prove.

ParkinSUM addresses this as an education and software-design problem: how can a
prototype show deterministic, evidence-oriented awareness without collecting
real patient data or making personal health recommendations?

## Prototype Solution

The app demonstrates a structured flow:

1. Enter a synthetic meal.
2. Add synthetic medication context.
3. Run deterministic rule checks.
4. Show an educational explanation with safety language and evidence context.
5. Keep the result framed as awareness, not individualized advice.

The prototype helps visitors see how local-first data handling, rule-based
logic, and conservative public copy can work together.

## Technical Architecture

- Flutter app interface for meal, medication, timeline, and result screens.
- Local-first app state and data flow for public demos.
- Deterministic runtime rule engine for structured conflict checks.
- Evidence-oriented explanation layer that keeps machine rules traceable.
- Synthetic scenario pack for safe walkthroughs.
- CI and public-readiness checks for formatting, tests, and repository hygiene.

See the [architecture overview](../ARCHITECTURE.md),
[rule engine overview](../RULE_ENGINE.md), and
[rule engine testing guide](../rule-engine-testing.md).

## Safety Boundary

ParkinSUM is for education, technical review, and portfolio demonstration. It
must not be used for diagnosis, treatment, medication timing decisions, dietary
instructions, patient monitoring, or emergency support.

The project intentionally avoids real patient data and does not claim clinical
validation, patient outcome improvement, regulatory approval, or medical-device
status.

See the [safety disclaimer](../../DISCLAIMER.md),
[public demo boundary](../PUBLIC_DEMO_BOUNDARY.md), and
[safety and ethics note](safety-and-ethics.md).

## Current Status

The repository is prepared as a public alpha showcase. It includes release
notes, CI checks, synthetic demo scenarios, issue templates, repository metadata
recommendations, and public-facing documentation.

The app remains an educational prototype. It is suitable for demonstrations,
code review, and discussion of local-first digital-health software patterns.

## Next Milestones

- Capture synthetic screenshots and a short demo GIF.
- Continue improving accessibility and localization.
- Expand copy-ready synthetic walkthroughs.
- Keep deterministic rule tests and evidence mapping easy to inspect.
- Maintain conservative safety language across README, site, release notes, and
  presentation materials.

## Reusable Materials

- [Technical case study](technical-case-study.md)
- [Project pitch](project-pitch.md)
- [FAQ](faq.md)
- [Safety and ethics](safety-and-ethics.md)
