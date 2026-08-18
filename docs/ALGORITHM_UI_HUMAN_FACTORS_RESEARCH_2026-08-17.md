# Algorithm UI and human-factors research — 2026-08-17

## Scope and boundary

This review asks how ParkinSUM should make result-affecting algorithms
inspectable without turning a mechanistic education prototype into apparent
patient-specific advice. It does not establish clinical accuracy, medical
benefit, regulatory status, or fitness for care.

## Primary-source findings

### Make every result-affecting algorithm discoverable

FDA describes human-factors work as the study of the interaction among users,
use environments, and user interfaces, with attention to use errors that can
affect safety. The relevant interface is broader than a single chart: it
includes controls, displays, labels, and instructions. ParkinSUM therefore
needs an inventory that lets a reviewer find every algorithm, see its inputs
and outputs, and identify the interpretation boundary.

- FDA, *Applying Human Factors and Usability Engineering to Medical Devices*
  (final guidance page, August 2026):
  https://www.fda.gov/regulatory-information/search-fda-guidance-documents/applying-human-factors-and-usability-engineering-medical-devices
- FDA, *Human Factors Considerations*:
  https://www.fda.gov/medical-devices/human-factors-and-medical-devices/human-factors-considerations

Transfer into this worktree:

- The Algorithm Observatory now includes a searchable and stage-filterable
  algorithm atlas.
- Every registry entry has an in-app visual contract, impact statement,
  input-to-output text, live-trace status, and limitation.
- A three-row sensitivity table runs the same production path for fixed
  reference, high-fat/high-protein, and incomplete-data scenarios. It compares
  completeness, aggregate lag, modeled overlap, severity, and confidence
  without presenting the differences as patient predictions.
- This is an engineering transparency control. It is not evidence that a user
  can interpret the display safely.

### Charts need equivalent text, not only a short screen-reader label

W3C's complex-image guidance treats charts, flow diagrams, and organizational
diagrams as information that usually needs both a short identification and a
long description containing the essential values, relationships, and trends.
W3C also recommends making that description visible where practical because
it helps users with low vision, learning disabilities, and limited subject
knowledge—not only screen-reader users.

- W3C WAI, *Complex Images* (updated 8 April 2026):
  https://www.w3.org/WAI/tutorials/images/complex/
- W3C WCAG 2.2 Technique G103, visual explanations plus text alternatives:
  https://www.w3.org/WAI/WCAG22/Techniques/general/G103

Transfer into the queue:

- Preserve the concise semantic label already attached to each mechanistic
  chart.
- The two live mechanistic curves now expose expandable point-by-point data
  tables. Equivalent long descriptions and tables remain to be completed for
  timelines, score decompositions, and conflict visualizations.
- Test keyboard access, focus order, zoom/reflow, contrast, and screen-reader
  output as executable journeys rather than treating a semantics node as
  conformance.

### Usability evidence must focus on critical tasks and harmful misuse

FDA frames human-factors evaluation around intended users, uses, environments,
and possible use errors. For ParkinSUM, the highest-risk failure is not simply
failing to find a graph. It is reading an educational overlap or uncertainty
signal as a dose, timing instruction, symptom forecast, or reason to change
food or medication without clinician review.

Transfer into the queue:

- Define critical interpretation tasks and use-related hazards before testing.
- Test whether representative users can distinguish modeled overlap,
  confidence, severity, missingness, and evidence strength.
- Treat any task that induces an unreviewed medication, diet, or timing change
  as a stop-rule event, not a copy-edit suggestion.

## Next research questions

1. Which visible and spoken representations best communicate uncertainty to
   people with Parkinson's disease, including motor, visual, and cognitive
   accessibility needs?
2. Can users correctly explain the difference among overlap score, confidence,
   severity, and predicted clinical response after a short onboarding?
3. Which critical tasks and foreseeable misuse scenarios belong in a formative
   study before any summative human-factors protocol?
4. What minimum structured table is equivalent to each live visualization
   without creating false numerical precision?
