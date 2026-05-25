# Impact FAQ

## Is ParkinSUM medical advice?

No. ParkinSUM is an educational digital-health prototype. It must not be used
for diagnosis, treatment, medication timing changes, dietary instructions,
patient monitoring, or emergency support.

## Does ParkinSUM use real patient data?

No public demo materials should use real patient data. The repository includes
synthetic scenarios for demonstration and testing. Public screenshots, GIFs,
presentations, and walkthroughs should use synthetic or sample data only.

Do not enter real medication schedules, symptoms, health records, names,
contacts, account identifiers, or private notes into public demos.

## Has ParkinSUM completed clinical validation?

No. ParkinSUM does not claim clinical validation, patient outcome improvement,
regulatory approval, or medical-device status. It is a software prototype and
educational research artifact, not a clinical intervention.

## Why local-first?

Local-first design makes the public showcase easier to run and safer to present.
It helps avoid accounts, external services, and real patient records during
education-focused demos. It also makes the software behavior easier to inspect
because the core flow can run from the local repository.

## Why not use an LLM for conflict decisions?

Conflict decisions need deterministic, testable behavior. ParkinSUM uses a rule
engine for structured checks so tests can verify which rules triggered, which
rules stayed silent, what severity labels were produced, and which evidence
references were attached.

An AI model may be useful later for wording polish or summarization, but it
should not decide the conflict result or change evidence-backed facts.

## What does the prototype demonstrate?

It demonstrates a responsible app pattern:

- Flutter user interface;
- local-first data flow;
- synthetic meal and medication scenarios;
- deterministic rule evaluation;
- evidence-oriented explanations;
- conservative public safety language.

## Can this be used in a classroom or portfolio?

Yes, if it is presented as an educational prototype with synthetic data. The
recommended materials are:

- [one-page summary](one-page-summary.md);
- [technical case study](technical-case-study.md);
- [project pitch](project-pitch.md);
- [safety and ethics](safety-and-ethics.md).

## Can contributors add new rules?

Contributors can propose research-rule improvements, but requests should include
evidence sources and must not present direct clinical advice. See the
[contribution guide](../../CONTRIBUTING.md) and
[public contribution backlog](../contribution-backlog.md).
