# Medication assertion source and temporal reconciliation

Reviewed: 2026-08-27
Queue item: `medication_assertion_source_temporal_reconciliation`

## Decision

The next medication-provenance layer after a single dose-confirmation receipt
should retain competing assertions as an explicit conflict graph. A patient
report, caregiver report, imported medication list, prescription, dispense,
package label and formal administration record are different evidence classes.
ParkinSUM must not silently select one, overwrite disagreement, or infer actual
administration or adherence from any one class.

The first implementation should separate event time from assertion, import and
recorded time and retain precision or uncertainty. This is needed before an
external medication source can safely affect the mechanistic trace.

## Evidence map

| Evidence | Result relevant to the design | Limit |
| --- | --- | --- |
| [HL7 FHIR R5 MedicationStatement](https://hl7.org/fhir/R5/medicationstatement.html) | `effective[x]`, `dateAsserted`, `informationSource` and `derivedFrom` distinguish when use was reported, when it was asserted, who supplied it and what evidence it derives from. The resource explicitly allows patient, caregiver and clinician reports and is distinct from request, dispense and administration records. | MedicationStatement is Trial Use in R5. Its structure does not make ParkinSUM FHIR-conformant or prove that a reported dose occurred. |
| [HL7 FHIR R5 MedicationAdministration](https://hl7.org/fhir/R5/medicationadministration.html) | A formal administration record can retain actual-administration detail such as time, dose, route, method, device and performer. | ParkinSUM does not create a formal administration record merely because a user checks a box or imports an external row. |
| [HL7 FHIR R5 Provenance](https://hl7.org/fhir/R5/provenance.html) | Activity occurrence and recorded time are separate; version-specific targets, agents and source/revision entities support append-only derivation and supersession. | A local digest is not a FHIR Signature, external identity proof, non-repudiation mechanism or legal audit. |
| [García González et al., 2024 prospective observational study](https://pubmed.ncbi.nlm.nih.gov/38675420/) | Among 1,131 emergency-department patients with multimorbidity or polypharmacy, 64.5% had at least one discrepancy between the electronic prescribing record and pharmacist-reconciled medication. The study retained 1,654 discrepancies; posology differences were 43.6%, commission 34.7% and omission 20.9%. | Hospital admission, pharmacist reconciliation and the selected population do not estimate ParkinSUM accuracy, Parkinson-specific disagreement or a safe automated source hierarchy. |
| [van der Nat et al., prospective cohort](https://pubmed.ncbi.nlm.nih.gov/35032251/) | Of 488 approached patients, 155 were included and 24 clinically relevant deviations were found between patient-updated personal health records and professional medication reconciliation. | Selection and hospital setting limit generalization; the result does not establish that a consumer app can adjudicate a discrepancy. |
| [Marinović et al., 2021 randomized trial](https://pubmed.ncbi.nlm.nih.gov/33969511/) | In 353 older adults, a pharmacist-led integrated transition model reduced the number of patients with unintentional discrepancies by 57.1%; incorrect dose, omission and commission were the common classes. | This was a multi-professional clinical intervention, not an automated reconciliation algorithm. It supports escalation and human review rather than autonomous resolution. |

## Current worktree boundary

The schema-v1 local dose receipt already binds one exact account-scoped intake,
product snapshot, raw expression, parsed AST, structured value, administration
time, confirmation time and coarse assertion source. It re-evaluates those
bindings before a dose can enter a result-affecting algorithm.

It does not yet retain:

- more than one assertion for the same candidate medication event;
- an external source artifact, revision, actor or functional role;
- request, dispense, statement and formal-administration evidence classes;
- effective intervals, time precision, timezone provenance or uncertainty;
- taken, not-taken, unknown, entered-in-error, superseded or retracted states;
- a derivation graph, contradiction set or append-only reconciliation decision.

Replacing the current `Intake` with the newest imported row would therefore
erase the disagreement the design needs to expose.

## Proposed contract

### Immutable assertion node

Each node should bind:

- assertion ID, schema, content digest, owner scope and predecessor;
- medication, ingredient/product, dose, route, form and release identity;
- evidence class: user or caregiver statement, package-derived, imported
  statement, prescription/request, dispense, device observation or formal
  administration;
- source artifact, source revision, actor and role, plus derivation links;
- effective event time or interval, precision, uncertainty and timezone source;
- asserted, imported and recorded clocks kept as separate values;
- taken, not taken, unknown or entered-in-error status;
- preservation and meaning boundaries for unavailable fields.

### Deterministic conflict graph

Nodes should be grouped only when medication/product identity and bounded time
overlap are mechanically compatible. Edges should state the exact relationship:
duplicate, corroborates, dose conflict, time conflict, product conflict, status
conflict, supersedes, retracts, derived from or unresolved candidate match.

No global source ranking should resolve a conflict. A formal administration
record may be more detailed, but an external resource label is not proof of its
authenticity, currentness or correct patient binding. Unknown and absence must
remain distinct from not taken.

### Result-affecting boundary

Only a current ParkinSUM local confirmation whose exact source chain has no
unresolved conflict for that event may provide a numeric dose to an algorithm.
The graph may explain why a value is held, but cannot recommend a dose, infer
adherence or convert a prescription, dispense, bottle strength or device signal
into proof of administration.

## Required executable evidence

- independent canonicalization and graph-construction oracle over neutral
  fixtures;
- source substitution, duplicate, delayed import, future event, clock skew,
  daylight-saving ambiguity, interval overlap and timezone mutation tests;
- status inversion, entered-in-error, supersession, retraction erasure,
  dangling derivation and source-revision drift tests;
- restart, offline, cross-tab/device/account, acknowledgement-loss and partial
  commit recovery tests;
- accessible side-by-side UI journeys for every shipped locale, including
  keyboard, screen reader, zoom and reflow;
- portable round trip retaining all claims and decisions without claiming FHIR
  conformance;
- representative-user research and clinician-led reconciliation studies before
  any claim of medication-safety benefit or reconciliation effectiveness.

## Boundary

This is a source-integrity and uncertainty-preservation design for an
educational prototype. It is not medication reconciliation by a pharmacist,
clinical verification, proof of administration, adherence measurement,
prescription validation, clinical validation, medical advice or regulatory
acceptance.

## Local bitemporal projection slice (2026-09-22)

`MedicationAssertionReconciliationService.projectBitemporal` now accepts two
independent UTC cutoffs: `validAt` selects the clinical time under review, and
`knownAt` limits the evidence and review decisions available to that historical
view. Assertion visibility requires the asserted and recorded clocks, plus an
import clock when present, to be at or before `knownAt`; an imported statement
without an import clock remains unresolved. A decision is visible only when its
`decidedAt` is at or before the same cutoff. Later entries retain their stable
ID, availability time and reason, but their claim or decision payload is omitted
from that projection.

For assertions known by the cutoff, the projection separately labels a stored
effective interval as matching, outside, or uncertain at `validAt`. Missing or
unknown time and unknown timezone provenance remain uncertain; the configured
time uncertainty widens the possible interval without turning boundary overlap
into a precise match. Source claims remain assertions, and every serialized
projection explicitly reports that it is not eligible for dose-result use.
Focused tests cover delayed import visibility, event-time interval status,
timezone uncertainty, and a later review decision. No persisted schema or
result-affecting gate changed.

The initial v1 slice did not establish a trusted transaction clock,
cross-device concurrency, external issuer authenticity, a full reconciliation
graph at each historical cutoff, or clinical meaning for medication courses.
The subsequent schema-v2 graph extension is recorded below; the other gaps
remain, so the queue item remains `research_required`.

## Historical conflict graph under bitemporal cutoffs (2026-09-23)

The bitemporal projection advances to schema v2 and now includes a deterministic
historical conflict graph. The service rebuilds the existing conflict graph
over only assertions and reconciliation decisions whose knowledge clocks pass
the selected cutoff; it uses `validAt` as the graph's temporal observation
point. The projection digest binds the rebuilt graph, including its edges,
integrity findings, matching review decision, and stale-decision count. The
historical graph intentionally has no dose-eligibility field; the outer
projection remains explicitly ineligible for result use.

This prevents a later imported conflict or review decision from appearing as a
known relationship before its knowledge time. The interface displays the
reconstructed edges beside each source's valid-time status and invalidates the
view when the source graph changes. Intake-level integrity markers without
their own recorded clock still cannot be assigned reliably to a historical
cutoff. The queue item remains `research_required` for that timing gap,
external-source trust, offline/cross-device behavior, and clinical evaluation.

## Untimed aggregate integrity markers (2026-09-23)

The bitemporal projection advances to schema v3. If the current Intake snapshot
contains a quarantined aggregate medication-reconciliation envelope without an
independent knowledge timestamp, the projection records
`knowledgeTimeUnresolved`, binds that state into its digest, excludes the
untimed marker from the reconstructed historical graph, and displays that the
projection is incomplete. It does not infer when the malformed envelope was
first observed or expose its raw payload in the historical view. The current
conflict graph and dose-result gate continue to treat the quarantine as a
blocking integrity finding.

This makes the uncertainty explicit but cannot recover a timestamp that was
never captured. Future quarantine paths still need a durable observation-time
record governed separately from the claim's event time; existing unclocked
markers cannot be dated retroactively. The projection is read-only, no Intake
or database schema changes, and the queue item remains `research_required`.

## Local bitemporal cutoff controls (2026-09-23)

The medication source-review page now lets the account holder select the event
time under review and a separate knowledge-time cutoff using UTC date/time
controls. A shortcut sets the knowledge cutoff to the selected event time, and
another restores the current time. The read-only result labels assertions
available by that cutoff separately from withheld later or unresolved
evidence, then shows whether a visible effective interval covers the selected
event time. Later assertion and review-decision payloads remain hidden. A source
graph revision invalidates the displayed projection until the user generates
it again.

The historical view does not write records or alter the current dose-result
gate. It does not establish transaction-time trust, external issuer
authenticity, complete historical conflict-graph reconstruction, course
semantics, or clinician-led reconciliation effectiveness. The queue item
remains `research_required`.
