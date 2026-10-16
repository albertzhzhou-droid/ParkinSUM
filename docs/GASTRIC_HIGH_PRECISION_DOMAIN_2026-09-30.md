# W20: bounded expansion of the existing high-precision reference

The existing `tool/gastric_high_precision_reference_check.mjs` still uses its
60-decimal Node BigInt arithmetic, range-reduced Taylor exponential and
atanh-series logarithm. Its default command retains the original six structures
and seven times (42 points). The extension adds manufactured inputs and uses the
same arithmetic implementation. It does not introduce a second reference model,
change production formulas or weights, fit parameters, or qualify medical use.

`tool/generate_gastric_high_precision_domain_corpus.mjs` authoring is independent
of production and produces the frozen
`test/fixtures/gastric_high_precision_domain/cases.json`. The corpus was saved
before running Dart vectors. Seed 20260930, limits, expected supported/HOLD
dispositions and hand-derived zero/one/half anchors are fixed inputs. It contains
16 boundary/degenerate parameter cases, 24 seeded parameter cases, one excluded
cancellation diagnostic and 12 unsupported parameter/protocol cases. No
numerical expectation is generated from production output.

| Manufactured calculation variable | Included bounds |
| --- | --- |
| Integer minute | 0–10080 |
| Positive half/t50/time/eta scale, minutes | 0.000001–1000000 |
| Lag, minutes | 0–1440 |
| Shape exponent | 0.05–8 |
| Siegel k, 1/min | 0.000000001–4 |
| Linear-exponential initial volume, mL | 0–2000 |
| Linear coefficient kappa | 0–2 |
| Fraction/mixing weight | 0–1 |
| Production components | 1–4; fraction sum within 1e-12 of 1 |

These are software calculation bounds, not evidence-based patient parameter
ranges. Fractional/negative/out-of-bound times, unknown structures or parameters,
missing parameters, non-finite values, invalid denominators/shapes and invalid
mixture weights are HOLD. The parser rejects malformed exponent suffixes,
repeated exponents and unbounded numeric text. The corpus tests the lower/upper
limits, t=0, before/at/after lag, zero-volume and zero/one-mixture degeneracies,
rapid-decay underflow and slow-decay cases. It samples this domain; passing 313
points does not prove every parameter in the continuous domain is accurate.

The tolerance was fixed before capture: absolute error must be no larger than
`5e-12 × max(1, |independent expected|)`. It was not changed after observing Dart.
The Siegel expression subtracts nearly equal numbers in `1-exp(-k*t)`. The
predeclared subdomain t>0, beta<1, k*t<1e-6 is excluded from supported projection
and remains HOLD. A separate diagnostic at k=1e-9, beta=0.05, t=1 minute records
the actual failure; it cannot certify numerical agreement or alter defaults.
This HOLD belongs to the verification harness; it does not claim to install a
new runtime production medication/model gate.

`tool/run_gastric_high_precision_domain_vectors.dart` captures production values
by calling the existing
`GastricStructuralUncertaintyService.evaluateDeclaredStructure`. It does not
copy its formulas or import the Node implementation. The Node checker computes
the expected values independently, verifies the exact corpus byte hash,
coverage, input parameters and every supported/HOLD disposition. Unsupported
points have no ordinary numeric value. Diagnostic values remain separate and
explicitly marked outside the supported domain. The receipt also binds the
reference source, production evaluator, capture runner and input generator.

The first complete Dart VM capture and default independent check passed on
2026-09-30. This capture does not establish numeric agreement on other runtimes:

- Existing gate: 42 points across six structures.
- Extended corpus: 53 parameter cases, 313 supported points, 13 HOLD points,
  zero failures among supported points.
- Worst supported absolute error: `3.97485080800218501e-13`, at the predeclared
  Siegel cancellation boundary k=1e-6, beta=0.05, t=1, below `5e-12`.
- Excluded diagnostic: independent value
  `0.645186610775294876296770610451`; Dart value `0.645186611268165`; absolute
  difference `4.92870123703229389548e-10`, above `5e-12`. Its `passed` is false
  and numeric projection remains HOLD. Overall gate PASS means the supported
  points passed and this predeclared counterexample was detected.
- A deliberate 0.001 numeric mutation is detected. Four Node unit tests cover
  dispositions, analytic anchors, parser negatives and verifier mutations.
  Literal mock vectors in checker unit tests are not production evidence.
- Targeted Dart runner analysis reports no issues.

The actual receipt is `build/gastric_high_precision_reference/latest.json`;
production vectors are in `build/gastric_high_precision_domain_vectors/latest.json`.
Input SHA-256 is
`b57894c1218b8aad0d7903ee6ac4d0e2bef540650d51b0f5c2462ec609d142e0`.
The default command runs both legacy and extended capture. The explicit offline
interface is `--domain-only --domain-fixture <saved-vector-path>`; a partial run
reports `legacy_gate_included: false` and cannot stand in for the full gate.
Module imports perform no SDK calls.

Agreement on manufactured arithmetic is distinct from experimental validation,
parameter identifiability, biological validity, clinical calibration, individual
prediction and treatment guidance. All such qualifications remain HOLD.


Integration identity boundary: hashes and targeted receipts quoted above identify the module-check snapshot before the final v54 configuration and source rebind. They are retained without restamping. Current whole-candidate receipts are regenerated by the final verification run and listed in [MEGA results](MEGA_UPGRADE_RESULTS_2026-09-30.md). Module PASS alone does not establish current whole-worktree acceptance.
