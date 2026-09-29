import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/dose_expression.dart';
import 'package:parkinsum_companion/domain/entities/versioned_dose_unit_mapping.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';

void main() {
  final parser = DosageNoteParser();
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/dose_expression_vectors.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = (fixture['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('grammar identity is versioned and deterministic', () {
    expect(DosageNoteParser.grammarId, isNotEmpty);
    expect(DosageNoteParser.grammarVersion, greaterThan(0));
    expect(DosageNoteParser.grammarDigest, hasLength(64));
    expect(DosageNoteParser.localUnitSystem, startsWith('urn:parkinsum:'));
  });

  for (final vector in cases) {
    test('vector ${vector['id']}', () {
      final input = vector['input'] as String;
      final result = parser.inspect(input);

      expect(result.status.name, vector['status'], reason: vector['id']);
      expect(result.rawText, input, reason: vector['id']);
      expect(result.grammarDigest, DosageNoteParser.grammarDigest);
      expect(result.toJson()['raw_text'], input);
      expect(result.toJson()['boundary'], contains('does not verify'));

      if (vector['status'] == 'accepted') {
        expect(result.accepted, isTrue);
        expect(result.reasonCodes, isEmpty);
        expect(result.expression, isNotNull);
        expect(result.expression!.value, vector['value']);
        expect(result.expression!.unit.code, vector['unit']);
        expect(result.expression!.unit.dimension.name, vector['dimension']);
        expect(
          result.expression!.unit.mappingEvidence.canonicalCode,
          result.expression!.unit.code,
        );
        expect(
          result.expression!.unit.mappingEvidence.sourceRevision,
          DosageNoteParser.grammarDigest,
        );
        expect(
          result.expression!.unit.mappingEvidence.sourceDisplay,
          result.expression!.unit.display,
        );
        expect(
          result.expression!.unit.system,
          DosageNoteParser.localUnitSystem,
        );
        expect(result.expression!.role, DoseExpressionRole.administrationDose);
      } else {
        expect(result.accepted, isFalse);
        expect(result.expression, isNull);
        expect(result.primaryReasonCode, vector['reason']);
        expect(parser.parse(input).explicit, isFalse);
      }
    });
  }

  test('result JSON cannot be mutated through reason-code input', () {
    final held = parser.inspect('100 mg then 50');
    expect(
      () => held.reasonCodes.add('dose.should_not_mutate'),
      throwsUnsupportedError,
    );
  });

  test('current result schema carries exact local mapping provenance', () {
    final result = parser.inspect('0.5 g');
    final resultJson = result.toJson();
    final expression = resultJson['expression'] as Map<String, Object?>;
    final unit = expression['unit'] as Map<String, Object?>;
    final mapping = unit['mappingEvidence'] as Map<String, Object?>;

    expect(resultJson['schema'], 'parkinsum.dose-expression-parse-result/2');
    expect(mapping['schema'], 'parkinsum.versioned-dose-unit-mapping/1');
    expect(mapping['sourceCode'], 'g');
    expect(mapping['canonicalCode'], 'g');
    expect(mapping['baseUnitCode'], 'mg');
    expect(mapping['conversionNumerator'], 1000);
    expect(mapping['conversionDenominator'], 1);
    expect(mapping['mappingType'], 'exactConversion');
    expect(mapping['sourceSystemUri'], VersionedDoseUnitMapping.tokenSystemUri);
    expect(mapping['canonicalSystemUri'], DosageNoteParser.localUnitSystem);
    expect(mapping['jurisdiction'], VersionedDoseUnitMapping.localJurisdiction);
    expect(mapping['licenseState'], VersionedDoseUnitMapping.localLicenseState);
    expect(resultJson['boundary'], contains('does not verify'));
  });

  test('stale local mapping is held before a quantity can be accepted', () {
    final stale = parser.inspect('1 g', evaluatedAt: DateTime.utc(2027, 9, 24));

    expect(stale.status, DoseExpressionParseStatus.held);
    expect(stale.expression, isNull);
    expect(stale.reasonCodes, contains('dose.unit_mapping_review_stale'));
  });

  test('comparator annotation is typed but never result eligible', () {
    final result = parser.inspect('<= 0.50 g');
    final diagnostic = result.diagnosticStructure!;
    final quantity = diagnostic.quantity!;

    expect(result.status, DoseExpressionParseStatus.held);
    expect(result.primaryReasonCode, 'dose.non_exact_comparator');
    expect(result.accepted, isFalse);
    expect(result.expression, isNull);
    expect(diagnostic.kind, DoseExpressionDiagnosticKind.comparatorQuantity);
    expect(
      diagnostic.comparator,
      DoseExpressionComparatorToken.lessThanOrEqual,
    );
    expect(quantity.lexicalValue, '0.50');
    expect(quantity.value, 0.5);
    expect(quantity.unit.display, 'g');
    expect(quantity.unit.system, DosageNoteParser.localUnitSystem);
    expect(quantity.unit.code, 'g');
    expect(quantity.unit.version, DosageNoteParser.localUnitVersion);
    expect(quantity.unit.dimension, DoseExpressionDimension.mass);
    expect(
      quantity.unit.mappingEvidence.sourceRevision,
      DosageNoteParser.grammarDigest,
    );
    expect(quantity.valueStart, 3);
    expect(quantity.valueEnd, 7);
    expect(quantity.unitStart, 8);
    expect(quantity.unitEnd, 9);
    expect(diagnostic.displayText, '<= 0.50 g');
    expect(
      result.toJson()['schema'],
      'parkinsum.dose-expression-parse-result/2',
    );
    expect(result.toJson().containsKey('diagnosticStructure'), isFalse);
  });

  test(
    'closed-range annotation preserves both lexical bounds and one unit',
    () {
      final result = parser.inspect('50–100 mg');
      final diagnostic = result.diagnosticStructure!;

      expect(result.status, DoseExpressionParseStatus.held);
      expect(result.primaryReasonCode, 'dose.range_not_supported');
      expect(result.accepted, isFalse);
      expect(result.expression, isNull);
      expect(diagnostic.kind, DoseExpressionDiagnosticKind.closedRange);
      expect(diagnostic.comparator, isNull);
      expect(diagnostic.quantity, isNull);
      expect(diagnostic.lowerBound!.lexicalValue, '50');
      expect(diagnostic.lowerBound!.value, 50);
      expect(diagnostic.upperBound!.lexicalValue, '100');
      expect(diagnostic.upperBound!.value, 100);
      expect(diagnostic.lowerBound!.unit.display, 'mg');
      expect(diagnostic.upperBound!.unit.code, 'mg');
      expect(
        diagnostic.lowerBound!.unit.dimension,
        DoseExpressionDimension.mass,
      );
      expect(
        diagnostic.lowerBound!.unit.mappingEvidence.sourceRevision,
        DosageNoteParser.grammarDigest,
      );
      expect(diagnostic.displayText, '50–100 mg');
    },
  );

  test(
    'malformed bounds and non-exact prose remain held without annotation',
    () {
      for (final input in ['100-50 mg', '<= about 50 mg', '<=50 IU']) {
        final result = parser.inspect(input);
        expect(result.status, DoseExpressionParseStatus.held, reason: input);
        expect(result.expression, isNull, reason: input);
        expect(result.diagnosticStructure, isNull, reason: input);
      }
    },
  );
}
