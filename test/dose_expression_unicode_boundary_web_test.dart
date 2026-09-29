import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/dose_expression.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';

void main() {
  final parser = DosageNoteParser();

  test('web runtime rejects Unicode characters attached to a unit token', () {
    for (final input in [
      '100 mgℊ',
      '100 mg\u0307',
      '100 mg\u200b',
      '100 mg\u202e',
    ]) {
      final result = parser.inspect(
        input,
        evaluatedAt: DateTime.utc(2026, 9, 27),
      );

      expect(result.status, DoseExpressionParseStatus.held, reason: input);
      expect(result.primaryReasonCode, 'dose.unit_unsupported', reason: input);
      expect(result.expression, isNull, reason: input);
    }
  });

  test(
    'web runtime preserves accepted no-break spacing and grammar identity',
    () {
      final result = parser.inspect(
        '100\u202fmg',
        evaluatedAt: DateTime.utc(2026, 9, 27),
      );

      expect(result.status, DoseExpressionParseStatus.accepted);
      expect(result.expression!.value, 100);
      expect(result.expression!.unit.code, 'mg');
      expect(result.grammarVersion, 4);
    },
  );

  test('web runtime rejects a Unicode letter before a unit token', () {
    final result = parser.inspect(
      '100 ℊmg',
      evaluatedAt: DateTime.utc(2026, 9, 27),
    );

    expect(result.status, DoseExpressionParseStatus.held);
    expect(result.primaryReasonCode, 'dose.unit_missing');
    expect(result.expression, isNull);
  });
}
