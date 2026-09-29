library;

import 'versioned_dose_unit_mapping.dart';

/// Parsing state for one user-entered medication logging expression.
///
/// `held` means the original text is preserved but no numeric dose from that
/// text may enter a result-affecting algorithm.
enum DoseExpressionParseStatus { empty, accepted, held }

enum DoseExpressionDimension { mass, volume }

enum DoseExpressionRole { administrationDose }

/// Presentation-only operator tokens found in a held expression.
///
/// These tokens are not FHIR `Quantity.comparator` codes and do not authorize
/// comparison or dose calculation.
enum DoseExpressionComparatorToken {
  lessThan('<'),
  lessThanOrEqual('<='),
  greaterThanOrEqual('>='),
  greaterThan('>');

  const DoseExpressionComparatorToken(this.symbol);

  final String symbol;
}

enum DoseExpressionDiagnosticKind { comparatorQuantity, closedRange }

/// Versioned local unit identity.
///
/// This is deliberately not labelled UCUM. It is a closed ParkinSUM input
/// vocabulary with its own system and version until independently validated
/// terminology assets and conformance evidence exist.
final class DoseUnitIdentity {
  const DoseUnitIdentity({
    required this.display,
    required this.system,
    required this.code,
    required this.version,
    required this.dimension,
    required this.mappingEvidence,
  });

  final String display;
  final String system;
  final String code;
  final String version;
  final DoseExpressionDimension dimension;
  final VersionedDoseUnitMapping mappingEvidence;

  Map<String, Object?> toJson() => <String, Object?>{
    'display': display,
    'system': system,
    'code': code,
    'version': version,
    'dimension': dimension.name,
    'mappingEvidence': mappingEvidence.toJson(),
  };
}

final class DoseQuantityExpression {
  const DoseQuantityExpression({
    required this.value,
    required this.unit,
    required this.role,
    required this.sourceStart,
    required this.sourceEnd,
  });

  final double value;
  final DoseUnitIdentity unit;
  final DoseExpressionRole role;
  final int sourceStart;
  final int sourceEnd;

  Map<String, Object?> toJson() => <String, Object?>{
    'value': value,
    'unit': unit.toJson(),
    'role': role.name,
    'source_span': <String, int>{'start': sourceStart, 'end': sourceEnd},
  };
}

/// Numeric operand retained for a held, view-only comparator or range shape.
///
/// The lexical value preserves the user's stated precision. Even when the
/// local unit token maps exactly, this value is never exposed as an accepted
/// [DoseQuantityExpression] and is never sent to a result-affecting algorithm.
final class DoseExpressionDiagnosticQuantity {
  const DoseExpressionDiagnosticQuantity({
    required this.lexicalValue,
    required this.value,
    required this.unit,
    required this.valueStart,
    required this.valueEnd,
    required this.unitStart,
    required this.unitEnd,
  });

  final String lexicalValue;
  final double value;
  final DoseUnitIdentity unit;
  final int valueStart;
  final int valueEnd;
  final int unitStart;
  final int unitEnd;
}

/// A syntax-only annotation for a held comparator quantity or closed range.
///
/// It is transient UI evidence, deliberately omitted from `toJson`, portable
/// packages, confirmation receipts, and algorithm inputs. It records syntax;
/// it does not assert the clinical meaning or inclusivity of the source text.
final class DoseExpressionDiagnosticStructure {
  const DoseExpressionDiagnosticStructure({
    required this.kind,
    required this.sourceStart,
    required this.sourceEnd,
    this.comparator,
    this.quantity,
    this.lowerBound,
    this.upperBound,
  });

  final DoseExpressionDiagnosticKind kind;
  final int sourceStart;
  final int sourceEnd;
  final DoseExpressionComparatorToken? comparator;
  final DoseExpressionDiagnosticQuantity? quantity;
  final DoseExpressionDiagnosticQuantity? lowerBound;
  final DoseExpressionDiagnosticQuantity? upperBound;

  String get displayText => switch (kind) {
    DoseExpressionDiagnosticKind.comparatorQuantity =>
      '${comparator!.symbol} ${quantity!.lexicalValue} '
          '${quantity!.unit.display}',
    DoseExpressionDiagnosticKind.closedRange =>
      '${lowerBound!.lexicalValue}–${upperBound!.lexicalValue} '
          '${lowerBound!.unit.display}',
  };
}

/// Full fail-closed parser result used by UI, tests, and compatibility APIs.
final class DoseExpressionParseResult {
  DoseExpressionParseResult({
    required this.rawText,
    required this.normalizedText,
    required this.grammarId,
    required this.grammarVersion,
    required this.grammarDigest,
    required this.status,
    required List<String> reasonCodes,
    required this.expression,
    this.diagnosticStructure,
  }) : reasonCodes = List<String>.unmodifiable(reasonCodes);

  final String rawText;
  final String normalizedText;
  final String grammarId;
  final int grammarVersion;
  final String grammarDigest;
  final DoseExpressionParseStatus status;
  final List<String> reasonCodes;
  final DoseQuantityExpression? expression;

  /// Transient view-only structure for selected held syntax. This is
  /// intentionally not part of the serialized parse-result or algorithm API.
  final DoseExpressionDiagnosticStructure? diagnosticStructure;

  bool get accepted =>
      status == DoseExpressionParseStatus.accepted && expression != null;

  String? get primaryReasonCode =>
      reasonCodes.isEmpty ? null : reasonCodes.first;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'parkinsum.dose-expression-parse-result/2',
    'raw_text': rawText,
    'normalized_text': normalizedText,
    'grammar_id': grammarId,
    'grammar_version': grammarVersion,
    'grammar_digest': grammarDigest,
    'status': status.name,
    'reason_codes': reasonCodes,
    'expression': expression?.toJson(),
    'boundary':
        'Input syntax and provenance only. This does not verify a prescription, '
        'dose appropriateness, administration, or medical advice.',
  };
}
