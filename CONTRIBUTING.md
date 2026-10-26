# Contributing

Contributions are welcome when they respect the public prototype boundary.
ParkinSUM is an educational and research prototype, not clinical software.

All contributors must follow the project
[Code of Conduct](CODE_OF_CONDUCT.md).

## Data Rules

- Use only synthetic or sample data.
- Do not include personal health information.
- Do not include Firebase tokens, service account keys, user exports, raw audit
  logs, real emails, full UIDs, credential paths, or private screenshots.
- Do not add claims that ParkinSUM has completed clinical validation, legal
  approval, privacy certification, or real-world health suitability.
- Do not write text that sounds like diagnosis, treatment, medication timing
  advice, individualized dietary guidance, patient care, or emergency support.

## Good First Issue Areas

Start with the public [contribution backlog](docs/contribution-backlog.md) or
copy a draft issue from [docs/issues/](docs/issues/).

- Improve multilingual UI strings or documentation wording.
- Add synthetic sample food-medication interaction examples.
- Improve accessibility for older users, including contrast, tap targets, and
  plain-language copy.
- Add or refine dark-mode UI checks.
- Refactor conflict-checking service tests.
- Design caregiver-oriented onboarding copy or screen flow notes.
- Add README screenshots or demo video captured with synthetic data only.

## Branch and Pull Request Workflow

1. Fork the repository if you do not have push access, then clone your fork.
   Add the original project as an `upstream` remote if needed.
2. Start from an updated default branch and create a focused branch **before**
   editing files:

   ```sh
   git switch main
   git pull --ff-only
   git switch -c docs/describe-your-change
   ```

3. Keep the diff focused. Review `AGENTS.md` before editing; it requires exactly
   one entry in [the iteration timeline](docs/APP_EVOLUTION_TIMELINE.md) per
   iteration, including the baseline, verification, remaining limits, and
   rollback scope. Preserve unrelated local changes.
4. Run the applicable checks below, review `git diff --check` and `git diff`,
   then stage only the intended files and commit them.
5. Push the branch to your fork (or a repository where you have push access):

   ```sh
   git push -u origin docs/describe-your-change
   ```

6. Open a pull request against the upstream default branch. Complete the
   [PR template](.github/PULL_REQUEST_TEMPLATE.md), describe the visible change,
   and report checks as passed, failed, or not run with the reason. A pushed
   branch alone does not create a pull request.

## Documentation-only Changes

Check relative links, heading anchors, command names, toolchain versions, and
claims against the tracked source. Keep historical release records dated; do
not present an old verification result as a fresh run. Use synthetic examples
and preserve the educational, non-clinical scope.

Run `git diff --check` and `npm run public:preflight` for a documentation change.
The complete `npm run verify:pr` workflow below remains the submission check;
if you cannot run it, explicitly list the omitted checks and why in the PR.
A manual documentation review does not establish that app tests or builds pass.

## Pull Request Expectations

Every pull request should state whether it touches:

- CDSS-style rule logic or result copy.
- Firebase rules, Auth, Firestore paths, or operator tooling.
- Privacy, disclaimer, support, or security text.
- Public demo behavior.
- Importers, provenance, or release evidence.
- Screenshots, demo media, sample data, or documentation claims.

Run before submitting:

```sh
npm run verify:pr
```

`npm run verify:pr` runs every step of the pull-request workflow
(`.github/workflows/ci.yml`) in the same order, including `flutter pub get`
before `dart format`, the Flutter tests and builds, the Node public preflight
(`public:preflight`, `rules:contract`, `rules:runner:test`, `schema:contract`,
`upgrade:queue`, `privacy:store`, `open-source:firewall`, `release:contract`,
`security:dependencies`, `rules:test`) and `npm run verify:all`. Steps that need
a toolchain you do not have (Go, Gradle, Java 21, an Android SDK) or the network
are reported as skipped, never as passed, and the command then exits with 3
instead of 0; say in the PR which steps were skipped.
`npm run verify:pr -- --list` shows every step and what it needs. See
[docs/PUBLIC_VERIFICATION.md](docs/PUBLIC_VERIFICATION.md).

`npm run rules:test` uses the Firestore Emulator and therefore needs Java 21 or
newer; the repository runner checks an explicit ParkinSUM Java home,
`JAVA_HOME`, standard Android Studio JBR locations, and `java` on `PATH`
without changing the system Java setting. Expected rule-denial cases may print
`PERMISSION_DENIED`; the command succeeds only when every allow and deny
assertion reaches its expected result and all seven required semantic cases
complete with no skipped or TODO result.

## Algorithm Configuration Identity

Do not bump the algorithm configuration identity by hand, and never on two
branches in parallel: both would edit the same governance files and create the
same `test/fixtures/governance_history_before_vN.json`. Leave the identity,
context-of-use ledger, plan, attestations and queue sentences alone in feature
commits. At merge time, rebase onto `origin/main` and run

```sh
npm run identity:rebind -- --title "<short noun phrase>" --reason "<binds …>"
```

then commit the result as its own last commit (drop and redo it after any
further rebase). The tool is idempotent and verifies the result with the
existing governance tests; see [docs/IDENTITY_REBIND.md](docs/IDENTITY_REBIND.md).

If your change is documentation-only and local tooling is unavailable, say so in
the PR and list the files you reviewed manually.

## Open-Source Research Boundary

Researching an upstream project does not authorize copying its code, assets,
schemas, fixtures, or generated output. Before citing a new GitHub repository in
the upgrade queue or research documentation, add its canonical repository URL,
reviewed commit, license status, and concept-only or transfer disposition to
`config/open_source_influence_inventory.json`, then run:

```sh
npm run open-source:firewall
```

`NOASSERTION`, a missing license, or an unresolved license keeps the influence
concept-only. Any local transfer requires an explicit path, compatible
copy/distribution authorization, applicable notice and source-disclosure
obligations, and a matching release-boundary declaration. Passing the checker
is an inventory and policy control; it is not legal advice, scientific
validation, or a substitute for artifact-level SBOM and NOTICE verification.

## Secondary Creator Token Flow

If you are remixing the project or testing a classmate or mentor contribution,
use the fork-first GitHub token sequence in
[docs/secondary-creator-token-flow.md](docs/secondary-creator-token-flow.md).
Scope the token to your fork, push your branch there, and open a pull request
back to `albertzhzhou-droid/ParkinSUM:main`. The repository provides permission
guidance and a machine-readable sequence, not real token values. Store personal
access tokens locally through GitHub CLI or a system credential manager, never
in source files.

## Public Demo Media

Screenshots and videos must use synthetic/sample data only. Before adding media,
check [docs/assets/screenshots/README.md](docs/assets/screenshots/README.md) and
[docs/assets/demo/README.md](docs/assets/demo/README.md).
