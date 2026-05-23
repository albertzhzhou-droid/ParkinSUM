# Privacy Notice and Disclaimer Draft

This is a working draft for product, privacy, and legal review. Do not treat it
as final legal text.

For the longer privacy policy draft and user data export/deletion language, see
`docs/privacy_policy_draft.md`.

## Short In-App Disclaimer

ParkinSUM Companion provides decision-support information about medication,
meal timing, food composition, and related evidence sources. It does not
diagnose disease, prescribe treatment, replace professional medical judgment,
or provide emergency alerts. Always review the evidence basis shown in the app
and consult a qualified healthcare professional before making medication,
dietary, or treatment decisions.

## Expanded Medical Disclaimer

ParkinSUM Companion is intended to support review of Parkinson-related
medication and nutrition information. The app may identify possible timing,
food, or medication-related considerations based on available reference data and
rules. The output is informational and should be independently reviewed.

The app is not intended to:

- diagnose, cure, mitigate, treat, or prevent disease by itself.
- replace a physician, pharmacist, dietitian, or other qualified healthcare
  professional.
- provide emergency, real-time, or time-critical alarms.
- instruct a user to start, stop, or change medication.
- guarantee that a meal, medicine, dose, schedule, or recommendation is safe for
  a specific person.

Users should seek professional medical advice for individual treatment
decisions. In an emergency, users should contact local emergency services.

## Data Sources and Evidence Disclaimer

The app uses curated records, official-source imports, local seed data, and
rule-based logic. Some source fields may be incomplete, stale, unavailable, or
not directly comparable across jurisdictions. When source evidence is uncertain,
the app should preserve the uncertainty in provenance, audit output, readiness
warnings, or conservative recommendation copy.

Recommendations should be interpreted together with:

- source references shown by the app.
- rule traces and explanation details.
- warnings about missing observations, stale rules, fallback jurisdictions, or
  backend limitations.
- the user's clinical context, medication regimen, and professional advice.

## Privacy Notice Draft

ParkinSUM Companion may process information that users enter about meals,
medications, timing, and related app activity. In Firebase mode, user-specific
records are stored under account-scoped paths tied to the signed-in Firebase
user id. Firestore rules are intended to restrict private user data so only the
signed-in owner can read or write it.

The app may store or process:

- account identifier from Firebase Authentication.
- meal entries and food selections.
- medication selections and timing information.
- clinical decision support audit records.
- app-generated recommendation and rule-trace records.
- technical metadata needed for synchronization, debugging, or release
  readiness.

The app also stores shared reference data, such as catalog rows, source
documents, rule records, and locale text. Shared reference data should not
contain user-private clinical records.

## User Data Practices to Confirm Before Public Release

Before public release, confirm and document:

- what Firebase Auth providers are enabled.
- whether email, display name, or other profile fields are collected.
- whether analytics, crash reporting, or third-party monitoring are enabled.
- whether logs can contain user-entered health information.
- how users request data deletion.
- how users request account deletion.
- how backups are retained and deleted.
- who can access production Firebase data.
- how admin/importer custom claims are granted and audited.
- support contact and response expectations.

Current P0 implementation status:

- In-app Privacy & Disclaimer entry exists on the login page.
- In-app Privacy & Disclaimer entry exists in the Firebase account area.
- Contact text displays `parkinsumservice@gmail.com` for support and privacy.
- Stage export/delete/account deletion drill passed for a disposable test uid.
- Internal/private prerelease owner acceptance is recorded in
  `docs/clinical_legal_privacy_final_signoff_package_20260522.md`. External
  clinical/legal professional review is not claimed.

## Security Commitments Draft

The production release should commit to:

- user-scoped private data paths.
- deny-by-default Firestore rules.
- admin/importer-only writes for shared catalog publication.
- no shared collection writes for patient-private records.
- review of rules before deployment.
- documented backup and rollback process.
- restricted production project access.

## Consent Copy Draft

By using ParkinSUM Companion, you acknowledge that the app provides
decision-support information only. You are responsible for reviewing the
evidence and consulting qualified healthcare professionals before making
medical, medication, or dietary decisions. You also acknowledge that information
you enter may be stored and processed to provide app functionality, subject to
the app's privacy notice.

## Public Release Blockers for Legal/Privacy Review

Do not release publicly until these items are resolved:

- Final privacy policy is approved.
- Final disclaimer is approved.
- User deletion/account deletion workflow is documented.
- Production support contact is published.
- Firebase production access control is reviewed.
- Any analytics/crash/logging data collection is documented.
- Jurisdiction-specific regulatory positioning is reviewed.
