# ParkinSUM Companion Wiki

<p align="center">
  <img src="https://raw.githubusercontent.com/albertzhzhou-droid/ParkinSUM/main/docs/assets/brand/parkinsum-wordmark.png" alt="ParkinSUM food medication interaction logo" width="760">
</p>

ParkinSUM Companion is a **production-architecture prototype** for educational demonstrations of local-first diet-medication awareness software. It combines synthetic meal logging, medication context, deterministic interaction checks, and evidence-oriented explanations.

> Educational prototype only. Synthetic/demo data only. Not medical advice, not a medical device, and no clinical validation is claimed.

## Wiki Navigation

| Page | What it shows |
| --- | --- |
| [[Architecture]] | The local-first Flutter layers, deterministic rule engine, and evidence trace flow. |
| [[Demo-Path]] | The reviewer walkthrough for running and inspecting the prototype with synthetic data. |
| [[Safety-Boundary]] | What the project can and cannot claim in public demos. |
| [[Contributing]] | Safe contribution routes and high-impact documentation/code areas. |

## Showcase Links

| Resource | Link |
| --- | --- |
| Animated Liquid Glass wiki page | https://albertzhzhou-droid.github.io/ParkinSUM/wiki/ |
| GitHub Pages landing page | https://albertzhzhou-droid.github.io/ParkinSUM/site/ |
| Repository README | https://github.com/albertzhzhou-droid/ParkinSUM#readme |
| Public verification guide | https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/PUBLIC_VERIFICATION.md |
| Evidence demo guide | https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md |

## What ParkinSUM Demonstrates

- **Local-first public demo path**: public evaluation should use local mode and synthetic/sample data.
- **Deterministic checks**: rule results are inspectable and replayable rather than black-box medical advice.
- **Evidence-oriented explanations**: user-facing copy carries source context, limitations, and not-advice language.
- **Catalog-backed context**: food and medication records preserve source and jurisdiction metadata.
- **Public guardrails**: README, docs, release checks, and media rules keep the project inside an educational boundary.

## Fast Local Preview

```sh
git clone https://github.com/albertzhzhou-droid/ParkinSUM.git
cd ParkinSUM
flutter pub get
flutter run -d chrome
```

Run public checks before presenting or publishing changes:

```sh
flutter analyze
flutter test
npm run public:preflight
npm run rules:contract
```

## Current Public Boundary

ParkinSUM Companion is appropriate for:

- Educational software demonstration.
- Architecture and mentoring discussion.
- Synthetic-data walkthroughs.
- Open-source review of deterministic rule explanations.

It is not appropriate for:

- Diagnosis, treatment, monitoring, prevention, patient care, or emergency support.
- Medication timing, dose, diet, or clinical decision-making guidance.
- Real patient records, real medication schedules, or public PHI demos.
- Claims of clinical validation, medical-device approval, or patient-outcome evidence.

