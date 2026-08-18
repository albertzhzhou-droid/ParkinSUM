# Device-bound secret storage, migration, and rotation research

Reviewed: 2026-08-18

## Decision

ParkinSUM now moves the local portable-package owner capability out of raw
SharedPreferences and into a versioned platform-protected store. This is a
bounded first secret: it does not imply that every local health record is
encrypted, that the user has authenticated, that secure deletion is proven, or
that any key is hardware-backed.

The implementation uses `flutter_secure_storage` 10.3.1 because one reviewed
adapter exposes Apple Keychain, Android Keystore-wrapped encrypted storage,
WebCrypto, Windows DPAPI, and Linux Secret Service while preserving one Dart
contract. Platform differences remain explicit in the capability object and UI
rather than being flattened into a generic “secure” label.

## Primary-source evidence map

| Source | Bounded use in this work | Limit retained |
|---|---|---|
| [Apple Keychain accessibility](https://developer.apple.com/documentation/security/ksecattraccessible) and [restricting Keychain accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) | Select a non-synchronizing ThisDeviceOnly accessibility class and report that policy. | Source configuration is not a physical-device access or migration result and does not prove Secure Enclave use. |
| [Android Keystore](https://developer.android.com/privacy-and-security/keystore) | Treat the package's Android envelope as Keystore-protected and deny backup/device transfer at the app manifest boundary. | Hardware-backed status varies by device and must not be inferred from the API. |
| [Android key attestation](https://developer.android.com/privacy-and-security/security-key-attestation) | Defines the future evidence needed before a hardware security-level label can be recorded. | No attestation chain is collected or validated in the current worktree. |
| [NIST SP 800-57 Part 1 Rev. 5](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final) | Motivates explicit key/capability lifecycle, inventory, compromise, rotation, recovery, and destruction boundaries. | This implementation is not a NIST conformance or cryptographic-module validation claim. |
| [NIST SP 800-38D](https://csrc.nist.gov/pubs/sp/800/38/d/final) | Supports the future requirement for authenticated record encryption and unique nonces. | The current slice stores one random capability; it does not introduce an application-defined record cipher. |
| [`flutter_secure_storage` 10.3.1](https://pub.dev/packages/flutter_secure_storage) | Supplies the reviewed cross-platform adapter and explicit platform options. | Package documentation and tests do not replace app-specific target-device drills or recovery design. |

## Implemented contract

- `ProtectedSecretStore` separates read/write/delete mechanics from an honest
  `ProtectedSecretStoreCapability` statement.
- Apple uses `unlocked_this_device`, non-synchronizing Data Protection Keychain
  configuration; Android uses an isolated namespace, disables backup migration
  and silent reset-on-error, and requires API 23+; Web states the HTTPS or
  localhost secure-context boundary; Windows and Linux name their actual
  package adapters.
- Every capability label sets `isHardwareBackedVerified: false`. A future
  attestation result must be runtime evidence, not a rename of an API.
- Local portable-owner schema v2 derives only a one-way lookup key from the
  local account scope. The stored schema-v1 envelope has exact keys, purpose,
  status, lookup digest, random secret, random key id, revision, UTC lifecycle
  timestamps, and protection-class binding.
- Creation, migration, rotation, and revocation are serialized per protected
  key. Writes and deletes are read back. A thrown write after durable success
  is treated as acknowledgement loss; a dropped write fails. Corrupt,
  conflicting, future-shaped, or protection-class-mismatched state never causes
  silent identity regeneration.
- The UI shows protection class and revision. Local rotation requires explicit
  confirmation that prior packages will no longer validate, rechecks the
  account lease, and clears generated/pasted/preview state after success.
- Critical-flow logs contain operation class, revision, and protection class,
  but never account scope, secret, key id, or raw platform exception.

## Verification implemented

Automated tests cover concurrent first creation, v1 migration and cleanup,
malformed and conflicting state, write acknowledgement loss, dropped write,
rotation, revocation, cross-account isolation, Firebase non-secret passthrough,
hardware-claim denial, visible protection metadata, and rotation-driven UI
clearing. The schema catalog records the v2 boundary, protected envelope, and
protected-store contract. The store-privacy gate pins the direct dependency,
lock identity, data flow, and `flutter_secure_storage_darwin` manifest bytes and
facts.

Build evidence is deliberately narrower than runtime evidence. Android debug,
iOS simulator, local Web, Firebase-mode Web, and an unsigned macOS Release
compile completed in this worktree. The normal signed macOS Release build could
not resolve a development signing certificate after enabling the Keychain
entitlement. The unsigned app therefore proves compilation only; it does not
prove a distributable signature, signed entitlements, or Keychain behavior on a
target Mac.

## Open boundaries

- There is no complete generated inventory of every credential, notification
  capability, consent record, encryption key, recovery secret, or secret-like
  value. Reminder plans remain business records and must not be split from
  their atomic persistence contract merely to move one field.
- Critical health records are not yet application-level authenticated encrypted
  envelopes. A separate queued design covers owner/schema/key/revision AAD,
  nonce uniqueness, atomic re-encryption, corruption, and recovery.
- Verified account deletion does not yet invoke revocation, and the local
  account has no recent-authentication gate for rotation. Rotation is therefore
  a local capability lifecycle control, not identity proof.
- Reinstall, app-data clearing, browser-origin change, backup/restore, OS
  upgrade, lock state, passcode/biometry change, Keystore invalidation, and real
  Windows/Linux adapters have no target-device evidence. Those states must be
  shown as unavailable or recovery-required rather than regenerated silently.
- Apple source entitlements are pinned, but signed distribution entitlements
  remain unverified until a provisioned macOS/iOS artifact is inspected and run
  on target devices. The current unsigned macOS artifact is not that evidence.
- The Web adapter depends on browser profile/origin behavior and does not make
  a cross-browser or cross-device durability claim. Linux depends on an
  available unlocked Secret Service implementation. Windows DPAPI is bound to
  the user profile rather than proven device hardware.
