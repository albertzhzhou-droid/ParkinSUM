# Local Privacy Preflight

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

> **This is repo hygiene + privacy-risk preflight — nothing more.** It is **NOT**
> HIPAA, GDPR, or PIPEDA compliance, **not** a legal certification, **not**
> clinical validation, and it **does not prove the app is secure**. Passing this
> gate only means the scanned, tracked files did not match a set of conservative
> patterns for secrets, PHI-like data, local paths, raw exports, and real-health
> narratives. A clean result is not a guarantee of safety.

## 1. Purpose

`LocalPrivacyPreflight` (P8) is a stricter, local, deterministic
repo-hygiene / privacy-risk scanner that runs over the files that would actually
be published (git-tracked files). It reduces the risk of accidentally committing
or publishing sensitive material: private keys and service-account credentials,
API keys/tokens outside the known public Firebase client config, PHI-like
fields with concrete values, absolute local machine paths, raw private data
exports/dumps, operator logs, and phrases that read like a real patient's
health narrative.

It **complements** `npm run public:preflight`; it does not replace it. The public
preflight remains the authoritative release gate for banned medical-advice copy
and public-demo boundary checks. This preflight adds an additional, narrower
privacy/secret-leak check on top.

## 2. Safety boundary

This is a **governance / hygiene tool**, not a feature of the conflict engine. It
adds no medical advice, performs no diagnosis, treatment, dosing, timing, or
dietary inference, uses no LLM, and does not modify the mechanistic engine,
importers, scoring, Firebase rules, or UI. It introduces no patient, subject, or
encounter semantics and no clinical-care workflow. It carries no
clinical-validation claim and is not clinically calibrated.

## 3. Relationship to `public:preflight`

| Aspect | `public:preflight` | `privacy:preflight` (this) |
| --- | --- | --- |
| Primary focus | Banned medical-advice copy, public-demo boundary | Secrets, PHI-like data, local paths, raw exports, narratives |
| Authority | Authoritative release gate | Complementary, stricter local check |
| Scope | Repo docs/config per its own rules | git-tracked (publishable) files |
| Relationship | Unchanged | Runs in addition; does not replace |

Both should pass before publishing. This tool never weakens or alters the public
preflight's behavior.

## 4. Rule families

| Family | Name | What it detects |
| --- | --- | --- |
| A | Secrets | Private keys, service-account fields (`client_email`/`private_key_id`), bearer/OAuth tokens, password/api-key/secret assignments with concrete values, DB URLs with embedded credentials, Google API keys |
| B | PHI-like fields | Strong keys (`patient_name`, `mrn`, `date_of_birth`, `symptom_log`, `medication_schedule`, `clinician_note`, `medical_record`, …) and weak keys (`subject`, `encounter`, `diagnosis`, `treatment`, `dob`, `phone`, `email`, `address`) with concrete values |
| C | Local paths | Absolute local machine paths (`/Users/<name>/`, `/home/<name>/`, `C:\Users\`, `Desktop`/`Downloads`/`Documents`) |
| D | Raw private exports | Filenames suggesting raw/private dumps or operator logs (`*_export.json`, `firestore_export.*`, `operator_log*`, `patient-dump*`, …) |
| E | Health narratives | Phrases that read like a real patient story (e.g. "my patient", "diagnosed with", "real medication schedule") |
| F | Generated/local dirs | Presence of `build/`, `.dart_tool/`, `coverage/`, `node_modules/`, `.firebase/` (should not be published) |
| G | Firebase public config | Google Web API key inside a **known public client config** path (expected, allowlisted) |
| H | Safety-policy allowlist | Known safe policy/provenance values (e.g. `synthetic_demo_only`, `not_clinically_calibrated`) that must never be flagged |

> Detector definitions are written value-/filename-shaped, and this tool's own
> source, tests, doc, and sibling secret scanners are skipped (a linter does not
> lint its own rules) so the scanner does not flag its own patterns.

## 5. Severity model

- **BLOCKER** (fails the gate, exit non-zero): private keys, service-account
  credentials, bearer/OAuth tokens, concrete password/api-key/secret values,
  DB URLs with real embedded credentials, API-key-like values **outside** the
  known Firebase client config, concrete PHI-like values in non-synthetic
  context, raw private export filenames, and real-health narratives in
  fixture/sample data.
- **WARN** (surfaced, does not fail): Firebase Web API key in a known public
  client config, generated/local directory present, weak PHI-like field names,
  schema-like names, API-key-like values inside generated output.
- **INFO** (informational): docs/guidance that legitimately *mention* a phrase
  while warning against it, local-path examples in docs, fixture/placeholder
  credentials (e.g. `localhost`, `user:pass@`), and synthetic/policy values.

`--strict` escalates every **WARN** to **BLOCKER**.

## 6. Allowlists

- **Known public Firebase client config paths** — `lib/firebase_options.dart`,
  `android/app/google-services.json`,
  `ios/Runner/GoogleService-Info.plist`,
  `macos/Runner/GoogleService-Info.plist`. A Web API key here is expected public
  client config and stays **WARN**, never BLOCKER.
- **Safety-policy values** — values such as `no_patient_no_subject_no_encounter`,
  `subject_omitted_no_phi`, `not_clinically_calibrated`, and `synthetic_demo_only`
  are never treated as a BLOCKER. Synthetic markers (`synthetic`, `demo`,
  `example`, `sample`, `fake`, `placeholder`, `omitted`, `redacted`, …) downgrade
  PHI/secret findings to WARN/skip.
- **Generated/local dirs** — reported as WARN, never block.

## 7. Scan scope

The CLI enumerates files with `git ls-files -z`, so it scans only **tracked**
files — the files that would actually be published. Gitignored local artifacts
(e.g. `android/local.properties`, Flutter ephemeral export scripts) are out of
scope by design. If git is unavailable, it falls back to a working-tree walk
that skips `.git`, `node_modules`, and generated directories. Binary/non-text
files and files larger than 1 MiB are skipped with a recorded reason.

## 8. Outputs

Deterministic reports are written under `build/local_privacy_preflight/`:

- `latest.json` — `report_type: local_privacy_preflight`, scanned/skipped
  counts, severity counts, `pass`, the findings list, limitations, the safety
  boundary, the not-advice text, and `not_clinically_calibrated: true`.
- `latest.md` — a human-readable summary table plus limitations and the safety
  boundary.

JSON keys carry no patient/subject/encounter semantics; the report is
key-level no-PHI by construction (verified in tests).

## 9. How to run

```
# via npm wrapper
npm run privacy:preflight

# directly
dart run tool/run_local_privacy_preflight.dart

# strict mode (WARN → BLOCKER)
dart run tool/run_local_privacy_preflight.dart --strict
```

Exit code is `0` when there are zero BLOCKER findings, non-zero otherwise.
BLOCKER lines are also echoed to stderr for quick triage.

## 10. Interpreting findings

1. **BLOCKER** — stop and remove/redact the matched content before publishing.
   If it is a genuine false positive, prefer a clearly synthetic value or a
   placeholder so the allowlist applies; do not weaken the detector.
2. **WARN** — review. Firebase web config and generated dirs are expected; weak
   PHI-like names may just be schema labels.
3. **INFO** — usually informational (docs, fixtures, localhost endpoints).

Findings include a `suggested_fix` and, when allowlisted, an `allowlist_reason`.

## 11. Limitations

- Repo-hygiene / privacy-risk scanning only; **not** HIPAA/GDPR/PIPEDA
  compliance, **not** a legal certification, **not** clinical validation, and it
  **does not prove the app is secure**.
- Pattern-based and conservative; it may miss novel secret or PHI shapes. A clean
  result must not be read as a guarantee of safety.
- Scans only tracked text files under the size limit; binary blobs and untracked
  local files are out of scope.

## 12. Test coverage

`test/local_privacy_preflight_test.dart` uses in-memory fixtures only (it never
scans the whole repo). It covers each rule family, the severity model, the
Firebase and safety-policy allowlists (which must never produce a BLOCKER), the
docs/fixture severity split, negated narratives, `--strict` escalation,
deterministic JSON encoding, the key-level no-PHI shape, and that a clean target
passes.

## 13. Extending the scanner

The scanner (`lib/domain/usecases/local_privacy_preflight.dart`) is pure: it
takes injectable `LocalPrivacyScanTarget`s and a `LocalPrivacyPreflightConfig`
and returns a `LocalPrivacyPreflightReport`. File I/O lives only in
`tool/run_local_privacy_preflight.dart`. To add a detector, add a
value-/filename-shaped pattern, choose a severity per Section 5, add an
allowlist path if it would self-match, and add an in-memory fixture test. Keep
all wording non-clinical and scanner-safe.

## 14. Non-clinical statement

ParkinSUM Companion is an educational and research prototype. This preflight does
not provide diagnosis, treatment, medication timing, dosing, dietary, or clinical
guidance, and it adds no patient-care workflow. It is not clinically calibrated
and carries no clinical-validation claim. Any future real-world health use would
require a separate intended-use statement and qualified professional, privacy,
security, and regulatory review.
