import '../entities/openfda_strength_expression.dart';

/// Anchored lexical parser for openFDA NDC active-ingredient strength text.
///
/// The parser intentionally does not interpret unit spellings. Its narrow
/// decimal-plus-unit grammar is a review aid, not an NDC/FHIR/UCUM validator.
final class OpenFdaStrengthExpressionParser {
  const OpenFdaStrengthExpressionParser();

  static final RegExp _expressionPattern = RegExp(
    r'^\s*([0-9]+(?:\.[0-9]+)?|\.[0-9]+)\s*([A-Za-zµμ]+)\s*(?:/\s*([0-9]+(?:\.[0-9]+)?|\.[0-9]+)\s*([A-Za-zµμ]+)?\s*)?$',
  );

  OpenFdaStrengthExpressionParseResult parse(String? rawSourceValue) {
    if (rawSourceValue == null || rawSourceValue.trim().isEmpty) {
      return OpenFdaStrengthExpressionParseResult(
        rawSourceValue: rawSourceValue,
        shape: OpenFdaStrengthExpressionShape.missing,
        syntaxRecognized: false,
        numeratorValueLexeme: null,
        numeratorUnitLexeme: null,
        denominatorValueLexeme: null,
        denominatorUnitLexeme: null,
        reasonCodes: const <String>[
          'medication.product_strength.source_value_missing',
        ],
      );
    }

    final match = _expressionPattern.firstMatch(rawSourceValue);
    if (match == null) {
      return OpenFdaStrengthExpressionParseResult(
        rawSourceValue: rawSourceValue,
        shape: OpenFdaStrengthExpressionShape.unsupported,
        syntaxRecognized: false,
        numeratorValueLexeme: null,
        numeratorUnitLexeme: null,
        denominatorValueLexeme: null,
        denominatorUnitLexeme: null,
        reasonCodes: const <String>[
          'medication.product_strength.syntax_outside_reviewed_subset',
          'medication.product_strength.source_unit_mapping_not_performed',
        ],
      );
    }

    final numeratorValue = match.group(1)!;
    final numeratorUnit = match.group(2)!;
    final denominatorValue = match.group(3);
    final denominatorUnit = match.group(4);
    final shape = denominatorValue == null
        ? OpenFdaStrengthExpressionShape.singleAmount
        : denominatorUnit == null
        ? OpenFdaStrengthExpressionShape.numericDenominatorWithoutUnit
        : OpenFdaStrengthExpressionShape.unitBearingDenominator;
    final reasonCodes = <String>[
      'medication.product_strength.source_unit_mapping_not_performed',
      'medication.product_strength.not_administration_dose',
    ];

    if (!_isPositiveDecimalLexeme(numeratorValue) ||
        (denominatorValue != null &&
            !_isPositiveDecimalLexeme(denominatorValue))) {
      reasonCodes.add(
        'medication.product_strength.non_positive_numeric_lexeme',
      );
    }
    if (denominatorValue == null) {
      reasonCodes.add('medication.product_strength.denominator_not_present');
    } else if (denominatorUnit == null) {
      reasonCodes.add('medication.product_strength.denominator_unit_absent');
    } else {
      reasonCodes.add(
        'medication.product_strength.denominator_semantics_unresolved',
      );
    }

    return OpenFdaStrengthExpressionParseResult(
      rawSourceValue: rawSourceValue,
      shape: shape,
      syntaxRecognized: true,
      numeratorValueLexeme: numeratorValue,
      numeratorUnitLexeme: numeratorUnit,
      denominatorValueLexeme: denominatorValue,
      denominatorUnitLexeme: denominatorUnit,
      reasonCodes: reasonCodes,
    );
  }

  bool _isPositiveDecimalLexeme(String lexeme) {
    final significantDigits = lexeme
        .replaceAll('.', '')
        .replaceFirst(RegExp(r'^0+'), '');
    return significantDigits.isNotEmpty;
  }
}
