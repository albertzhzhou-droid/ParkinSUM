# ParkinSUM Security Hardening

This project is a Flutter client with Firebase Auth, Firestore, and Firebase
Hosting. There is no custom public server process in this repository, so backend
abuse protection is enforced through Firebase Security Rules, Firebase App
Check, Hosting headers, and operator hygiene.

## Runtime Controls

- Firestore writes are limited to explicit user-owned collections. The broad
  `users/{uid}/{document=**}` owner write rule is intentionally forbidden.
- User profile writes must bind `patientId` to `request.auth.uid`.
- Meal, intake, active-drug, app metadata, and clinical-audit writes are checked
  by allow-list validators for keys, IDs, types, and coarse size limits.
- Clinical audits are create-only; updates and deletes are denied.
- Top-level `cdss_tables` remains closed. Curated catalog writes go through
  `app_catalog/{table}/rows/{rowId}` and require the `admin` or `cdssImporter`
  custom claim plus the catalog schema gate.
- Local AI endpoints must stay on loopback HTTP(S) without credentials, query
  strings, fragments, or non-loopback hosts.

## App Check

App Check support is compiled behind dart defines so local development is not
blocked by missing provider setup.

Production web build example:

```sh
flutter build web \
  --dart-define=PARKINSUM_BACKEND=firebase \
  --dart-define=PARKINSUM_ENV=prod \
  --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion \
  --dart-define=PARKINSUM_FIREBASE_APP_CHECK=true \
  --dart-define=PARKINSUM_RECAPTCHA_SITE_KEY=<recaptcha-v3-site-key>
```

For reCAPTCHA Enterprise, use
`--dart-define=PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY=<enterprise-site-key>`
instead of the v3 key. After provider registration is verified in Firebase
Console, enable enforcement for Firestore. App Check reduces scripted abuse of
Firebase services; it does not replace account authorization rules or upstream
rate limiting.

## DDoS And Injection Posture

- Firebase Hosting serves static assets behind Google's edge. Repository-level
  DDoS controls are therefore limited to static-hosting headers and App Check
  for Firebase service calls. If a custom Cloud Run, Functions, or external API
  backend is added later, put it behind Cloud Armor or an equivalent WAF/rate
  limiter before public release.
- The app does not construct SQL queries. Firestore injection risk is handled by
  explicit document paths, safe ID patterns in rules, and allow-listed request
  fields.
- Hosting sends CSP, HSTS, `nosniff`, frame blocking, referrer policy,
  permissions policy, and COOP headers from `firebase.json`.

## Operator Hygiene

- Token files, authenticated probe exports, and operator audits must stay under
  ignored local paths and mode `0600`.
- Run `node tool/local_sensitive_artifact_sanitize.mjs --root <private-hold>`
  before archiving or sharing local operator evidence.
- Run `npm run security:backend` before deployment or public repository sync.
