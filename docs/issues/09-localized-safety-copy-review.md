# Add localized safety-boundary copy review

Labels: `localization`, `accessibility`

## Problem

Safety language needs to remain clear when UI copy is localized.

## Expected output

Review existing safety-boundary strings for one locale and propose clearer
wording while preserving meaning.

## Files likely involved

- `lib/core/i18n/app_i18n.dart`
- `lib/core/i18n/app_i18n_full_translations.dart`
- `test/response_copy_service_test.dart`

## Difficulty

Intermediate.

## Safety notes

Do not soften the safety boundary. Translations must still say educational-only,
synthetic/demo data, and no medical advice.
