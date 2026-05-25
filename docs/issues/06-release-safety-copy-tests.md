# Add copy tests for release safety language

Labels: `testing`, `demo/release`

## Problem

Public-facing docs must avoid unsupported claims, but some checks are currently
concentrated in the preflight script.

## Expected output

Add or extend tests/checks that verify release docs mention educational-only
use, synthetic/demo data, and no clinical validation claimed.

## Files likely involved

- `tool/public_repo_preflight.mjs`
- `package.json`
- `docs/release/`

## Difficulty

Intermediate.

## Safety notes

The check should block overclaims without blocking correct negated safety
language.
