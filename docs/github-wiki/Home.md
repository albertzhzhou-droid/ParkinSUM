<p align="center"><img src="https://raw.githubusercontent.com/wiki/albertzhzhou-droid/ParkinSUM/assets/hero.svg" width="960" alt="ParkinSUM Companion: an educational, local-first prototype with deterministic, traceable conflict reasoning. 65 registered algorithms, 26,995 official FDC rows, 0 clinical claims."></p>

> [!IMPORTANT]
> **Educational prototype.** It is not a medical device and makes no claim of clinical validation. Public demos use synthetic data only. Review any health question with a qualified clinician.

ParkinSUM Companion is a local-first Flutter workspace for meal and medication **records**. It is organised in five chapters (**Today, Timeline, Next meal, Insights, Library**) with one entry composer and a **⌘K / Ctrl+K** command palette. Deterministic rules keep authority over classifications, scores, evidence and safety gates. The mechanistic conflict engine is trace-only: every layer writes an inspectable trace, and it never chooses meal times or reorders recommendations. Optional, consent-gated loopback AI is limited to reranking screened candidates and polishing wording. Food data is copied verbatim from official sources and tested back against them.

## Five things to know

| | |
| --- | --- |
| **One deterministic pass** | Meal composition → gastric emptying → absorption window → LNAA competition → result. Same inputs, same trace. [[Conflict engine →\|Conflict-Engine]] |
| **Findings lower confidence, never the score** | Food-borne L-dopa, unstated dry/cooked state and inconsistent source records add uncertainty reasons and cap confidence. [[How →\|Conflict-Engine]] |
| **Official data, tested back** | 26,995 FoodData Central 2025-04-24 rows for 280 foods; every value is re-read from the source CSV in tests. [[Food data →\|Food-Data]] |
| **Evidence says what it does *not* support** | Each registered source carries its mechanism and its limitation, negative findings included. [[Evidence & archives →\|Evidence-and-Archives]] |
| **Governance is append-only** | 27 context-of-use records, each blocked pending evidence; none carries an approval. [[Ledger →\|Evidence-and-Archives]] |

## Pages

| Page | What you get |
| --- | --- |
| [[Conflict-Engine]] | The layer pipeline, what each trace records, and how confidence is capped. |
| [[Food-Data]] | Provenance from official CSV to test, composition identities, LNAA calibration. |
| [[Evidence-and-Archives]] | The evidence archive and the governance ledger. |
| [[Architecture]] | Local-first layers and where to start reading code. |
| [[Demo-Path]] | A synthetic-data walkthrough for reviewers. |
| [[Safety-Boundary]] | What the project is and is not for. |
| [[Contributing]] | Scoped contributions and the PR checklist. |

## Run it locally

```sh
git clone https://github.com/albertzhzhou-droid/ParkinSUM.git
cd ParkinSUM
flutter pub get
flutter run -d chrome --dart-define=PARKINSUM_BACKEND=local
```

Complete onboarding with a fresh synthetic profile. Do not use owner records, real account identifiers or personal exports in a public demonstration.

Before presenting or publishing a change:

```sh
flutter analyze
flutter test
npm run verify:all
```

## Links

[Capability matrix](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/CAPABILITY_MATRIX.md) · [Changelog](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/CHANGELOG.md) · [README](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/README.md) · [Disclaimer](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/DISCLAIMER.md) · [Conflict engine model](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/CONFLICT_ENGINE_MODEL.md) · [Known risks](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/known_risks.md) · [Evolution timeline](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/APP_EVOLUTION_TIMELINE.md) · [Paper showcase](https://albertzhzhou-droid.github.io/ParkinSUM/site/) · [Visual guide](https://albertzhzhou-droid.github.io/ParkinSUM/wiki/)

<sub>Animations respect your system's reduced-motion and dark-mode settings.</sub>
