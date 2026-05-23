enum QualifierKind {
  exact('exact'),
  range('range'),
  lessThan('lt'),
  lessThanOrEqual('lte'),
  trace('trace'),
  missing('missing'),
  parsingUncertainty('parsing_uncertainty');

  final String wireValue;
  const QualifierKind(this.wireValue);
}

class QualifiedValue {
  final QualifierKind qualifierKind;
  final double? low;
  final double? high;
  final double? valueNum;
  final String rawValueText;

  const QualifiedValue({
    required this.qualifierKind,
    required this.low,
    required this.high,
    required this.valueNum,
    required this.rawValueText,
  });

  bool get isComparable => low != null && high != null;

  Map<String, dynamic> toJson() => {
        'qualifier_kind': qualifierKind.wireValue,
        'low': low,
        'high': high,
        'value_num': valueNum,
        'raw_value_text': rawValueText,
      };
}

QualifiedValue parseQualifiedValue(
  String? raw, {
  double traceCap = 0.1,
}) {
  final normalized = (raw ?? '').trim();
  final lower = normalized.toLowerCase();

  if (normalized.isEmpty ||
      normalized == '-' ||
      lower == 'missing' ||
      lower == 'n/a') {
    return QualifiedValue(
      qualifierKind: QualifierKind.missing,
      low: null,
      high: null,
      valueNum: null,
      rawValueText: normalized,
    );
  }

  if (lower == 'trace' || lower == 'tr' || lower == 'traces') {
    return QualifiedValue(
      qualifierKind: QualifierKind.trace,
      low: 0,
      high: traceCap,
      valueNum: null,
      rawValueText: normalized,
    );
  }

  final lessEqMatch =
      RegExp(r'^<=\s*([0-9]+(?:[.,][0-9]+)?)$').firstMatch(lower);
  if (lessEqMatch != null) {
    final high = double.parse(lessEqMatch.group(1)!.replaceAll(',', '.'));
    return QualifiedValue(
      qualifierKind: QualifierKind.lessThanOrEqual,
      low: 0,
      high: high,
      valueNum: null,
      rawValueText: normalized,
    );
  }

  final lessMatch = RegExp(r'^<\s*([0-9]+(?:[.,][0-9]+)?)$').firstMatch(lower);
  if (lessMatch != null) {
    final high = double.parse(lessMatch.group(1)!.replaceAll(',', '.'));
    return QualifiedValue(
      qualifierKind: QualifierKind.lessThan,
      low: 0,
      high: high,
      valueNum: null,
      rawValueText: normalized,
    );
  }

  final rangeMatch =
      RegExp(r'^([0-9]+(?:[.,][0-9]+)?)\s*[-–]\s*([0-9]+(?:[.,][0-9]+)?)$')
          .firstMatch(lower);
  if (rangeMatch != null) {
    final low = double.parse(rangeMatch.group(1)!.replaceAll(',', '.'));
    final high = double.parse(rangeMatch.group(2)!.replaceAll(',', '.'));
    return QualifiedValue(
      qualifierKind: QualifierKind.range,
      low: low,
      high: high,
      valueNum: null,
      rawValueText: normalized,
    );
  }

  final exact = double.tryParse(lower.replaceAll(',', '.'));
  if (exact != null) {
    return QualifiedValue(
      qualifierKind: QualifierKind.exact,
      low: exact,
      high: exact,
      valueNum: exact,
      rawValueText: normalized,
    );
  }

  return QualifiedValue(
    qualifierKind: QualifierKind.parsingUncertainty,
    low: null,
    high: null,
    valueNum: null,
    rawValueText: normalized,
  );
}

bool intervalsOverlap(QualifiedValue left, QualifiedValue right) {
  if (!left.isComparable || !right.isComparable) {
    return false;
  }
  return left.low! <= right.high! && right.low! <= left.high!;
}
