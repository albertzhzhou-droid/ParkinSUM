# Claude Project Instructions

## Project Safety Boundary

ParkinSUM Companion is an educational and research software prototype. It is
designed to demonstrate production-style app architecture, Firebase governance,
CDSS-style rule explanation, data provenance, local-first behavior, and
release-readiness operations.

As currently intended, this repository is not a deployed high-risk healthcare
product. It is not a medical device, not clinical software, and not a patient
care system. It must not be used for diagnosis, treatment, medication timing,
dietary decisions, clinical decision-making, emergency decisions, patient care,
or personal health management.

Public demonstrations, tests, screenshots, seed data, walkthroughs, and examples
must use synthetic or sample data only. Do not ask for, generate, store, or
process real patient health information, medication schedules, symptoms,
identifiers, credentials, Firebase tokens, service account credentials, raw
operator audit logs, or other sensitive personal data.

No external clinical, legal, privacy, regulatory, or professional review is
claimed by this repository. Any future real-world health, patient-facing, or
clinical use would require a separate intended-use statement, qualified
professional review, privacy review, security review, and applicable regulatory
analysis before use.

## What Would Push This Toward a Concern

This project would become a policy, safety, or compliance concern if it were
changed or presented in any of the following ways:

- Deployed to real patients as a substitute for professional medical advice.
- Made definitive clinical recommendations without appropriate disclaimers.
- Designed to discourage patients from consulting their doctors or qualified
  clinicians.

## Required Behavior When Editing Code

When working on this repository, preserve the prototype-only safety boundary.
Do not convert the project into a system that provides individualized medical,
dietary, medication, emergency, or clinical instructions.

Allowed work includes:

- Flutter, Dart, Firebase, Firestore rules, i18n, UI, architecture, tests,
  documentation, release tooling, and synthetic demo flows.
- Educational explanations of deterministic rules, as long as they remain
  clearly non-clinical and non-prescriptive.
- Localized copy that explains uncertainty, evidence provenance, safety
  boundaries, and the need to consult qualified clinicians.
- AI-assisted wording polish that improves readability without changing medical
  meaning, risk scores, severity, evidence, action labels, or rule outcomes.

Do not generate or add:

- Diagnosis, treatment, medication timing, dosage, dietary instructions, or
  patient-care recommendations.
- Claims that the app is clinically validated, approved, safe for real patient
  use, a medical device, or a substitute for professional care.
- Copy that says a meal, medication, timing choice, or symptom pattern is
  definitely safe or unsafe for a specific person.
- Workflows that collect or display real patient data in public demos.
- Attempts to bypass platform safety policies, content filters, account
  restrictions, or provider terms.

## AI and Recommendation Guardrails

The app may contain AI-assisted copy-polish or recommendation-explanation
experiments, but AI must remain non-authoritative. AI must not be the source of
clinical truth and must not override deterministic safety rules, scores,
severity, evidence references, or audit records.

If implementing AI-related code:

- Keep AI output suggestion-only and non-prescriptive.
- Keep deterministic rule outputs inspectable and auditable.
- Preserve evidence/provenance fields.
- Preserve disclaimers and professional-consultation language.
- Add tests for safety-copy integrity where relevant.
- Make it clear to users when AI assisted wording is used.

## i18n and User-Facing Copy Rules

All localized strings related to health, medication, meals, risk, safety, or
recommendations must keep the same safety meaning as the source language.
Translations should be fluent, plain, and understandable, but they must not
become more clinically assertive than the original.

Preferred wording style:

- "This prototype can show an educational caution based on its rules."
- "Review this with a qualified clinician before making health decisions."
- "The source coverage is incomplete, so this result should not be treated as
  personal medical advice."

Avoid wording like:

- "You should take this medication at..."
- "This food is safe for you."
- "This result confirms..."
- "Follow this treatment plan."
- "No doctor review is needed."

## Source Documents

Before changing safety-sensitive behavior or user-facing health copy, review:

- `README.md`
- `DISCLAIMER.md`
- `docs/PUBLIC_DEMO_BOUNDARY.md`
- `docs/known_risks.md`
- `docs/release_acceptance_report.md`

Keep these documents aligned with any code or copy changes.
