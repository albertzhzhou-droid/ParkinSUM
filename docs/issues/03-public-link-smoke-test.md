# Add documentation smoke test for public links

Labels: `testing`, `documentation`

## Problem

Public docs and the GitHub Pages site contain many internal links that can
drift.

## Expected output

Add a lightweight script or documented command that checks internal
Markdown/HTML links without requiring external network access.

## Files likely involved

- `tool/`
- `package.json`
- `docs/site/README.md`
- `README.md`

## Difficulty

Intermediate.

## Safety notes

The checker should not upload docs, call private services, or scan ignored
token/export folders.
