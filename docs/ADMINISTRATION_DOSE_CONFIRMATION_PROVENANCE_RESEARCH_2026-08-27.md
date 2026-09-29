# Administration-dose confirmation provenance and reconciliation

Reviewed: 2026-08-27  
Queue item: `administration_dose_confirmation_receipt_and_reconciliation`

## Decision

The next medication-input slice should add a ParkinSUM-local confirmation
receipt that binds one exact user assertion to one intake revision. The receipt
must not be represented as a prescription, a formal medication-administration
record, a clinician verification, or proof that a medicine was taken.

The current schema-v1 dose-expression parser is a prerequisite, not sufficient
provenance. It can determine whether text has one supported quantity, but it
does not identify who asserted it, which product and record revision were
reviewed, whether stored raw and structured values still agree, or whether a
later parser or catalog version changed the meaning.

## Primary-source evidence map

| Source | What it supports | What it does not establish for ParkinSUM |
| --- | --- | --- |
| [HL7 FHIR R5 MedicationStatement](https://hl7.org/fhir/R5/medicationstatement.html) | A medication-use statement may be a report from a patient or another source; `dateAsserted`, `informationSource`, and `derivedFrom` keep assertion time and supporting source explicit. The resource is distinct from a formal MedicationAdministration. | It does not make ParkinSUM FHIR-conformant, prove that a dose was administered, or validate a prescription. MedicationStatement itself is Trial Use in R5. |
| [HL7 FHIR R5 Provenance](https://hl7.org/fhir/R5/provenance.html) | Provenance models a target, activity time/recorded time, responsible agent, and source or revision entities. Version-specific identity and separate records for separate activities support an append-only revision design. Optional signatures have a specific integrity/non-repudiation purpose. | A local content digest is not a FHIR `Signature`, legal signature, non-repudiation proof, identity proof, or external audit. ParkinSUM has no FHIR server or validated profile. |
| [FDA Applying Human Factors and Usability Engineering to Medical Devices, August 2026](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/applying-human-factors-and-usability-engineering-medical-devices) | User-interface design should be evaluated to reduce foreseeable use errors and resulting harm for intended users, uses, and environments. This supports explicit review, changed-field visibility, accessibility, and adversarial confirmation journeys. | The guidance does not determine ParkinSUM's regulatory status, approve the interface, or replace representative-user human-factors evidence. The app remains an educational prototype. |

## Current worktree implementation

- `DosageNoteParser.inspect` now returns raw text, normalized text, grammar
  identity, reason codes, and a typed quantity only for unambiguous supported
  syntax.
- `AdministrationDoseConfirmationReceipt` now binds the reviewed medication,
  product snapshot, raw and parsed expression, structured dose, grammar and
  unit identity, account-scope digest, administration and confirmation time,
  expected record revision, UI action and mutation operation.
- Timeline and onboarding require explicit confirmation. Package-derived text
  remains only a source class until the user confirms the quantity.
- Result-affecting orchestration re-evaluates every binding; unconfirmed,
  legacy, malformed, future-schema or drifted evidence cannot supply a numeric
  dose.
- SQLite schema v9, Firestore shape rules, recoverable history, exact undo,
  portable export, localized badges and the Algorithm Observatory expose the
  same local assertion boundary.
- Eleven deterministic mutation cases plus model, widget, journey, database
  and export tests are now executable through `npm run dose:confirmation` and
  the composed `npm run verify:all` gate.

The item remains research-required because durable Web/Firestore transaction
parity, partial acknowledgement and retry recovery, offline/cross-device races,
independent receipt implementation, complete assistive-technology evidence and
representative-user human-factors evaluation remain open.

## Implemented local receipt contract

The first version should retain, at minimum:

- receipt schema and digest;
- owner scope, intake ID, expected record revision, and mutation operation ID;
- medication identity and selected product/package snapshot;
- exact raw dose expression and its normalized typed AST;
- grammar ID, version, digest, and local unit vocabulary identity;
- structured value/unit and an explicit raw-to-structured agreement state;
- asserted administration time and separately recorded confirmation time;
- assertion source: typed, package-derived, imported, or legacy-unconfirmed;
- confirmation action and UI contract version;
- recoverable-history operation identity and exact before/after receipts;
- a boundary stating that this is a user report, not prescription or
  administration verification.

## Fail-closed reconciliation

The dose must be held from result-affecting algorithms when any of these occur:

1. raw text and structured quantity disagree;
2. grammar, local unit vocabulary, medication, product, route, form, release,
   time, account, or record revision differs from the receipt;
3. a legacy/imported value has no confirmation receipt;
4. a digest, predecessor, source, or required identity is absent or malformed;
5. an edit, undo, restore, offline replay, or concurrent write invalidates the
   reviewed preview;
6. acknowledgement is missing after a partial backend mutation.

Reconfirmation must show the exact changed fields. It must not default a package
strength into an administration dose or imply what quantity the user should
take.

## Remaining evidence required before promotion

- independent receipt-digest and raw/AST agreement fixtures;
- strength-as-dose, raw replacement, AST replacement, grammar downgrade,
  product swap, time change, stale preview, cross-account replay, duplicate
  acknowledgement, and partial-commit mutations;
- keyboard, screen-reader, zoom/reflow, motor-access, locale, and bidirectional
  review journeys;
- memory, Web, SQLite, and Firestore expected-revision parity plus restart and
  offline recovery;
- Web and Firestore expected-revision, acknowledgement-loss and retry parity;
- representative-user human-factors work before any stronger use-safety claim.

## Boundary

This research strengthens input provenance and use-error resistance. It does
not establish medication adherence, prescription validity, clinical accuracy,
scientific validation, device qualification, regulatory acceptance, patient
benefit, or medical advice.
