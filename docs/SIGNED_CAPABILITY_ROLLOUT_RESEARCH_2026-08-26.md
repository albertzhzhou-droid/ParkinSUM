# Signed capability rollout: implemented boundary and remaining research

## Purpose

This subsystem can conservatively enable or disable a closed set of optional
engineering capabilities without allowing a remote document to change a
clinical-algorithm formula, parameter, applicability rule, evidence statement,
or safety message. It is release-safety infrastructure, not a clinical feature
and not evidence that any scientific model is valid.

## Implemented worktree contract

- `parkinsum.signed-capability-manifest/1` is an exact-key, size-bounded,
  canonical JSON contract. It permits only three global booleans:
  `local_ai_reranking`, `external_catalog_refresh`, and
  `off_device_operational_telemetry`. There is no evaluation context and no
  user, account, medication, meal, health-state, cohort, or pseudonym target.
- An envelope carries a canonical base64url Ed25519 signature and key ID.
  Verification uses the lockfile-pinned Dart
  [`cryptography`](https://pub.dev/packages/cryptography) implementation.
- Local policy matches issuer, environment, key ID, 32-byte public key,
  revocation set, allowed capability set, lifetime, expiry, and clock skew.
  Unknown fields, future schemas, malformed values, bad signatures, wrong
  environment, revoked or unknown keys, excessive lifetime, expiry, replay,
  downgrade, broken predecessor chains, unsafe key transitions, or invented
  rollback targets fail closed.
- `parkinsum.capability-activation-state/2` persists one verified
  last-known-good envelope plus bounded exact history. A candidate becomes
  active only after write and exact read-back. A write that committed and then
  lost its acknowledgement is recovered; a failed or mismatching write retains
  the prior state. Process-wide scope serialization prevents concurrent genesis
  overwrite. Version 2 also binds an accepted distribution endpoint, exact-body
  SHA-256 strong ETag, active-manifest digest, and UTC acceptance time in the
  same transaction. Version 1 remains readable without a validator and migrates
  only after a newly fetched candidate verifies and survives durable read-back.
- Emergency manifests may disable but cannot newly enable a capability.
  Rollback must name a verified historical sequence and digest and reproduce
  that historical capability map exactly.
- Settings exposes signature, source, environment, expiry, reason, rollback,
  capability decisions, history count, local clear, reload, and verify/activate
  controls. Pasted manifests are not uploaded. An optional distribution client
  can fetch from one exact build-allowlisted, public-DNS, dedicated cross-origin
  HTTPS endpoint. It rejects user info, query strings, fragments, non-443
  ports, redirects, non-JSON content, malformed UTF-8, responses over 64 KiB,
  total-budget timeouts, and any response whose strong ETag is not the quoted
  SHA-256 of the exact response bytes. Conditional `If-None-Match` reuse accepts
  `304` only for the client's previously accepted ETag; every fetched candidate
  still passes the complete local signed-manifest verifier before activation.
  A transport-valid but signature-invalid body never commits its ETag. Restart
  restores a validator only when the persisted active manifest is still valid
  and the exact configured endpoint is unchanged; local clear removes both.
  Network fetches are serialized separately from short state mutations. Clear
  or explicit manual activation advances a local generation immediately, so a
  previously started download cannot reactivate after an emergency clear.
- When a production trust root is configured, the Local AI adapter checks the
  signed decision before consent evaluation or any loopback probe. With no
  trust root, remote policy is inactive; the pre-existing separately consented
  local-only workflow remains governed by local settings rather than being
  mislabeled as remotely managed.

## Build-time public trust configuration

The app reads these compile-time values:

| Define | Meaning |
|---|---|
| `PARKINSUM_CAPABILITY_ENVIRONMENT` | Exact manifest environment; defaults to `development`. |
| `PARKINSUM_CAPABILITY_ISSUER` | Exact trusted issuer; defaults to `parkinsum-release`. |
| `PARKINSUM_CAPABILITY_KEY_ID` | Trusted Ed25519 public-key identifier. |
| `PARKINSUM_CAPABILITY_PUBLIC_KEY_BASE64URL` | Canonical base64url 32-byte Ed25519 public key. |
| `PARKINSUM_CAPABILITY_REVOKED_KEY_IDS` | Comma-separated locally revoked key IDs. |
| `PARKINSUM_CAPABILITY_MANIFEST_URL` | Optional exact HTTPS manifest URL; empty keeps network retrieval disabled. |
| `PARKINSUM_CAPABILITY_MANIFEST_ALLOWED_HOSTS` | Exactly one public DNS host, which must equal the URL host. |

Missing or malformed key configuration creates an unconfigured verifier and
conservative managed decisions. Private keys must never be supplied through
build defines, committed to source, embedded in an app, copied into fixtures,
or printed in logs. Signing is intentionally outside this repository.

## Research basis and non-conformance boundary

The [OpenFeature evaluation specification](https://openfeature.dev/specification/sections/flag-evaluation/)
supports typed defaults and non-throwing abnormal evaluation. ParkinSUM uses a
stricter global-only contract and does not implement an OpenFeature provider.

[The Update Framework specification](https://theupdateframework.github.io/specification/latest/)
motivates rollback, freeze, expiry, trusted-root, and key-lifecycle defenses.
This subsystem is not a TUF client, does not publish TUF metadata, and makes no
TUF conformance claim. The strict byte length and content-digest ETag checks are
an implementation inference from TUF's length/hash and consistent-snapshot
defenses, not a substitute for TUF metadata. [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html)
defines HTTP validator, conditional request, redirect, and representation
semantics used by the transport client. [RFC 9111](https://www.rfc-editor.org/rfc/rfc9111.html)
requires validators to be associated with a stored response and describes when
a matching strong validator may freshen it after `304`; ParkinSUM adds the
stricter signed-activation transaction before treating a response as stored.
NIST's
[Secure Software Development Framework](https://csrc.nist.gov/pubs/sp/800/218/final)
is lifecycle guidance; it is not certification of this implementation.

## Remaining blockers before production acceptance

1. Define reviewed offline-root and scoped online-signer custody, authorization,
   rotation, revocation, threshold, recovery, and destruction procedures.
2. Build and audit the production publication service and endpoint. The client
   path exists, but there is no production endpoint, immutable publication
   pipeline, multi-region consistency proof, server audit trail, availability
   exercise, or target-browser/CDN/service-worker verification of intermediary
   cache behavior and a cookie-free dedicated cross-origin endpoint. Request code
   adds no account, health-body, or authorization fields, but normal browser and
   network metadata and Cookie behavior remain target-environment concerns.
3. Exercise power loss, process kill, storage corruption, reinstall, clock
   change, offline expiry, and emergency recovery on every supported platform.
4. Wire external-catalog refresh and off-device telemetry consumers only after
   their separate consent, privacy, source, residency, retention, and deletion
   gates pass. Their current managed decisions do not create those features.
5. Add append-only key transparency, consistency or witness checking,
   split-view detection, signed revocation publication, and a
   compromised-signer drill. These remain a separate upgrade-queue item.
6. Obtain independent security review. A valid signature proves only a byte/key
   relation; it does not prove signer intent, key custody, privacy, scientific
   validity, clinical safety, regulatory acceptance, or successful recovery.
