# Configuration-completeness witness review authority lifecycle

Status: research design only  
Date: 2026-09-02  
Scope: authorization of a specific, deterministic algorithm-configuration completeness witness

## Decision summary

ParkinSUM should keep three independently verifiable layers. A deterministic completeness witness answers **what configuration, implementation sources, dependencies, provenance fields, and result sinks were covered**. A DSSE authorization answers **which trusted reviewers authorized those exact witness bytes, for which declared scope and time window**. A versioned trust/status ledger answers **which keys and roles were trusted, rotated, expired, or revoked when the authorization was evaluated**.

None of the three layers proves that an algorithm is scientifically correct, clinically valid, safe for an individual, or suitable for patient care. A passing result is only `valid_for_declared_configuration_scope` under a named review policy.

## Threats this design must close

The current checked-in completeness witnesses are useful deterministic evidence, but their `reviewedAt` metadata is not an independent authorization. Without a separate authority lifecycle, a proposer could reuse one key under several role labels, replay a superseded authorization, rely on an expired or revoked key, hide a witness revocation, or roll a client back to an older trust policy. A signature can also verify while the application consumes bytes different from those that were verified.

The design therefore treats every unknown schema, role, key, policy version, time state, predecessor, or digest mismatch as a HOLD. It retains the rejected evidence and reason; it does not rewrite history into a passing state.

## Layer 1: deterministic completeness witness

The completeness witness remains a content-derived artifact. For the same canonical inputs it must produce byte-identical canonical bytes and the same digest, without a signing key, network call, or wall-clock read.

Its declared scope should bind at least:

- witness schema and generator version;
- algorithm ID and configuration-scope ID;
- canonical configuration digest and registered implementation source-bundle digest;
- exact parameter/provenance field IDs and their source-record identities;
- field-to-result-sink mappings and the complete required result-sink set;
- transitive result-affecting dependency identities and digests;
- explicit exclusions and limitations.

The witness digest is an object of authorization, not authorization itself. A display timestamp, author name, or checked-in location must not change this distinction. Any field, sink, dependency, source, generator, or canonicalization change produces a different witness digest and requires a new authorization.

## Layer 2: DSSE exact-bytes authorization

The authorization should use an application-specific payload type and a DSSE envelope. DSSE signs the pre-authentication encoding of the payload type and serialized body. The verifier must pass the same verified serialized bytes to the parser and application layer; reparsing a different envelope representation is forbidden. DSSE also defines threshold verification in terms of unique trusted public keys. Its `keyid` is unauthenticated and is only a lookup hint, never a trust decision. See the pinned [DSSE protocol v1.0.2](https://github.com/secure-systems-lab/dsse/blob/v1.0.2/protocol.md).

The signed payload should be a versioned in-toto Statement whose subject digest is the deterministic witness digest and whose application-specific predicate binds:

```text
authorizationSchema
witnessDigest
algorithmId
configurationScopeDigest
policyDigest
statusLedgerVersion
authorizationSerial
issuedAt
notBefore
expiresAt
declaredReviewerRole
reviewerIdentityDigest
limitations
```

`issuedAt`, `notBefore`, and `expiresAt` are signed fields. The verifier evaluates them against trusted time evidence; a local clock with unknown integrity cannot authorize use. The payload has one canonical byte representation, bounded size, and an exact media type. Unknown fields or schema versions fail closed until explicitly migrated.

The in-toto [Statement v1.2](https://github.com/in-toto/attestation/blob/v1.2.0/spec/v1/statement.md) supplies the subject-plus-predicate separation, while the [Envelope guidance v1.2](https://github.com/in-toto/attestation/blob/v1.2.0/spec/v1/envelope.md) records the DSSE transport pattern. These formats provide structure, not ParkinSUM review authority; the policy and trusted keys remain application-owned.

## Layer 3: versioned trust and status ledger

The trust policy and status ledger are separately versioned, content-addressed, and signed. They define a closed role vocabulary, reviewer identities, trusted public-key bytes and algorithms, role membership, distinct-key thresholds, validity periods, predecessor digests, witness revocations, key revocations, and root rotations. Private production keys must never be committed to the repository or embedded in an app artifact.

Every required reviewer role must be satisfied by a different reviewer identity and a different trusted public key. Repeating one signature, one public-key byte sequence, one reviewer under aliases, or one key across several role labels counts once and cannot satisfy the threshold. The proposal author and algorithm owner do not count as independent reviewers. Scientific review and release-governance review remain separate roles; neither role inherits the other.

Trust is established from a pinned or independently distributed root. Root rotation follows the TUF update pattern: the next sequential root version must satisfy the threshold of the currently trusted old root and the threshold of the proposed new root before it replaces local trust. Skipped versions, predecessor mismatch, threshold loss, expired metadata, freeze, fast-forward, or rollback are HOLD states. See the pinned [TUF specification v1.0.32](https://theupdateframework.github.io/specification/v1.0.32/).

Witness and key revocations are append-only status events. Each event binds its schema, monotonically increasing sequence, predecessor digest, target witness or exact public-key digest, reason code, effective time, issuer role, and authorization envelope. Revocation never deletes the original witness, authorization, or historical decision. A replacement witness or key starts a new independently authorized lineage; it does not renew or inherit the old authorization automatically.

An append-only Merkle log can provide inclusion and consistency evidence for ledger views. The design may adapt the proof semantics in [RFC 9162](https://www.rfc-editor.org/rfc/rfc9162.html), but a Certificate Transparency proof is not by itself a ParkinSUM trust decision and does not prevent every split view without independent checkpoint comparison.

## Evaluation order and fail-closed states

Evaluation is deterministic for a supplied witness, envelopes, policy snapshot, ledger snapshot, trusted-time evidence, and retained local high-water marks:

1. Parse bounded, supported schemas and canonical bytes.
2. Recompute the witness digest and declared configuration scope.
3. Verify DSSE over the exact bytes delivered to the application.
4. Resolve candidate keys from the trusted policy; use `keyid` only to narrow attempts.
5. Enforce different-reviewer and different-key role thresholds.
6. Validate policy/ledger signatures, sequential versions, predecessor chain, and locally retained high-water marks.
7. Apply key and witness revocations effective at the decision time.
8. Validate `notBefore` and `expiresAt` using trusted time evidence.
9. Recompute current configuration, source, dependency, and witness digests.

Any failure stops before a reviewed/eligible claim is emitted. The Algorithm Observatory should expose one of these machine-stable states, plus actionable detail:

| UI state | Meaning and action |
| --- | --- |
| `unsigned` | No authorization envelope; HOLD and request review. |
| `signature_invalid` | No signature verifies over the exact payload bytes; HOLD. |
| `policy_unknown` | Policy, role, schema, root, or ledger version is unsupported; HOLD. |
| `threshold_unsatisfied` | Required distinct reviewer/key roles are incomplete; HOLD. |
| `not_yet_valid` | Trusted time precedes signed `notBefore`; HOLD. |
| `expired` | Trusted time is at or after signed `expiresAt`; HOLD and re-review. |
| `witness_revoked` | An effective append-only event revokes the witness; HOLD. |
| `key_revoked` | A required signature uses a key revoked for the decision time; HOLD. |
| `clock_unverified` | Time integrity or uncertainty is insufficient to evaluate validity; HOLD. |
| `stale_configuration` | Current configuration/source/dependency digest differs; HOLD and regenerate. |
| `rollback_detected` | Policy, ledger, root, witness, or authorization precedes a retained high-water mark or has an invalid predecessor; HOLD and recover trust state. |
| `valid_for_declared_configuration_scope` | Exact witness, threshold, lifecycle, time, and current digests pass for the displayed scope only. |

The UI must show the witness, authorization, policy, ledger, and root digests; algorithm and declared scope; accepted reviewers, roles, and distinct key digests; validity window and trusted-time status; revocation/rotation lineage; replacement identity when present; and limitations. It must not collapse a HOLD reason into “not reviewed” or a pass into “validated algorithm.”

## Verification and mutation plan

Implementation should include independently generated fixtures and mutation tests for: changed payload bytes after verification; generic or changed payload type; forged `keyid`; duplicate signatures; one key or reviewer relabelled into several roles; unknown role/key/algorithm/scope; signature and canonicalization failure; boundary instants for all three signed times; missing or uncertain trusted time; expired authorization; witness/key revocation before and after the decision time; stale configuration/source/dependency; predecessor deletion; split view; skipped root; old-only or new-only root rotation signatures; rollback to every retained high-water mark; and attempted automatic renewal/inheritance.

Passing fixtures must be reproducible offline from public keys and synthetic content. Failure fixtures retain the exact rejected artifact and status. Production signing ceremonies, private-key custody, reviewer independence, and recovery drills require evidence outside the repository.

The [SLSA Verification Summary Attestation v1.2](https://slsa.dev/spec/v1.2/verification_summary) is useful as a model for a verifier-authored result bound to a policy and resource, but its own security considerations mean a successful summary is not proof that a resource is risk-free or that a signer remained uncompromised. The [NIST Secure Software Development Framework 1.1](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf) supports protecting artifacts, provenance, roles, and integrity throughout development; it does not supply ParkinSUM scientific or clinical validation.

## Explicit non-claims

This research design does not establish that any current reviewer is independent, any production key is protected, trusted time is available, a transparency service is deployed, or a root-rotation/recovery drill has passed. It also does not establish physiological fidelity, population calibration, clinical utility, regulatory clearance, medical-device status, or safe treatment guidance. Those require separate scientific, clinical, operational, legal, and regulatory evidence.
