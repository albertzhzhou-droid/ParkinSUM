# Unit-aware immutable mechanistic event ledger

Reviewed: 2026-09-29

## Product decision

ParkinSUM now projects a validated mechanistic context into a schema-versioned, immutable event ledger. The ledger is a read-only audit and replay surface. It never creates, infers, recommends, or reschedules a medication dose, and it is not a medical record, measured concentration series, or calibrated pharmacokinetic dataset.

Schema v3 keeps the exact full `TimeAxisConflictContext` and sorted
`MealComposition` input binding, and adds strict pressure and ordinal-severity
dimensions. A privacy-minimized owner-observation importer can append the
existing owner-filtered projection as supplemental replay events. These events
are included in the ledger and capsule digests but do not alter the engine-input
binding or enter conflict, ranking, or recommendation calculations. The
readable event projection remains intentionally non-lossless. A separate
schema-v1 capsule preserves and reconstructs the
complete ledger, context and composition input with exact scalar wrappers; the
meal-check, recommendation and Observatory paths authorize and evaluate only
the restored objects. Any configuration, context, composition, projection,
capsule, round-trip, or post-authorization mutation drift blocks numerical
output. The Algorithm Observatory renders both gates, identities, findings and
boundaries.

## Contract

Current schema: `parkinsum.mechanistic-event-ledger/3` (schemas v1 and v2 are
catalogued as historical evidence and cannot authorize production model input)

```text
validated production context
        |
        v
strict ledger projection
  - dose | meal | observation | context
  - known | unknown | notCollected | BQL | censored
  - original value/unit -> canonical value/unit
  - offset-bearing original timestamp -> UTC instant
  - stable equal-time order
  - source + revision + synthetic identity
        |
canonical sorted JSON -> full audit SHA-256
canonical replay projection -> semantic replay SHA-256
        |
lossless capsule -> strict reconstruction -> authorization -> engine view
        |
strict round-trip parser -> Observatory UI and deterministic gate
```

The full audit digest preserves original units, the offset-bearing timestamp, and provenance. The second canonical replay digest excludes those representation choices while retaining canonical values, the UTC instant, event order, source/revision identity, and replay-relevant attributes. Metamorphic tests therefore prove that `100 mg` at `03:00-05:00` and `0.1 g` at the same `08:00Z` instant have different audit digests but the same replay digest.

The parser rejects unsupported or missing fields, future schema versions, non-finite numbers, dimensionally invalid or ambiguous units, offset-free timestamps, invalid offsets, UTC disagreement, duplicate immutable event IDs, duplicate equal-time ordering, malformed identifiers, and either digest mismatch. Zero and unknown are different states. Below-quantification values carry a positive limit but no fabricated point value.

## Open-source comparison

- [rxode2 event tables](https://nlmixr2.github.io/rxode2/reference/eventTable.html) represent dosing and sampling event schedules with explicit times, amounts, units, compartments, and event semantics. ParkinSUM adopted the architectural lesson that event meaning and units must be explicit; it did not copy rxode2 code or claim feature or scientific equivalence.
- [Open Systems Pharmacology PK-Sim](https://github.com/Open-Systems-Pharmacology/PK-Sim) separates formulations, administration protocols, events, observers, and observed data as model-building blocks. Its public event redesign also emphasizes one timeline for administrations and events. ParkinSUM used this only as a design comparison and does not import its models or protocols.

These mature systems are simulation platforms. Their existence does not validate ParkinSUM's educational timing-overlap assumptions.

## Timezone research and next boundary

The [IANA Time Zone Database](https://www.iana.org/time-zones) is periodically updated when governments change boundaries, UTC offsets, or daylight-saving rules. An offset proves the mapping for one instant but cannot express the rules needed for future local-time arithmetic.

[RFC 9557](https://www.rfc-editor.org/rfc/rfc9557.html) extends Internet timestamps with timezone information and explains that local times can map to zero or multiple instants around clock changes. It also requires action when critical timezone information is inconsistent or unsupported. The general mechanistic event path still requires an explicit offset and does not claim full timezone-rule replay. A narrow optional path now carries IANA zone ID, caller-labeled tzdb/provider release, exact zone-table digest, civil wall time, and fold choice for an owner observation only; broad event coverage and rule-drift reconciliation remain open.

The broader multi-event and platform-drift work remains separately queued. A new standalone schema-v1 resolver now accepts a Gregorian timezone-naive civil time, an IANA ID present in an injected rules database, an explicit offset, an earlier/later/reject fold choice, and caller-declared ruleset/provider identity. Its result records the UTC instant, a digest of the exact selected zone tables, and a canonical SHA-256 over the complete evidence body; DST gaps, unresolved folds, unknown zones, malformed rules, and offset/zone mismatches fail closed. Tests use the locked `timezone` 0.11.1 package's bundled tzdb 2025c. IANA has since published 2026d, so this 2025c fixture demonstrates deterministic resolution, not current future-time accuracy. The resolver evidence can now be explicitly attached by record ID to a schema-v2 owner-observation projection and preserved in supplemental schema-v3 replay rows. Historical records do not retain their original civil wall time, so the path never backfills them; the caller's tzdb/provider labels are not independently attested, and RFC 9557 or multi-release/platform comparison is not implemented. It remains distinct from notification scheduling; reconciliation must never silently alter a recorded instant or medication event.

## Current limitations

- The Observatory fixture is synthetic and visibly marked as such.
- Normalized meal values are canonical projections; ordinary persistence does not yet retain every pre-normalization user unit.
- The new bridge appends the owner-filtered personal-observation projection to a mechanistic ledger as supplemental audit rows. It carries the source projection digest, hashed event identity, source/status, occurrence and recording UTC instants, declared timezone label, explicit missingness, and bounded severity/pressure measurements without free text or owner/recorder IDs. When the caller supplies matching evidence, it also preserves the original civil time, IANA zone, caller-labeled tzdb/provider, zone-rule digest, offset, and fold choice. Same-time rows are ordered after existing ledger events, repeated imports are idempotent, and mixed synthetic/owner data is rejected. This bridge is an explicit in-memory API; existing saved observations are not automatically routed into it.
- External laboratory/FHIR ingestion, below-quantification and censored observation imports, durable owner consent and persistence semantics, automatic historical backfill, and IANA/tzdb/fold binding for dose, meal, context, or reminder events remain open. The importer records only UTC instants and a caller-declared timezone label unless the caller supplies matching resolution evidence; it never infers an historical local offset.
- The mechanistic ledger now supports bounded pressure and ordinal-severity dimensions in addition to mass, energy, duration, fraction, and volume; pressure conversion retains the narrow NIST-based mm[Hg]/kPa factor and does not claim general UCUM support.
- The readable projection omits complete food components, food-component timeline events, and extended medication metadata; it remains intentionally distinct from the lossless capsule.
- Dart and independently written Node checks cover a bounded three-vector corpus; physical-device, every-release-platform, migration and third-party attestations remain incomplete.
- The audit and replay digests prove canonical identity at two disclosed projections; neither proves truth of the source observation, biological validity, or clinical utility.

## Local owner-observation audit projection

Schema `parkinsum.personal-observation-event-ledger/2` projects the active owner's already-saved symptom, self-reported motor-state, and blood-pressure records. It preserves source/status, UTC occurrence and recording instants, the caller-declared timezone label, and explicit unknown versus not-collected states; callers may bind explicit local-time resolution evidence by selected record ID, with zone and resolved instant checked against the saved observation. Symptom labels, notes, owner IDs, and recorder IDs are excluded; event identity is a deterministic SHA-256 token and remains linkable within repeated snapshots. The projection is calculated in memory, performs no write or network request, and remains outside every recommendation/prediction input. The new importer can attach these projected rows to a schema-v3 mechanistic audit/replay ledger; the rows are supplemental annotations, not part of the engine input binding, and do not affect evaluation.

Blood-pressure values are displayed in their original `mm[Hg]` unit and canonically represented in `mm[Hg]`; the bounded converter also supports `kPa` using the NIST Handbook 133, 2026 Appendix E factor `1 kPa = 7.500615 mmHg` ([NIST source](https://www.nist.gov/document/2026-hb-133-appendix-e)). This is a local engineering conversion, not a claim of UCUM validation or measurement accuracy. Timezone names remain caller-declared unless an explicit matching resolution receipt is supplied; that receipt preserves its tzdb/provider labels but does not independently attest them. The projection covers existing local records only; it does not import FHIR or laboratory observations and does not represent censored laboratory results.
