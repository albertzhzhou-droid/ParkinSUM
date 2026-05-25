# Repository Metadata

Use this file when configuring the public GitHub repository metadata for
ParkinSUM Companion. The wording is intentionally conservative: ParkinSUM is an
educational software prototype using synthetic/demo data, not medical advice,
not a medical device, and no clinical validation is claimed.

## Short Repository Description

Recommended GitHub repository description:

```text
Educational Flutter prototype for Parkinson's disease diet-medication awareness, local-first demos, and evidence-oriented food-drug interaction explanations.
```

This description is accurate for GitHub search while avoiding claims about
diagnosis, treatment, clinical validation, medical-device status, or real-world
patient-care suitability.

## Recommended GitHub Topics

Use only precise, defensible topics:

```text
flutter
parkinsons-disease
levodopa
food-drug-interactions
clinical-decision-support
local-first
digital-health
patient-education
mhealth
offline-first
```

Avoid misleading tags:

```text
medical-device
diagnosis
treatment
clinical-validation
prescription
patient-monitoring
```

Notes:

- `clinical-decision-support` is acceptable only as a software-architecture and
  CDSS-style rule-explanation topic. Do not describe ParkinSUM as validated
  clinical decision support for real care.
- `patient-education` means educational content design, not individualized
  medical guidance.
- `offline-first` and `local-first` refer to the public-demo architecture and
  local app behavior.

## Social Preview Image Text

Recommended text for GitHub social preview:

```text
ParkinSUM Companion
Educational Parkinson's diet-medication awareness prototype
Local-first Flutter app | Synthetic demo data only
```

Small safety line:

```text
Not medical advice. Not a medical device.
```

Keep the preview clean and readable at small sizes. Do not include screenshots
that show real health information, real medication schedules, credentials,
Firebase project details, raw operator logs, UIDs, or local machine paths.

See `docs/media/social-preview.md` for a reusable design brief.

## Suggested Pinned Repository Description

Suggested pinned-card or profile description:

```text
ParkinSUM Companion is a local-first Flutter educational prototype exploring meal logging, medication context, deterministic food-drug interaction checks, and evidence-oriented explanations for Parkinson's disease diet-medication awareness. Public demos use synthetic data only.
```

## Academic Citation Wording

Suggested prose citation:

```text
Zhou, Zhenghang. ParkinSUM Companion: a local-first Flutter prototype for Parkinson's disease diet-medication education. GitHub repository, v0.1.0-alpha, 2026. Available at: https://github.com/albertzhzhou-droid/ParkinSUM
```

Suggested context sentence:

```text
ParkinSUM Companion is cited here as an educational software prototype and architecture artifact; it is not cited as a clinical intervention, medical device, treatment system, or patient-outcome study.
```

The repository also includes `CITATION.cff` so citation tools can discover the
software citation automatically.

## Manual GitHub Setup Steps

`gh auth status` currently reports an invalid token in this local environment,
so these settings should be updated manually in GitHub unless an authenticated
token with repository metadata permissions is available.

1. Open `https://github.com/albertzhzhou-droid/ParkinSUM`.
2. Select the gear icon next to the repository About panel.
3. Paste the short repository description from this document.
4. Add the recommended topics exactly as listed above.
5. Add the project website URL after GitHub Pages is enabled:

   ```text
   https://albertzhzhou-droid.github.io/ParkinSUM/site/
   ```

6. Open `Settings` -> `Social preview`.
7. Upload a preview image generated from the brief in
   `docs/media/social-preview.md`.

If GitHub CLI is re-authenticated later, equivalent commands are:

```sh
gh repo edit albertzhzhou-droid/ParkinSUM \
  --description "Educational Flutter prototype for Parkinson's disease diet-medication awareness, local-first demos, and evidence-oriented food-drug interaction explanations." \
  --homepage "https://albertzhzhou-droid.github.io/ParkinSUM/site/"

gh repo edit albertzhzhou-droid/ParkinSUM \
  --add-topic flutter \
  --add-topic parkinsons-disease \
  --add-topic levodopa \
  --add-topic food-drug-interactions \
  --add-topic clinical-decision-support \
  --add-topic local-first \
  --add-topic digital-health \
  --add-topic patient-education \
  --add-topic mhealth \
  --add-topic offline-first
```

Do not add topics or descriptions that imply diagnosis, treatment, clinical
validation, medical-device approval, or public patient-care readiness.
