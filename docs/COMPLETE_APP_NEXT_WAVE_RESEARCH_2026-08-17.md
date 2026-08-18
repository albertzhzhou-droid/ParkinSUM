# Complete-app next-wave research

Reviewed: 2026-08-18

Status: architecture and queue evidence only

## Boundary

This review identifies missing engineering controls for an educational and
research prototype. It does not establish patient-level accuracy, clinical
benefit, regulatory status, terminology conformance, or store-policy approval.
Only primary or official sources and official project documentation were used.
External implementations are concept references; no upstream code, model, or
data asset is authorized for copying by this review.

## 1. Runtime model applicability and abstention

The production path needs a versioned, machine-enforced applicability manifest
for every result-affecting algorithm. A context-of-use statement in a research
document is not a runtime guard. Unknown release type, route, formulation,
observable, unit, timing domain, or unsupported input should yield an explicit
`notApplicable` result rather than silently choosing a familiar curve and only
widening uncertainty.

The [FDA 2023 final computational-model credibility guidance](https://www.fda.gov/media/154985/download)
separates context of use, model risk, applicability, code verification,
calculation verification, validation, and uncertainty quantification. The
[EMA PBPK reporting guideline](https://www.ema.europa.eu/en/reporting-physiologically-based-pharmacokinetic-pbpk-modelling-simulation-scientific-guideline)
similarly ties qualification to intended use and platform assumptions. These
are governance precedents; ParkinSUM is not a qualified PBPK platform.

Required future control:

- pin observable, claim class, component identity, route/form/release, fed
  state, time and unit bounds, evidence IDs, review state, and manifest digest;
- default-deny missing, unknown, out-of-domain, or digest-mismatched contexts;
- prevent an abstained model from emitting model-driven severity, ranking, or
  recommendation copy;
- show the failed predicates and manifest version in the trace and Observatory;
- require inside, outside, and unknown boundary tests for every provider.

## 2. Independent numerical verification oracle

Tests that call the production implementation can prove invariants and catch
regressions but may reproduce the same wrong equation, sign, scale, or constant.
Each registered result-affecting algorithm therefore needs an independently
written mathematical specification and frozen numerical vectors that do not
import production functions, constants, or generated output.

The FDA guidance defines code verification separately from calculation
verification and empirical validation. An optimizer fit, another model, or a
second copy of the production function is not an independent truth oracle.

Required future control:

- use analytic solutions, manufactured cases, or justified higher-precision
  calculations where possible;
- derive numerical tolerances from the method rather than observed output;
- include unit changes, segmented thresholds, lag signs, release classes,
  extreme inputs, and invalid configuration;
- mutation-test invariant-preserving defects such as minute/hour scaling,
  normalized-but-wrong weights, and reordered terms;
- block release when a registered algorithm lacks an oracle or its oracle
  digest drifts without review;
- label the report as implementation verification, not biological validation.

## 3. Versioned terminology and unit firewall

SMART-on-FHIR transport cannot repair ambiguous local identities or units.
Drug, food-component, and unit normalization must be versioned before a
standard-shaped view can influence an algorithm.

Relevant official boundaries:

- [RxNorm APIs](https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html) expose
  current, active, historical, and version endpoints. The
  [NLM terms](https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html) set request
  and cache expectations and do not grant every RxClass or SNOMED right.
- [UCUM 2.2](https://ucum.org/ucum) supplies machine-comparable units under a
  [specific interoperability license](https://ucum.org/license); a project may
  not silently redefine the standard.
- The [FAO INFOODS tagname page](https://www.fao.org/infoods/infoods/standards-guidelines/food-component-identifiers-tagnames/en/)
  contains dated and separately extended lists, so online presence is not proof
  of a complete current vocabulary.
- [FHIR R5 NutritionIntake](https://fhir.hl7.org/fhir/nutritionintake-definitions.html)
  is Trial Use. Existing ParkinSUM views must remain labelled FHIR-inspired
  until a pinned profile and validator prove conformance.

Required future control:

- store terminology system URI, code, version, display, source revision,
  mapping type, jurisdiction, license state, and ingredient/product/form/route
  equivalence;
- preserve original and canonical UCUM units plus conversion factors;
- keep ambiguous, approximate, stale, dimensionally invalid, or unlicensed
  mappings unmapped and non-result-affecting;
- never turn unknown into zero;
- include terminology versions in exports and the canonical algorithm digest.

## 4. Store privacy-declaration drift gate

Repository privacy text is not evidence that App Store and Play declarations
match the built artifact. The release needs a canonical inventory connecting
dependencies, permissions, entitlements, network destinations, and data fields
to reviewed store declarations.

[Apple required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
requires approved reasons for covered APIs, including use introduced by SDKs.
[Google Play Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469)
places responsibility for app and third-party SDK collection and sharing on the
developer. Both policies are dynamic and must be refreshed for each release.

Required future control:

- generate a versioned privacy-surface inventory from dependencies, merged
  manifests, permissions, entitlements, endpoints, fields, purposes, and
  local/off-device/third-party classification;
- inspect the aggregated Apple archive privacy report and required reasons;
- compare Android artifact facts with a reviewed Data Safety snapshot;
- fail CI on any unclassified SDK, permission, endpoint, or data field;
- require dated human approval and never auto-answer or auto-upload store forms.

## 5. Cross-backend durable mutation protocol

Atomic onboarding does not make ordinary profile, medication, intake, meal, or
reminder CRUD atomic. Each mutation needs one backend-neutral contract carrying
owner, operation ID, expected revision or base digest, schema version, and
payload digest. Durable acknowledgement must precede success UI or in-memory
publication.

Official platform constraints differ:

- Flutter [`shared_preferences`](https://pub.dev/packages/shared_preferences)
  says persistence is asynchronous and unsuitable for critical data; cached
  APIs also have multi-engine/isolate consistency limits.
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
  are atomic and may retry, but fail offline and require side-effect-free
  callbacks.
- [SQLite atomic commit](https://www.sqlite.org/atomiccommit.html) documents
  crash-oriented all-or-nothing behavior.
- [IndexedDB 3](https://www.w3.org/TR/IndexedDB-3/) defines atomic transactions
  and durability hints, but the cited edition is a Working Draft; runtime
  feature detection and browser evidence remain necessary.

Required future control:

- make same-operation retry idempotent and different-revision conflict explicit;
- use transactional storage for critical Web records rather than claiming
  durability from SharedPreferences;
- use Firestore compare-and-set transactions without callback side effects;
- keep business state and success audit history in the same atomic boundary;
- inject read, write, acknowledgement, process-kill, quota, corruption,
  migration, two-tab, and two-device faults across all backends;
- after cold restart, expose only the complete old or complete new state.

## 6. Privacy-preserving operational observability

Production support needs enough evidence to distinguish crashes, startup
failure, backend latency, notification drift, and algorithm abstention without
turning health records into telemetry. Logging more data and hashing a stable
user identifier are not privacy controls by themselves.

The [OpenTelemetry sensitive-data guidance](https://opentelemetry.io/docs/security/handling-sensitive-data/)
places responsibility on the implementer, identifies health and behavior data
as sensitive, recommends data minimization, and warns that hashes over small or
predictable identifier spaces can be reversible in practice. OpenTelemetry is
an architectural reference only; this review does not authorize a telemetry
vendor or off-device collection.

Required future control:

- default to local-only diagnostics and require a separately versioned,
  purpose-bound opt-in before any off-device signal;
- use a machine-readable allowlist for event names, coarse durations, bounded
  counts, release identity, and non-semantic error classes;
- reject medication names, meals, free text, source documents, raw exception
  payloads, email, UID, stable account hashes, notification payloads, and exact
  user timestamps before export;
- enforce cardinality, retention, sampling, regional endpoint, deletion, and
  emergency-disable budgets and test the serialized envelope rather than only
  the logging call site;
- expose what was collected and allow the user to revoke future collection;
  consent to research, support, or reminders never implies telemetry consent.

## 7. Cross-platform performance and energy budgets

Passing widget tests does not show that the registered-user journey is usable
on a low-end physical device. Performance evidence must be captured from a
release or profile build with an explicit device, OS, thermal state, dataset,
and route rather than inferred from debug mode or a simulator.

Flutter's [performance guidance](https://docs.flutter.dev/perf/best-practices)
ties frame work to the display budget and notes battery and thermal effects.
Android's [Macrobenchmark guidance](https://developer.android.com/topic/performance/baselineprofiles/measure-baselineprofile)
warns that emulator measurements can be incorrect and distinguishes time to
initial display from time to full display.

Required future control:

- set reviewed budgets for cold and warm startup, time to usable registered
  state, frame build/raster time, jank, memory peak, package size, network
  bytes, background wakeups, and battery or energy proxy;
- run deterministic large-catalog, long-timeline, locale, text-scale,
  accessibility, offline, and low-memory journeys on representative physical
  Android and iOS devices plus supported desktop and Web targets;
- attach raw machine-readable measurements, device identity, artifact hash,
  run count, variance, and failure class to the release evidence;
- fail on statistically and practically meaningful regressions without
  presenting a single fast development machine as a population guarantee.

## 8. Signed capability rollout and emergency disable

A complete app needs a way to disable a broken optional capability without
shipping an unreviewed algorithm or silently changing a user's scientific
result. A remote flag is executable policy and therefore needs an identity,
schema, signature, expiry, conservative default, and audit trail.

The [OpenFeature evaluation specification](https://openfeature.dev/specification/sections/flag-evaluation/)
is a useful vendor-neutral lifecycle and typed-evaluation reference, including
default values on abnormal execution. ParkinSUM needs stricter health-data and
algorithm boundaries than the generic specification.

Required future control:

- accept only signed, versioned, unexpired manifests whose key, environment,
  capability ID, type, constraints, and rollback target are locally trusted;
- use fail-closed defaults and last-known-good atomic activation; malformed,
  stale, future-schema, partial, wrong-environment, or unverifiable manifests
  cannot enable a capability;
- prohibit PHI, health-state, medication, meal, account, or stable pseudonym
  targeting and record only privacy-safe aggregate rollout evidence;
- allow emergency disable of optional network or UI capabilities, but never
  remotely alter algorithm formulas, parameters, applicability, evidence, or
  safety copy outside the normal reviewed promotion and digest process;
- make current state, source, expiry, reason, and rollback visible to operators
  and test offline, clock-skew, key-rotation, replay, and rollback scenarios.

## 9. Reproducible release SBOM and signed attestation

Dependency lockfiles and a source commit do not prove which dependencies,
toolchain, generated assets, configuration, or artifact bytes reached a
release. Every distributed artifact needs a reproducible evidence envelope
that can be checked independently and offline.

NIST's [Secure Software Development Framework](https://csrc.nist.gov/pubs/sp/800/218/final)
defines high-level secure-development practices for the software lifecycle.
[CycloneDX](https://cyclonedx.org/specification/overview/) defines recognized
BOM media types and an attestation predicate, while
[Sigstore verification guidance](https://docs.sigstore.dev/cosign/verifying/verify/)
shows identity- and digest-bound artifact and attestation verification. These
are candidate standards, not evidence that the current release is signed or
reproducible.

Required future control:

- emit a deterministic CycloneDX or SPDX SBOM for every Web, Android, Apple,
  desktop, npm, and source artifact, including direct/transitive dependencies,
  licenses, generated assets, and build tools;
- bind commit, clean-tree status, source digest, lockfiles, toolchain and SDK
  versions, build defines, schema/configuration identities, test evidence, and
  artifact checksums in a signed provenance statement;
- verify signature identity, issuer, subject digest, environment, required
  claims, SBOM schema, dependency inventory, and vulnerability-policy result;
- provide an offline verification bundle and instructions, exercise key
  rotation and revocation, and fail release when the artifact differs from the
  attested bytes;
- keep signing credentials outside source, logs, build archives, fixtures, and
  public evidence and never treat a valid signature as scientific or clinical
  validation.

## 10. Device-bound secret storage and rotation

Preference storage is not a secret store. Account capability tokens,
encryption material, and other secret-like values need a complete inventory,
an explicit protection policy, and a versioned migration and rotation path.
[Apple Keychain](https://developer.apple.com/documentation/security/storing-keys-in-the-keychain)
and [Android Keystore](https://developer.android.com/privacy-and-security/keystore)
provide different primitives and failure modes; neither API name proves that a
particular key is hardware-backed, recoverable, synchronized, or safe to
export.

Required future control:

- classify every secret-like value by owner, purpose, lifetime, exportability,
  backup behavior, and current storage;
- use reviewed Keychain accessibility/synchronization and a
  Keystore-protected envelope, recording hardware security only when the
  runtime proves it;
- version key IDs and make migration, rotation, revocation, acknowledgement
  loss, invalidation, and rollback explicit and fail closed;
- test reinstall, OS upgrade, lock state, device transfer, account switch, and
  deletion on physical devices without treating secure storage as user
  authentication.

## 11. Platform data protection and implicit backup

An explicit encrypted export is not the same as operating-system backup,
device transfer, or file-at-rest protection. Android documents that backup and
transfer behavior can vary by OS and manufacturer, while Apple exposes data
protection and Keychain policies with different availability and synchronization
semantics.

Relevant official boundaries:

- [Android Auto Backup and device transfer](https://developer.android.com/identity/data/autobackup)
- [Apple complete file protection](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/completefileprotection)
- [Apple platform security](https://developer.apple.com/security/)

Required future control:

- inventory every persisted database, preference, cache, file, log, export,
  and Keychain item and bind it to protection, retention, backup, and transfer
  policy;
- inspect packaged release artifacts, not only source manifests;
- run physical-device backup, restore, transfer, locked-device, reinstall, and
  corrupted-backup drills;
- report vendor-specific or uninspectable behavior as unverified and keep
  explicit user-owned portability as a separate consented workflow.

## 12. Backend location, retention, and residency contract

Firebase service configuration is external state. Firestore documents that a
[database location](https://firebase.google.com/docs/firestore/locations) is
selected at provisioning and cannot later be changed. Account deletion may
also require recent authentication, and deletion of one service record does
not establish full cross-service erasure.

Required future control:

- bind actual project/app IDs, Firestore database and provisioned location,
  Auth domain, configured service regions, environment, and artifact in a
  reviewed manifest;
- enumerate every collection, authentication record, object, log, export, and
  backup with purpose, owner, retention trigger, deletion path, and location;
- query actual service state before enabling production writes and block
  emulator, default-project, stale, or cross-environment identity;
- test expiry, recent-auth failure, partial outage, retries, orphaned records,
  restore, and deletion without converting observed technical location into a
  legal residency or compliance claim.

## Dependency order

```text
parameter provenance + canonical configuration identity
  -> runtime applicability/abstention
  -> independent numerical oracle

terminology + unit firewall
  -> unit-aware event ledger
  -> any standards-conformant exchange sandbox

backend-neutral mutation contract
  -> offline conflict UI
  -> backup/restore and user-owned package import

artifact privacy inventory
  -> reviewed store declarations
  -> signed release evidence

privacy-safe observability schema
  -> release telemetry envelope tests
  -> production support dashboards and alerts

artifact-level journeys
  -> physical-device performance and energy budgets

canonical capability manifest + reviewed algorithm identity
  -> signed optional-capability rollout
  -> emergency disable and audited rollback

license firewall + deterministic release manifest
  -> SBOM and signed provenance
  -> offline artifact verification

account lifecycle + durable mutation protocol
  -> device-bound secret storage and rotation
  -> platform backup and file-protection attestation

server-authoritative provenance + store privacy inventory
  -> backend location and retention manifest
  -> verified deletion and residency evidence
```

No queue item should move to shipped because its document exists. Each item
requires executable fail-closed acceptance evidence in the actual production
path or release artifact.
