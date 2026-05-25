# Synthetic Demo Scenarios

ParkinSUM includes a small synthetic scenario pack for public demos:
`docs/assets/demo/synthetic-scenarios.json`.

These examples are fictional and are for educational demonstration only. They
are not medical advice, not a medical device workflow, have no clinical
validation, and are not suitable for diagnosis, treatment decisions, medication
timing changes, dietary instructions, clinical decision-making, patient care, or
emergency support.

The current app does not expose a public one-click demo-data loader. Treat the
JSON pack as copy-ready demo input, a manual walkthrough guide, and a future
loader fixture. Do not import it into a real user account or mix it with real
health information.

## Included Pack

- File: `docs/assets/demo/synthetic-scenarios.json`
- Version: `0.1.0-alpha`
- User profile: fictional `Demo User Alpha`
- Medication context: synthetic levodopa-containing context for app
  demonstration only, not a prescription and not a dosing recommendation
- Data labels: synthetic data, fictional user, educational demonstration, not
  medical advice, not a medical device

## Scenario Walkthroughs

### High-Protein Meal Near Synthetic Medication Time

This scenario pairs a synthetic tofu and lentil bowl with a synthetic medication
event one hour earlier. It demonstrates the current baseline
`pd.ldopa.protein.window.v1` rule, which is evidence-linked and deterministic.

Expected demo point: ParkinSUM should explain the protein and relative-timing
context without telling a user to change medication timing, dose, treatment, or
diet.

### Balanced Meal Outside the Baseline Timing Window

This scenario pairs a synthetic rice, vegetable, and fruit meal with a
synthetic medication event more than five hours earlier. It demonstrates a
low-alert comparison where the current baseline levodopa/protein timing rule
does not match.

Expected demo point: visitors can see that the rule engine is conditional and
does not warn for every meal.

### Fiber/Fat-Heavy Meal Context

This scenario uses synthetic avocado, nut spread, and whole-grain toast. The
meal carries fiber and fat context, and it also contains enough protein within
the baseline timing window to match `pd.ldopa.protein.window.v1`.

Expected demo point: fat and fiber can be represented as context, but the
baseline output should still be framed around the active evidence-linked protein
timing rule. Do not claim a standalone fat/fiber clinical rule unless such a
rule is explicitly imported and evidence-linked.

### Low-Risk Educational Snack Example

This scenario uses a synthetic applesauce snack with low protein context and no
baseline rule match.

Expected demo point: visitors can compare a no-match result against the
protein-timing examples without treating the output as medical clearance for a
real person.

## Manual Demo Flow

1. Run ParkinSUM in local mode.
2. Use a fictional profile such as `Demo User Alpha`.
3. Enter only the synthetic meal and medication context shown in the JSON pack.
4. Run the food-drug awareness check.
5. Explain that the output is educational, deterministic, and evidence-oriented.
6. Do not show real accounts, real schedules, real symptoms, identifiers,
   Firebase credentials, local file paths, or private logs.

## Safety Boundary

The demo scenarios must not be used to decide what a person should eat, when a
person should take medication, whether a medication is appropriate, or whether a
meal is safe. For real health questions, users should consult qualified
clinicians or pharmacists.
