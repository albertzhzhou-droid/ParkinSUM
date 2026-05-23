import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';

void main() {
  test('parse exact qualified value', () {
    final value = parseQualifiedValue('1.5');
    expect(value.qualifierKind, QualifierKind.exact);
    expect(value.low, 1.5);
    expect(value.high, 1.5);
  });

  test('parse less-than qualified value', () {
    final value = parseQualifiedValue('<0.4');
    expect(value.qualifierKind, QualifierKind.lessThan);
    expect(value.low, 0);
    expect(value.high, 0.4);
  });

  test('parse trace qualified value', () {
    final value = parseQualifiedValue('trace', traceCap: 0.05);
    expect(value.qualifierKind, QualifierKind.trace);
    expect(value.low, 0);
    expect(value.high, 0.05);
  });

  test('interval overlap works', () {
    final left = parseQualifiedValue('1-3');
    final right = parseQualifiedValue('2-4');
    expect(intervalsOverlap(left, right), isTrue);
  });
}
