# Explanation Copy Compiler

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

> **Deterministic copy compilation + validation only.** It renders and validates
> non-prescriptive copy from the `SafeCopyTemplateRegistry`. It adds **no**
> medical advice, **no** dose/timing/diet guidance, and **no**
> clinical-calibration claim, and it is **not** wired into the UI or scoring.

## 1. Purpose

`ExplanationCopyCompiler` (P6) is the compiler layer over the
`SafeCopyTemplateRegistry` skeleton. It takes a template plus placeholder
bindings and a small context, **renders** the final copy string, and
**validates** that the result stays inside the educational safety boundary. It
turns the registry from a static list into a usable, validated copy-compilation
step that other tooling (and, in a future approved batch, the UI) can build on.

## 2. Safety boundary

The compiler is pure and deterministic. It introduces no patient/subject/
encounter semantics, no LLM, and no network. It cannot, by construction, emit a
prescriptive phrase (a banned-phrase match is a BLOCKER), and it enforces the
presence of the required safety terms. It does not change scoring and is not
wired into the UI in this work.

## 3. What it does

For each template + bindings + context it:

1. Resolves the locale (falling back to the template's default with an `info`
   finding when the requested locale is absent).
2. Binds `{placeholder}` tokens from the supplied bindings.
3. Validates placeholders, required safety/evidence terms, banned phrases, and
   the structural requirements, producing findings.
4. Returns the rendered `CompiledCopy` only when there is no BLOCKER.

## 4. Finding types and severity

| Finding | Severity |
| --- | --- |
| `missing_required_placeholder` | blocker |
| `unresolved_placeholder` (a `{x}` remained after render) | blocker |
| `missing_safety_term` (on the default-locale render) | blocker |
| `banned_phrase` (reuses the LocalizationSafetyLint families) | blocker |
| `requires_source_refs_unsatisfied` | blocker |
| `requires_limitation_unsatisfied` | blocker |
| `requires_not_advice_unsatisfied` | blocker |
| `unknown_placeholder` (binding not declared) | warn |
| `missing_evidence_term` | warn |
| `locale_fallback` (requested locale absent) | info |

A result is valid (and a `CompiledCopy` is produced) only when there are zero
BLOCKER findings.

## 5. Placeholder binding

Templates use `{name}` placeholders. Required placeholders must be bound;
unknown bindings (not in `allowedPlaceholders`/`requiredPlaceholders`) are a
WARN; any placeholder left unresolved after rendering is a BLOCKER (no copy is
emitted with a dangling token).

## 6. Required safety / evidence terms

Safety terms (e.g. `educational`, `not medical advice`, `not clinically
calibrated`) are enforced as BLOCKERs on the **default-locale** render; evidence
terms (e.g. `source-linked`, `source-quality`) are WARNs. Non-default locales are
validated separately by `localization:lint` (so CJK renders are not false-failed
against English term literals).

## 7. Banned-phrase validation

The compiler reuses `LocalizationSafetyLint.bannedFamilies` (en/zh/fr/ja). A
match is a BLOCKER, except where the surrounding text is a safe negation (e.g.
"not clinically-validated", "not medical advice"), which is never flagged.

## 8. Structural requirements

A template may declare `requiresSourceRefs`, `requiresLimitationText`, and
`requiresNotAdviceText`. These are satisfied by the supplied `CopyCompileContext`
(`sourceRefs`, `hasLimitationText`, `hasNotAdviceText`) — or, for not-advice, by
the rendered text already containing "not medical advice". The compiler never
fabricates these; an unmet requirement is a BLOCKER.

## 9. How to run

```sh
dart run tool/run_explanation_copy_compile.dart   # or: npm run copy:compile
```

This compiles every registry template with deterministic sample bindings and
writes `build/explanation_copy/latest.{json,md}`. Exit code is `0` when all
templates compile with zero BLOCKER findings.

## 10. How to inspect the report

`latest.json` lists every `CompiledCopy` (rendered text + provenance) and all
findings with severity counts; `latest.md` is a reviewer table of the compiled
copy plus findings, limitations, and the safety boundary.

## 11. Relationship to the registry and the localization lint

- `SafeCopyTemplateRegistry` (the P6 skeleton) supplies the templates.
- `ExplanationCopyCompiler` renders + validates them at compile time.
- `localization:lint` (P7) independently validates per-locale copy surfaces.

Together they form the P6/P7 copy-safety layer. Routing the **app's actual UI
strings** through this compiler (the full copy migration) remains future work and
is intentionally out of scope here to preserve the "no UI changes" boundary.

## 12. Limitations

- Compiles + validates copy templates; it does not migrate UI strings or change
  scoring.
- Banned-phrase matching is the conservative LocalizationSafetyLint families; not
  a clinical-safety guarantee.
- Required safety/evidence terms are enforced on the default-locale render.
- Synthetic/demo only; not clinically calibrated; carries no clinical-validation
  claim.

## 13. Reviewer checklist

- [ ] Every registry template compiles (`npm run copy:compile` → 0 blocker).
- [ ] No rendered copy contains a banned prescriptive phrase.
- [ ] Required safety terms are present; structural requirements are satisfied by
      real context, never fabricated.
- [ ] The report JSON is deterministic and emits no patient/subject/encounter
      keys.
- [ ] No UI string was migrated/changed in this PR (migration stays future work).
