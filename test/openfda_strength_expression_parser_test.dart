import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/openfda_strength_expression.dart';
import 'package:parkinsum_companion/domain/usecases/openfda_strength_expression_parser.dart';
import 'package:parkinsum_companion/domain/usecases/openfda_strength_expression_source_manifest_builder.dart';

void main() {
  const parser = OpenFdaStrengthExpressionParser();

  test('keeps /1 as a denominator lexeme with no inferred unit', () {
    final result = parser.parse('100 mg/1');

    expect(
      result.shape,
      OpenFdaStrengthExpressionShape.numericDenominatorWithoutUnit,
    );
    expect(result.rawSourceValue, '100 mg/1');
    expect(result.numeratorValueLexeme, '100');
    expect(result.numeratorUnitLexeme, 'mg');
    expect(result.denominatorValueLexeme, '1');
    expect(result.denominatorUnitLexeme, isNull);
    expect(
      result.reasonCodes,
      contains('medication.product_strength.denominator_unit_absent'),
    );
    expect(result.toJson()['evidence_state'], 'held');
  });

  test('retains volume and time-looking denominator tokens without typing', () {
    final concentrationLike = parser.parse('50 mg/5mL');
    final timeLike = parser.parse('1 mg/24h');

    expect(
      concentrationLike.shape,
      OpenFdaStrengthExpressionShape.unitBearingDenominator,
    );
    expect(concentrationLike.denominatorValueLexeme, '5');
    expect(concentrationLike.denominatorUnitLexeme, 'mL');
    expect(
      concentrationLike.reasonCodes,
      contains('medication.product_strength.denominator_semantics_unresolved'),
    );
    expect(
      timeLike.shape,
      OpenFdaStrengthExpressionShape.unitBearingDenominator,
    );
    expect(timeLike.denominatorValueLexeme, '24');
    expect(timeLike.denominatorUnitLexeme, 'h');
    expect(timeLike.syntaxRecognized, isTrue);
    expect(timeLike.toJson()['algorithm_eligible'], isFalse);
    expect(timeLike.toJson()['administration_dose_eligible'], isFalse);
  });

  test(
    'preserves exact decimal spelling and never returns a numeric value',
    () {
      final result = parser.parse('.125 mg/1');
      final json = result.toJson();

      expect(result.numeratorValueLexeme, '.125');
      expect(result.rawSourceValue, '.125 mg/1');
      expect(json.containsKey('numerator_value'), isFalse);
      expect(json.containsKey('numerator_ucum_code'), isFalse);
      expect(json['source_unit_mapping_performed'], isFalse);
      expect(json['fhir_strength_eligible'], isFalse);
      expect(json['algorithm_eligible'], isFalse);
    },
  );

  test('holds missing, unsupported and non-positive expressions', () {
    expect(parser.parse(null).shape, OpenFdaStrengthExpressionShape.missing);
    expect(parser.parse('  ').shape, OpenFdaStrengthExpressionShape.missing);
    expect(
      parser.parse('COMBO').shape,
      OpenFdaStrengthExpressionShape.unsupported,
    );
    expect(
      parser.parse('0 mg/1').reasonCodes,
      contains('medication.product_strength.non_positive_numeric_lexeme'),
    );
    expect(
      parser.parse('1 mg/0mL').reasonCodes,
      contains('medication.product_strength.non_positive_numeric_lexeme'),
    );
    expect(parser.parse('1 mg/0').toJson()['evidence_state'], 'held');
  });

  test('result digest binds exact input, parser version and disposition', () {
    final first = parser.parse('1 mg/24h');
    final repeat = parser.parse('1 mg/24h');
    final changedSpacing = parser.parse('1 mg / 24h');

    expect(first.sha256, hasLength(64));
    expect(first.sha256, repeat.sha256);
    expect(first.sha256, isNot(changedSpacing.sha256));
    expect(
      first.toJson()['schema_uri'],
      OpenFdaStrengthExpressionParseResult.schemaUri,
    );
    expect(
      first.toJson()['parser_version'],
      OpenFdaStrengthExpressionParseResult.parserVersion,
    );
  });

  test('pinned openFDA snapshot lexical corpus remains fully held', () {
    final asset = File(
      'assets/data/common_medication_products_openfda.json',
    ).readAsBytesSync();
    const expectedAssetSha256 =
        '8b2e38710abe34567414c66bd5c1a197e74b256da1b16d7d7a947fad554f063c';
    expect(
      sha256.convert(asset).toString(),
      expectedAssetSha256,
      reason: 'Refresh requires a reviewed source-snapshot update.',
    );

    final snapshot = jsonDecode(utf8.decode(asset)) as Map<String, dynamic>;
    final records = (snapshot['records'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final parsed = <OpenFdaStrengthExpressionParseResult>[];
    for (final wrapper in records) {
      final record = wrapper['record'] as Map<String, dynamic>;
      final ingredients = record['active_ingredients'] as List<dynamic>;
      for (final rawIngredient in ingredients) {
        final ingredient = rawIngredient as Map<String, dynamic>;
        final rawStrength = ingredient['strength'] as String;
        final result = parser.parse(rawStrength);
        expect(result.rawSourceValue, rawStrength);
        expect(result.syntaxRecognized, isTrue, reason: rawStrength);
        expect(result.toJson()['evidence_state'], 'held');
        expect(result.toJson()['fhir_strength_eligible'], isFalse);
        expect(result.toJson()['administration_dose_eligible'], isFalse);
        expect(result.toJson()['algorithm_eligible'], isFalse);
        parsed.add(result);
      }
    }

    expect(records, hasLength(157));
    expect(parsed, hasLength(213));
    expect(
      parsed
          .where(
            (item) =>
                item.shape ==
                OpenFdaStrengthExpressionShape.numericDenominatorWithoutUnit,
          )
          .length,
      197,
    );
    expect(
      parsed
          .where(
            (item) =>
                item.shape ==
                OpenFdaStrengthExpressionShape.unitBearingDenominator,
          )
          .length,
      16,
    );
  });

  test(
    'source manifest binds each strength row to product and SPL identity',
    () {
      final asset = File(
        'assets/data/common_medication_products_openfda.json',
      ).readAsBytesSync();
      const builder = OpenFdaStrengthExpressionSourceManifestBuilder();
      final manifest = builder.buildFromBytes(asset);
      final json = manifest.toJson();

      expect(manifest.sourceAssetSha256, sha256.convert(asset).toString());
      expect(manifest.sourceRecordCount, 157);
      expect(manifest.rows, hasLength(213));
      expect(manifest.rows.map((row) => row.sha256).toSet(), hasLength(213));
      expect(manifest.sha256, hasLength(64));
      expect(
        json['schema_uri'],
        'parkinsum.openfda-strength-expression-source-manifest/1',
      );
      expect(
        json['source_asset_path'],
        'assets/data/common_medication_products_openfda.json',
      );
      expect(json['fda_data_verified'], isFalse);
      expect(json['clinical_or_algorithm_eligible'], isFalse);
      expect(
        manifest.rows.every(
          (row) =>
              row.productNdc.isNotEmpty &&
              row.productId.isNotEmpty &&
              row.splId.isNotEmpty &&
              row.ingredientName.isNotEmpty &&
              row.parseResult.toJson()['evidence_state'] == 'held',
        ),
        isTrue,
      );
    },
  );

  test('manifest row and root digests change when source identity changes', () {
    final asset = File(
      'assets/data/common_medication_products_openfda.json',
    ).readAsBytesSync();
    const builder = OpenFdaStrengthExpressionSourceManifestBuilder();
    final original = builder.buildFromBytes(asset);
    final changed = jsonDecode(utf8.decode(asset)) as Map<String, dynamic>;
    final firstWrapper =
        (changed['records'] as List<dynamic>).first as Map<String, dynamic>;
    final firstRecord = firstWrapper['record'] as Map<String, dynamic>;
    firstRecord['product_id'] = '${firstRecord['product_id']}_changed';
    final mutated = builder.buildFromBytes(utf8.encode(jsonEncode(changed)));

    expect(
      mutated.rows.first.parseResult.sha256,
      original.rows.first.parseResult.sha256,
    );
    expect(mutated.rows.first.sha256, isNot(original.rows.first.sha256));
    expect(mutated.sha256, isNot(original.sha256));
  });

  test('manifest rejects incomplete and duplicate source-row identities', () {
    const builder = OpenFdaStrengthExpressionSourceManifestBuilder();
    final asset = File(
      'assets/data/common_medication_products_openfda.json',
    ).readAsBytesSync();
    final missing = jsonDecode(utf8.decode(asset)) as Map<String, dynamic>;
    final missingWrapper =
        (missing['records'] as List<dynamic>).first as Map<String, dynamic>;
    (missingWrapper['record'] as Map<String, dynamic>).remove('spl_id');
    expect(
      () => builder.buildFromBytes(utf8.encode(jsonEncode(missing))),
      throwsFormatException,
    );

    final duplicate = jsonDecode(utf8.decode(asset)) as Map<String, dynamic>;
    final records = duplicate['records'] as List<dynamic>;
    records.add(jsonDecode(jsonEncode(records.first)));
    expect(
      () => builder.buildFromBytes(utf8.encode(jsonEncode(duplicate))),
      throwsFormatException,
    );
  });
}
