# Account Security Lifecycle Research — 2026-08-17

## Scope and product boundary

This review covers the registered-user account surface in the current
ParkinSUM Flutter worktree. It does not claim that the app, Firebase project,
or deployment has achieved a particular authentication assurance level. It
separates client-deliverable password UX from identity-provider configuration,
provider linking, account recovery, and phishing-resistant authentication.

## Current implementation decision

Password-linked Firebase users can now change a password only after entering
their current password. The implementation creates a fresh email credential,
calls `reauthenticateWithCredential`, and only then calls `updatePassword`.
Provider exceptions are mapped to bounded, localized user messages; passwords
are not logged, persisted, trimmed, or interpolated into errors. Local-only
accounts continue to report password workflows as unsupported.

The client applies a 15-code-point minimum to newly selected passwords. It
allows spaces and Unicode, imposes no upper/lowercase, number, or symbol rule,
supports paste/autofill, and includes a show-password control. The identity
provider remains authoritative and may reject a value under its configured
policy.

## Evidence mapping

| Evidence | Supported decision | Important limit |
| --- | --- | --- |
| [Firebase: manage users](https://firebase.google.com/docs/auth/flutter/manage-users) | Password changes are sensitive operations; `updatePassword` requires recent sign-in and `reauthenticateWithCredential` supplies fresh proof. `providerData` exposes linked provider IDs. | Documentation describes SDK behavior, not this project's Firebase console policy or production deployment. |
| [Firebase: link multiple providers](https://firebase.google.com/docs/auth/flutter/account-linking) | `linkWithCredential` can keep the same Firebase UID and data, while `provider-already-linked`, `invalid-credential`, and `credential-already-in-use` need explicit recovery paths. | Linking and data-merge policy are not implemented in this slice. |
| [Firebase: authentication errors](https://firebase.google.com/docs/auth/flutter/errors) | `account-exists-with-different-credential` requires signing into the existing provider and then linking the pending credential. | A safe merge cannot be inferred from email equality and must not be improvised client-side. |
| [Firebase: Flutter MFA](https://firebase.google.com/docs/auth/flutter/multi-factor) | Flutter SMS MFA requires Firebase Authentication with Identity Platform, verified email, reauthentication for enrollment, and recovery planning with more than one factor. | Firebase's own current guide says to avoid SMS MFA because it is insecure and easy to compromise or spoof. SMS is therefore not treated as the target strong factor. |
| [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html) | Single-factor passwords require at least 15 characters; systems should allow at least 64, spaces, Unicode code-point counting, password managers, paste, and a display option, without composition or periodic-rotation rules. Prospective passwords should be checked against a compromised/common blocklist. | The local minimum and UX do not constitute verifier compliance. Firebase/server policy, blocklist behavior, throttling, protected transport, storage, and audit controls remain outside this client proof. |
| [NIST password customer experience](https://pages.nist.gov/800-63-4/sp800-63b/customer/) | Requirements and rejection feedback should be clear and actionable; long passphrases and password managers should be supported. | Usability guidance does not establish security effectiveness for this deployment. |

## Why SMS MFA was not enabled

The current Firebase Flutter guide both exposes SMS MFA and explicitly warns
against using it. NIST also states that passwords are not phishing-resistant
and that authenticators requiring manual entry of an output, including OTP,
are not phishing-resistant because the output is not bound to the intended
verifier session. Enabling SMS solely because an SDK path exists would create a
misleading “strong authentication” claim.

The upgrade queue therefore requires a separate authenticator decision covering
WebAuthn/passkey-capable provider support, verifier-name binding, replay
resistance, supported platforms, device loss, multiple authenticators, and
recovery. No passkey capability is claimed by the current app.

## Remaining validation and external dependencies

- Exercise Firebase Auth Emulator and staging-project tests for reauthentication,
  wrong-password throttling, expired sessions, weak-password policy, and
  password-provider absence.
- Configure and verify the provider-side password policy and common/compromised
  password blocklist behavior; do not duplicate a breach corpus in the client.
- Design provider linking and collision recovery without changing UID ownership
  or silently merging clinical records.
- Select and validate a phishing-resistant authenticator across web, iOS,
  Android, and Windows, including device-loss recovery and accessible fallback.
- Protect account deletion and export with recent-login proof and server-side
  audit evidence before exposing either action.
