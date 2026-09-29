# Complete-app next-wave research

## 2026-08-27 medication-input continuation

The dose-expression slice now has a versioned fail-closed typed AST, visible
accepted/held UI, and a neutral Dart/JavaScript differential corpus. The
worktree now also implements the first administration-dose confirmation
receipt and reconciliation slice; see
`docs/ADMINISTRATION_DOSE_CONFIRMATION_PROVENANCE_RESEARCH_2026-08-27.md` and
queue item `administration_dose_confirmation_receipt_and_reconciliation`.

This remains a local user-assertion and provenance design. It is not a FHIR
conformance, medication-administration, prescription-validation, or clinical
accuracy claim.

## 2026-08-27 algorithm-configuration ownership continuation

The canonical configuration identity now maps every one of 111 explicit
parameter/provider records to registered algorithm consumers and partitions all
63 registered algorithms into eleven with at least one explicit field record
and 52 source-bundle-only fallbacks. The Algorithm Observatory exposes both
states and two exact complete-per-field witnesses: gastric emptying over 17
declared fields and levodopa absorption opportunity over 13; the remaining 61
algorithms, including the legacy scorer, stay explicitly incomplete. See
`docs/ALGORITHM_CONFIGURATION_OWNERSHIP_AND_CHANGE_IMPACT_RESEARCH_2026-08-27.md`.

Research also added
`algorithm_transitive_result_dependency_closure`. The current source bundle is
the union of manually declared descriptor paths, so it cannot prove that a new
helper, callback, initializer, polymorphic target, generated bridge or external
configuration edge was not omitted. The proposed pinned Dart-analyzer gate
derives conservative forward and reverse closures and treats every reachable
unresolved edge as a HOLD; see
`docs/ALGORITHM_TRANSITIVE_RESULT_DEPENDENCY_CLOSURE_RESEARCH_2026-09-02.md`.

The legacy scorer slice binds 33 numeric score, bound, threshold and Top-K
leaves plus its stable tie policy to production execution, configuration
identity and visible provenance. Future research added
`food_composition_candidate_set_snapshot_and_rank_uncertainty_gate` because a
fixed scorer cannot reproduce or justify an order if catalog releases, food
matches, preparation/portion basis, missing/LOQ semantics or candidate
eligibility drift. See
`docs/FOOD_COMPOSITION_CANDIDATE_SET_SNAPSHOT_AND_RANK_UNCERTAINTY_RESEARCH_2026-09-02.md`.

A narrower production-adapter slice is now shipped under canonical
configuration `2026.09.02-v40`
(`56cf755398784e7067c32bc1eb1d197f2b2c737868b6b015aaa431018959ceaf`)
and registered source bundle
`fc9eebdaa016136f558f4a07c7c0b70254092633a25ca1bf26312a104a9d4bdf`.
The 23rd mathematical/unit invariant calls the real catalog-candidate adapters
and verifies that source-missing markers override stale nutrient and energy
numbers, an unmarked true zero remains zero, and a source value `V` in grams
per 100 g is projected to a valid `W`-gram serving as
`N=(V×W)/100`. Only exact `per_100g` input is eligible. USDA's
[Foundation Foods](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)
and [Global Branded Foods](https://fdc.nal.usda.gov/GBFPD_Documentation/)
documentation distinguishes 100 g from 100 mL bases, the
[FDC API](https://fdc.nal.usda.gov/api-spec/fdc_api.html) defines the transport
surface, and the [BIPM SI Brochure](https://www.bipm.org/en/publications/si-brochure/)
keeps quantity and unit identity explicit. Therefore `per_100mL`, unknown unit
or basis, invalid source values, and invalid serving masses remain null; no
density is invented. The visible report is now 23/23, 22/63 mathematical/unit,
and 30/63 combined with the eight direct executable contracts; 33 algorithms
remain uncovered.

This slice does not close the candidate-set snapshot/rank-uncertainty work. It
does not freeze a catalog release, prove match or eligibility completeness,
verify that every importer supplies correct missing/basis metadata, implement a
repository-wide typed quantity algebra, reproduce the result externally, or
establish biological/clinical validity or utility.

The NextMeal UI now labels baseline candidates whose relative order or
display-set membership changed in the snapshot-bound, bounded source-range
scenarios. The labels appear in all 13 shipped languages, but they do not
change the deterministic order or close the wider uncertainty gate.

The local `algorithm_configuration_change_impact_and_requalification_matrix`
is now shipped: it enumerates semantic differences, traverses explicit field →
algorithm → output relationships, retains before/after null and failure states,
and assigns separate verification, validation, human-factors and
requalification obligations. Its manufactured candidate remains promotion
blocked. The next baseline-governance gap is
`configuration_baseline_durable_store_and_transparency_witness`; the current
registry is not yet a crash-atomic multi-writer authority or externally
witnessed transparency log.

The next researched medication-input layer is multi-source assertion and
temporal reconciliation. It retains patient/caregiver reports, imported lists,
requests, dispenses and formal administration evidence as distinct claims,
preserves conflicting event/assertion/import/recorded times, and never infers
adherence. See
`docs/MEDICATION_ASSERTION_SOURCE_TEMPORAL_RECONCILIATION_RESEARCH_2026-08-27.md`
and queue item `medication_assertion_source_temporal_reconciliation`.

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

The current worktree now includes a versioned, SHA-256-bound applicability
manifest for all six live mechanistic providers, embeds it in canonical
algorithm identity, propagates it into source references, emits live medication
predicate outcomes, and renders the declared context in the Observatory. The
remaining gap is complete per-provider runtime outcome coverage plus governed
external product/terminology/label/population identity and independent
promotion authority. A context-of-use statement or matching digest alone is
not clinical qualification.

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
- A page-currency review on 2026-09-24 found that the official page reports a
  2022-10-20 update, gives a base list updated through 2007, and lists 142 and
  156 additions in 2008 and 2010; it still labels 130 proposed tags and the
  consolidated Excel list "coming soon." The content-addressed
  `parkinsum.infoods-tagname-source-identity/1` artifact records only this
  page-level observation. It does not archive or hash the remote page, establish
  a complete current release, or authorize tag mappings.
- [FHIR R5 NutritionIntake](https://hl7.org/fhir/R5/nutritionintake.html) is
  Trial Use. The existing aggregate view remains labelled FHIR-inspired. A
  separate owner-scoped timeline action now creates a narrow local
  NutritionIntake-shaped preview using uncoded text, unknown status, an explicit
  Patient reference, and only supported time/amount precision. It has no pinned
  implementation profile or official validator result, so it does not claim
  FHIR conformance or interoperability.

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

### Current worktree slice (2026-08-18)

The worktree now implements a schema-v1, process-memory-only ledger and a
Settings surface for startup, backend, notification, and model-availability
outcomes. The ledger keeps only closed categories, coarse duration buckets,
capability state, and bounded counts for 24 hours. Turning collection off
clears it immediately. If the 32-cell local cardinality budget is exhausted,
the UI reports the dropped count and the export-envelope gate refuses the
incomplete snapshot rather than crashing or silently under-reporting it.

Bootstrap and reminder-response initialization now write only non-semantic
local outcomes. The deterministic export envelope is deliberately unusable by
default and requires an exact notice identity, current authorization receipt,
reviewed release identity, sampling, retention, region, access, deletion, and
emergency-disable policy before bytes can be materialized. There is no sender,
collector, credential, endpoint deployment, dashboard, or off-device data
flow. This proves a bounded local contract and a fail-closed future envelope;
it does not prove consent, production telemetry privacy, deletion, or support
effectiveness.

### 6A. Aggregate privacy budget and small-cohort suppression

Closed fields and aggregate counts are useful minimization controls, but they
do not by themselves prevent a rare platform/failure combination from
identifying a person or repeated queries from revealing a small cohort. The
[NIST differential-privacy introduction](https://www.nist.gov/blogs/cybersecurity-insights/differential-privacy-privacy-preserving-data-analysis-introduction-our)
notes that ordinary aggregation protects only under limited group-size
conditions and remains vulnerable to privacy attacks.

[NIST SP 800-226](https://csrc.nist.gov/pubs/sp/800/226/final) treats epsilon
as a privacy-loss upper bound and describes composition across repeated
analyses. It also emphasizes that a real guarantee depends on the protected
entity, neighboring-dataset definition, contribution bounds, mechanism,
implementation, parameter choice, and privacy/utility trade-off. ParkinSUM has
none of those mechanisms today and must not label a cardinality cap,
suppression threshold, or hashed identifier as differential privacy.

Required future control:

- suppress unsupported and undersized cohorts before any dashboard release,
  with reviewed rare-event and auxiliary-information threat models;
- define the protected entity, neighboring datasets, contribution bounds,
  clipping, query identity, retention, and reset policy across accounts,
  devices, retries, and releases;
- if differential privacy is used, version the mechanism, epsilon, delta,
  sensitivity, randomness source, composition accountant, total budget, and
  privacy/utility evidence, and fail closed when the accountant is unavailable
  or exhausted;
- test repeated differencing, membership inference, rare platform slices,
  malicious queries, concurrent budget use, restart, rollback, and deletion;
- preserve explicit consent, access, store-declaration, and operational-only
  boundaries. Statistical privacy never converts telemetry into clinical
  evidence or anonymous individual data.

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

The current worktree now implements the local verification and recovery core:
a strict schema-v1 manifest and envelope, canonical Ed25519 signatures through
the pinned Dart [`cryptography` package](https://pub.dev/packages/cryptography),
a closed list of three global boolean
capabilities, exact issuer/environment/key trust, expiry and clock-skew bounds,
replay/downgrade/chain rejection, explicit key rotation and revocation,
last-known-good persistence with exact read-back, bounded exact rollback
history, conservative defaults, and an operator page. The managed Local AI
adapter consults this policy when a trust root is configured. There is no user
or health-data targeting. With no trust root, remote policy is inactive and
the existing separately consented local-only behavior remains locally governed
rather than being silently relabeled as remotely managed.

The worktree also has an optional strict retrieval client for one exact
build-allowlisted, public-DNS, dedicated cross-origin HTTPS endpoint. It uses a
bodyless GET, rejects redirects and ambiguous URLs, enforces JSON, strict UTF-8,
a 64 KiB streamed limit, and one monotonic timeout budget, and requires the
strong ETag to equal the quoted SHA-256 of the exact response bytes. A matching
`304` may reuse only the client's accepted ETag; a new body still must pass all
signed-manifest checks. The schema-v2 activation state commits the accepted
endpoint, exact-body ETag, active-manifest digest and UTC acceptance time in the
same durable transaction, restores it across restart only for the same endpoint
and still-valid manifest, and migrates schema v1 only after a new verified
fetch. A transport-valid but signature-invalid response cannot poison the
validator. Concurrent fetches serialize through validator commit, while clear
or manual activation advances a generation immediately so an older in-flight
response cannot reactivate after emergency clear. Request code adds no account, health-body, or
authorization fields, but browser/network metadata and Cookie behavior still
need target-environment audit.

This is narrower than [The Update Framework specification](https://theupdateframework.github.io/specification/latest/):
it borrows rollback, freeze, expiry and key-lifecycle principles but is not a
TUF client or conformant repository. Ed25519 verification proves only that the
bytes match a configured public key; it does not prove safe private-key
custody, signer authority, complete distribution, clinical validity, or
scientific accuracy.

Remaining required control:

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

The still-open production boundary includes an offline or threshold recovery
root, private-key custody and signer authorization, a production publication
service and endpoint, immutable/versioned distribution, multi-region and
mirror consistency proof, browser/CDN/service-worker cache conformance,
cookie-free target verification, crash/power-loss
and target-device drills, server-side audit evidence, consumer wiring for
catalog refresh and telemetry, and independently reviewed compromise recovery.
Follow-on queue items separately cover key transparency and fleet convergence
so those controls are not conflated with the local verifier.

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

## 13. Context-of-use change impact and requalification ledger

A versioned applicability manifest identifies the declared boundary, and a
configuration digest identifies executable bytes and parameters. Neither proves
that evidence accepted for an older question, formulation, population,
observable, or decision influence remains adequate after a change.

FDA's final CM&S credibility guidance uses a risk-informed framework for a
particular context of use. EMA's PBPK reporting guidance ties platform
qualification and specific model performance to intended use. The
[FDA-recognized ASME V&V 40-2018 entry](https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfstandards/detail.cfm?standard__identification_no=38534)
describes a framework for assessing the relevance and adequacy of completed
verification and validation activities. These sources motivate a change-control
pattern; they do not qualify ParkinSUM.

Required future control:

- create an immutable old/new manifest and configuration record with semantic
  diff, affected providers/predicates, question and context of use, model risk,
  decision influence, author, review time, and release artifact;
- derive required code/calculation verification, validation, qualification,
  uncertainty, human-factors, and independent-review activities, and block
  promotion while any required evidence is absent, stale, conflicting, or
  unapproved;
- prohibit silent evidence carry-forward across product, component,
  formulation, route, population, fed state, observable, terminology,
  parameter source, or decision influence;
- show implementation verification, scientific validation, platform/model
  qualification, regulatory review, and external approval as separate states;
- preserve rollback, revocation, last-known-good identity, and rejected-claim
  history through concurrent review, partial deployment, offline recovery, and
  acknowledgement loss.

Current worktree status (2026-08-18): the first schema-v1 governed-baseline
record now binds the exact manifest, configuration, semantic diff, affected
providers and predicates, model risk, evidence lanes, decision and record
digests. A deterministic release gate blocks identity drift and unsafe
approval, and the Observatory shows each evidence lane independently. The
record intentionally remains `blockedPendingEvidence`: implementation and
calculation verification are complete, while uncertainty, human factors,
scientific validation, model qualification and independent review remain
incomplete. Durable multi-release history, signed reviewer authority,
evidence expiry/equivalence, rollback/revocation and failure-recovery evidence
remain open; the current gate is not requalification by itself.

## Dependency order

```text
parameter provenance + canonical configuration identity
  -> runtime applicability/abstention
  -> independent numerical oracle
  -> evidence currency and source-status review
  -> claim evidence contradiction and synthesis adjudication
  -> context-of-use change and requalification ledger

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
  -> aggregate privacy budget and small-cohort suppression
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

## 14. Evidence currency, correction, retraction and claim sunset

Code, parameter and applicability identities can remain byte-for-byte stable
while the evidence used to justify a provider or boundary changes. The
[NLM policy for errata, retractions and linked citations](https://www.nlm.nih.gov/bsd/policy/errata.html)
shows that PubMed records can carry retraction, correction and expression-of-
concern relationships. [Crossmark](https://www.crossref.org/services/crossmark/)
similarly exposes corrections, retractions and other updates that affect how a
work should be interpreted. The EMA PBPK page preserves a current effective
version and document history, while its guideline says qualification is tied
to intended purpose and platform version. These services help identify status;
they do not independently establish that a source is scientifically adequate
for ParkinSUM.

The current worktree now binds five reviewed claims across all six live
providers to exact source revisions, affected providers and predicates,
applicability rationale, status-resolution method, observed-at and review-by
times, reviewer, expiry and sunset disposition. Its deterministic gate holds
corrected evidence and blocks superseded, retracted, withdrawn, expression-of-
concern, expired, unavailable or unknown evidence, then opens context-of-use
requalification even when code and manifest hashes are unchanged. It remains
an offline unsigned initial snapshot, not an exhaustive claim catalog or a
live status service. Production completion still requires archived refresh
artifacts, append-only signed history, reviewer authority, durable provider
disablement and independent review. Network failure and the absence of a
notice can never promote evidence or imply scientific validity. As-of
evaluation also rejects future-observed status: a record observed after the
requested snapshot resolves to unknown and quarantines its affected providers.
The mechanistic engine now evaluates this offline status snapshot before
emitting its educational trace; corrections hold the affected trace for review,
while adverse, expired, unknown, future-observed, or malformed evidence blocks
it. Candidate samples use the same assessment time. Blocked results carry the
snapshot digest in their abstention reasons. Successful and currency-blocked
results now carry a strict schema-v1 receipt binding registry version and digests,
UTC assessment time, exact provider and claim sets, disposition, and a
tamper-evident binding digest; deterministic replay fixes and reports its own
assessment time. The receipt is unsigned and in-memory, so it does not provide
append-only history, durable cross-session quarantine, independent review, or
live source refresh. This runtime gate does not change the conservative
recommendation rank or safety rules.
The diagnostics source search exposes only exact source-ID-linked claim rows and
keeps unmatched source metadata explicitly unassessed; this is not a live status
refresh or provider-disablement attestation.

## 15. Claim-level contradiction, certainty and applicability adjudication

Evidence currency and evidence adequacy are different questions. A source may
have no recorded correction or retraction while still being at high risk of
bias, indirect for the modeled population or observable, imprecise, duplicated
with another publication, or directionally inconsistent with other current
evidence. The
[Cochrane Handbook, Chapter 14](https://training.cochrane.org/handbook/current/chapter-14)
requires outcome-specific certainty judgments and explicit reasons across risk
of bias, inconsistency, indirectness, imprecision and publication bias. This is
a review method, not proof that a ParkinSUM claim has high certainty.

[AHRQ's applicability methods guidance](https://effectivehealthcare.ahrq.gov/products/methods-guidance-applicability/methods)
treats applicability as a separate, structured judgment tied to population,
intervention, comparator, outcomes and setting, and warns that no single
universal checklist resolves every review. Its
[grading guidance](https://effectivehealthcare.ahrq.gov/products/methods-guidance-tests-grading/methods)
also separates the strength of a body of evidence from the quality of one
study. These sources support a governance pattern; they do not authorize
automated clinical grading or substitute for independent domain review.

The current worktree now implements the first offline, schema-v1 fail-closed
adjudicator. It binds each governed claim to an exact outcome and measure,
population, intervention/exposure, comparator, study design, source revision,
independence group, affected provider, risk-of-bias, applicability, precision,
reporting-bias, declared certainty, reviewer artifacts and expiry. Support,
null, opposing and adverse directions remain separate. Contradiction, adverse
findings, source withdrawal and outcome/measure mismatch block; duplicate
cohorts, insufficient independent families, indirectness, imprecision,
unassessed domains, stale review and reviewer disagreement hold. The current
five bodies are intentionally held pending independent dual review, and the
Observatory and COU ledger show that hold rather than a favorable grade.

This is not a complete evidence-synthesis program. Exhaustive searching,
independent extraction, validated risk-of-bias instruments, normalized effect
estimates and units, a governed cohort/publication dependency graph, signed
append-only reviewer decisions, durable provider quarantine and rollback, live
source refresh, clinical/domain review, prospective validation and regulatory
qualification remain open. The system must never promote a claim by citation
count, silently average incommensurable studies, or translate an evidence-
governance state into clinical validity, treatment advice, regulatory review or
approval.

No queue item should move to shipped because its document exists. Each item
requires executable fail-closed acceptance evidence in the actual production
path or release artifact.

## 2026-09-28 algorithm-configuration coverage update

The current schema-v6 identity emits 119 parameter/provenance records for all
63 registered algorithms. Sixteen algorithms have at least one explicit field
record, while 47 remain source-bundle-only; the protein-trend record binds the
effective-occurrence time basis, protein grams per meal, ordering, mean formula
and empty-input value. Only gastric emptying and
levodopa-absorption opportunity retain complete witnesses within their
declared boundaries. A new prototype-heuristic record binds the local dose
parser's grammar ID, version, digest, unit-system URI, and unit-map version.
It does not claim that every parser branch is represented or that the grammar
establishes prescription or dose validity. The current identity is
`2026.09.29-v52` (`77d2a1d030443c12f125e0ee9606f25a085dab76ef73d7a20fb62d7c9019a99d`)
with source-bundle digest
`15a293f7efa3501b0d206570d651b1abecc828e2d796751debd5225cece4bd6d`.
The v52 identity also binds the mechanistic trace evidence-currency gate and
its unsigned result receipt; the earlier v51 manifest bound the protein-trend aggregation contract and its
direct meal and output-point sources, plus a standalone production-parser trace
provider. The fixed parser syntax cases omit raw text and parsed values, and do
not feed the other Observatory scenarios. These records add no clinical
interpretation.
The P0 configuration-identity queue item remains open: 61 algorithms still
lack complete-per-field witnesses, and transitive dependency closure,
independent calibration-data governance, and external source normalization
remain unresolved.
