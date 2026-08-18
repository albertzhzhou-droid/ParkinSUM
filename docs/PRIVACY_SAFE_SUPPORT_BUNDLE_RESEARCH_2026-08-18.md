# Privacy-safe technical support bundle research

Date reviewed: 2026-08-18

## Decision

ParkinSUM should not export its local debug output, exception objects, stack
traces, application paths, backend endpoints, or user records as a support
artifact. The implemented schema-v1 support bundle is instead assembled from a
closed allowlist of non-user technical facts:

- app and deterministic-algorithm build identity;
- coarse platform capability statements;
- stable diagnostic check IDs, states, and bounded counts; and
- governance and catalog inventory counts.

The bundle is generated only after the user selects its sections. The exact
JSON is shown before any delivery action and remains local unless the user
explicitly chooses Copy or Save / Download. No upload or issue creation exists.

## Source findings and transfer limits

### OWASP logging guidance

The [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)
distinguishes operational and security logs and says that access tokens,
passwords, encryption keys, sensitive personal data, database connection
strings, and higher-classification data should not be recorded directly. It
also identifies file paths and internal network names as values that may need
special handling. ParkinSUM applies the stricter rule: these fields are absent
from the support-bundle type system rather than collected and redacted later.

This source is general logging guidance. It does not certify the ParkinSUM
implementation, determine a lawful basis, or prove that a generated artifact
cannot be identifying when combined with external information.

### Signal debug-log pattern

Signal's [bug-reporting guidance](https://github.com/signalapp/Signal-Android/wiki/Submitting-useful-bug-reports)
asks users to capture a debug log after reproducing a problem and states that
its in-app debug logs are stripped of personal information while retaining the
last two digits of phone numbers for correlation. ParkinSUM adopts only the
user-initiated review pattern. It does **not** copy Signal's upload flow,
partial-identifier strategy, log contents, source code, or claim that an
arbitrary raw log can be made safe by scrubbing.

### Firefox troubleshooting-information pattern

Firefox exposes an `about:support` page with human-readable and raw-JSON copy
actions. Mozilla's [support documentation](https://support.mozilla.org/en-US/kb/use-troubleshooting-information-page-fix-firefox)
notes that the copied version omits the profile-directory line for privacy.
ParkinSUM adopts the exact-preview and explicit-copy pattern, but its schema is
much narrower: it does not expose extensions, environment variables, profile
directories, preferences, graphics identifiers, crash reports, or raw system
inventory.

### GitHub issue forms

[GitHub issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
provide structured inputs, validations, dropdowns, and checkboxes, then convert
responses into a public issue body. That is useful for a future support-case
workflow but is not safe to invoke automatically: user-entered problem text,
screenshots, and copied logs may contain health or account information, and a
public issue is an off-device disclosure. The current implementation therefore
stops at a local artifact.

### Build-information dependency boundary

The current [`package_info_plus` requirements](https://pub.dev/packages/package_info_plus)
list Android Gradle Plugin 8.12.1 or newer for the latest package line, while
this worktree is still on Android Gradle Plugin 8.11.1. This slice therefore
does not add that dependency or weaken Android build validation. App name and
version come from checked-in defaults that are mechanically compared with
`pubspec.yaml`, with optional Flutter build-name, build-number, and 64-hex
build-digest defines overriding them at compile time. Until a signed artifact
attestation supplies and independently verifies the digest, the field remains
the explicit `unavailable` sentinel; it is never fabricated from the dirty
worktree or current HEAD.

## Architecture

```text
deterministic checks + build constants + coarse platform capabilities
                              |
                              v
                  closed-schema snapshot service
                    (raw exceptions discarded)
                              |
                              v
           section selection + account/source revision lease
                              |
                              v
       exact-key validation -> budgets -> privacy-pattern scan
                              |
                              v
             exact local JSON preview + SHA-256 identity
                              |
                  user explicitly chooses action
                              |
                   Copy or conservative Save
```

The account identifier is used only to decide whether an in-flight operation
is still authorized. It is never passed to the domain artifact. Recollection
before Copy or Save must produce the same source-revision digest; otherwise the
preview is destroyed and no side effect occurs.

## Failure and privacy boundaries

- Diagnostic exceptions become an `*_unavailable` code; exception text and
  stack data are discarded.
- Unavailable counts are `null`, never fabricated zero.
- The envelope has exact keys and schema version 1. Unknown fields cannot be
  introduced through the public service inputs.
- UTF-8 byte, node, collection-width, string, numeric, and generation-time
  budgets are checked before an artifact is returned.
- Email-, URL-, bearer-token-, and common absolute-path patterns fail the final
  privacy scan.
- Desktop delivery never creates, overwrites, or deletes a path through the
  current portable sink. It can only recognize an already-existing
  byte-identical file; otherwise the UI offers the explicitly authorized Copy
  fallback. Web requests a browser download and does not claim durable save.
- A checksum detects change; it is not encryption, authentication, anonymity,
  provenance authority, or proof of who created the artifact.

## Deliberately excluded

- user profile, health records, meals, intakes, medication or reminder data;
- UID, email, patient ID, device ID, stable account pseudonym, or IP address;
- activation tokens, credentials, project IDs, endpoints, or source URLs;
- raw exception strings, stack traces, paths, logs, telemetry, or crash dumps;
- automatic upload, email attachment, GitHub issue creation, or background
  collection.

## Residual work

1. The app has no signed release attestation tying the bundle's reported build
   identity to an independently verifiable distributed artifact.
2. The bundle reports direct app/build and selected governance identities, not
   a complete SBOM or operating-system inventory.
3. Copy and browser download require physical-device and assistive-technology
   journeys; a browser download request is not durable-save proof.
4. Chinese and English copy is reviewed locally. Other shipped locale families
   currently use the existing English fallback for this new surface.
5. There is no user-controlled reproduction recorder or support-case workflow.
   Any future issue integration must keep user-authored free text separate from
   the privacy-safe machine bundle and require a second exact preview before an
   off-device disclosure.
