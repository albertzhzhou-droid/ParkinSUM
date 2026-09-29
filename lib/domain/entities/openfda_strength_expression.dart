import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Syntactic class for a source strength string. These labels describe only
/// visible delimiters; they do not assign units, dosage forms, or clinical
/// meaning.
enum OpenFdaStrengthExpressionShape {
  missing,
  unsupported,
  singleAmount,
  numericDenominatorWithoutUnit,
  unitBearingDenominator,
}

/// Lexical parse result for the openFDA NDC
/// `active_ingredients[].strength` string.
///
/// This versioned contract preserves the source spelling and exposes only
/// anchored lexical tokens. Every result is held: no UCUM mapping, product
/// denominator, FHIR strength, administration dose, or algorithm input is
/// produced. Source-record identity must be bound by a caller separately.
final class OpenFdaStrengthExpressionParseResult {
  OpenFdaStrengthExpressionParseResult({
    required this.rawSourceValue,
    required this.shape,
    required this.syntaxRecognized,
    required this.numeratorValueLexeme,
    required this.numeratorUnitLexeme,
    required this.denominatorValueLexeme,
    required this.denominatorUnitLexeme,
    required List<String> reasonCodes,
  }) : reasonCodes = List<String>.unmodifiable(
         reasonCodes.toSet().toList()..sort(),
       );

  static const String schemaUri =
      'parkinsum.openfda-strength-expression-parse-result/1';
  static const String parserVersion = 'openfda-strength-expression-parser/1';
  static const String sourceField = 'active_ingredients[].strength';

  final String? rawSourceValue;
  final OpenFdaStrengthExpressionShape shape;
  final bool syntaxRecognized;
  final String? numeratorValueLexeme;
  final String? numeratorUnitLexeme;
  final String? denominatorValueLexeme;
  final String? denominatorUnitLexeme;
  final List<String> reasonCodes;

  static const bool sourceUnitMappingPerformed = false;
  static const bool fhirStrengthEligible = false;
  static const bool administrationDoseEligible = false;
  static const bool algorithmEligible = false;

  /// Digest of this parser result and its version, not a source-record
  /// identity. A consuming workflow must bind product and source provenance.
  String get sha256 => _sha256(
    jsonEncode(<Object?>[
      schemaUri,
      parserVersion,
      sourceField,
      rawSourceValue,
      shape.name,
      syntaxRecognized,
      numeratorValueLexeme,
      numeratorUnitLexeme,
      denominatorValueLexeme,
      denominatorUnitLexeme,
      'held',
      reasonCodes,
      sourceUnitMappingPerformed,
      fhirStrengthEligible,
      administrationDoseEligible,
      algorithmEligible,
    ]),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_uri': schemaUri,
    'parser_version': parserVersion,
    'source_field': sourceField,
    'raw_source_value': rawSourceValue,
    'shape': shape.name,
    'syntax_recognized': syntaxRecognized,
    'numerator_value_lexeme': numeratorValueLexeme,
    'numerator_unit_lexeme': numeratorUnitLexeme,
    'denominator_value_lexeme': denominatorValueLexeme,
    'denominator_unit_lexeme': denominatorUnitLexeme,
    'evidence_state': 'held',
    'reason_codes': reasonCodes,
    'source_unit_mapping_performed': sourceUnitMappingPerformed,
    'fhir_strength_eligible': fhirStrengthEligible,
    'administration_dose_eligible': administrationDoseEligible,
    'algorithm_eligible': algorithmEligible,
    'sha256': sha256,
  };

  static String _sha256(String value) =>
      crypto.sha256.convert(utf8.encode(value)).toString();
}
