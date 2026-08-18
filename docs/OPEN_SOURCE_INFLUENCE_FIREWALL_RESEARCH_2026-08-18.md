# Open-source influence and license firewall

Reviewed: 2026-08-18

## Decision

ParkinSUM may study public open-source systems to understand architecture,
failure modes, test strategy, and interaction patterns. A public repository or
an SPDX label does **not** authorize copying, linking, vendoring, adapting, or
redistributing code, model projects, datasets, reports, fonts, screenshots, or
generated artifacts.

The repository now has an offline, versioned firewall. Every GitHub project
already cited by the research documents or complete-app queue must have one
entry in `config/open_source_influence_inventory.json`. Each entry binds the
official repository, a full commit SHA, declared and GitHub-detected license
evidence, reviewed artifact types, the concepts studied, transfer status,
authorization, release paths, and obligations.

This is repository engineering review, not legal advice.

## Requirements and architecture

Functional requirements:

- discover every GitHub repository cited under the reviewed research roots;
- distinguish source code, documentation, UI patterns, API contracts, model,
  data, report, and release assets;
- distinguish `concept_only`, `copied`, `linked`, `vendored`, and `derived`;
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
research docs + complete-app queue
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

The committed inventory contains 34 upstream influences:

- 32 are concept-only and have no authorized local paths or distributed
  artifacts;
- Flutter 3.47.0 (`4cf2416…`) and `flutter_local_notifications` 22.3.0
  (`b475bc8…`) are existing linked dependencies, bound to `pubspec.yaml` and
  `pubspec.lock`, with license-notice and generated-license-bundle obligations;
- eight repositories remain `NOASSERTION` and therefore concept-only;
- no upstream model, dataset, report, package archive, vendored source tree, or
  derived implementation is approved for distribution.

Important examples:

| Upstream | Evidence at review | Current disposition |
| --- | --- | --- |
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
| GitHub reports no license | Entry stays `NOASSERTION`, concept-only |
| GPL/AGPL transfer lacks legal review, notice, or source disclosure | CI blocks |
| MIT/BSD/Apache transfer lacks notice | CI blocks |
| Unreviewed vendored directory appears | CI blocks |
| Upstream changes after the pinned commit | Current offline gate remains reproducible but stale until a reviewed refresh |
| Generated Flutter notices differ in a built artifact | Not yet physically attested; remains a release residual |

The trade-off is deliberate: the offline gate cannot prove that an upstream
repository has not relicensed or rewritten architecture after the pinned
commit. Automatic network refresh would weaken reproducibility and could turn
a transient API result into a release decision. The next queue item therefore
uses a networked proposal stage plus human review, never an automatic import.

## Remaining work

- generate and verify deterministic SPDX or CycloneDX SBOMs for every release
  artifact, not only lockfile evidence;
- inspect the generated license bundle inside each built artifact;
- obtain external legal review before any reciprocal or unresolved transfer;
- bind NOTICE/source-offer obligations to artifact checksums;
- implement upstream semantic/license drift proposals with rate-limit,
  repository-move, archive, deleted tag, mutable tag, and `NOASSERTION`
  handling;
- keep scientific validity, model qualification, data-use permission, privacy,
  and regulatory claims outside this license gate.
