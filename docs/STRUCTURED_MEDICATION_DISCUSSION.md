# Structured Medication Discussion Entries

The care workspace can keep account-entered medicine, over-the-counter,
vitamin, and supplement items for a future visit. These entries help collect
information that may be missing from the application's medication catalog.
They remain discussion material, not a reconciled medication list.

Each entry stores the name as entered, a self-selected category, a reported
use status (`reportedCurrent`, `reportedStopped`, or `uncertain`), an optional
ingredient label copied by the user, optional free-text dose/schedule and a
question to verify. The signed-in app account and entry time are retained. The
ingredient label and dose text are not parsed, standardized, matched to a
catalog ingredient or product, or used as inputs to rule evaluation. The
selected category and reported use are user-entered claims, not verified facts.

The visit-preparation preview includes entries recorded on or before its
generation time. It labels them as unverified, retains the ingredient and
dose/schedule text, and carries the question and local source ID. It can group
identical labels across active-intake evidence and account-entered entries
after case and repeated-space normalization. This is a prompt to verify labels
and products manually; it does not establish
chemical equivalence, current use, duplicate therapy or risk. It does not use
fuzzy matching, aliases, salt stripping or catalog resolution. Entries
recorded after the report time are omitted and counted with other future
records. No interaction, diagnosis or treatment judgment is made from these
entries.

## Medication-list self-check

The care workspace also lets the account holder mark four categories as
reviewed: current medication selections, over-the-counter medicines,
vitamins/supplements, and stopped or uncertain-use items. Each mark is stored
with the local account scope and time, and the visit report reproduces it as
an owner-reported check. It records only that the owner marked the category
after looking at the app's entries; it does not show that every medicine was
entered, that information is accurate, or that a clinician reconciled it. The
report continues to ask the person to verify the complete list even when all
four categories are marked. Review marks do not alter medication entries or
rule evaluation.

This workflow follows only the general information-review pattern described in
the [ADFICE_IT design paper](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0297703): check patient information, including medication lists, and add missing items. ParkinSUM instead records a fresh, account-holder self-check of its own categories. No ADFICE_IT code, UI design, guideline, rule specification, or advice text was copied.

After a visit, the account owner can append a discussion update with a
self-reported status and optional note. The history is append-only and linked
to the discussion entry; later visit reports show the latest update recorded
by report time. The complete saved history can be reviewed in the workspace;
each report labels the latest update as owner-reported and not clinician-
verified. The history view is account-bound and hides its content if the
account changes. Deleting a discussion entry also deletes its linked history.
The status and note do not authenticate a clinician, capture a verified
clinical decision, change a medicine, or enter rule evaluation.

## Storage and migration

The account-scoped local care-workspace envelope is schema v5. It accepts
schema-v1 through v4 data without writing during load. Version 1 supplies empty
discussion-entry and outcome lists; version-2 entries receive a missing
ingredient label; version 3 has no outcome history; version 4 has no medication
list review marks. Earlier workspaces receive no inferred marks. Each version
writes v5 on the next successful change. Unsupported versions, invalid entry
shapes, orphaned outcome references, owner mismatches, duplicate IDs or review
sections, and capacity overflows fail closed; a failed load or save preserves
the stored document. Entries and marks use the same account-local workspace as
observations and questions, remain outside existing portable-data backups,
and do not enable caregiver sharing or authenticated clinician access.

This feature does not provide a complete medication catalog, product/ingredient
identity resolution, pharmacy import, prescription verification, adherence
evidence, or clinical medication reconciliation. A user should verify the
details with an appropriate professional; the app does not recommend starting,
stopping, or changing a medicine.
