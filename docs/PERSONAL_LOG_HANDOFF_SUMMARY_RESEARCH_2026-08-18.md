# Personal log handoff summary research — 2026-08-18

## Decision

ParkinSUM now has a bounded, user-initiated personal-log summary workflow. It
is deliberately not an EHR export, International Patient Summary (IPS),
diagnosis, treatment plan, or clinically verified record. The output contains
only the user's selected local snapshot and retains unknown values as unknown.

The first implementation uses one fixed Flutter page widget for both preview
and PDF rendering. This makes the preview visually faithful and permits
offline platform-font fallback for user-entered scripts. It also means the PDF
is image-based: text is not tagged, searchable, selectable, or independently
proven accessible. The UI and upgrade queue state that limitation.

## Primary and official evidence map

| Source | What it supports | What it does not prove |
| --- | --- | --- |
| [HL7 IPS `$summary` OperationDefinition v2.0.1](https://www.hl7.org/fhir/uv/ips/en/OperationDefinition-summary.html) | An on-demand summary can be explicitly generated from the latest available information and returned as a document bundle. This supports a user-requested snapshot pattern. | ParkinSUM is not claiming IPS conformance, a FHIR Bundle, clinical completeness, healthcare-provider authorship, or EHR interoperability. The cited guide is trial-use. |
| [Flutter `printing` 5.15.0](https://pub.dev/packages/printing) | Current Flutter APIs support system print layout and PDF sharing on the package's declared platforms. Its macOS setup documents the print entitlement. | A `true` system-sheet result is not a durable receipt that a printer produced paper or that a recipient saved a file. Physical-target evidence is still required. |
| [Dart `pdf` 3.13.0](https://pub.dev/packages/pdf) | Offline PDF byte generation and fixed page construction. The package is Apache-2.0 licensed. | The package alone does not create a tagged PDF/UA document, validate reading order, or license arbitrary fonts. |
| [WCAG 2.2 PDF techniques](https://www.w3.org/WAI/WCAG22/Techniques/pdf/) | Searchable/tagged PDF structure, document title, language, reading order, and text alternatives require explicit techniques and tests. | Technique conformance does not establish clinical, privacy, interoperability, or legal compliance. |
| [ISO 14289-2:2024 PDF/UA-2 catalog page](https://www.iso.org/standard/82278.html) | PDF/UA is a distinct accessibility standard rather than a visual-similarity claim. | The standard text is not reproduced here, and the current raster artifact is not claimed to conform. |

Sources were reviewed on 2026-08-18. Dependency versions above are the
versions locked by this worktree, not evergreen claims.

## Open-source pattern review

The [Medplum FHIR operations documentation](https://github.com/medplum/medplum/blob/main/packages/docs/docs/api/fhir/operations/index.mdx)
illustrates an open-source pattern in which a named operation has an explicit
input/output contract instead of an unbounded “export everything” action.
ParkinSUM transfers only that architectural pattern: a bounded operation,
explicit options, deterministic result identity, and no write during preview.
No Medplum source code or clinical behavior was copied. Its Apache-2.0 project
license and FHIR focus do not make ParkinSUM an EHR or a conformant FHIR server.

## Implemented contract

- The user selects an inclusive date range, sections, and redaction level.
- Current medication selections and historical-only medication references are
  separate sections.
- Stored timestamps, profile timezone label, original dose, canonical
  milligram conversion, source labels, missing nutrients, unresolved catalog
  references, and unsupported units remain explicit.
- Null and missing are never converted to zero. A sourced zero remains zero.
- Source and content SHA-256 identities, record counts, budgets, owner binding,
  and schema version are generated deterministically.
- Preview and PDF use the same page widget. Copy uses the exact frozen text.
- Account scope, account epoch, selected options, and a full source-revision
  digest are rechecked around asynchronous generation and before delivery.
- Cancellation does not display a success claim. Platform failures show a
  bounded error code, not raw user content or exception text.
- The artifact visibly denies clinical verification, diagnosis, treatment,
  recommendation, and medical-record status.

## Failure and privacy boundaries

Generation fails closed on an empty section set, reversed or over-budget date
range, duplicate record/catalog identifiers, negative or non-finite numbers,
oversized text, excessive records/pages, or an oversized rendered PDF. A
source or account change clears the artifact. Logs contain only operation,
page count, and a short content-digest prefix.

The print/share plugin opens an operating-system workflow. ParkinSUM cannot
atomically cancel an OS side effect after the platform call begins and cannot
prove that the user or a recipient saved, printed, deleted, or protected the
result. The output can contain sensitive health and medication data, is not
encrypted, and should be handled as user-selected sensitive content.

## Remaining complete-app work

1. Produce a tagged, searchable, selectable, multilingual and bidirectional
   document with reviewed offline font licensing and an independently checked
   structure tree. This is tracked separately as
   `accessible_searchable_multiscript_document_export`.
2. Localize semantic document content, not only the surrounding settings UI.
3. Run physical-device and target-desktop print, share, cancellation,
   screen-reader, large-document, low-memory, page-break and recipient
   round-trip drills with artifact checksums.
4. Complete terminology governance and cross-backend record enumeration.
5. If durable save proof is required, design a target-specific document
   provider workflow with explicit acknowledgement rather than interpreting a
   system sheet result as a receipt.
