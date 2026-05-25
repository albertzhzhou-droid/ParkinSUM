# Safety And Ethics

ParkinSUM is intentionally framed as an educational software prototype. Its
public impact depends on being useful without overstating what the app can do.

## Core Boundary

ParkinSUM is:

- an educational digital-health prototype;
- a Flutter and local-first architecture example;
- a deterministic rule-engine demonstration;
- a synthetic-data walkthrough for public discussion;
- a portfolio and mentoring artifact.

ParkinSUM is not:

- medical advice;
- a medical device;
- a diagnostic, treatment, monitoring, or prevention tool;
- a medication timing or dietary instruction system;
- a patient-care or emergency-support system;
- a substitute for clinicians or pharmacists.

## Data Ethics

Public demos must use synthetic or sample data only. Do not include:

- real patient records;
- real medication schedules;
- symptoms or clinical notes;
- account identifiers;
- private Firebase exports;
- credentials, tokens, or service-account files;
- screenshots that reveal private local paths or accounts.

The synthetic scenario pack is safe for demonstrations because it uses fictional
meals, fictional profile context, and synthetic medication context.

## Explanation Ethics

Health-adjacent software should make uncertainty visible. ParkinSUM's
explanations are designed to show:

- which deterministic rule produced the result;
- which structured inputs mattered;
- what evidence references are attached;
- what limitations apply;
- why the output is educational and not individualized advice.

The project avoids using LLM inference for conflict decisions because those
decisions should remain deterministic, auditable, and testable.

## Claim Discipline

When presenting ParkinSUM, use conservative language:

- "educational prototype";
- "synthetic demo data";
- "deterministic rule checks";
- "evidence-oriented explanations";
- "not medical advice";
- "no clinical validation claimed."

Avoid language that implies the prototype can improve patient outcomes, guide
real treatment, replace professional judgment, or satisfy regulatory standards.

## Responsible Presentation Checklist

Before sharing ParkinSUM publicly:

1. Use only synthetic examples.
2. Include the safety disclaimer.
3. Avoid screenshots with real accounts or private paths.
4. Say that conflict logic is deterministic and test-covered.
5. Say that the project does not provide personal medical advice.
6. Link to the [public demo boundary](../PUBLIC_DEMO_BOUNDARY.md) and
   [rule engine testing guide](../rule-engine-testing.md).

## Related Materials

- [One-page summary](one-page-summary.md)
- [Technical case study](technical-case-study.md)
- [Project pitch](project-pitch.md)
- [FAQ](faq.md)
