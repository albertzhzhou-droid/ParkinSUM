# Public Showcase Readiness

ParkinSUM Companion is ready to be presented as a public GitHub prototype when
the public repository preflight reports zero blockers.

## Intended Public Use

- Architecture review.
- Portfolio presentation.
- Educational software engineering discussion.
- Synthetic-data demonstration.
- Review of Firebase governance, Firestore rules, provenance, release evidence,
  and operator tooling.

## Out of Scope for the Public Showcase

- Real user registration for health use.
- Real health, medication, symptom, meal, or patient records.
- Real-world clinical, legal, privacy, or regulatory claims.
- Diagnosis, treatment, medication timing, dietary guidance, emergency support,
  or personal health management.
- External clinical/legal/privacy professional approval claims.

## Required Public Repository Controls

- `DISCLAIMER.md`, `SECURITY.md`, `CONTRIBUTING.md`, and `LICENSE` are present.
- User-visible support and privacy contact is `parkinsumservice@gmail.com`.
- Local token files, service account keys, user exports, and raw operator audit
  logs are not included in the public repository.
- GitHub issue and pull request templates warn contributors not to submit
  personal health information or credentials.
- `npm run public:preflight` passes with zero `BLOCKER` findings.

## Evidence & Traceability Showcase Entry Points

The evidence/traceability layer is the primary review surface. It is a set of
deterministic, synthetic-data artifacts — not clinical calibration and not
medical advice:

- Guided walkthrough: `docs/EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md`
- Implemented vs future work: `docs/CAPABILITY_MATRIX.md`
- Exact reviewer commands: `docs/PUBLIC_VERIFICATION.md`
- Documentation index: `docs/README.md`

## Future Real-World Use Gate

If this project is ever repositioned as a real health, clinical, or personal
decision-support product, the public-showcase readiness decision no longer
applies. A separate productization track would be required, including
professional clinical review, legal/privacy review, security review,
production-support ownership, and applicable regulatory analysis.
