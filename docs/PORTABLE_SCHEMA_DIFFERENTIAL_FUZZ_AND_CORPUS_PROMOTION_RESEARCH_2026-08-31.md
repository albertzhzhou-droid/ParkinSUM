# Portable schema differential fuzzing and corpus promotion

Date: 2026-08-31  
Status: first fixed local Dart/Node campaign slice implemented; continuous and
release-artifact coverage remains open

## Decision

ParkinSUM now treats the original JSON text as security- and
interoperability-relevant input. The production preview performs a bounded
recursive-descent preflight before `jsonDecode`, and the independent Node lane
parses the same raw synthetic text before `JSON.parse`. Duplicate member names,
unpaired UTF-16 surrogates, Unicode noncharacters, invalid escapes, truncation
and declared resource-budget violations fail closed.

The campaign is intentionally reproducible rather than random-by-default:

- generator plan v1 freezes three regression seeds, 13 lexical/semantic
  partitions, package/node/depth/width/source-string-token/decoded-string/key/
  number-token budgets, a post-return elapsed observation threshold and two
  runtime lanes;
- exploratory seeds require explicit local operator input and are neither
  enabled nor retained by default;
- 31 retained synthetic inputs are covered by one explicit corpus-level
  privacy review; this first corpus does not claim per-case minimization;
- 47 cases total (31 retained plus 16 fixed-generated) bind plan, corpus,
  registry and source identities, assert disposition/reason-code agreement,
  and independently recompute migration output/receipt identities;
- source-token, decoded-string and decoded-key budgets are distinct, and the
  independent parser scans string and number tokens incrementally before
  handing a bounded token to the platform decoder;
- unsupported-version, extra-field and integrity-invalid precedence is fixed
  and tested across both production and independent classifiers;
- the Node canonicalizer retains the tested Dart VM distinction between JSON
  integers and doubles (`0` versus `0.0`, `1.0`, `-0.0` and exponent input),
  including signed-64-bit boundaries; stale token metadata is ignored after a
  value is mutated;
- compound lexical precedence is frozen for malformed escapes after a string
  boundary, surrogate failures before an over-budget tail, object width before
  long-key rejection, non-JSON whitespace before depth, and EOF before a
  phantom node-budget increment; unique manifest inventory plus
  owner/integrity/privacy and reminder activation/consent/presentation scalars
  are checked independently;
- empty or duplicate reminder identifiers and decimal-spelled values where
  Dart requires an `int` fail closed in both lanes;
- a valid escaped supplementary-plane scalar is exercised inside a resealed
  v3 package, while nonzero root rotations witness real property-order change;
- a two-second post-return overrun is blocking, but it cannot interrupt a hung
  synchronous parser. Cross-runtime replay minimization and automatic corpus
  promotion remain required before any disagreement can be promoted.

## Primary-source findings applied

1. [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259.html) defines JSON
   interoperability limits and notes that behavior is unpredictable when
   object member names are not unique. This supports raw-text duplicate-member
   rejection before a last-value-wins decoder can erase the evidence.
2. [RFC 7493 (I-JSON)](https://www.rfc-editor.org/rfc/rfc7493.html) requires
   UTF-8, unique object member names, and strings without surrogate or Unicode
   noncharacter code points. It also cautions that numeric values outside the
   interoperable binary64 range/precision are not reliably portable. The first
   campaign hardens string scalars and independently reproduces the tested Dart
   VM numeric lexical/canonical behavior, including the signed-64-bit boundary;
   Dart web and exact large-value-as-string schema modeling remain open.
3. [Unicode Standard Annex #15](https://www.unicode.org/reports/tr15/) defines
   canonical and compatibility normalization forms. ParkinSUM does not silently
   normalize portable strings: canonically equivalent spellings can have
   different exact bytes and may carry source meaning. The corpus distinguishes
   scalar validity from normalization or canonical-byte identity.
4. [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html) defines JCS for
   cryptographic JSON canonicalization. ParkinSUM continues to label its own
   `sorted-key-json-v1` precisely; this campaign does not rebrand it as JCS.
5. Google's archived but pinned
   [good fuzz target guidance](https://github.com/google/fuzzing/blob/master/docs/good-fuzz-target.md)
   motivates deterministic, fast, isolated targets that reach meaningful code.
   ParkinSUM therefore runs production preview code in Dart and a separately
   written parser in Node, with stable inputs and no network or user data.

## Implemented surfaces

- `config/portable_schema_fuzz_plan.json`
- `test/fixtures/portable_schema_regression_corpus.json`
- `tool/run_portable_schema_differential_fuzz_check.dart`
- `tool/portable_schema_differential_fuzz.mjs`
- `tool/portable_schema_differential_fuzz.test.mjs`
- `lib/domain/usecases/user_portable_data_package_service.dart`
- `lib/features/settings/portable_data_package_page.dart`

The Settings portable-data page shows the fixed seed, partition, corpus and
runtime counts plus the unverified release-platform boundary. It reports a
compiled configuration, not proof that a campaign just ran on the user's
device, and states that Node never runs in-app.

## Explicit remaining boundary

This is not continuous or coverage-guided fuzzing. It does not yet execute the
browser, Android, iOS, macOS, Windows or Linux release artifacts; collect
allocation telemetry; provide a preemptive hard timeout; replay both runtimes
during reduction; prove semantic equivalence-class coverage; quantify
equivalent mutants; validate issuer authenticity; perform durable import; or
establish clinical correctness. The campaign has dedicated depth, width,
source-string-token, decoded-string, decoded-key, number-token, compound-error,
manifest-inventory and integrity-contract boundary cases; package-byte and node
budgets are production-bound plan values, and the EOF compound exercises node
precedence, but pure node-boundary acceptance/rejection cases remain open.

The independent Node semantic projection is intentionally described as finite:
it currently mirrors the frozen envelope, manifest and reminder subset, not all
Dart profile, preference, medication, intake, meal and audit-link shapes,
scalars, identifier/reference relationships or record budgets. A passing
campaign therefore does not establish full-package `ready`/`corrupt` parity for
untested payloads. Those gaps keep
`portable_schema_continuous_differential_fuzz_and_corpus_promotion` queued.

Research also added the P1 queue item
`portable_schema_equivalence_class_coverage_and_semantic_mutation_adequacy`.
That item requires a formal lexical/decoded/canonical/schema/migration
equivalence model, mutation operators mapped to every invariant, equivalent and
surviving mutant accounting, unreachable-partition reasons, and independently
bound release-artifact identities.

## Reproduce

```bash
npm run portable:schema-fuzz
```

Ignored deterministic evidence is written to
`build/portable_schema_fuzz/dart_campaign.json` and
`build/portable_schema_fuzz/node_conformance.json`. A passing run contains no
minimized failure: the generic reducer is unit-tested separately, while a real
disagreement is quarantined by source digest until cross-runtime replay exists.
