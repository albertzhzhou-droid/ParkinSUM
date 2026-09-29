# Mechanistic lossless replay capsule and cross-runtime conformance research

Date: 2026-08-31  
Status: implemented first slice; engineering replay evidence only

## Decision

ParkinSUM now places a strict, self-contained replay boundary between mechanistic input construction and result-affecting evaluation. The schema-v1 capsule embeds the complete schema-v2 mechanistic ledger, the exact `TimeAxisConflictContext`, and the complete sorted `MealComposition` map. Meal check, next-meal recommendation and Algorithm Observatory must serialize, parse, reconstruct and reauthorize these restored objects before a conflict engine or candidate scorer can use them. Reconstruction or identity failure returns `blockedIntegrity`; it cannot emit a numerical candidate score.

This closes the earlier information-loss gap in the readable ledger projection. It does not change the readable projection into a lossless clinical interchange format.

## Standards evidence and design consequences

### Stable canonical bytes

[RFC 8785 JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html) defines deterministic property sorting, UTF-8 output, preservation of Unicode strings without normalization, and an I-JSON input boundary. It also explains that values needing precision beyond interoperable JSON numbers should use strings. [RFC 7493 I-JSON](https://www.rfc-editor.org/rfc/rfc7493.html) forbids duplicate object member names and warns that integers outside the exact binary64 range cannot be assumed to survive unchanged.

The ParkinSUM profile therefore:

- recursively sorts object keys and preserves array order;
- preserves Unicode code points without normalization;
- encodes every integer as a reserved typed decimal-string wrapper;
- encodes every double as its exact 16-hex-digit IEEE-754 binary64 bit pattern;
- forbids native JSON numbers inside the capsule payload;
- rejects unknown root fields, unknown schema/profile versions and digest drift.

The profile is named `parkinsum.jcs-safe-lossless-scalars/1`. It is informed by JCS, but ParkinSUM does **not** claim complete RFC 8785 conformance: the typed scalar profile deliberately avoids JCS native-number serialization, and the current gate is not the RFC's full official vector suite.

### Schema evolution

[JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12) separates core and validation vocabularies and supplies explicit mechanisms for schema identification and composition. The current parser uses an application-owned closed-field contract rather than claiming JSON Schema validator conformance. A future migration gate must retain frozen old/new fixtures and produce an explicit `lossless`, `incompatible`, or `deliberate-loss` receipt. Deliberate or unclassified loss must never authorize mechanistic output.

### Timezone truth boundary

The capsule preserves the already-resolved UTC instants and numeric offsets present in the source objects. It has no global timezone contract; an owner-observation event may carry optional resolver evidence when a caller explicitly supplies it through the schema-v2 projection. Missing IANA zone, tzdb release, civil time, fold choice or future rule interpretation is never fabricated. [RFC 9557](https://www.rfc-editor.org/rfc/rfc9557.html) describes offset/time-zone consistency requirements, while the [IANA Time Zone Database releases](https://www.iana.org/time-zones/releases) demonstrate that rules change over time. As of this research date IANA lists 2026c as the newest release. The optional owner-observation path carries a caller-declared release in each supplied receipt, but does not provide a capsule-wide or independently verified tzdb pin. Historical instant replay and future civil-time intent remain separate claims.

## Implemented contract

The capsule root contains exact schema/profile identity, capsule identity, algorithm configuration digest, source ledger/config/input-binding identities, timezone contract, payload and payload SHA-256. The payload contains:

- the complete ledger and event fields, including extended medication metadata, food-component timeline data, observations, windows, provenance, units, missingness and ordering;
- every result-affecting context field;
- every meal composition, food component and amino-acid profile required by ledger references.

After parsing, the service reconstructs the objects, compares them with the source values and runs the existing ledger authorization boundary again. Production code consumes only the restored authorization lease.

## Verification evidence

`npm run mechanistic:lossless-replay` composes:

1. Dart capture, canonicalization, parse, exact reconstruction and reauthorization for three Observatory scenarios;
2. Dart mutations for digest, root field and version drift;
3. an independently written Node canonicalizer over the emitted vectors;
4. Node mutations for map-order equivalence, binary64-bit change, native-number injection after valid rehash, null-versus-missing distinction and Unicode code-point distinction.

The gate writes ignored artifacts to `build/mechanistic_replay_capsule/`. Unit and widget tests separately prove rich metadata/food structures, production failure closure and the dedicated Algorithm Observatory panel.

## What this does not establish

Passing establishes bounded software replay agreement for fixed synthetic inputs. It does not establish:

- persistence durability, import/export compatibility or crash recovery;
- schema migration correctness beyond v1;
- duplicate-member detection before a permissive JSON parser has collapsed input;
- parser resource-exhaustion resistance or differential fuzz coverage;
- byte agreement on every supported Web, Android, Apple or desktop release runtime;
- IANA timezone/tzdb/fold evidence for event kinds beyond explicitly resolved owner observations, or future reminder intent;
- independent third-party reproduction;
- biological truth, model validity, parameter identifiability, clinical calibration, benefit, safety, regulatory qualification or medical advice.

The upgrade queue retains the original cross-platform item as `research_required` and adds `mechanistic_replay_schema_migration_and_differential_fuzz_corpus` for the next evidence layer.
