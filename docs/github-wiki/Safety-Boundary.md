# Safety Boundary

<p align="center"><img src="https://raw.githubusercontent.com/wiki/albertzhzhou-droid/ParkinSUM/assets/safety-boundary.svg" width="960" alt="A boundary ring around an educational prototype using synthetic data only. Inside: architecture review, deterministic rule explanations, synthetic walkthroughs, provenance inspection. Outside: diagnosis or treatment, medication timing or dose, dietary instructions, real patient data."></p>

ParkinSUM Companion is an educational prototype and public showcase artifact. It must not be presented as a medical product.

## How the code keeps the boundary

- Dose-relative values exist only when a dose was explicitly logged. Doses are never invented.
- Food-borne L-dopa is shown as presence and variability context. It is never converted into a dose equivalent.
- Source findings and ambiguities only widen uncertainty. They never make a result look more certain.
- User-facing copy is checked against banned phrases such as instructions to take, change, avoid or time anything.

## Appropriate Public Framing

- Educational software prototype.
- Local-first Flutter architecture demonstration.
- Synthetic-data walkthrough.
- Deterministic rule and evidence-trace review.
- Open-source contribution and mentoring project.

## Disallowed Public Framing

- Medical device.
- Diagnostic, treatment, monitoring, prevention, or emergency tool.
- Medication timing, dose, diet, or clinical decision-making system.
- Patient-care application.
- Patient-outcome evidence or approval claim.

## Demo Data Boundary

Do not use:

- Real patient records.
- Real medication schedules.
- Real symptoms or notes.
- Private Firebase exports.
- Service-account keys or tokens.
- Full UIDs, raw audit logs, real emails, or local credential paths.

## Required Links

- Disclaimer: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/DISCLAIMER.md
- Public demo boundary: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/PUBLIC_DEMO_BOUNDARY.md
- Known risks: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/known_risks.md
- Public verification: https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/PUBLIC_VERIFICATION.md
