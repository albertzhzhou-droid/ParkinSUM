# Evidence scope

What this repository's screenshots, fixtures, checks and releases establish, and
what they do not. These limits used to sit in the project README; they were
moved here on 2026-10-20 so the README can open with what the project is for.
None of them were relaxed.

ParkinSUM is an educational production-architecture prototype. It is not
medical advice, not a medical device and not a clinical decision tool, and its
model is not clinically calibrated. See the [disclaimer](../DISCLAIMER.md) and
the [public demo boundary](PUBLIC_DEMO_BOUNDARY.md).

## By area

| Area | Evidence boundary |
| --- | --- |
| **Paper workspace** | UI behavior is distinct from model or clinical validity. |
| **Algorithm Observatory** | Static contracts and executable trace coverage remain separately labeled. |
| **Medication and food context** | Unsupported context withholds interpretation; unknown data is not inferred. |
| **Owner-controlled records** | Local records can contain sensitive information. Public demos must remain synthetic. |
| **Research workbench** | Fixture agreement is scoped engineering evidence, not general standards conformance or clinical validation. |

## The model

- The educational model provides no patient-specific
  pharmacokinetic/pharmacodynamic prediction or patient-outcome evidence.
- Literature-informed gastric-residence, absorption-opportunity, amino-acid
  competition, and per-dose traces are educational sensitivity views. They do
  not select meal times or reorder candidate recommendations. The production
  decision-influence boundary is `trace_only`; outputs carry applicability and
  uncertainty limits.
- Missing formulation, route, release type, dose evidence, or applicability
  cannot silently authorize a mechanistic curve.
- In the app, a result whose only elevated finding is missing medication input
  (for example dose or medication time) is shown as "can't assess yet". Its
  stored rule score, severity and decisions are unchanged and remain visible
  under "How was this computed?". This is a presentation rule, not a judgment
  that the meal is fine.

## Coverage and fixtures

- The Observatory separates production-derived observations from static
  registry contracts. A declared algorithm descriptor does not establish
  executable trace coverage or complete verification.
- Synthetic cases, content-bound replay artifacts, source-quality reports, and
  independent contract checks support review. Passing a fixture proves only the
  checked assertion within its scope.

## Screenshots

- The [showcase](site/index.html) presents the interface. Screenshot source,
  synthetic-state, and review boundaries are recorded in the
  [media index](assets/screenshots/README.md).
- A browser capture establishes visible rendering at its recorded revision, not
  physical-device behavior, workflow completion, accessibility conformance, or
  clinical accuracy.
- The README's 1440 × 1000 browser captures use a fresh local profile, one
  synthetic banana meal, zero selected medications, and no AI consent. They
  were captured on 2026-09-29 from the development worktree; they are not a
  final-commit binary attestation, and they predate the 2026-10-20
  plain-language copy changes.

## Verification commands

Generated reports belong under ignored `build/` paths. A command listed in the
README is a reproducible entry point, not a claim that every check passed for
every commit; use CI and the dated [timeline](APP_EVOLUTION_TIMELINE.md) for
actual results and open limitations. The
[public verification guide](PUBLIC_VERIFICATION.md) documents each command's
scope and failure meaning.

## Records and privacy

Owner-entered records and portable exports can contain sensitive data; local
storage and file digests do not establish anonymity, encryption, or external
authenticity. Do not publish personal exports, credentials, raw operator logs,
or real health records.

## Standards experiments and sources

FHIR-inspired views, import previews, and development-only standards
experiments have separate, explicit scopes. Neither a local EvidenceTraceBundle
nor a passing synthetic differential establishes general FHIR/CQL/CDS Hooks
conformance. Source-adapter fixtures do not establish live production
ingestion. Open-source references remain subject to repository and asset-level
license review; a research reference is not permission to transfer its content.

## Releases

Android demo/debug artifacts from other releases do not establish production
signing or app-store readiness.

## Citing and reuse

For academic use, cite ParkinSUM as a software prototype or educational
research artifact, not as a clinical intervention, medical device, or
patient-outcome study. Public GitHub visibility is not clinical, legal,
privacy, or regulatory approval. Contact: `parkinsumservice@gmail.com`.
