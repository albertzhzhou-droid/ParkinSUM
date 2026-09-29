# Catalog version change diff

The offline comparator in `CatalogVersionChangeDiffService` accepts two
caller-supplied captures for the same catalog, source system, and jurisdiction.
Each capture contains its release identity, an explicit release sequence, and
the exact code/display rows supplied by its caller. Its SHA-256 identifies that
captured record set; it does not verify a publisher archive or show that the
capture is complete.

Changed codes require explicit transition evidence that names the source code,
current target code or codes, evidence reference and digest, both capture
digests, a caller-declared review state, and a caller-declared license
disposition. Those metadata are not independently authenticated.
An unchanged source code and display can pass through without a crosswalk. An
absent source code is unresolved unless reviewed retirement evidence says it
was deprecated. Similar names never create a mapping. Split, merge, ambiguous,
stale, unreviewed, unlicensed, and unsupported transitions remain held for an
owner decision.

The diff is deterministic and includes old and candidate identities, reasons,
and evidence references. Its SHA-256 is a content identity, not a digital
signature.

The Data Integrity page can compare the two captures from pasted JSON. It
recomputes both capture digests, rejects unknown fields, enforces a 2 MiB limit
per capture and a 1 MiB limit for evidence, and shows category counts plus at
most 20 changed codes. The result remains in page memory and is discarded as
soon as an input changes.

A separate button explicitly scans the current in-memory active medication
selection and intake list against medication definitions for exact old
source-code tokens in the changed diff. It requires matching source system and
jurisdiction, excludes placeholder codes, and returns aggregate counts only.
It never shows record IDs, names, or dose details. Active selections and
historical intakes do not bind a catalog release, so a hit is a potential
reference rather than a confirmed affected record; multiple changed-code
matches remain unattributed. An account, active-selection, intake, or catalog
identity change expires the aggregate preview. The scan is local, ephemeral,
and read-only.

A separate food-catalog action matches changed source codes against current
`FoodItem.sourceFoodCode` values and resolves saved `MealItem.foodId` values
through that current food catalog. It requires exact source-system and
jurisdiction matches, excludes placeholder codes and duplicate food IDs, and
reports aggregate food-entry, meal-line, and meal counts only. It does not read
serving quantities, alter scores, show record or food names, or change meals.
Because neither current food records nor meal lines bind the compared release,
every match is a potential reference rather than a confirmed affected entry.
The preview expires when account scope, source food identities, or meal-line
food identities change.

Caller-supplied captures may be incomplete subsets; the preview does not
verify a publisher archive, perform an owner-bound transaction, roll back a
confirmed change, or gate production algorithms. The schema and classifier are
original ParkinSUM code; no external terminology rows, crosswalk mappings,
rules, or assets are bundled.
