# Safe Copy Template Registry (skeleton)

Educational/research prototype. **Not medical advice, not clinically calibrated,
and carries no clinical-validation claim.**

## Purpose

A small, explicit foundation for future **centralized** user-facing copy. It
holds representative, non-prescriptive boundary templates so that copy can be
governed (and localization-linted) in one place. This is a **skeleton** — it does
**not** migrate every string and is **not** wired into the UI or scoring yet.

## Templates (v1)

`SafeCopyTemplateRegistry` (`lib/domain/usecases/safe_copy_template_registry.dart`)
ships six templates:

1. `mechanistic_explanation_boundary` — boundary copy for a modeled, source-linked
   overlap explanation (carries an `{overlap_percent}` placeholder).
2. `source_quality_boundary` — source-quality signals describe sourcing, not
   clinical accuracy.
3. `missing_context_boundary` — incomplete source coverage → reduced confidence.
4. `evidence_trace_boundary` — the local evidence trace is not a patient record.
5. `not_advice_default` — the shared default not-advice text.
6. `not_clinically_calibrated_default` — the shared not-clinically-calibrated text.

## Template fields

`templateId`, `outputType`, `defaultLocale`, `localizedText` (locale → text),
`requiredPlaceholders`, `allowedPlaceholders`, `requiredSafetyTerms`,
`requiredEvidenceTerms`, `bannedPhraseFamilies`, `requiresSourceRefs`,
`requiresLimitationText`, `requiresNotAdviceText`, `notes`.

## Safety requirements

Templates are **non-prescriptive**: no medication-timing, dose, or diet advice;
no safety or clinical-calibration claim. Each carries appropriate safety/evidence
boundary terms and is verified by the localization lint (it must lint with **0
blockers**). See `docs/LOCALIZATION_SAFETY_LINT.md`.

## Status / limitations

Skeleton only; localization coverage beyond the few provided locales and
migration of live UI strings are **future work**. Not wired into the UI or the
scoring engine in this PR.
