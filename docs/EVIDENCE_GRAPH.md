# Local Evidence Graph

Educational/research prototype. Synthetic/demo artifacts only. **Not medical
advice, not clinically calibrated, and carries no clinical-validation claim.**

## 1. Purpose

The EvidenceGraphBuilder composes ParkinSUM's existing synthetic artifacts
(mechanistic replay, source-quality perturbation report, release snapshot,
EvidenceTraceBundle, and optionally the public demo walkthrough) into a
deterministic, machine-readable **local evidence/provenance graph**. It helps
reviewers see *how synthetic demo outputs are produced from source-linked
metadata and reports* — in one JSON + Mermaid view.

## 2. Safety boundary

This is a **local evidence graph only**. It is **not** a patient record; it emits
**no** patient / subject / encounter semantics; it is **not** a FHIR `Provenance`
resource; it is **not** W3C PROV conformant; it is **not** clinical validation;
it is **not clinically calibrated**; and it is **not medical advice**. It never
uses `resourceType: Provenance` or `resourceType: Bundle`.

## 3. What the graph includes

- `graph_type = parkinsum_local_evidence_graph`,
  `conformance_status = local_not_fhir_provenance_not_w3c_prov`,
  `phi_policy = no_patient_no_subject_no_encounter`.
- **Nodes** (closed type set): source_document, observation, resolved_fact,
  food_variant, drug_variant, metadata_completeness_gate, source_authority_gate,
  mechanistic_layer, replay_report, source_quality_report, release_snapshot,
  evidence_trace_bundle, public_demo_walkthrough, safety_boundary, limitation.
  Each node carries id, type, label, summary, sourceRefs, metadata, missingness,
  optional safety boundary, optional status.
- **Edges** (closed type set): derived_from, uses, summarizes, explains, checks,
  limits, reports, links_to. Each carries id, from, to, type, label, sourceRefs,
  metadata.
- Graph-level sourceRefs (union of node sourceRefs, sorted), safety boundary,
  not-advice text, and limitations.

## 4. What the graph does NOT include

No patient/subject/encounter, MedicationRequest/MedicationAdministration,
dosageInstruction, timing instruction, diagnosis, treatment, or clinical
recommendation keys; no FHIR/PROV `resourceType`; no raw advice; no PHI.

## 5. Inputs

Parsed artifact maps (file I/O lives in the tool wrapper):
`build/mechanistic_replay/latest.json`,
`build/source_quality_perturbation/latest.json`,
`build/release_snapshot/latest.json`, an EvidenceTraceBundle JSON (a synthetic
sample if no standalone artifact exists), and optionally
`build/public_demo_walkthrough/latest.json`. Any absent input becomes a
**`missing_artifact`** node — never a fabricated success.

## 6. Outputs

- `build/evidence_graph/latest.json` — the full graph.
- `build/evidence_graph/latest.mmd` — a Mermaid `flowchart TD`.
- `build/evidence_graph/latest.md` — the Mermaid graph in a fenced block.

## 7. How to run

```sh
dart run tool/generate_evidence_graph.dart   # or: npm run evidence:graph
```

It reads existing `build/` artifacts (run the replay / source-quality /
release-snapshot tools first for a fully-populated graph). No network; no slow
verification commands are run inside the tool.

## 8. How to inspect the JSON graph

Open `build/evidence_graph/latest.json`. Confirm `graph_type`,
`conformance_status`, `phi_policy`, the `nodes`/`edges` arrays, and that any
absent input shows a node with `status: missing_artifact` and
`missingness.artifact_present: false`.

## 9. How to inspect the Mermaid graph

Open `build/evidence_graph/latest.mmd` (or the fenced block in `latest.md`) in any
Mermaid viewer. Node order and edge order are deterministic; labels are sanitized
(no raw JSON, no PHI).

## 10. How missing artifacts are represented

A missing or malformed input produces a node of the expected type with
`status: missing_artifact` (and a `[missing_artifact]` marker in the Mermaid
label). The graph structure stays stable so diffs are meaningful; nothing is
fabricated.

## 11. Relationship to FHIR Provenance / W3C PROV / FAIR

These standards are used **only as inspiration** for local educational
traceability:

- **HL7 FHIR Provenance** describes the entities and processes involved in
  producing/delivering/influencing a resource, supporting authenticity, trust,
  and reproducibility. ParkinSUM's graph borrows the *idea* but is **not** a FHIR
  Provenance resource.
- **W3C PROV** models provenance via entities, activities, and agents.
  ParkinSUM's graph is **not** a PROV export.
- **FAIR principles** apply not only to data but also to the algorithms, tools,
  and workflows that produce data — motivating a machine-readable trace of how
  synthetic outputs are produced.

## 12. Limitations

Composed from synthetic/demo artifacts only; deterministic but not exhaustive;
not FHIR/PROV conformant; not a patient record; not clinical validation; not
clinically calibrated. Source-quality and provenance edges are educational
traceability, not clinical accuracy.

## 13. Reviewer checklist

- [ ] `dart run tool/generate_evidence_graph.dart` writes the three outputs.
- [ ] JSON declares `parkinsum_local_evidence_graph` /
      `local_not_fhir_provenance_not_w3c_prov` / `no_patient_no_subject_no_encounter`.
- [ ] No patient/subject/encounter (or other clinical-care) **keys** appear.
- [ ] Missing inputs show `status: missing_artifact` (not fabricated).
- [ ] source-quality → metadata completeness + source authority edges exist.
- [ ] replay → mechanistic layer edge exists; release snapshot → safety boundary
      edge exists.
- [ ] Mermaid output is deterministic and free of advice phrasing.
