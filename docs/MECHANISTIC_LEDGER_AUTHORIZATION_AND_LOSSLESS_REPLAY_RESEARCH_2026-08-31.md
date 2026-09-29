# Mechanistic ledger authorization and lossless replay boundary

Date reviewed: 2026-09-29

ParkinSUM is an educational and research prototype. This work establishes an
engineering integrity boundary before mechanistic computation; it does not
establish biological truth, clinical calibration, efficacy, safety,
regulatory qualification, or medical advice.

## Question

Can the existing readable mechanistic event ledger safely become the input to
the production conflict and candidate-scoring engines, and can a separate
artifact reconstruct the complete input without side objects?

The code audit found that it cannot yet be reconstructed losslessly. The
projection intentionally omits extended medication metadata, complete food
components, and food-component timeline events. Reconstructing engine input
from that projection would silently discard information.

The implemented answer is to retain the readable projection for audit and add
a separate lossless replay capsule. Production now evaluates reconstructed and
reauthorized capsule objects rather than treating the readable projection as a
lossless interchange format.

## Evidence used

- The [FDA credibility-assessment guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions)
  frames model credibility as risk-informed evidence for a stated context of
  use. ParkinSUM therefore keeps input-integrity evidence separate from model
  validation and clinical claims.
- [HL7 FHIR R5 Provenance](https://hl7.org/fhir/provenance.html) represents the
  entities and activities involved in producing or influencing a resource.
  ParkinSUM borrows the principle that derivation and identity should be
  explicit, but does not claim FHIR conformance.
- [W3C PROV-O](https://www.w3.org/TR/prov-o/) provides a vocabulary for
  entities, activities, agents, and derivation. The local authorization report
  similarly exposes its input, ledger, configuration, and report identities,
  without claiming PROV-O serialization or interoperability.
- [UCUM](https://ucum.org/) defines unambiguous units and conversion semantics.
The current converter remains a small reviewed local subset (mass, energy,
duration, fraction, volume, pressure, and ordinal severity); it is not a UCUM
parser or conformance claim.

## Implemented slice

Schema v2 adds `input_binding_sha256`, computed over the exact serialized
`TimeAxisConflictContext` plus the sorted full `MealComposition` map. A
versioned authorization service verifies that binding, configuration identity,
readable event projection, meal-composition references, context attributes,
and ledger round trip before issuing a short-lived view over the exact bound
objects. Each view access recomputes the binding, so mutation of caller-owned
nested collections after authorization fails closed.

The production meal-check route, next-meal recommendation route, and Algorithm
Observatory now build the ledger, capture a schema-v1 lossless capsule, parse
and reconstruct its complete ledger/context/composition payload, and authorize
those restored objects before invoking the conflict engine or candidate
scorer. A failed reconstruction or authorization returns a typed
`blockedIntegrity` trace and no numerical candidate score. The Observatory
shows authorization and capsule state, identities, findings, exact-scalar
profile, timezone boundary, and non-clinical boundary.

The authorization gate runs all three synthetic Observatory scenarios and
configuration, context, and composition-identity mutations. The separate
`mechanistic:lossless-replay` gate adds rich Dart reconstruction vectors and an
independently written Node canonicalizer with map-order, binary64, native JSON
number, null-versus-missing, and Unicode mutations. Tests also cover nested
post-authorization mutation and production no-score behavior.

Schema v3 adds strict pressure and ordinal-severity dimensions. The
`MechanisticObservationEventImporter` can append the current owner's already
privacy-minimized schema-v1 observation projection as supplemental event rows,
bound to its source-projection digest. These UTC-timed annotations survive the
capsule digest and round trip but do not extend the engine-input binding or
enter conflict, ranking, or recommendation calculations. Import is an explicit
in-memory API; saved observations are not automatically routed, and this does
not import laboratory/FHIR records or censored measurements.

The Observatory now offers an explicit save action for its fixed synthetic
replay capsule. The existing repository seam stores canonical JSON under the
capsule SHA-256 in native SQLite schema v11, Web preferences, and the existing
owner-scoped Firestore user space; the in-memory backend supports deterministic
tests. Repeated identical writes are idempotent, and every read strictly
reconstructs the capsule and rechecks its digest. Firestore security rules
allow owner reads and create-only writes with a bounded canonical body. No
scenario is saved until the user presses the button.

## What remains open

Content binding plus the capsule proves bounded reconstruction of the complete
objects that were hashed for the tested Dart/Node fixtures. It does not make
the human-readable event list lossless. The current opt-in persistence tests
cover memory and Web round trips, the SQLite schema-v11 row contract, and
Firestore owner/append-only rules; they do not yet prove the native v10-to-v11
upgrade against an installed database or a Firestore client round trip. Export,
schema-migration corpus, parser resource limits, every release platform,
independent third-party reproduction, and broad IANA timezone/tzdb/fold coverage also
remain open; only explicitly resolved owner-observation events can carry optional evidence.
