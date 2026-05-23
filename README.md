# ParkinSUM Companion

ParkinSUM Companion is a production-architecture prototype and educational
research project. It demonstrates privacy-aware Firebase governance,
CDSS-style rule execution, provenance-first official-data ingestion, and
operator release workflows using a Parkinson medication-food interaction
scenario.

This repository is intended for architecture review, portfolio presentation,
technical evaluation, and synthetic-data demonstration. It is not intended for
real-world clinical use, diagnosis, treatment, medication timing decisions,
patient care, or personal health management.

## Public Showcase Status

- Public release type: prototype showcase.
- Package name: `parkinsum_companion`.
- Current app version: `1.0.0+1`.
- Default backend: local mode.
- Firebase backend mode: available for internal operator validation.
- Firebase projects in config: `parkinsum-companion-dev`,
  `parkinsum-companion-stage`, `parkinsum-companion`.
- Firestore configuration: rules and indexes are present.
- Firebase Hosting configuration: `firebase.json` points Hosting at
  `build/web` with no-store HTML and long-cache static assets.
- Public contact: `parkinsumservice@gmail.com`.

Public GitHub visibility does not claim external clinical, legal, privacy, or
regulatory approval. See [DISCLAIMER.md](DISCLAIMER.md) and
[PUBLIC_SHOWCASE_READINESS.md](PUBLIC_SHOWCASE_READINESS.md).

## What This Prototype Demonstrates

- Firebase Auth and Firestore account-bound user paths.
- Firestore security rules for owner-only private records and
  admin/importer-governed catalog writes.
- CDSS-style deterministic rule traces, source references, and explainable
  result copy.
- Provenance-first official-data importer and seed workflows.
- Operator tooling for release manifests, backup evidence, monitoring checks,
  audit summaries, and rollback records.
- Public showcase boundaries that keep real health data out of public demos.

## Safety Boundary

Use only synthetic or sample data when demonstrating this project publicly. Do
not submit real health information, medication schedules, symptoms, account
tokens, Firebase credentials, service account keys, user exports, or raw
operator audit logs to this repository.

The app may contain CDSS-style example logic, but those examples are for
software architecture demonstration only. They are not instructions for real
health decisions.

## Local Commands

Run all commands from this directory.

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" pub get
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" analyze
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" test
```

Run the app in local mode:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" run -d chrome
```

Run the public repository preflight:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
npm run public:preflight
```

Run Firebase rules contract validation:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
node tool/firestore_rules_contract_check.mjs
```

## Internal Firebase Operator Commands

Firebase-backed commands are retained to show the production-style governance
architecture. They require project access and must not be used with real user
health data in public demos.

Run the app against stage Firebase:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" run -d chrome --dart-define=PARKINSUM_BACKEND=firebase --dart-define=PARKINSUM_ENV=stage --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion-stage
```

Build the Firebase-backed web artifact:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" build web --dart-define=PARKINSUM_BACKEND=firebase --dart-define=PARKINSUM_ENV=prod --dart-define=PARKINSUM_FIREBASE_PROJECT_ID=parkinsum-companion
```

Lightweight operator gates:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
node tool/operator_gate.mjs --env stage --project parkinsum-companion-stage --release-id p1_stage_gate
node tool/operator_gate.mjs --env prod --project parkinsum-companion --read-only --release-id p1_prod_gate
```

## Documentation

- [Disclaimer](DISCLAIMER.md)
- [Public showcase readiness](PUBLIC_SHOWCASE_READINESS.md)
- [Security policy](SECURITY.md)
- [Contribution guide](CONTRIBUTING.md)
- [Architecture overview](docs/ARCHITECTURE.md)
- [Public demo boundary](docs/PUBLIC_DEMO_BOUNDARY.md)
- [Release evidence index](docs/RELEASE_EVIDENCE_INDEX.md)
- [Firebase production operations runbook](docs/firebase_operations_runbook.md)
- [Environment and deployment guide](docs/environment_deployment.md)
- [Rollback runbook](docs/rollback_runbook.md)
- [Known risks](docs/known_risks.md)

## Firebase Seed Workflow

Export and upload workflows are internal operator examples. Do not run them
against public demo data or with real user health records.

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/dart" run tool/firebase_seed_export.dart --user-uid=<firebase_uid>
node tool/firestore_seed_upload.mjs build/firebase_seed/official_core_seed.json --dry-run
```

## Public GitHub Preflight

The preflight scans the whole working tree, including local build artifacts, and
separates findings into:

- `BLOCKER`: must be fixed before publishing.
- `WARN`: usually acceptable local/generated evidence or internal operator
  references.
- `INFO`: positive readiness evidence.

Reports are written to:

- `build/public_release_preflight/latest.json`
- `build/public_release_preflight/latest.md`

Public showcase readiness requires zero `BLOCKER` findings.
