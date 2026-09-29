# Portable schema migration registry and cross-runtime conformance

Reviewed: 2026-08-31

## Decision

ParkinSUM now treats each readable portable-package version as a frozen
validator contract rather than interpreting historical bytes through only the
latest shared constants. The first local slice provides:

- immutable v2 and v3 schema-resource URNs, structural-contract digests,
  semantic-policy digests, and validator identities;
- one explicit v2-to-v3 migration with eight field-level semantic changes and
  five preservation invariants;
- a no-write migration receipt binding the exact source bytes, canonical source
  and output documents, both validators, migration and semantic-diff identities,
  warnings, held fields, and the preview-only decision;
- a Flutter-hosted Dart fixture/mutation corpus and an independently written
  Node parser, canonicalizer, migrator, receipt verifier, and mutation suite;
- a Settings preview card that makes the selected source validator, target
  validator, decision, warnings, and limits visible before any future import.

The registry is a second fail-closed gate after the existing production
portable-package validator. It does not replace nested dose-evidence or reminder
semantics, and it does not authorize durable import.

## Evidence mapping

| Source | Relevant point | ParkinSUM transfer | Limit retained |
| --- | --- | --- | --- |
| [JSON Schema 2020-12 Core](https://json-schema.org/draft/2020-12/json-schema-core) | `$id` establishes stable schema-resource identity and identifiers can be resolved independently of retrieval location. | Historical validators have immutable `urn:parkinsum:schema:user-portable-data-package:{version}` resource identities and content-addressed structural contracts. | The compact local structural projection is not claimed to be a complete JSON Schema document or conformance implementation; application cross-field semantics remain code. |
| [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259.html) | Object member names should be unique; behavior for duplicates is otherwise unpredictable across implementations. | Both runtimes reject duplicate raw object members before accepting a fixture, including before Node `JSON.parse`. | Two parsers and a finite corpus do not establish agreement for every platform or JSON implementation. |
| [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html) | Cryptographic JSON canonicalization requires deterministic serialization, unique names, stable string handling, and defined property sorting. | Dart and Node independently reproduce ParkinSUM's pinned `sorted-key-json-v1` output and retain Unicode code points. | `sorted-key-json-v1` remains explicitly distinct from JCS; it does not claim complete RFC 8785 number, string, I-JSON, or UTF-16 ordering conformance. |
| [W3C PROV-O](https://www.w3.org/TR/prov-o/) | Provenance can express that one entity was derived from another through an activity. | The receipt records source, transform, and derived-output identities without embedding user records. | The receipt is ParkinSUM JSON, not PROV-O/RDF conformance, and has no trusted actor, clock, or signature. |
| [RFC 6902](https://www.rfc-editor.org/info/rfc6902/) | JSON Patch defines a syntax for applying document operations. | It was reviewed as an interchange option, but the registry uses named semantic diffs and an executable reviewed transform because defaults, consent holds, and invariants carry meaning beyond patch syntax. | The migration descriptor is not a general JSON Patch engine. |
| [Google fuzzing guidance](https://github.com/google/fuzzing/blob/master/docs/why-fuzz.md) and [good fuzz-target guidance](https://github.com/google/fuzzing/blob/master/docs/good-fuzz-target.md) | Automated fuzzing explores unexpected inputs; useful targets are deterministic, fast, and reproducible. | A separate P1 queue item now specifies synthetic generators, parser/resource budgets, deterministic minimization, differential classification, and promotion of reviewed counterexamples. | Continuous fuzzing and every-release-platform parser execution are not implemented in this slice. |

## Frozen identities

| Contract | SHA-256 identity |
| --- | --- |
| Registry | `66d9de4f25796f279dc1666c26acdf30ad552470bc645fa6d9ea39911643c521` |
| v2 validator | `45f73a0b502bbdb88a05dec355c307a7bc9f845a523a486253c780f7371b4e9f` |
| v2 structural contract | `9931fabd7a3a84123d7ebdd1df4a7a4c08dc176f72b4d5ba64f14e2323747fbd` |
| v2 semantic policy | `1dc90c2f96ed42fa1ebae39dfe832b8dec6721b231306ff7a891e3bde325cf46` |
| v3 validator | `73a20c10fbd58809e7db835a17876bf9f61d295c9d76378643b72177f7b1d223` |
| v3 structural contract | `ebdde2519df47a9b8d3ddc77605a7a1d86d00dc1ec2dba2c4f317b3ff12cdb68` |
| v3 semantic policy | `2af37911cc8d0b08571999e0b7da94173df4247a88b0c9f83d716487269076f5` |
| v2-to-v3 migration | `d0b446a0477483b0dde813974c0735224cba6d7fc7eb611a4fc6881698199349` |
| v2-to-v3 semantic diff | `c5025ffa5405b17007be16a0bd126d9e79b34e9508c8eb39d0a81665be6b8c67` |

These identities detect reviewed-contract drift. They do not authenticate who
created a package or prove the truth of its contents.

## Runtime path

1. The production no-write inspector enforces lexical and decoded resource
   budgets, exact fields, package/file checksums, identifiers, owner scope, and
   nested domain semantics.
2. The frozen registry independently accepts exactly v2 or v3 and rejects
   omitted, unknown, mixed, duplicate-member, or future-version documents.
3. A v2 document is migrated in memory. Its target v3 files are run through the
   production nested validators again before the preview can be ready.
4. A privacy-bounded receipt is returned through the isolate boundary and
   rendered in Settings. No record, reminder, permission, preference, account,
   or durable file state is changed.

The log line contains only source/target versions, decision, and a truncated
receipt identity. It does not print package contents, account identifiers, or
record data.

## Verification

Run:

```sh
npm run portable:schema-migration
```

The command regenerates two synthetic Dart package vectors and one Dart VM
numeric-canonicalization fixture, executes eight Dart mutation/invariant
checks, runs five Node unit tests, and independently checks both package
vectors, the numeric fixture, and nine Node mutation/invariant cases. Generated
evidence is ignored under `build/portable_schema_migration/`:

- `dart_vectors.json`
- `node_conformance.json`

The pinned registry, validator, migration, and semantic-diff identities are
also asserted by `test/portable_schema_migration_registry_test.dart`; production
preview and UI rendering are covered by the portable-package service and page
tests.

## Boundary and next work

This is deterministic software-conformance evidence over finite synthetic
fixtures. It is not exhaustive parser verification, issuer authenticity,
non-repudiation, FHIR/PROV/JSON-Schema/JCS conformance, clinical correctness,
safe durable import, backup/restore, or patient-safety evidence.

The next queued slice is
`portable_schema_continuous_differential_fuzz_and_corpus_promotion`: versioned
synthetic generators, explicit byte/node/depth/width/time budgets, Dart/Node and
release-artifact differential classification, deterministic minimization, and
privacy-reviewed regression-corpus promotion. Durable import remains separately
blocked on an explicit confirmation transaction, last-known-good rollback,
crash/fault injection, and target-device capability issuance.
