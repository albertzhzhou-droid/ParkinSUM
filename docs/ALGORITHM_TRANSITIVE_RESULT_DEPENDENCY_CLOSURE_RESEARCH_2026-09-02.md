# Conservative transitive result-dependency closure research — 2026-09-02

## Scope and boundary

ParkinSUM currently hashes the source paths explicitly declared by each
`AlgorithmDescriptor`. That proves that a declared file changed; it does not
prove that every local declaration capable of influencing a result was
declared. The configuration-impact service likewise traverses reviewed
identifiers and file-level relationships, not a mechanically derived symbol
dependency graph.

This research proposes a fail-closed, conservative static-analysis gate. Its
strongest permitted success state is `complete_for_declared_local_scope` under
a versioned closed-world policy. It is engineering traceability only. Static
reachability is not observed execution, exact data flow, external-system
coverage, equation correctness, scientific validity, clinical validation,
regulatory qualification, or patient-specific safety evidence.

## Implemented prerequisite slice — 2026-09-02

The compatibility and stable-root prerequisite is now executable, while the
overall queue item intentionally remains `research_required`:

- `pubspec.yaml` exact-locks `analyzer: 14.1.0`; `pubspec.lock` binds the
  official archive SHA-256
  `62993bed6eadbe9596c5c20d5c167e7bc563c5fe266657a04ddeb93bdb84f4c9`.
  The reviewed runtime is Flutter 3.47.0 with Dart 3.13.0.
- `config/algorithm_result_root_manifest.json` uses schema v1 and the explicit
  `conservative_primary_library_v1` policy. It maps all 63 registry IDs exactly
  once to stable application-owned root/result-sink IDs and canonical package
  URIs. Its canonical SHA-256 is
  `3fbb3d17a9ab65bdfc401138aaac321eb42912344793c10ead35ab2a912fdb66`.
- `npm run algorithm:dependency-compatibility` validates manifest/Registry
  bijection and runs `AnalysisContextCollection`. The accepted local run used
  one context and resolved 63/63 roots as library units through that context's
  own `currentSession`, with no blocking error diagnostic or package-URI drift.
- The schema-v1 compatibility report binds the exact analyzer archive,
  Dart/Flutter versions, root manifest, lockfile, package config and analysis
  options digests. Durable evidence contains no absolute path, Analyzer
  object/session identity or source offset.
- Mutations cover missing, stale, swapped and duplicate roots, unsafe paths,
  URI aliases, unknown Analyzer-owned keys, traversal permutation, non-success
  results, inconsistent sessions, non-library roots, URI drift, blocking
  diagnostics, environment holds and toolchain drift.

The original compatibility-only stage used `held_pending_parkinsum_edge_generator` because no ParkinSUM-owned edge preview yet existed. Schema-v14 now adds bounded traversal of accepted local import/export candidate targets on top of the schema-v13 fail-closed part-ownership join. The preview still does not establish complete dispatch, manual-bridge, result-impact, closure, or UI coverage.

### First root-local direct-edge probe — 2026-09-26

`npm run --silent algorithm:direct-edge-probe` now runs a schema-v1
ParkinSUM-owned probe against the 63 registered primary-library units. It
records resolved method, top-level function, and constructor references using path-free library
URIs and declaration-kind/name chains. Function-value invocations and
ordinary instance-method dispatch are retained as unresolved evidence rather
than treated as closed targets. The report binds the root manifest, source
bytes for the manifest-listed root files, exact Analyzer archive identity,
lockfile, package configuration, analysis-options digest, and Dart version.
It also binds `package.json`, the declared npm entrypoint, and the generator,
runner, and focused test source digests, giving the probe and its local
verification fixture stable identities. It always reports
`closure_complete: false`.

The current local run resolved **63/63 roots** through one analysis context and
recorded **8,967** direct references: **3,338** constructor calls and **5,629**
method/top-level-function invocations. It retained **86 unresolved groups**
covering **4,972** possible polymorphic targets, **20** function-value calls,
**113** declaration-identity gaps, and **1** unresolved static target. No
environment hold or machine-absolute path appeared; report digest:
`220e1d1d70d459089815cf8e7b1d7402930d7cff523bd8589e3848d9e8c31038`. A
second invocation through the declared npm entrypoint produced the same
digest. The focused fixture tests passed 2/2 and analysis of the probe,
runner, and test found no issues.

This is a root-unit direct-edge inventory, not a declaration-level caller
graph. It does not yet include import/export/part namespace edges, getters,
setters, fields, initializers, operators, generic dispatch, inheritance,
mixins, complete extension or callback target sets, non-root source units,
untracked or ignored inputs, reviewed manual bridges, or forward/reverse
closure. The separate queue item remains `research_required`.

### Caller- and namespace-aware root probe — 2026-09-26

The schema-v2 probe adds a stable source declaration identity to each emitted
root-local call edge and keeps namespace directives in a separate edge set.
It preserves import/export/part directive order, URI literals, resolved
package URIs, import prefixes and deferred status, show/hide names, and each
conditional branch. Declaration identities use library URIs and element-kind
and name chains; no source offsets, Analyzer object IDs, or absolute paths are
serialized. Calls without a stable caller are held.

The latest run again resolved **63/63 roots** and recorded **8,967** direct
result edges. Every emitted result edge has a caller identity. The root
libraries contained **436 import branches**; no export or part directive
occurred in this registered root set. The fixture separately exercises an
export and a part directive; the part edge is recorded while its source body
is explicitly held as not analyzed. The run contains **102 unresolved
groups**: **4,972** possible polymorphic targets, **20** function-value calls,
**113** target identity gaps, **30** caller identity gaps, and **1** unresolved
static target. It has no environment holds or absolute-path leak. The report
digest is
`fa42a7d56e81c1e4b2824c22900e50c5b1245f0a27a5747b3f5930e4ae9935dd`.
The fixture also verifies a prefixed deferred import and the part-of target
URI. Focused tests passed 2/2 and analysis found no issues.

The generator still analyzes only the registered primary root units. It does
not inventory every declaration in `lib/`, follow local target bodies, prove
conditional target selection, analyze part contents, or reconcile tracked,
dirty, untracked, generated, and ignored source inputs. Therefore its
schema-v2 report remains `closure_complete: false`, and the queue item remains
`research_required`.

## Primary and official evidence

| Source | Design implication | Boundary |
| --- | --- | --- |
| [Official Dart `analyzer` 14.1.0 package](https://pub.dev/packages/analyzer/versions/14.1.0) | Exact-lock the selected analyzer release and retain its package/archive identity. | The package does not provide a clean public/internal API boundary and warns that breaking changes are inevitable; compatibility must be demonstrated, not assumed. |
| [Dart analyzer 14.1.0 `AnalysisContextCollection`](https://pub.dev/documentation/analyzer/14.1.0/dart_analysis_analysis_context_collection/AnalysisContextCollection-class.html) | Analyze the repository through contexts created for explicit included paths. | Context construction alone does not discover result roots or produce a complete call graph. |
| [Dart analyzer 14.1.0 `AnalysisSession`](https://pub.dev/documentation/analyzer/14.1.0/dart_analysis_session/AnalysisSession-class.html) and [`ResolvedUnitResult`](https://pub.dev/documentation/analyzer/14.1.0/dart_analysis_results/ResolvedUnitResult-class.html) | Resolve each analysis context through its own consistent session and retain diagnostics and semantic AST evidence. | Invalid or inconsistent results, non-success result variants, and configured blocking diagnostics must become incomplete/held evidence, not a successful closure. |
| [Dart analyzer 14.1.0 AST visitors](https://pub.dev/documentation/analyzer/14.1.0/dart_ast_visitor/) | Supply syntax and resolved-element evidence to a ParkinSUM-owned edge and dispatch generator. | A visitor is not a call-graph generator. The AST evolves, and even direct visitor implementations cannot detect every semantic shape change; coverage needs a pinned version and mutation fixtures. |
| [Dart language specification](https://dart.dev/resources/language/spec) | Define the language semantics and accepted feature specifications against which dispatch rules are reviewed. | The Dart 3 specification is still in progress, so the implementation must bind the exact language/tool version and any applicable accepted feature specifications rather than claiming timeless coverage. |
| [Reps, Sagiv, and Horwitz, *Interprocedural Dataflow Analysis via Graph Reachability*](https://research.cs.wisc.edu/wpis/papers/diku-tr94-14.pdf) | Interprocedural analysis can be framed as reachability over realizable paths under explicit finite/distributive assumptions. | The paper does not supply Dart semantics or make a general static call graph identical to runtime behavior. |
| [SLSA Build Provenance 1.2](https://slsa.dev/spec/v1.2/build-provenance) | Bind the generated report to source, toolchain, parameters, resolved dependencies, builder and content-addressed subject. | SLSA describes provenance; its dependency completeness is best effort and cannot prove semantic closure. |
| [NIST SP 800-218, SSDF 1.1](https://csrc.nist.gov/pubs/sp/800/218/final) | Integrate automated analysis, evidence collection and provenance into a maintained toolchain. | SSDF is an outcome-oriented practice framework, not a Dart dependency-analysis algorithm. |

The earlier `latest` URLs were research-discovery links only. The accepted
contract now uses version-specific 14.1.0 API links matching the exact
dependency lock. Any upgrade must repeat the compatibility and mutation spike
before changing those links or the reviewed toolchain identity.

## Proposed contract

Implementation began with the bounded analyzer compatibility and identity
spike recorded above. It demonstrates that one exact analyzer version works
with the reviewed Dart and Flutter toolchain, resolves every reviewed analysis
context through that context's own consistent `AnalysisSession`, and
re-resolves durable root identities without serializing analyzer objects. This
authorizes work on the ParkinSUM-owned edge generator; it does not authorize a
closure claim.

The gate starts from a versioned result-root manifest. Each registered
algorithm maps exactly once to application-owned logical stable root and result
sink IDs plus canonical package URI, library URI, declaration kind, enclosing
declaration and name. Analyzer `Element.id`, object identity, source offsets,
session identity and machine-absolute paths are evidence-local and are never
durable identities. Missing, duplicate, stale or ambiguous resolution is held.

The input snapshot separately binds Git-tracked HEAD, the dirty diff, untracked
files, and Gitignore-classified ignored or generated files through explicit
reviewed inclusion or exclusion. It also binds the exact dependency lock,
`.dart_tool/package_config.json`, `analysis_options.yaml`, generator identity,
and content digests without publishing machine-absolute paths. An ignored or
generated source cannot silently disappear from the declared scope.

A ParkinSUM-owned edge and dispatch generator uses analyzer evidence; the
analyzer itself is not represented as providing a complete call graph. The
generator distinguishes namespace-resolution edges from result-dependency
edges and records:

- imports, exports and parts as namespace-resolution evidence;
- direct resolved calls, constructors and operator invocations;
- function values, callbacks and tear-offs;
- getter, setter, field, constant and top-level initializer dependencies;
- inheritance, override, mixin, extension and possible polymorphic targets;
- generated-source and reviewed manual-bridge edges; and
- unresolved edges for dynamic dispatch, service location/dependency
  injection, external packages, platform channels, FFI, assets or external
  configuration.

The closed-world rule, subtype universe and target-selection algorithm are
versioned. Unsupported syntax, unsupported semantics, open-world dispatch, or a
bridge pattern without reviewed evidence is held rather than guessed complete.
Manual bridge records have typed endpoints, rationale, owner, review identity
and expiry. Because manual review cannot prove that every external mechanism was
discovered, the graph never claims complete runtime or external-system closure.

Forward closure answers which declarations may affect one registered result.
Reverse closure exports only the affected registered algorithm IDs and the
canonical graph digest for one changed declaration. The existing configuration
impact matrix remains the sole owner of algorithm-to-output, replay-fixture, UI
and requalification relationships. Shared helpers and strongly connected
components must be deterministic and must not depend on traversal order.

Every result-reachable local source must reconcile with `AlgorithmRegistry`
`sourcePaths` and the registered source-bundle digest. Every declared source
must either contain reachable owned/shared declarations or a reviewed reason
for conservative inclusion. Missing paths, orphan declarations, conflicting
ownership, configured blocking diagnostics, unresolved reachable edges, or
deterministic node, edge or depth budget exhaustion prevent
`complete_for_declared_local_scope`. A wall-clock cancellation is a held
operational failure; it cannot shape a canonical graph or produce truncated
success.

## Verification and UI requirements

Mutation fixtures must cover omitted helpers, import/export aliases, part
files, callbacks and tear-offs, getters and initializers, operator and
generic/extension dispatch, overrides and mixins, generated/manual bridges,
dynamic and open-world unresolved calls, shared cycles, stale exclusions and
removed descriptor paths. They must also prove that inconsistent sessions,
non-success analysis results, unsupported constructs, ignored generated inputs,
and deterministic budget exhaustion are held. Repeated runs and traversal-order
permutations must produce byte-identical canonical reports.

Algorithm Observatory should expose, for every algorithm, direct and
transitive local dependencies, shared ownership, declaration-to-algorithm
reverse impact, edge class, unresolved blockers, declared scope and
report/toolchain identity. It must provide an accessible table alternative,
omit machine-absolute paths, and state that
`complete_for_declared_local_scope` is conservative engineering traceability
rather than observed execution, exact data-flow proof, external-system
coverage, or scientific/clinical evidence.

## Decision

The work is recorded as
`algorithm_transitive_result_dependency_closure` with status
`research_required`, effort 5 and score 10. Its only queue prerequisite is the
shipped algorithm atlas; configuration identity depends on this closure so the
absence of closure cannot become a circular completion prerequisite. The
bounded analyzer compatibility, logical stable roots, and the schema-v11
supported-call, property, operator, indexed-access, executable-reference,
declared-type-relation, runtime type-expression, constructor-initializer, and
type-alias-target reachability preview are implemented.
The probe inventories
all 444 discovered regular Dart files under `lib/`, records accepted/held
unit observations against unique package URIs, separates registered-root
edges from source-local helper and part edges, and computes bounded reachability
over supported calls, resolved executable references, property references,
operators, indexed accesses, declared inheritance, mixin, extension and
extension-type representation relations, and resolved type tests, casts and
type literals, plus constructor field initialization, constructor redirection,
and resolved super-constructor references, plus direct targets for resolved
non-generic named type aliases. The property slice maps field-backed accessors to stable
backing-field identities, while explicit getter and setter declarations retain
accessor identities. Dynamic operator targets, open dispatch sets, unresolved
type relations, generic type arguments, and generic, nested, function, or record
type-alias target shapes retain explicit HOLD records. Since manifest roots
identify whole primary libraries rather than exact callable result sinks, this
is a conservative library-seeded preview, not result-specific closure. Until the full
declaration-level edge and dispatch generator, closed-world and
unsupported/open-world HOLD policies, manual bridges, whole-input snapshot,
and forward/reverse closure are executable, this evidence cannot be called
`complete_for_declared_local_scope`.

## 2026-09-26 schema-v3 source-universe probe

The pinned Analyzer probe now discovers every regular `.dart` file under
`lib/` and records a path-free package URI, result variant, session consistency,
blocking diagnostics, supported edge counts and unresolved count for each
unit. The current checkout produced 444/444 accepted observations, and the
unique source-unit URI set reconciled to the discovered file count. A separate
SHA-256 snapshot binds the bytes at repository-relative `lib/...` paths.

Across the 63 registered roots it retained 8,967 algorithm-owned direct-call
edges. The source-local declaration graph contains 43,355 supported direct
call edges across roots, helpers and part units without assigning helper
ownership to an algorithm. Namespace branches remain a separate AST-derived
collection: 2,228 total, with 436 root-attributed and 1,792 source-local
branches. Import/export branch order, conditional URI branches, prefixes,
deferred imports, combinators, `part`, and `part of` are retained. Fixture tests
also verify helper and part calls are visited while source-local edges have no
inferred algorithm owner.

The report records 102 root unresolved groups (5,136 occurrences) and 589
source-unresolved groups (18,785 occurrences). All 63 primary roots resolve;
there are no environment holds or absolute/file URI strings in the report.
`closure_complete` remains false because this probe covers only its supported
direct-call classes, does not join part declarations back to their registered
root ownership, and does not yet model property/initializer/operator edges,
closed-world dispatch, typed bridges, or transitive forward/reverse closure.
The report also lacks a tracked/dirty/untracked/Gitignore and non-`lib/` source
snapshot. This is static engineering traceability only, not runtime behavior,
exact data flow, scientific evidence, or clinical validation.

## 2026-09-26 schema-v8 declared type-relation reachability preview

The schema-v8 collector records class `extends`, `with`, and `implements`
relations; enum mixin and interface relations; mixin `on` constraints and
interfaces; extension `on` types; extension-type interfaces; and the resolved
extension-type representation type. The relation source is the stable class,
enum, mixin, extension, or extension-type declaration identity. These edges
participate in the conservative declaration traversal, while dynamic override
and extension dispatch remain open. Unresolved relation targets are held.
Generic relation arguments produce a HOLD because their full type structure is
not modeled; named type aliases keep an edge to the alias and a HOLD because
the aliased target shape is not closed.

The focused synthetic fixture covers class inheritance, mixins, interfaces,
mixin constraints, named and generic extensions, extension-type interface and
representation edges, and type-alias and generic-argument HOLDs. The production
scan resolves 63/63 roots and 444/444 source units, and emits 22,348 root edges,
114,033 source declaration edges, and 2,228 namespace branches. It includes 66
root and 313 source `inheritance_extends` edges; 10 root and 17 source mixin
edges; 3 root and 74 source interface edges; and 1 root and 4 source extension
`on` edges. No production mixin-constraint or extension-type relations were
present in this snapshot. The root-seeded previews sum to 100,681 reachable
edges and 22,399 reached declarations, with maximum depth 11. The report keeps
6,072 reachability HOLD groups across 155,324 occurrences, including 45,138
external-target and 107,268 possible-polymorphic-target occurrences. It has
363 root unresolved groups (15,470 occurrences) and 2,000 source-unresolved
groups (63,020 occurrences). There are no environment holds or absolute/file
URI leaks, and `closure_complete` remains false.

The focused Flutter fixture suite passed 3/3. The focused queue contract passed
1/1; the complete queue suite remains 40/41 solely because its pre-existing
global limit allows at most three `in_progress` items while the queue has
four. Dart analysis reported no issues, then exited 1 because the sandbox
denied an external telemetry timestamp update. Two consecutive full scans
produced canonical report digest
`bd4097b28e1f8623a6e14b36e241641ee2dc0aab430dbf7c1acacc88896e5c39`.
Independent verification matched the canonical report, manifest, all seven
bound toolchain/configuration/source files, root and `lib/` snapshots, all
63 accepted roots and 444 accepted source units. It found no path leaks,
environment holds, or exceeded traversal budgets.
Dynamic override target sets, complete extension applicability, generic type
argument closure, and alias target expansion remain unimplemented, in addition
to the existing result-sink, callback, external bridge, SCC/reverse-closure,
and whole-input snapshot boundaries. This remains static engineering
traceability, not runtime behavior, exact data flow, scientific evidence, or
clinical validation.

## 2026-09-26 schema-v9 runtime type-test, cast, and type-literal reachability preview

The schema-v9 collector records resolved `IsExpression` targets as
`type_test`, `AsExpression` targets as `type_cast`, and `TypeLiteral` targets
as `type_literal`. These edges identify the referenced type declaration from
the enclosing stable caller and participate in the conservative declaration
traversal. Generic type arguments remain explicit HOLDs; unresolved or
non-named type shapes are not guessed.

The synthetic fixture exercises all three expression forms from a stable
function caller. The production scan resolves 63/63 roots and 444/444 source
units and emits 22,677 root edges, 116,027 source declaration edges, and 2,228
namespace branches. It includes 164 root and 1,091 source `type_test` edges,
165 root and 892 source `type_cast` edges, and 11 source `type_literal` edges;
the registered root libraries contain no type literals in this snapshot. The
root-seeded previews sum to 102,293 reachable edges and 22,570 reached
declarations, with maximum depth 11. The report retains 6,439 reachability
HOLD groups across 157,449 occurrences, including 46,702 external-target and
107,268 possible-polymorphic-target occurrences. It has 378 root unresolved
groups (15,522 occurrences) and 2,061 source-unresolved groups (63,194
occurrences). No environment holds or path leaks occurred, and
`closure_complete` remains false.

The focused Flutter fixture suite passed 3/3, including type tests, casts,
type literals, and the earlier declared type-relation cases. Dart analysis
reported no issues. The focused queue contract passed 1/1; the full queue
suite remains 40/41 solely because its existing global invariant finds four
`in_progress` items where at most three are allowed. Two consecutive full
scans produced canonical report SHA
`8239d5c3829ec60333e15015f1642b1712f68eac5b026b9b228abaf66d7ea917`.
Independent verification matched the canonical report and all ten bound
manifest, toolchain/configuration/source and source-snapshot identities. All
63 roots and 444 source units were accepted, with no path leaks, environment
holds, or exceeded traversal budgets.
Generic type-argument closure, aliases, runtime dispatch targets, and the
existing exact result-sink, callback, external bridge, SCC/reverse-closure,
and whole-input snapshot boundaries remain open. This is static engineering
traceability, not runtime execution, exact data flow, scientific evidence, or
clinical validation.


## 2026-09-26 schema-v10 constructor-initializer reachability preview

The schema-v10 collector records `constructor_field_initialization` edges for
field-initializer lists and initializing-formal parameters. It uses the
resolved `ConstructorElement.superConstructor` and
`ConstructorElement.redirectedConstructor` to record
`super_constructor_call` and `constructor_redirection` edges, including
Analyzer-resolved implicit superclass constructor selection. Calls to
implicit-default, mixin-application, or extension-type recovery constructors
retain a `constructor_body` HOLD because those generated bodies are not
source declarations. Missing field or constructor targets are held explicitly.

The synthetic fixture exercises field formals, explicit field initializers,
named and unnamed superclass constructors, a generative redirect, and an
implicit superclass invocation. It also verifies that uses of implicit or
generated default constructors stay held. The production scan resolves 63/63
roots and 444/444 source units and emits 23,501 root edges, 124,018 source
declaration edges, and 2,228 namespace branches. It includes 644 root and
6,751 source field-initialization edges and 180 root and 1,240 source
super-constructor edges; no production constructor-redirection edge occurred
in this snapshot. Implicit/generated constructor bodies add 21 root and 132
source HOLD occurrences. The root-seeded previews sum to 112,344 reachable
edges and 24,471 declarations, with maximum depth 11. The report retains 6,952
reachability HOLD groups across 158,765 occurrences, including 47,923
external-target and 107,268 possible-polymorphic-target occurrences. It has
388 root unresolved groups (15,543 occurrences) and 2,138 source-unresolved
groups (63,326 occurrences). `closure_complete` remains false.

Flutter fixture tests passed 3/3 and Dart analysis reported no issues. The
focused queue contract passed 1/1; the full queue suite remains 40/41 because
the shared queue has four `in_progress` items against its existing maximum of
three. Two consecutive full scans produced canonical report SHA
`7ec08612e9606c1981c719509d499f6260a5764f25a35be59d9e8ad139c79370`.
Independent verification recomputed the report digest, canonical root
manifest, all seven bound source/configuration files, and both root and all-
`lib/` source snapshots. All 63 roots and 444 units were accepted; no
environment holds, path leaks, or exceeded reachability budgets were found.
Complete initializer semantics remain open for generated bodies, external
implementations and unmodeled initializer forms, alongside the existing
result-sink, callback, dispatch, bridge, SCC/reverse-closure, and whole-input
snapshot boundaries. This remains static engineering traceability, not runtime
execution, exact data flow, scientific evidence, or clinical validation.

## 2026-09-26 schema-v11 type-alias target preview

The schema-v11 collector inspects the Analyzer-resolved `TypeAliasElement`
through both public type-alias AST forms. A non-generic alias to a direct named
interface target emits a `type_alias_target` edge from the alias declaration
to that target. A use-site relation to such an alias no longer adds a redundant
alias-shape HOLD because the alias declaration now carries the target edge.
Generic aliases, instantiated targets, nested aliases, function aliases,
record aliases, and unavailable alias elements remain explicit HOLDs.

The fixture proves `InheritedAlias -> InheritedBase`, and verifies that generic
type parameters and function-alias shapes stay held. The production snapshot
contains no direct non-generic named alias target edge; it has 3 root and 25
source occurrences held for unsupported alias shapes. The scan still resolves
63/63 roots and 444/444 source units and emits 23,501 root edges, 124,018
source declaration edges, and 2,228 namespace branches. The 63 root previews
sum to 112,344 reachable edges and 24,471 declarations at maximum depth 11.
Reachability holds rise to 6,974 groups across 158,798 occurrences. The base
inventory records 391 root unresolved groups (15,546 occurrences) and 2,150
source-unresolved groups (63,351 occurrences). `closure_complete` remains
false.

Dart analysis reported no issues and the focused Flutter fixture suite passed
3/3. Two consecutive scans produced canonical report SHA
`6295555a9f12f713ec905d862870dc6da33b7993139ecf66b5f7a528d6807211`.
Independent input and report hash verification and queue checks are recorded
with the iteration timeline. This improves type-alias traceability only; it
does not close arbitrary alias expansion or generic type structure.

## 2026-09-26 schema-v4 supported-call reachability preview

The probe now emits one supported-call reachability summary for each of the
63 registered primary-library roots. Because the manifest currently identifies
whole libraries instead of precise result-producing declarations, traversal
seeds from all supported caller declarations observed in each root library.
It follows only accepted local-package source units and supported direct-call
edges. External targets remain visible as holds and are not traversed.

The current report records 27,585 reachable call edges across 6,062 reached
declarations, with maximum depth 11. No per-root deterministic node, edge, or
depth budget was exceeded. The report retains 1,587 reachability-hold groups
covering 45,085 occurrences, including 17,541 external-target occurrences and
25,472 possible-polymorphic-target occurrences. Other holds retain unavailable
source or target identities, function-value and static unresolved calls, and
unexpanded conditional namespace branches. Deferred imports are not modeled,
and part-body/root ownership is not joined. The base inventory still records 102 root unresolved
groups (5,136 occurrences) and 589 source-unresolved groups (18,785
occurrences); unresolved and open-world edges are not silently treated as
closed.

An independent traversal recomputed all 63 per-root reachability summaries
with no mismatches. Two consecutive full probe runs produced the same canonical
report digest:
`1d195b2df40bd52e9917f2f631fb82f597bb52784d95f5ccd729a3ba86315d0c`.
The report remains path-free for graph identities and binds the v4 generator,
runner, focused probe test, package and lock inputs, and the all-`lib/` byte
snapshot. It reports no environment holds, no absolute/file URI leaks, and
`closure_complete: false`.

This preview does not bind reachability to exact result sinks or prove data
flow. It does not traverse external targets or close possible polymorphic
dispatch, callbacks, function values, or unresolved declaration identities.
Conditional imports are not selected, deferred imports are not expanded, and
part declarations are not reconciled to registered-root ownership. Getter,
setter, field, initializer, operator and inheritance edges, reviewed bridges,
strongly connected component and reverse closure, impact-package binding, and
tracked/dirty/untracked/Gitignore plus non-`lib/` source snapshots remain open.
The queue item therefore remains `research_required`; this static engineering
traceability is not runtime evidence, scientific evidence, or clinical
validation.

## 2026-09-26 schema-v5 property read/write reachability preview

The schema-v5 source collector now emits supported `property_read` and
`property_write` edges from resolved property references. It records
top-level/static/instance fields and explicit getter/setter declarations;
synthetic accessors induced by a variable point to the variable's stable field
identity, so a read can reach declarations in that field's initializer. Simple
and compound assignment plus prefix/postfix increment and decrement use the
Analyzer's resolved read/write targets. Unqualified field references and
prefixed/property access are also collected. Instance access preserves an
open-polymorphic-target HOLD; this does not infer a closed override set.

The current full-library scan resolves 444/444 source units and emits 18,680
algorithm-owned root edges, 97,395 source-local declaration edges, and the same
2,228 separate namespace branches. The supported-call reachability preview
contains 83,478 reachable edges and 21,552 reached declarations across 63/63
roots, with maximum depth 11. No deterministic node, edge or depth cap was
reached. It records 3,091 reachability-hold groups covering 116,406
occurrences, including 28,826 external-target occurrences and 85,145
possible-polymorphic-target occurrences. The base inventory retains 173 root
unresolved groups (12,385 occurrences) and 1,056 source-unresolved groups
(52,277 occurrences). The report has no environment holds or absolute/file URI
leaks, and `closure_complete` remains false.

The focused fixture now exercises instance and static field reads/writes,
top-level variable reads/writes, explicit getters/setters, compound assignment,
and the getter-body-to-backing-field edge. An independent Analyzer smoke run
resolved the fixture and verified all of those edge classes. An independent
traversal matched all 63 per-root summaries and graph digests, all 3,091 blocker
groups, the canonical report SHA, and all ten bound input and source-snapshot
hashes; it found no absolute/file URI leaks. Two consecutive full runs produced
the same canonical report digest:
`b408090090217087bbd7b2cb02445e0f8024c6b4eebfc22e68c07e0087b4b8c1`.
The focused Flutter fixture suite passed 3/3. Dart analysis printed `No issues
found`; its CLI then exited 1 because the sandbox denied a telemetry metadata
timestamp update outside the workspace.

This is still only a supported direct-reference slice. It does not model
operator or indexed access, complete initializer semantics, all possible
dynamic/polymorphic targets, typed bridges, SCC/reverse closure, precise result
sinks, or non-`lib/` and Gitignore-classified source inputs. The queue item
remains `research_required`; the graph is static engineering traceability, not
runtime behavior, exact data flow, scientific evidence, or clinical validation.

## 2026-09-26 schema-v6 operator and indexed-access reachability preview

The schema-v6 collector adds resolved `binary_operator`,
`compound_assignment_operator`, `prefix_operator`, `postfix_operator`,
`index_read`, and `index_write` edges. Compound indexed assignments use the
Analyzer-resolved index read target, compound operator target, and index write
target. In write context, the index expression may not carry its ordinary
`staticType`; the enclosing compound-assignment node owns the resolved read and
write elements. Dynamic targets with no resolved method and resolved candidates
with open target sets remain explicit HOLDs. Recorded instance operator methods
also retain the existing polymorphic-dispatch HOLD.

The final full-library scan resolves 444/444 source units and emits 21,687
algorithm-owned root edges, 110,573 source-local declaration edges, and 2,228
AST-preserved namespace branches. Across 63/63 root-seeded summaries, the
preview contains 97,460 reachable edges and 22,199 reached declarations summed
across roots, with maximum depth 11. No deterministic node, edge, or depth
budget was exceeded. It records 5,599 reachability-hold groups across 152,491
occurrences, including 42,808 external-target and 106,838
possible-polymorphic-target occurrences. The base inventory retains 345 root
unresolved groups (15,435 occurrences) and 1,872 source-unresolved groups
(62,747 occurrences). The report has no environment holds or absolute/file URI
leaks, and `closure_complete` remains false.

The focused fixture covers resolved user-defined binary and unary operators,
plain indexed reads and writes, compound indexed reads/operators/writes, and
dynamic operator HOLDs, alongside the prior property and call cases. The
focused Flutter fixture suite passed 3/3. Two consecutive full scans produced
the same canonical report SHA:
`dba4a0f73b0e71f3c79e18ed9a1fd17a510a1834dffe12e5751732565e077a7e`. An
independent check recomputed the canonical report hash and all ten bound
manifest, toolchain/configuration, generator, runner, test, and source-snapshot
hashes; all matched. The report binds all 444 discovered `lib/` sources. Dart
analysis printed `No issues found`, then exited 1 when the sandbox denied an
external telemetry timestamp update.

Generic dispatch and complete operator target sets, complete initializer
semantics, reviewed typed bridges, SCC and reverse closure, exact result-sink
binding, and tracked/dirty/untracked/Gitignore plus non-`lib/` source snapshots
remain open. The queue item remains `research_required`; this is static
engineering traceability, not runtime behavior, exact data flow, scientific
evidence, or clinical validation.

## 2026-09-26 schema-v7 function, method, and constructor reference reachability preview

The schema-v7 collector records `function_value_reference` edges for resolved
top-level functions and method tear-offs, and `constructor_tear_off` edges for
named and unnamed constructor references. When Analyzer resolves a
`FunctionExpressionInvocation` to an executable declaration, that candidate is
also recorded as a `function_expression_invocation` edge. The invocation still
retains a HOLD because function-value flow and the complete callback target set
are not closed; unresolved invocation targets remain explicit as well.

The final full-library scan resolves 63/63 roots and 444/444 source units, and
emits 22,268 root edges, 113,625 source declaration edges, and 2,228 namespace
branches. Function-value references account for 578 root edges and 3,022
source-local edges; constructor tear-offs add 3 root and 26 source-local edges.
Across the 63 bounded root previews, the report sums to 100,601 reachable
edges and 22,301 reached declarations, with maximum depth 11. No deterministic
node, edge, or depth budget was exceeded. The report retains 6,035 reachability
HOLD groups across 155,186 occurrences, including 45,070 external-target and
107,218 possible-polymorphic-target occurrences. The base inventory contains
362 root unresolved groups (15,468 occurrences) and 1,948 source-unresolved
groups (62,957 occurrences). There are no environment holds or absolute/file
URI leaks, and `closure_complete` remains false.

The focused fixture verifies top-level functions, instance methods, named and
unnamed constructors as tear-offs, and that indirect invocation remains held.
The Flutter fixture suite passed 3/3. Two consecutive full scans produced
canonical report SHA
`27347cddb2fceec38629f6a350139b4d5e40c29cdb4312d1347199b4866703ad`.
Independent verification matched the report hash and all ten bound manifest,
toolchain/configuration, generator, runner, test, and source-snapshot hashes.
Dart analysis printed `No issues found`; the CLI then exited 1 when the sandbox
denied an external telemetry timestamp update.

Complete function-value flow, local closure identity, callback target-set
closure, generic dispatch, and polymorphic target closure remain open, along
with the previously listed initializer, bridge, result-sink, SCC/reverse, and
whole-input snapshot boundaries. This remains static engineering traceability,
not execution, exact data flow, scientific evidence, or clinical validation.


## 2026-09-27 schema-v12 bounded cycle and reverse-ownership preview

Schema-v12 adds two deterministic summaries to the existing path-free report.
Each root-seeded reachability record now carries the sorted declaration identities
it reached and strongly connected components found within that root's accepted,
supported local subgraph. The SCC pass uses iterative Kosaraju traversal with
sorted adjacency, includes multi-node cycles and self-loops, and hashes sorted
member identities. A separate inverse index maps each reached declaration
identity to the algorithm IDs whose whole registered primary-library roots
reached it. Reverse rows explicitly set `exact_result_impact: false` and
`closure_complete: false`; the report never promotes these previews to a
complete closure.

Two consecutive `npm run --silent algorithm:direct-edge-probe` full runs
resolved 63/63 roots and 459/459 discovered regular Dart units under `lib/`,
with source inventory reconciliation true. The scan emitted 23,602
algorithm-owned root edges, 128,477 source-local declaration edges, and 2,277
AST-preserved namespace branches. Across the 63 bounded root summaries it
records 113,908 reachable edges and 24,649 reached declarations, maximum depth
11, and 121 SCC components containing 139 declaration occurrences. The inverse
index contains 9,104 declaration identities and 24,649 algorithm-declaration
pairs; 4,344 declarations have multiple candidate root owners, and the maximum
owner count is 61. The canonical schema-v12 report digest was identical across
both runs: `00964e8db2fa406996aae98a856b839d23ac05f92f40f2e49815af21e15f8015`.

The same report records 7,053 reachability-HOLD groups across 161,473
occurrences, 393 root-unresolved groups across 15,623 occurrences, and 2,246
source-unresolved groups across 66,259 occurrences. No per-root node, edge, or
depth budget was exceeded; no environment holds or absolute/file-URI leaks
were found. The focused Dart suite passed 4/4, the queue-boundary Node test
passed 1/1, and scoped Dart analysis reported no issues. The generated report
remains under ignored `build/`; this increment did not publish it as app data.

These numbers describe repeated static traversal of the current local `lib/`
source inventory. Every root still seeds from a whole primary library rather
than its exact callable result sink. The inverse rows therefore show candidate
source ownership, not which output changes, and they do not close dynamic or
generic dispatch, callback flow, reviewed bridges, part ownership, external or
non-`lib/` inputs, tracked/dirty/untracked/Gitignore snapshots, or impact-package
bindings. The Observatory still does not load or execute this offline report.
The queue remains `research_required`, `closure_complete` remains false, and no
runtime, exact-data-flow, scientific, clinical, or patient-specific claim
follows from this preview.

## 2026-09-27 schema-v13 Analyzer-validated part ownership join

Schema-v13 records an optional `containing_library_package_uri` for every
source-unit observation and adds a path-free `part_ownership` preview. A part
unit is eligible only when Analyzer resolves it in the same accepted session,
reports a package URI for its containing library, that library is an accepted
source unit, and exactly one library AST `part` branch targets the part URI.
Reachability then enters that part through the validated library branch and
accepts declaration edges whose source is that visited part. Unmatched,
ambiguous, missing, or held ownership stays a typed reachability HOLD. No
augment relationship or conditional/deferred namespace interpretation is
inferred.

The production `lib/` scan still contains 459/459 accepted regular Dart units,
with zero part units and zero part-ownership rows, so this increment does not
claim new production part coverage. The Analyzer fixture now exercises a real
library and `part of` unit: a registered-root caller reaches `partCaller`, and
the part-local constructor edge reaches `PartLeaf`; the summary reports two
visited source units and does not emit the old unconditional part-ownership
HOLD.

Two consecutive declared full scans produced identical schema-v13 digest
`1f4314ae161c44b8ddd01862a73d7b0041eefaa12b576018055469bf4ba6c2f6`. They
resolve 63/63 roots and 459/459 source units; the 63 summaries total 749
reachable source-unit visits, 113,908 reachable edges and 24,649 declarations
at maximum depth 11. The bounded SCC preview remains 121 components (139
declaration occurrences), and reverse ownership remains 9,104 identities and
24,649 root-declaration pairs. The run records 7,053 reachability-HOLD groups
/ 161,473 occurrences, 393 root-unresolved groups / 15,623 occurrences, and
2,246 source-unresolved groups / 66,259 occurrences. No reachability budget or
environment hold occurred; the report contains no absolute/file-URI leak and
`closure_complete` remains false. The focused Dart suite passed 4/4, scoped
Dart analysis reported no issues, and the focused queue contract passed after
being updated for the v13 snapshot.

This is Analyzer-backed static source ownership on a bounded fixture, not
runtime behavior, exact result-sink impact, a complete declaration closure,
scientific evidence, clinical validation, or patient-specific evidence. The
queue remains `research_required`; exact callable sinks, open-world dispatch,
callbacks, augment and manual-bridge ownership, repository-state snapshots,
impact binding, and forward/reverse Observatory presentation remain open.

## 2026-09-27 schema-v14 conservative namespace source traversal

Schema-v14 recursively visits accepted local source units named by `import`
and `export` branches found in each root's already reachable libraries. It
includes every candidate branch for conditional directives and deferred
imports, while preserving separate HOLDs for conditional target selection,
deferred loading, unresolved targets, source units outside the accepted `lib/`
inventory, and conflicting branch semantics. Per-root digests now bind sorted
reachable source URIs and namespace-branch semantic variants. A deterministic
100,000-source-unit-per-root cap prevents unbounded traversal. The report also
adds a sorted reverse index from accepted reachable source URI to candidate
algorithm owners; this remains source ownership, not exact result impact.

The Analyzer fixture verifies recursive traversal through a root import,
conditional import candidates, a deferred import, an export, a part unit, and
a helper's own import. It reaches five source units across seven namespace
branches, records selection and deferred-loading HOLDs, and confirms the
source-unit budget stops traversal deterministically. Production has nine
conditional namespace rows across root and source observations, three
conditional-selection HOLD occurrences, no deferred namespace directives,
and still zero part units or ownership rows.

Two consecutive declared full scans produced identical schema-v14 digest
`3fed4b14668a854a32d61da35efdd76099e80ce0b692a38df4420c2e05488ff2`. They
resolve 63/63 roots and 459/459 accepted source units; the 63 summaries total
1,025 reachable source-unit visits, 2,926 reachable namespace-branch visits,
113,908 reachable declaration edges, and 24,649 declarations at maximum depth
11. Reverse declaration ownership remains 9,104 identities and 24,649
algorithm-declaration pairs; reverse source ownership contains 211 URIs and
1,025 algorithm-source pairs. The bounded SCC preview remains 121 components
(139 declaration occurrences). Reachability records 8,694 HOLD groups /
200,014 occurrences; root-unresolved and source-unresolved counts remain 393 /
15,623 and 2,246 / 66,259. No budget or environment hold occurred, no absolute
or file-URI leak was found, and `closure_complete` remains false. Canonical
hash recomputation and generator, runner, and test-source digest checks passed.
The focused Flutter suite passed 4/4, scoped Dart analysis reported no issues,
and the focused queue contract passed 1/1.

This expands a conservative static candidate source graph only. It does not
model which conditional branch or deferred library executes, prove exact
callable result-sink impact, close open-world dispatch or callbacks, bind
manual bridges or repository state, or provide runtime, scientific, clinical,
or patient-specific evidence. The queue remains `research_required`.
