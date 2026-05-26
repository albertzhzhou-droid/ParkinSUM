# Secondary Creator Token Flow

This guide gives remixers, classmates, and mentor reviewers a safe fork-first
GitHub token setup for pulling ParkinSUM, making scoped changes in their own
fork, and sending updates back by pull request.

Do not commit real tokens, `.env` files, credential paths, Firebase ID tokens,
service account keys, user exports, raw audit logs, real emails, full UIDs, or
private screenshots. Public contributions must use synthetic or sample data
only.

## Recommended Access Model

Use a fork-based pull request. Secondary creators should not need direct write
access to `albertzhzhou-droid/ParkinSUM`.

| Creator type | Repository access | Recommended token permissions |
| --- | --- | --- |
| Public remixer | Fork only | Fine-grained token for the remixer's fork: `Contents: Read and write`, `Metadata: Read`, `Pull requests: Read and write` |
| Classmate or mentor reviewer | Fork only | Same as public remixer; add `Issues: Read and write` only if the task includes GitHub issue updates |

Pulling the public repository does not require a token. A token is only needed
when pushing a branch to the creator's fork, opening pull requests through the
CLI, or updating issue metadata.

## Token Sequence

Use this sequence as the source of truth for creator onboarding:

1. Create a fine-grained personal access token in GitHub.
2. Scope it to only your fork of ParkinSUM.
3. Grant the minimum permissions listed above.
4. Store it locally with GitHub CLI or your system credential manager.
5. Fork the repository on GitHub, then clone the public repository or your fork.
6. Create a scoped branch.
7. Run the public safety checks that fit the change.
8. Push the branch to your fork.
9. Open a pull request against `albertzhzhou-droid/ParkinSUM:main`.
10. Confirm the PR description states that the change uses synthetic/sample data
    only and contains no credentials.

The same sequence is available in machine-readable form at
[docs/secondary-creator-token-sequence.json](secondary-creator-token-sequence.json).

## Local Setup

Install GitHub CLI, then authenticate without writing the token into the
repository:

```sh
gh auth login
gh auth status
```

Fork `albertzhzhou-droid/ParkinSUM` in GitHub, then clone the repository:

```sh
git clone https://github.com/albertzhzhou-droid/ParkinSUM.git
cd ParkinSUM
```

If you are using a fork, set your fork as the push remote:

```sh
git remote rename origin upstream
git remote add origin https://github.com/<your-user>/ParkinSUM.git
git fetch upstream
```

Create a branch for a scoped change:

```sh
git switch -c contributor/<short-change-name>
```

## Update Flow

Keep your branch current:

```sh
git fetch upstream
git rebase upstream/main
```

Run the public checks that match the change:

```sh
npm ci
npm run public:preflight
flutter analyze
flutter test --concurrency=1
```

For documentation-only changes, at minimum review the edited files for:

- no real health information;
- no credentials, tokens, local machine paths, or private account identifiers;
- no clinical, legal, privacy, regulatory, or patient-outcome claims.

Push your branch:

```sh
git push -u origin contributor/<short-change-name>
```

Open a pull request:

```sh
gh pr create \
  --repo albertzhzhou-droid/ParkinSUM \
  --base main \
  --head <your-user>:contributor/<short-change-name> \
  --title "docs: describe <short change>" \
  --body "Uses synthetic/sample data only. Contains no credentials or private records."
```

GitHub's web UI can also open the pull request after the branch is pushed to the
fork. Use `albertzhzhou-droid/ParkinSUM` as the base repository, `main` as the
base branch, and your fork branch as the compare branch.

## Maintainer Checklist

Before reviewing or merging a secondary creator PR:

- Confirm the PR is scoped and does not expand clinical claims.
- Confirm no secrets, Firebase token files, service account keys, real user
  exports, real emails, full UIDs, credential paths, or private screenshots are
  present.
- Confirm public-demo examples use synthetic or sample data only.
- Ask for `npm run public:preflight` output when the change touches public docs,
  release materials, or demo assets.
- Ask for `flutter analyze` and focused tests when the change touches app code.

## Token Revocation

Creators should revoke or rotate the token immediately if it is pasted into a
chat, committed, shown in a screenshot, printed in a public log, or stored on a
shared machine.

If a token or private record reaches this repository, revoke or rotate the
credential first, then contact `parkinsumservice@gmail.com`.
