# Repository Metadata

Use this file when configuring the public GitHub repository metadata for
ParkinSUM Companion. The wording is intentionally conservative: ParkinSUM is an
educational software prototype using synthetic/demo data, not medical advice,
not a medical device, and no clinical validation is claimed.

## Verified GitHub Metadata — 2026-09-29

The repository description and homepage were updated successfully on GitHub.
This record covers those two settings only; it does not establish a successful
Pages deployment, topic changes, or a social-preview upload.

Current repository description:

```text
A local-first Flutter research notebook for meals, medication context, and evidence-oriented explanations. Educational prototype with synthetic demos.
```

Current homepage:

[ParkinSUM Paper showcase](https://albertzhzhou-droid.github.io/ParkinSUM/site/)

The description preserves the educational scope without claiming diagnosis,
treatment, clinical validation, medical-device status, or patient-care
suitability.

## Recommended GitHub Topics

The following remain recommendations, not a record of verified remote topic
changes. Use only precise, defensible topics:

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

The warm Paper preview is available at
`docs/assets/social-preview/parkinsum-social-preview-warm.png` (1280 × 640 PNG).
Its text is:

```text
ParkinSUM Companion
ParkinSUM
A local-first research notebook.
Meals, medication & evidence context
Educational prototype · Synthetic demos
github.com/albertzhzhou-droid/ParkinSUM
```

Small safety line:

```text
Not medical advice.
```

Keep the preview clean and readable at small sizes. Do not include screenshots
that show real health information, real medication schedules, credentials,
Firebase project details, raw operator logs, UIDs, or local machine paths.

See `docs/media/social-preview.md` for all three brand assets, typography
provenance, and the generation prompts. Local README and Pages references use
the warm assets; the GitHub repository social-preview setting still requires
uploading this PNG in repository Settings. **Upload is pending; success has not
been verified.** Creating or committing an image does not update that GitHub
setting.

## Suggested Pinned Repository Description

Suggested pinned-card or profile description:

```text
ParkinSUM Companion is a local-first Flutter educational prototype exploring meal logging, medication context, deterministic food-drug interaction checks, and evidence-oriented explanations for Parkinson's disease diet-medication awareness. Public demos use synthetic data only.
```

## Academic Citation Wording

[`CITATION.cff`](../CITATION.cff) is the authoritative source for the software
citation, including title, author, release date, and version. Use the fields
for the artifact being cited rather than copying a version into this metadata
guide. When discussing untagged development, identify the exact commit or ref
and access date separately; do not invent a new release version.

Suggested context sentence:

```text
ParkinSUM Companion is cited here as an educational software prototype and architecture artifact; it is not cited as a clinical intervention, medical device, treatment system, or patient-outcome study.
```

## Remaining GitHub Setup

The description and homepage are already set as recorded above.

- Review the recommended topics before changing them.
- Upload the actual warm PNG under repository **Settings → Social preview**,
  then verify the saved repository setting. The upload is currently pending.
- Verify the deployed Pages route separately from the homepage field.

For a future update, the equivalent description/homepage command is:

```sh
gh repo edit albertzhzhou-droid/ParkinSUM \
  --description "A local-first Flutter research notebook for meals, medication context, and evidence-oriented explanations. Educational prototype with synthetic demos." \
  --homepage "https://albertzhzhou-droid.github.io/ParkinSUM/site/"
```

Topic changes are a separate action. Do not assume suggested topics were
applied merely because the description/homepage command succeeded.

Do not add topics or descriptions that imply diagnosis, treatment, clinical
validation, medical-device approval, or public patient-care readiness.
