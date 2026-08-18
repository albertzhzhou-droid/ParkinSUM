# Unit-aware immutable mechanistic event ledger

Reviewed: 2026-08-18

## Product decision

ParkinSUM now projects a validated mechanistic context into a schema-versioned, immutable event ledger. The ledger is a read-only audit and replay surface. It never creates, infers, recommends, or reschedules a medication dose, and it is not a medical record, measured concentration series, or calibrated pharmacokinetic dataset.

The first production integration is deliberately observational: the Algorithm Observatory uses the same fixed production-engine scenario, then renders its dose, meal, and context events with their event identities, explicit equal-time order, source/revision identity, synthetic marker, original and canonical units, UTC instant, and numeric offset. The scorer and conflict engine still consume their existing validated `TimeAxisConflictContext`; the ledger cannot change a result.

## Contract

Schema: `parkinsum.mechanistic-event-ledger/1`

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
strict round-trip parser -> Observatory UI
```

The full audit digest preserves original units, the offset-bearing timestamp, and provenance. The second canonical replay digest excludes those representation choices while retaining canonical values, the UTC instant, event order, source/revision identity, and replay-relevant attributes. Metamorphic tests therefore prove that `100 mg` at `03:00-05:00` and `0.1 g` at the same `08:00Z` instant have different audit digests but the same replay digest.

The parser rejects unsupported or missing fields, future schema versions, non-finite numbers, dimensionally invalid or ambiguous units, offset-free timestamps, invalid offsets, UTC disagreement, duplicate immutable event IDs, duplicate equal-time ordering, malformed identifiers, and either digest mismatch. Zero and unknown are different states. Below-quantification values carry a positive limit but no fabricated point value.

## Open-source comparison

- [rxode2 event tables](https://nlmixr2.github.io/rxode2/reference/eventTable.html) represent dosing and sampling event schedules with explicit times, amounts, units, compartments, and event semantics. ParkinSUM adopted the architectural lesson that event meaning and units must be explicit; it did not copy rxode2 code or claim feature or scientific equivalence.
- [Open Systems Pharmacology PK-Sim](https://github.com/Open-Systems-Pharmacology/PK-Sim) separates formulations, administration protocols, events, observers, and observed data as model-building blocks. Its public event redesign also emphasizes one timeline for administrations and events. ParkinSUM used this only as a design comparison and does not import its models or protocols.

These mature systems are simulation platforms. Their existence does not validate ParkinSUM's educational timing-overlap assumptions.

## Timezone research and next boundary

The [IANA Time Zone Database](https://www.iana.org/time-zones) is periodically updated when governments change boundaries, UTC offsets, or daylight-saving rules. An offset proves the mapping for one instant but cannot express the rules needed for future local-time arithmetic.

[RFC 9557](https://www.rfc-editor.org/rfc/rfc9557.html) extends Internet timestamps with timezone information and explains that local times can map to zero or multiple instants around clock changes. It also requires action when critical timezone information is inconsistent or unsupported. The current ledger therefore rejects offset-free local timestamps, but it does not yet claim full timezone-rule replay: it lacks IANA zone ID, tzdb release, civil-time fold/gap decision, and rule-drift reconciliation.

A separate queue item now covers that future work. It remains distinct from historical ledger integrity and from notification scheduling; timezone reconciliation must never silently alter a recorded instant or medication event.

## Current limitations

- The Observatory fixture is synthetic and visibly marked as such.
- Normalized meal values are canonical projections; ordinary persistence does not yet retain every pre-normalization user unit.
- No laboratory observation or censoring importer currently creates observation events.
- Only supported mass, energy, duration, and fraction conversions are accepted; unsupported UCUM expressions remain outside this schema.
- The same-language/device round trip is tested, but physical-device and cross-runtime attestations are not complete.
- The audit and replay digests prove canonical identity at two disclosed projections; neither proves truth of the source observation, biological validity, or clinical utility.
