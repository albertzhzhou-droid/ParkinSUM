# ParkinSUM Workspace Rules

## In-place iteration and disk use

- Evolve this existing worktree in place. Do not create a new directory that
  contains a complete copy of the repository, source tree, dependencies, build
  outputs, or all project content for an iteration.
- Do not use folder copies as versioning or rollback. Use surgical source
  edits, Git diffs/commits when authorized, and the canonical timeline below.
- Normal tool-managed caches and build outputs may be regenerated in their
  existing ignored locations, but must not be duplicated into iteration or
  backup folders inside the workspace.

## Mandatory iteration timeline

- After every implementation iteration, append exactly one entry to
  `docs/APP_EVOLUTION_TIMELINE.md`.
- Record the date and iteration id, committed HEAD and refreshed public-main
  baseline, schema/version changes, concrete changed files and behavior,
  verification evidence, unresolved boundaries, and a surgical rollback scope.
- Maintain that one timeline file. Do not create per-iteration timeline files
  or directories containing duplicated project content.

## Worktree truth boundaries

- Keep public GitHub, committed local HEAD, uncommitted work, and ignored or
  generated paths distinct in every audit.
- Preserve unrelated or concurrent dirty-worktree changes. Never use a broad
  reset to roll back one iteration.
