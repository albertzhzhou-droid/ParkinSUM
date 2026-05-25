# Roadmap

This roadmap is scoped to the public educational prototype. It does not imply
clinical validation, real-world patient use, regulatory clearance, or readiness
for medical decision-making.

## v0.1.0-alpha Showcase

- Publish a GitHub release with educational/research-only release notes.
- Add real app screenshots captured with synthetic data.
- Add a 1-2 minute demo video or GIF showing onboarding, meal entry,
  medication context, and conflict explanation.
- Provide a sample demo dataset or clearly documented demo-mode path.
- Keep `npm run public:preflight` at zero `BLOCKER` findings.

## Evidence And Rule Transparency

- Build an evidence-linked rule registry overview for reviewers.
- Document severity labels, source references, and rule trace fields.
- Add more synthetic examples for levodopa-food interaction awareness,
  protein-timing education, and non-clinical explanation copy.
- Keep deterministic rules as the source of truth for results.

## Accessibility And Education

- Improve contrast, tap targets, and readable copy for older users.
- Add caregiver-oriented onboarding and education flows.
- Integrate offline educational booklet content as a clearly separated
  education layer.
- Expand multilingual strings with reviewer-friendly coverage notes.

## Open-Source Readiness

- Label starter issues as `good first issue` and `help wanted`.
- Add contribution examples for docs, UI strings, accessibility, tests, and
  synthetic sample interactions.
- Keep README, architecture docs, rule-engine docs, and release notes aligned
  with the prototype safety boundary.

## Later Research Directions

- Versioned evidence registry with review status and source provenance.
- Release-diff reports for rule and evidence changes.
- More complete synthetic benchmark cases for rule regression tests.
- Portfolio page linking GitHub, demo video, release notes, and community
  feedback summary.
