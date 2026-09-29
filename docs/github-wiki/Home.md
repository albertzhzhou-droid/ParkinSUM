# ParkinSUM Companion Wiki

ParkinSUM is an educational **production-architecture prototype** that brings
meal and medication records, deterministic explanations, and evidence review
into a local-first Flutter workspace.

> Not medical advice or a medical device. The model is not clinically
> calibrated. Public demonstrations use synthetic or sample data only;
> no clinical validation is claimed.

## The September Paper update

The interface now uses five chapters — **Today, Timeline, Next meal, Insights,
and Library** — with one entry composer and a shared **⌘K / Ctrl+K** command
palette. Paper uses warm opaque surfaces, legible typography, and finite
transitions that respect reduced motion. The evidence tools have their own
sidebar destinations, including the Algorithm Observatory and synthetic rule
test workbench.

The Observatory distinguishes production-derived traces from static contracts.
It supports fixed synthetic scenarios, explanations, configuration identity,
and replay review; coverage labels do not imply that every algorithm has an
executable trace or complete verification.

## Wiki navigation

| Page | Purpose |
| --- | --- |
| [[Architecture]] | Local-first layers, deterministic rules, and evidence flow. |
| [[Demo-Path]] | A current synthetic-data reviewer walkthrough. |
| [[Safety-Boundary]] | Limits of public use and project claims. |
| [[Contributing]] | Scoped contributions and review expectations. |

## Project links

- [Paper showcase](https://albertzhzhou-droid.github.io/ParkinSUM/site/)
- [Visual project guide](https://albertzhzhou-droid.github.io/ParkinSUM/wiki/)
- [Current README](https://github.com/albertzhzhou-droid/ParkinSUM#readme)
- [Documentation index](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/README.md)
- [Capability matrix](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/CAPABILITY_MATRIX.md)
- [Verification guide](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/PUBLIC_VERIFICATION.md)
- [Changelog](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/CHANGELOG.md)

## Run locally

Use the Flutter version pinned in CI and the repository's Dart SDK range.

```sh
git clone https://github.com/albertzhzhou-droid/ParkinSUM.git
cd ParkinSUM
flutter pub get
flutter run -d chrome --dart-define=PARKINSUM_BACKEND=local
```

Complete onboarding with a fresh synthetic profile. Do not use owner records,
real account identifiers, or personal exports for a public demonstration.

Deterministic rules retain authority over classifications, scores, evidence,
and safety gates. The mechanistic model is trace-only and does not choose meal
times or reorder recommendations. Optional consent-gated loopback AI is limited
to screened-whitelist reranking and wording polish.

This repository is for educational software review. It is not for diagnosis,
treatment, medication timing, dosing, diet guidance, patient care, or emergency
support. Browser captures and synthetic checks do not establish clinical
validity, general standards conformance, or physical-device acceptance.
