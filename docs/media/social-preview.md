# Social Preview Design Brief

Create a clean GitHub social preview image for ParkinSUM Companion.

## Canvas

- Size: `1280 x 640 px`
- Format: PNG
- Layout: clear text-first design, readable when cropped in GitHub previews
- Background: calm light green or off-white with a restrained dark green accent
- Avoid: stock clinical imagery, hospital imagery, pills as the main visual,
  diagnosis/treatment imagery, real screenshots with user data, or abstract
  shapes that obscure the text.

## Primary Text

```text
ParkinSUM Companion
```

## Supporting Text

```text
Educational Parkinson's diet-medication awareness prototype
Local-first Flutter app | Synthetic demo data only
```

## Safety Line

```text
Not medical advice. Not a medical device.
```

## Visual Direction

- Use a simple composition with the project name on the left and a compact
  architecture motif on the right.
- Suggested motif: four small connected labels:
  `Meal context`, `Medication context`, `Rule check`, `Evidence explanation`.
- Use accessible contrast and large text.
- Keep the safety line visible but secondary.
- Do not show real patient records, real medication schedules, symptoms,
  Firebase tokens, service-account files, raw operator logs, UIDs, real email
  addresses, or local machine paths.

## Export Name

Recommended output path after creating the image:

```text
docs/assets/social-preview/parkinsum-social-preview.png
```

If the image is added later, update `docs/repository-metadata.md` and the
GitHub repository social preview setting.
