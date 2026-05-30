# Localization Safety Lint

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

## 1. Purpose

The LocalizationSafetyLint protects user-visible copy and localization surfaces
from drifting into unsupported medical advice, overconfident claims, missing
safety boundaries, missing evidence/limitation wording, or incomplete
translations across locales. It pairs with the **SafeCopyTemplateRegistry**
(`docs/SAFE_COPY_TEMPLATE_REGISTRY.md`) — a small skeleton of representative,
non-prescriptive boundary copy.

## 2. Safety boundary

This is a **safety/governance lint**, not a feature of the conflict engine. It
adds no medical advice, uses no LLM translation, and does not modify the
mechanistic engine, importers, scoring, Firebase rules, or UI. It is **not a
translation-quality guarantee**, **not a clinical-safety guarantee**, and **does
not replace human review**.

## 3. Why localization safety matters

The English source copy may be safe, but a localized string can accidentally
become prescriptive ("recommended dose") or overconfident ("safe for you"), or
drop the safety boundary entirely. The lint flags these so they are caught before
they reach users.

## 4. What surfaces are linted

The lint operates on a list of `LocalizationSurface` entries (file I/O lives in
the tool wrapper). In v1 the tool lints the **SafeCopyTemplateRegistry** copy
across the locales each template provides. The app's full i18n dictionary is
Flutter-coupled and is **not** loadable from the pure-Dart CLI, so the report
records an informational `no_locale_dictionary_discovered` finding rather than
fabricating coverage — full-dictionary linting is **future work**.

## 5. Required locales

Core locales: **en, zh, fr, ja** (the app's `_strings` set). Source locale: `en`.
(The app also ships additional UI locales — ko/hi/es/vi/th/id/ru/pl/ar — which are
out of scope for v1 banned-phrase coverage.)

## 6. Rule families

- **A — missing locale coverage**: each configured safety key must exist in every
  required locale (warn; blocker in `--strict`).
- **B — missing safety boundary**: boundary/explanation surfaces must carry a
  non-prescriptive boundary term (educational / not medical advice / not
  clinically calibrated / modeled / source-linked, incl. zh/fr equivalents).
- **C — missing evidence/limitation terms**: explanation surfaces must mention
  source / evidence / provenance / limitation / modeled.
- **D — banned phrase families**: multilingual unsafe prescriptive phrases (see
  §7). Blocker.
- **E — placeholder validation**: unknown placeholder (warn); missing required
  placeholder (warn; blocker in `--strict`).
- **F — overconfidence heuristic**: conservative English patterns (guaranteed,
  best for you, optimal for you, this will work, always safe).
- **G — safety-policy allowlist**: policy values and safe negated phrases are
  exempt (see §8).

## 7. Banned phrase examples (v1)

- **en** (shown hyphenated here so this doc stays scanner-clean; the lint uses the
  normal spaced forms in code): `recommended-dose`, `recommended-timing`,
  `adjust-your-dose`, `take-medication-at`, `avoid-protein`, `safe-for-you`,
  `confirmed-safe`, `clinically-validated`, `patient-calibrated`.
- **zh**: 建议剂量, 推荐剂量, 建议服药, 应该服药, 应该吃, 避免蛋白, 对你安全, 已验证安全, 临床验证.
- **fr**: dose recommandée, moment recommandé, ajuster votre dose, prenez le
  médicament, évitez les protéines, sûr pour vous, validé cliniquement.
- **ja**: 推奨用量, 服用すべき, 薬を服用してください, タンパク質を避ける, あなたに安全, 臨床的に検証済み.

The multilingual list is a **conservative v1**; coverage is not exhaustive.

## 8. Safety-policy allowlist

Values such as `not_clinically_calibrated`, `subject_omitted_no_phi`,
`no_patient_no_subject_no_encounter`, `inspired_not_conformant`, and safe negated
phrases (e.g. "not clinically calibrated", a negated `clinically-validated`
claim, "not medical advice") are **never** flagged. A preceding negation
("not "/"non "/"pas ") also
suppresses a Latin-script banned hit.

## 9. How to run

```sh
dart run tool/run_localization_safety_lint.dart           # or: npm run localization:lint
dart run tool/run_localization_safety_lint.dart --strict  # escalate coverage/placeholder gaps
```

Writes `build/localization_safety_lint/latest.{json,md}`. Exits non-zero iff a
**blocker** finding exists. No network.

## 10. How to interpret findings

`blocker` = unsafe prescriptive copy (or, in strict mode, missing required
coverage/placeholder) → must fix. `warn` = a gap to review (missing boundary,
overconfidence, unknown placeholder, missing coverage). `info` = contextual note
(e.g. the app dictionary was not loadable from the CLI). Each finding names the
surface, locale, key, and matched snippet.

## 11. Limitations

v1 lints the safe-copy registry; full app-dictionary coverage is future work.
Multilingual banned-phrase patterns are conservative and not exhaustive. Not a
translation-quality or clinical-safety guarantee; no LLM; human review still
required.

## 12. Reviewer checklist

- [ ] `dart run tool/run_localization_safety_lint.dart` exits 0 (0 blockers).
- [ ] Registry templates carry safety boundary + evidence terms and no banned
      phrases.
- [ ] Banned phrases in en/zh/fr/ja are flagged as blockers.
- [ ] Safety-policy values and negated phrases are NOT flagged.
- [ ] Unknown/missing placeholders are reported.
- [ ] Report JSON emits no patient/subject/encounter keys.
