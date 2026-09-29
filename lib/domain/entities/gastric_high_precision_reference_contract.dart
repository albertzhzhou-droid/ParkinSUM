const int gastricHighPrecisionReferenceSchemaVersion = 1;
const String gastricHighPrecisionReferenceSchema =
    'parkinsum.gastric-high-precision-reference-check/1';

/// Source-level contract for the precision-diverse release artifact.
///
/// The executable verifier lives under `tool/` and is deliberately written in
/// Node/BigInt rather than Dart so it does not share production binary64
/// arithmetic. This contract makes the artifact discoverable by schema
/// governance without implying runtime or clinical use.
abstract final class GastricHighPrecisionReferenceContract {
  static const String arithmeticIdentity =
      'independent-node-bigint-fixed-decimal';
  static const int decimalDigits = 60;
  static const String boundary =
      'Manufactured calculation verification only; not identifiability, '
      'biological validity, clinical calibration, individual prediction, '
      'treatment guidance, or medical advice.';
}
