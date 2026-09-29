# Open-source influence and license firewall

Reviewed: 2026-09-29

## Decision

ParkinSUM may study public open-source systems to understand architecture,
failure modes, test strategy, and interaction patterns. A public repository or
an SPDX label does **not** authorize copying, linking, vendoring, adapting, or
redistributing code, model projects, datasets, reports, fonts, screenshots, or
generated artifacts.

The repository now has an offline, versioned firewall. Every supported GitHub,
GitLab, or Bitbucket project found in the configured research documents,
complete-app queue, application source, tool source, bundled assets, or
`pubspec.yaml` must have one entry in
`config/open_source_influence_inventory.json`. Each entry binds the official
repository, a full commit SHA, declared and repository-detected license evidence,
reviewed artifact types, the concepts studied, transfer status, authorization,
release paths, and obligations.

This is repository engineering review, not legal advice.

## Requirements and architecture

Functional requirements:

- discover every supported GitHub, GitLab, or Bitbucket repository in the reviewed documents, queue, source, tools, assets, and Pubspec roots;
- distinguish source code, documentation, UI patterns, API contracts, model,
  data, font, report, and release assets;
- distinguish `concept_only`, `development_linked`, `copied`, `linked`,
  `vendored`, and `derived`;
- pin a full upstream commit instead of relying on a moving default branch;
- prevent unresolved or reciprocal-license content crossing the release
  boundary without explicit obligations and review;
- detect unreviewed `vendor`, `third_party`, `external`, or `upstream`
  directories in production roots;
- run offline in local verification and CI.

Non-functional requirements:

- deterministic and network-independent after review;
- fail closed on new references, missing entries, duplicate identities,
  malformed commits, license overstatement, and release-boundary drift;
- no automatic code import or license decision;
- preserve the distinction between release hygiene and scientific validity.

```text
docs + queue + source + tools + assets + pubspec
              |
              v
  GitHub repository discovery --------+
                                      |
versioned influence inventory --------+--> strict offline validator
                                      |      - identity/commit/license
production directory scan ------------+      - artifact/transfer class
                                             - obligations/local paths
                                             - vendored-path drift
                                                      |
                       +------------------------------+
                       | pass                         | block
                       v                              v
              verify:all + CI              explicit review/update
```

The checker does not fetch the network during CI. Network research updates the
pinned snapshot deliberately; a separate future drift workflow must propose a
reviewable diff rather than silently rewriting the inventory.

## Current reviewed boundary

The reviewed inventory contains 99 pinned upstream influences (96 GitHub, two Bitbucket, and one GitLab), including three typography-provenance repositories discovered from source, bundled assets, and the Pubspec, plus OpenClinical PROformajs, DIKB Evidence Analytics, GREvaluator, CAREPATH CDS Specifications, AHRQ CQL Testing Framework, the 2025 two-stage conformal Parkinson medication study, its 2026 CASCADE successor, PRANA, ClinicClaw, ConGaIT, LangCare MCP FHIR as a CDSS connector/workflow reference, MD2SKILL as a pinned guideline-prompt lead with unresolved repository and asset licensing, the Microsoft Azure Healthcare Digital Quality CQL SDK as a pinned, concept-only CQL/PostgreSQL execution-engine reference, and Fully Open Meditron as a pinned LLM-CDSS research-pipeline reference, plus ClinCalc as a pinned mixed-license clinical-calculator engine reference:

- 89 are concept-only and have no authorized local paths or distributed
  artifacts;
- 15 repository-license records remain unresolved as `NOASSERTION`; README claims and GitHub labels are not treated as verified license text;
- Flutter 3.47.0 (`4cf2416…`) and `flutter_local_notifications` 22.3.0
  (`b475bc8…`) plus `share_plus` 13.3.0
  (`2c5b4935c85fdbfeffea2bd68c9286c064ed8b7c`) are the three release-linked
  dependencies, bound to `pubspec.yaml` and `pubspec.lock`, with
  license-notice and generated-license-bundle obligations. `share_plus` is
  used only for explicit handoff HTML file sharing; Linux file sharing is
  unsupported, and its system result does not prove recipient receipt or save;
- Two derived font sets cross the release boundary with separately pinned family terms: [Geist](https://github.com/vercel/geist-font/releases/tag/1.8.0) and [Source Serif 4](https://github.com/adobe-fonts/source-serif/releases/tag/4.004R). The checked-in versions remain Geist 1.800, Geist Mono 1.701, and Source Serif 4.004, and their OFL texts are included through Flutter Pubspec. The 2026-09-29 publication review confirmed that the four Source Serif static derivatives retained the upstream Reserved Font Name `Source`. Their embedded family is now `Parkin Serif Display`, with matching unique, full and PostScript names. Copyright and license records remain intact; all 15 non-name/non-head tables and every head byte except the required checksum were verified byte-identical, preserving outlines, shaping and metrics. Asset filenames and the Flutter `SourceSerif4Display` alias remain compatible. `OFL-SourceSerif4.txt` is the LF-normalized [pinned Adobe license](https://github.com/adobe-fonts/source-serif/blob/a9eaef81588dddd479f2275d87b3707ed7ae2847/LICENSE.md), SHA-256 `acb2b8ba7420e412cd26f7d2b05d1692951ea8c6f4118a3a2c903a0f1fff1feb`. This resolves the local derivative naming issue without claiming external legal approval;
- Inventory schema v7 assigns each of the 14 local font and OFL notice files exactly one file-level record. Each record binds its path and current SHA-256 to the pinned family license evidence and applicable notice; the offline checker rejects missing or duplicate paths, changed bytes, mismatched identities, unsafe paths and broken notice links. Font tests also preserve the renamed embedded Source Serif family and the original copyright notice. The fonts were originally instantiated from Google Fonts revision `87a44ad3d4535f7b3a5a715a08e8944f144afd06`; byte equivalence of those derived binaries to upstream inputs is not asserted. [Google Fonts licenses vary by family](https://github.com/google/fonts/blob/main/README.md), so the collection-level record remains `NOASSERTION` and concept-only;
- CQF CQL 5.3.0 (`engine`, `engine-fhir`, and `quick`) at source commit
  `88693baefa482ec6f189c90113cfe1f3f4ce9d31`, CQF `cql-execution` 3.3.2 at
  `1991335e7ad490a8db88a05dd7f03dc3eecbda6d`, CQF `cql-exec-fhir` 2.1.6 at
  `f3f9a968d597e2f029533a9e5cb1e6a643f2f69a`, Google CQL at `b9169ccd…`, and
  Google FhirProto Go at `31c3b614…` are the five `development_linked`
  influences. CQF JVM checks nine synthetic literal cases against the CQF
  JavaScript path from the same implementation family and separately evaluates
  three fixed FHIR R4 retrieval cases with its pinned model-info module; Google
  CQL directly parses the literal corpus and evaluates the same three retrieval
  cases through its local Bundle retriever, plus six fixed Observation/ValueSet
  cases with a local synthetic expansion. FhirProto Go v0.7.4 parses those nine
  fixed synthetic Bundles. The JavaScript FHIR data-source check separately
  evaluates six Observation and local synthetic ValueSet cases; a companion
  CQF JVM run applies a fixed local version-aware `TerminologyProvider` and
  exercises both CQL `Code in ValueSet` and filtered FHIR retrieval against the
  same six Observation cases. Google CQL agrees with JavaScript on all six
  membership outcomes; both differ from the version-aware JVM provider on the
  `Coding.version: v2` fixture because the pinned Go interpreter omits that
  field in its terminology call. The provider-specific result is recorded
  without a conformance claim. A test
  confirms the upstream `PatientSource` does not filter `Observation.subject`,
  so the JavaScript harness filters foreign resources before evaluation and
  the bounded JVM retrieve provider scopes by Patient. All five
  influence entries have dependency-lock, development-only, and license-notice
  obligations and are excluded from release distribution. An additional
  terminology reference, the CQF `cql-exec-vsac` 2.2.0 adapter at
  `fe7c19cc3e51095ec050b60486598023afa3ac98` remains concept-only: VSAC
  refresh requires a UMLS API key and
  network access, and neither the package nor its terminology assets are used;
- thirteen repositories remain `NOASSERTION` and therefore concept-only. These
  include the mixed-license Google Fonts collection, which cannot inherit one
  repository-wide font license, and a one-commit food-drug interaction
  detector whose pinned tree has no license file; the latter remains a
  source-available research lead, not confirmed open-source software;
  DIKB Evidence Analytics is also recorded as unresolved because its README
  says licensing varies by subproject, with GNU GPL, Apache-2.0, or MIT terms;
  no repository-wide license is inferred;
- CAREPATH CDS Specifications is pinned at `82839d8ef5f3d23306beaf072790cb08a379e4fa`, with Apache-2.0 declared and detected at repository level. Its pinned tree contains 65 service JSON files, 13 guideline-derived Excel specifications, and 349 Mustache cards; those clinical assets remain a separate unresolved `NOASSERTION` hold;
- AHRQ CQL Testing Framework is pinned at `60aae55fbab5cb7ad5aea8039e33148e42653954`; the repository declares and GitHub detects Apache-2.0. Its example CQL, FHIR fixtures, and VSAC value-set cache are three independent `NOASSERTION` / `not_reviewed` asset holds, and no framework source or assets were transferred;
- PRANA is pinned at `11fd6cd52d561c428682866b70b187bcb18e7c40`; its README lists offline HTML tools for NEWS2 triage, adult/pediatric ICU scores, sepsis support, ventilation/PEEP, delirium, and insulin titration. Root GPL-3.0 is repository-level evidence only; embedded score and clinical-rule content remains a separate unresolved `NOASSERTION` asset hold. No source or clinical content was transferred, and independent clinical validation was not established;
- ClinicClaw is pinned at `fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e` with Apache-2.0 detected at repository level. Its README presents a research/demo v0.1.0 with eight FHIR R4 workflows and OPA approval gates, but says authentication is dev-mode passthrough and it must not be deployed with real patient data; benchmark metrics are self-reported and unverified. Clinical-policy files and Synthea FHIR fixtures remain separate unresolved `NOASSERTION` / `not_reviewed` holds; no code, policy, fixture, benchmark result, or model output was transferred;
- ConGaIT is pinned at `3101558fa527cc3092cb2f7970a4d3ba78808b2d` on `main`; the GitHub repository page labels its repository license MIT. Its README presents a Parkinson gait dashboard with CNN Hoehn-and-Yahr staging, LRP explanations, and clinician contest-and-justify interactions, and instructs users to place an API key in `config.py`. This is a proof-of-concept contestability reference, not validation of ParkinSUM. Clinical-decision logic, dataset, model weights, and figures have four separate unresolved `NOASSERTION` / `not_reviewed` asset holds; no source, prompt, model, data, or figure was transferred;
- LangCare MCP FHIR is pinned at `d3651b3c8cb940be47c5f376255dded4035a14b8` on `main`; the pinned root `LICENSE` and GitHub label identify MIT. Its README describes a FHIR R4 MCP server with search/read/create/update tools and 40+ agent-facing workflow guides. This is connector and workflow-library architecture, not an independently evaluated clinical decision engine. The clinical guide files under `skills/` remain a separate unresolved `NOASSERTION` / `not_reviewed` hold; no code, skill, patient data, or clinical rule was transferred;
- MD2SKILL is pinned at `1e539eba7bff01b3a0a9abd3bd314398b42d2b89`; its README advertises 888 guideline-derived prompt skills across 11 specialties and claims MIT, but the pinned root listing has no separate `LICENSE`, so repository licensing remains `NOASSERTION` / unresolved. The `skills/` clinical prompt library has a separate unresolved `NOASSERTION` / `not_reviewed` hold. It remains a concept-only lead, not confirmed open-source software or a deterministic engine; no prompt or guideline content was transferred;
- FastEval Parkinsonism is pinned at `5e7b08ecc8495f9c9a69bba7d224fad69f6fbd16` as an Apache-2.0 video-based finger-tapping motor-assessment/workflow reference, not a validated CDSS. Its `src/lib/hand_predictor/utils/saved_models` contents retain a separate unresolved `NOASSERTION` / `not_reviewed` model hold. The 2024 paper says original videos are not public and access requires author permission, institutional approval, and a proposal; the README says tests are not implemented. No source, model, or video was transferred or executed;
- Fully Open Meditron is pinned at `65d23a58df15cffdc151fd366083cbe4e49615be`; its root LICENSE is Apache-2.0 for repository code, while the README separately assigns a research-use license to the corpus and says models/data are not approved for clinical deployment. The pinned data directory and README-listed model releases remain separate unresolved `NOASSERTION` / `not_reviewed` holds. The README citation field is TODO; evaluation claims were not independently verified. No source, data, model, or result was transferred or executed;
- ClinCalc is pinned at `6ed6201b7321cca179053907aaa7baacb2659355` as a concept-only clinical-calculator engine reference. The README describes one Rust core behind CLI, REST, MCP, and Python interfaces; literature citations, typed schemas, per-calculator license metadata, and published-vector tests; and limits the project to development, research, education, and evaluation, not stand-alone decisions for individual patient care. The pinned Cargo.toml declares `AGPL-3.0-or-later AND LGPL-3.0-or-later`; the root README describes QRISK3/QFracture LGPL derivatives and CC-BY-SA-4.0 clinical references, while GitHub labels the root license AGPL-3.0. The repository-level disposition therefore remains `NOASSERTION` in this single-SPDX inventory, and calculator modules retain a separate unresolved clinical-rule asset hold. No code, score, test vector, or clinical content was transferred or executed;
- Microsoft Azure Healthcare Digital Quality CQL SDK is pinned at `c2f1335543d0e385104a42e028fc10141b729a9f`; the pinned root LICENSE is MIT, and its README describes the 0.7.0 Python CQL/ELM-to-parameterized-PostgreSQL-SQL path over FHIR R4 JSONB. It is an adjacent execution engine, not a standalone point-of-care PlanDefinition service. The README says MIT covers SDK source only and does not grant rights to third-party measure specifications, ValueSets, or code systems. The `measures/`, `tests/fixtures/`, and `src/cql_sdk/postgres/` content categories remain separate unresolved `NOASSERTION` / `not_reviewed` holds. No SDK source, CQL, measure, fixture, terminology, or FHIR content was copied or executed locally;
- The two-stage Parkinson medication prediction implementation is pinned at `4f9fbcd537b9bb0592638e843d9ca018fc34e681`, with BSD-3-Clause-Clear declared and detected. Its 631-admission research paper and aggregate baseline/metric outputs are a historical method comparator; the notebook and summary figures stay concept-only, with a separate unresolved report-asset hold and no transfer;
- CASCADE Conformal Prediction is pinned at `840ae293ac05dadb0d13d08c032c7db4bcf4ab21` as a concept-only Parkinson LEDD uncertainty-propagation study. Its notebooks reference an unavailable `data_1Y.csv` and include saved results; data and report outputs remain separate `NOASSERTION` / `not_reviewed` holds. GitHub detects BSD-3-Clause-Clear, while the root copyright line still contains placeholders; no code, dataset, model, or report was transferred;
- Sixty separate asset-category dispositions across 38 repositories cover clinical-rule, data, font, model, report, and terminology assets. The 58 clinical-rule, data, model, report, and terminology records across 36 repositories remain `NOASSERTION` and `not_reviewed`; two font records separately identify OFL-1.1 and are now joined to 14 unique file-level SHA-256 records. Repository-level SPDX is not inherited by an asset. Static-font and license-text source byte equivalence is unverified; Source Serif retains an explicit reserved-font-name resolution obligation, and overall external legal approval remains unrequested;
- SPICE 2.0 server is pinned at `bdc06bbdd855aa65f0692df9218eeb0102bf74b5` with a BSD-3-Clause repository license. Its README is used only to compare the documented CQL, FHIR mapper, offline, notification, and user-service boundaries; this is not evidence of a reviewed deployment or clinical-rule content;
- ClinicDx is pinned at `1e329e903f297942160184dbf484874c33bd5e52` with a CC-BY-4.0 repository license. Its README and research note describe hybrid knowledge retrieval and report held-out synthetic evaluation, coverage gaps, and no formal clinical validation. Separately distributed model weights, guideline knowledge, and clinical-rule assets remain held for independent license review;
- OpenClinical PROformajs is pinned at GitLab commit
  `642e8559ab67cfdc11ef156b96f4af13bbc62548`. Its package declares GPL-3.0,
  while repository detection is `NOASSERTION`; only protocol/runtime separation
  and rewind/replay architecture are recorded. The README describes GPLv3 and
  commercial licensing, and its example clinical-rule assets have a separate
  unresolved `NOASSERTION` hold. No code, protocol, or rule is transferred;
- no upstream CDSS model, dataset, report, package archive, vendored source
  tree, clinical rule, or clinical implementation is approved for distribution.
  The only derived assets currently mapped across the release boundary are the
  two font families; their notice and reserved-name obligations remain open for
  release review.

Important examples:

| Upstream | Evidence at review | Current disposition |
| --- | --- | --- |
| [share_plus](https://github.com/fluttercommunity/plus_plugins) | 13.3.0, pinned at `2c5b4935c85fdbfeffea2bd68c9286c064ed8b7c`; BSD-3-Clause; the lockfile and generated Flutter license bundle bind the released dependency | Explicit HTML file-share adapter only; not used for CDSS logic or as evidence that a recipient saved a file |
| [CQF cql-execution](https://github.com/cqframework/cql-execution/tree/v3.3.2) | 3.3.2 at `1991335e7ad490a8db88a05dd7f03dc3eecbda6d`; Apache-2.0; pinned as a development dependency | Executes translated ELM for local synthetic comparisons; partial CQL support and JavaScript numeric limits remain explicit; no release distribution |
| [CQF cql-exec-fhir](https://github.com/cqframework/cql-exec-fhir/tree/f3f9a968d597e2f029533a9e5cb1e6a643f2f69a) | 2.1.6 at `f3f9a968d597e2f029533a9e5cb1e6a643f2f69a`; Apache-2.0; pinned as a development dependency | Loads local per-patient FHIR Bundles for JavaScript CQL execution; the tested Observation harness removes foreign-subject resources because the upstream provider does not do so; no server query or release distribution |
| [OpenClinical PROformajs](https://gitlab.com/openclinical/proformajs/-/tree/642e8559ab67cfdc11ef156b96f4af13bbc62548) | Package declares GPL-3.0; repository detection is `NOASSERTION`; pinned GitLab commit `642e8559ab67cfdc11ef156b96f4af13bbc62548` | Protocol/enactment separation and timestamped replay are concept-only architecture references. Example clinical-rule assets remain unresolved; no code, protocols, or rules are transferred |
| [CQF cql-exec-vsac](https://github.com/cqframework/cql-exec-vsac/tree/fe7c19cc3e51095ec050b60486598023afa3ac98) | v2.2.0 at `fe7c19cc3e51095ec050b60486598023afa3ac98`; Apache-2.0; concept-only | Optional VSAC ValueSet adapter; API-backed refresh requires a UMLS API key and network. The package is not installed or called, and no cache, credential, or terminology content is used |
| [CQF CQL JVM](https://central.sonatype.com/artifact/org.cqframework/engine/5.3.0) | `engine`, `engine-fhir`, and `quick` 5.3.0 from source commit `88693baefa482ec6f189c90113cfe1f3f4ce9d31`; Apache-2.0; Gradle lock binds the selected graph | Development-only nine-case literal platform-parity check plus a three-case local synthetic FHIR R4 retrieval comparison; no release distribution |
| [PK-Sim](https://github.com/Open-Systems-Pharmacology/PK-Sim) | Repository declares GPLv2, while GitHub Licensee reports `NOASSERTION`; pinned commit `4d39ebc…` | Model-building-block pattern only; no code/model/report transfer |
| [Open Systems Pharmacology Suite](https://github.com/Open-Systems-Pharmacology/Suite) | Repository declares GPLv2; GitHub reports `NOASSERTION`; pinned `daf7b61…` | Extension and qualification workflow only |
| [OSP PBPK Model Library](https://github.com/Open-Systems-Pharmacology/OSP-PBPK-Model-Library) | No machine-resolved repository license at review; pinned `07a71b3…` | Model/data/report assets remain unresolved and concept-only |
| [rxode2](https://github.com/nlmixr2/rxode2) | GPL-3.0; pinned `1d6e2a5…`; current release evidence included v5.1.1 | Unit-bearing event-table architecture only |
| [nlmixr2](https://github.com/nlmixr2/nlmixr2) | GPL-3.0; pinned `f1ac84b…`; current release evidence included v5.0.0 | Estimation-diagnostic concepts only |
| [OHIF Viewer](https://github.com/OHIF/Viewers) | MIT; pinned `6155c58…`; latest reviewed release v3.12.11 | Extension/provider lifecycle concept only; no OHIF code copied |
| [mHabit](https://github.com/FriesI23/mhabit) | Apache-2.0; pinned `e9527bc…`; latest reviewed release v1.24.2+156 | Local-first export/import and optional-sync concepts only |
| [HealthLog](https://github.com/MBombeck/HealthLog) | GitHub reports `NOASSERTION`; pinned `0a20925…` | Self-hosting/recovery concepts only; no transfer permitted |

The inventory also covers the other medication, nutrition, FHIR, wearable,
secret-storage, observability, and testing projects already referenced in the
research corpus. The checker compares the discovered set exactly, so a new
GitHub URL cannot remain an unreviewed footnote.

## Primary-source limits

- [GitHub's license API](https://docs.github.com/en/rest/licenses/licenses)
  uses Licensee and returns SPDX-shaped matches, but GitHub explicitly says it
  does not account for dependency licenses or every other way a project may
  declare terms, and it is not legal advice. `NOASSERTION` is therefore a hard
  unresolved state, not permission.
- [SPDX](https://spdx.dev/use/specifications/) is an international open
  standard and lists SPDX 3.0 as the current stable document version at this
  review. An SPDX identifier describes terms; it does not prove compatibility,
  fulfillment, provenance, or permission for separate model/data assets.
- [GitHub dependency review](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependency-review)
  can identify dependency and license changes in pull requests, but it does
  not replace this repository's concept/copy/link/vendor/derive classification
  or asset-level review.

## Failure modes and trade-offs

| Failure | Result |
| --- | --- |
| New research URL without inventory entry | CI blocks with discovery drift |
| Moving branch or tag | Not trusted; inventory uses full commit SHA |
| Repository host reports no license | Entry stays `NOASSERTION`, concept-only |
| GPL/AGPL transfer lacks legal review, notice, or source disclosure | CI blocks |
| MIT/BSD/Apache transfer lacks notice | CI blocks |
| Unreviewed vendored directory appears | CI blocks |
| Upstream changes after the pinned commit | Current offline gate remains reproducible but stale until a reviewed refresh |
| Generated Web and Android Flutter notices differ | The release-evidence check fails on byte mismatch; Maven license text, archive-to-cache verification, legal completeness and other platforms remain separate holds |

The trade-off is deliberate: the offline gate cannot prove that an upstream
repository has not relicensed or rewritten architecture after the pinned
commit. Automatic network refresh would weaken reproducibility and could turn
a transient API result into a release decision. The networked proposal stage
below records observations for human review and never imports upstream content
or rewrites the inventory.

## Read-only upstream drift proposal

The schema-v1 collector in `tool/open_source_drift_proposal.mjs` can be run
manually from the `Open-source drift proposal` workflow. It checks the
repository identity, current default-branch name and head, whether the exact
reviewed commit still resolves, archive state where the host exposes it,
provider-detected license metadata, tags that still point at the reviewed
commit, API version, rate-limit headers, and pagination completion. The
GitHub adapter resolves the branch ref and traverses bounded Git commit-parent
metadata to check whether the reviewed pin remains in its history; it does
not request commit diffs. The adapters use the [GitHub repository API](https://docs.github.com/en/rest/repos/repos),
[Git references API](https://docs.github.com/en/rest/git/refs), and
[Git commits API](https://docs.github.com/en/rest/git/commits), the
[GitLab Projects API](https://docs.gitlab.com/api/projects/), and the
[Bitbucket Cloud repository API](https://developer.atlassian.com/cloud/bitbucket/rest/api-group-repositories/).

The workflow has `contents: read` permission and uploads a 30-day JSON review
artifact. The proposal is bound to the exact inventory SHA-256. A prior proposal
is used only when its digest and influence set match and a matching decision
ledger contains the latest accepted human decision for every source. The
schema-v1 review tool binds a decision to the canonical proposal digest,
inventory digest, source identity, reviewer-entered identity, UTC review time,
rationale, change classification, and HTTPS evidence references. It chains each
event to the preceding SHA-256 digest and supports acceptance, rejection,
deferral, and revocation. `project` creates a new reviewed-baseline artifact
only after every source is accepted; the next collector run requires that
artifact and its ledger together. It never edits either input. Supplying an
unreviewed proposal, an incomplete ledger, a mismatched inventory, or a
revoked/deferred decision remains unverified. On a later run with the same
inventory and an accepted reviewed baseline, changed tag references,
provider-detected license, repository identity, or archive state are surfaced
for review. GitHub redirects are captured rather than followed;
API failures, malformed responses, rate limits, unsafe/incomplete pagination,
and unavailable metadata never produce a pass.

For a human review, create a source decision template with
`node tool/open_source_drift_decision_ledger.mjs template --proposal build/open_source_drift_proposal/proposal.json --influence <inventory-id>`, fill its decision, classification, identity, UTC time, rationale, and evidence URLs, then use `append` to write each event to a new ledger path. After every influence has a current accepted event, `project` emits a new reviewed-baseline file. Never put patient information, credentials, or secrets in the rationale or evidence list.

If `config/open_source_drift_proposal_baseline.json` and
`config/open_source_drift_decision_ledger.json` are later added together through
a reviewed change, the manual workflow verifies the chain and compares against
that accepted snapshot. If only one exists, the workflow stops. Until both
exist, every run explicitly reports the absence of a prior drift baseline.

The report is intentionally not an approval. A first observation cannot prove
that a tag was not deleted or retargeted before this baseline; the current
inventory does not record the previously reviewed tag name. The collector does
not fetch or parse root license text, so live declared-license evidence stays
`NOASSERTION`. GitLab and Bitbucket ancestry comparison is not yet implemented,
and Bitbucket Cloud metadata does not expose archive state or detected SPDX in
this adapter; those records remain unverified. A reviewer must inspect the
source at its pinned URL and classify changes against the concept, transferred
files, dependency graph, NOTICE/source-offer duties, SBOM, and scientific,
model, or data claims. The workflow does not download source trees, code,
models, datasets, or reports, mutate `config/open_source_influence_inventory.json`,
or create an approval itself. The local append command writes a new ledger file
and refuses to overwrite an existing output; the project command similarly
emits a new baseline artifact. Reviewers must retain the ledger anchor in the
reviewed change. Hash chaining can expose edits relative to that retained
anchor, but it does not authenticate the self-asserted reviewer identity or
prove immutability outside version control. No historical baseline, ledger, or
live proposal has yet been accepted, so the queue remains open.

## Remaining work

- generate and verify deterministic SPDX or CycloneDX SBOMs for every release
  artifact, not only lockfile evidence;
- refresh Web and Android builds until their NOTICE bytes match the pinned
  Flutter collector reconstruction, then verify extracted Pub cache bytes
  against locked archive hashes and add Maven/non-Pub platform license-text
  evidence;
- obtain external legal review before any reciprocal or unresolved transfer;
- bind NOTICE/source-offer obligations to artifact checksums;
- complete upstream semantic/license drift review with a committed, reviewed
  baseline and append-only decision ledger; exercise the new ledger against a
  live proposal; support declared-license evidence,
  host-specific history checks, and prior-tag deletion/retarget detection;
- keep scientific validity, model qualification, data-use permission, privacy,
  and regulatory claims outside this license gate.
