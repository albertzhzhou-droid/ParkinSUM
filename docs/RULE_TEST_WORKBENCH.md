# Synthetic rule test workbench

Open **Settings → Engineering diagnostics → Rule test workbench**. The page
edits engineering fixtures in memory. It does not read the account's meals,
medication history or observations, and does not install a rule into the
application's knowledge database.

## Run and inspect a case

1. Start with the bundled rule pack and the supplied synthetic case.
2. Edit the case JSON. Keep `synthetic_only: true` and the fixed
   `context.user_profile.patient_id: "synthetic_test_case"`. Use explicit
   timezone offsets for timestamps. Nullable fields stay null; unsupported
   shapes or units are rejected instead of guessed.
3. Author the `expected` section from the rule specification and review it
   independently. The workbench never copies actual output into expectations.
4. Run the case. Inspect each expected/actual assertion and the engine's rule
   explanations. A passing run establishes agreement with those assertions
   for that case, not clinical correctness or approval to activate the rule.
5. Copy the case or report only with the corresponding explicit button. Save
   the copied JSON separately if it must survive closing the page.

`expected.targets: null` means no assertion about final targets. An empty
array means an explicit assertion that there are no final audit targets.
These are different: the engine can emit a `runtime-context` fallback even
when no rule matches. Target assertions compare the exact target set, final
decision and winning rule IDs; suppressed candidates are not winners.
`missing_fields_by_rule` asserts the engine's field codes for specified rules.
A missing or excluded trace cannot pass as an empty missing-field list.
With no assertions the result is **not verified**, even when execution succeeds.

An expectation fragment has this form; it is an illustration of the schema,
not a reviewed clinical test answer:

```json
{
  "targets": [
    {
      "target": "drug-meal",
      "decision": "WARN",
      "winning_rule_ids": ["rule-id-from-the-bound-pack"]
    }
  ],
  "missing_fields_by_rule": {
    "rule-id-from-the-bound-pack": []
  }
}
```

## Compare and replay rule packs

The pack contains complete declarative rule JSON plus a binding to its source,
bundle version, content digest and per-rule versions. Import validates that
binding. A case bound to a different pack does not silently run against the
new pack. Explicitly rebinding a case preserves its authored expectations and
requires another run.

Bindings declare `synthetic-json-binary64-v1`: object keys are sorted, array
order is retained, every JSON node is type-tagged, and numeric values use exact
binary64 bytes. `1` and `1.0` share an identity; signed zero normalizes to zero.
Non-finite numbers, magnitudes above 9,007,199,254,740,991 and malformed Unicode
are rejected. This format avoids desktop/web JSON-number serialization drift.
The engine's existing native input digest is reported separately and is not
claimed to be portable.

The rule-pack field imports an already bound export. Editing its rule content
without rebuilding its binding in the authoring API is intentionally rejected;
this page does not yet provide a draft rule authoring or approval form.

The comparison identifies added, removed and changed rule IDs, ordered-array
changes and field paths. Absent fields differ from explicit null. A content
change without a rule-version change is highlighted. This is a structural
comparison, not a semantic-equivalence or provenance-authentication proof.
Numeric presentation differences are runtime-dependent: the VM can preserve
`1.0` versus `1`, while the web runtime may already have collapsed them.

By default only active rules execute. Draft or historical-status simulation
requires an explicit mode selection, which is recorded with the included and
excluded statuses. It cannot change production activation. Old rule JSON runs
on the **current Dart engine**; reports identify that engine configuration.
Historical source-document bodies, terminology databases and executable
versions are not restored. Rule-provided source references remain visible,
but the workbench does not retrieve or independently verify their content.

## Scope and limits

Cases and packs use schema v1, strict keys and bounded JSON. Context fields
follow the existing runtime model: for example, a missing whole meal is null,
but an individual meal nutrient cannot be null in that model and is rejected
rather than converted to zero. Imported case text is user-authored: a fixed
synthetic subject marker does not prove that every free-text field is free of
personal information. Use fabricated fixtures only.

Dose-band simulation supports the explicitly checked field/unit combinations;
ambiguous unit conversion paths in the current engine are rejected. A rejected
combination is unsupported, not a negative clinical result.

The workbench is the test/replay portion of the expansion plan. A complete
knowledge-package lifecycle still needs content-bound independent review of
positive, negative, missing-input and boundary cases, authenticated reviewer
authority, and a fail-closed activation/withdrawal path. Existing publication
records and passing workbench assertions do not establish those capabilities.
FHIR interchange and independent CQL execution are separate subsequent work.
