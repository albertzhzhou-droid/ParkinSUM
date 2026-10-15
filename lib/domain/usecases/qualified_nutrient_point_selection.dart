/// One unambiguous point selected for a legacy non-null numeric adapter.
/// Source observations stay in their owning evidence/provenance records.
final class QualifiedNutrientPoint {
  const QualifiedNutrientPoint({
    required this.value,
    required this.rowIndex,
    this.supportingRowIndexes = const [],
  });
  final double value;
  final int rowIndex;

  /// Every retained occurrence of the same proven source evidence.
  final List<int> supportingRowIndexes;
}

final class QualifiedNutrientPointSelection {
  const QualifiedNutrientPointSelection({
    required this.points,
    required this.observedAttributes,
  });
  final Map<String, Map<String, QualifiedNutrientPoint>> points;
  final Map<String, Set<String>> observedAttributes;
  bool hasEvidence(String entity, String attribute) =>
      observedAttributes[entity]?.contains(attribute) ?? false;
}

/// Preserve the existing catalogue point policy: exactly one finite,
/// non-negative exact evidence and one source-document identity per nutrient.
/// Only complete matching provenance can prove repeated occurrences of that
/// evidence. An ordinary duplicate, censored or ambiguous observation withholds
/// arithmetic, rather than authorizing a fallback to another number.
QualifiedNutrientPointSelection selectQualifiedNutrientPoints(
  List<Map<String, Object?>> rows,
) {
  final grouped = <String, Map<String, List<int>>>{};
  for (var index = 0; index < rows.length; index++) {
    final entity = '${rows[index]['entity_key'] ?? ''}';
    final attribute = '${rows[index]['attribute_code'] ?? ''}';
    if (entity.isEmpty || attribute.isEmpty) continue;
    grouped
        .putIfAbsent(entity, () => {})
        .putIfAbsent(attribute, () => [])
        .add(index);
  }
  final points = <String, Map<String, QualifiedNutrientPoint>>{};
  for (final entity in grouped.entries) {
    for (final attribute in entity.value.entries) {
      final indexes = attribute.value;
      // The importer retains unresolved evidence in its source audit even when
      // an invalid peer cannot become an observation. That does not make the
      // surviving exact row a uniquely supported point.
      if (indexes.any(
        (index) =>
            rows[index]['record_locator']?.toString().contains(
              ':unresolved:food_nutrient:',
            ) ??
            false,
      )) {
        continue;
      }
      final exact = indexes
          .where((index) => rows[index]['qualifier_kind'] == 'exact')
          .toList();
      final sources = indexes
          .map((index) => '${rows[index]['source_doc_id'] ?? ''}')
          .toSet();
      if (exact.isEmpty || sources.length != 1) continue;
      if (exact.length > 1 &&
          exact
              .skip(1)
              .any(
                (index) => !_sameProvenEvidence(rows[exact.first], rows[index]),
              )) {
        continue;
      }
      if (indexes.any(
        (index) => !_supportsPointBasisAndUnit(rows[index], attribute.key),
      )) {
        continue;
      }
      final value = rows[exact.first]['value_num'];
      if (value is! num || !value.isFinite || value < 0) continue;
      if (indexes.any(
        (index) =>
            !exact.contains(index) &&
            !_isSourceSampleRange(rows[index], value.toDouble()),
      )) {
        continue;
      }
      points.putIfAbsent(
        entity.key,
        () => {},
      )[attribute.key] = QualifiedNutrientPoint(
        value: value.toDouble(),
        rowIndex: _stableRepresentative(rows, exact),
        supportingRowIndexes: List<int>.unmodifiable(exact),
      );
    }
  }
  return QualifiedNutrientPointSelection(
    points: Map.unmodifiable({
      for (final entry in points.entries)
        entry.key: Map<String, QualifiedNutrientPoint>.unmodifiable(
          entry.value,
        ),
    }),
    observedAttributes: Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: Set<String>.unmodifiable(entry.value.keys),
    }),
  );
}

bool _sameProvenEvidence(
  Map<String, Object?> left,
  Map<String, Object?> right,
) {
  // An absent method/sample/locator is not proof of equality. Existing legacy
  // rows remain usable singly, but cannot authorize duplicate consolidation.
  const required = [
    'source_doc_id',
    'entity_key',
    'attribute_code',
    'scope_hash',
    'unit',
    'basis_type',
    'method_code',
    'record_locator',
  ];
  for (final key in required) {
    final value = left[key]?.toString().trim() ?? '';
    if (value.isEmpty || left[key] != right[key]) return false;
  }
  if (left['basis_amount'] != 100 || right['basis_amount'] != 100) return false;
  final locator = left['record_locator'].toString();
  final explicitSample = left['sample_id']?.toString().trim();
  final otherSample = right['sample_id']?.toString().trim();
  final hasSample =
      (explicitSample?.isNotEmpty ?? false) ||
      (otherSample?.isNotEmpty ?? false);
  final sameSample =
      explicitSample != null &&
      explicitSample.isNotEmpty &&
      left['sample_id'] == right['sample_id'];
  final sourceSummary = RegExp(
    r':summary:food_nutrient:[^:]+$',
  ).hasMatch(locator);
  if (hasSample ? !sameSample : !sourceSummary) return false;
  for (final key in [
    'qualifier_kind',
    'value_num',
    'low',
    'high',
    'value_type',
  ]) {
    if (left[key] != right[key]) return false;
  }
  return true;
}

int _stableRepresentative(List<Map<String, Object?>> rows, List<int> indexes) {
  final ranked = indexes.toList()
    ..sort((a, b) {
      final order = '${rows[a]['observation_id'] ?? ''}'.compareTo(
        '${rows[b]['observation_id'] ?? ''}',
      );
      return order == 0 ? a.compareTo(b) : order;
    });
  return ranked.first;
}

bool _isSourceSampleRange(Map<String, Object?> row, double point) {
  if (row['qualifier_kind'] != 'range' ||
      row['value_num'] != null ||
      !(row['record_locator']?.toString().endsWith(':sample_range') ?? false)) {
    return false;
  }
  final text = row['raw_value_text']?.toString() ?? '';
  final minimum = double.tryParse(
    RegExp(
          r'(?:^|;\s*)source_min=([^;]+)',
        ).firstMatch(text)?.group(1)?.trim() ??
        '',
  );
  final maximum = double.tryParse(
    RegExp(
          r'(?:^|;\s*)source_max=([^;]+)',
        ).firstMatch(text)?.group(1)?.trim() ??
        '',
  );
  final low = row['low'];
  final high = row['high'];
  return minimum != null &&
      maximum != null &&
      minimum.isFinite &&
      maximum.isFinite &&
      low is num &&
      high is num &&
      low == minimum &&
      high == maximum &&
      minimum >= 0 &&
      minimum <= point &&
      point <= maximum;
}

bool _supportsPointBasisAndUnit(Map<String, Object?> row, String attribute) {
  final expectedUnit = attribute.endsWith('_mg')
      ? 'mg'
      : attribute.endsWith('_ug')
      ? 'ug'
      : attribute.endsWith('_kcal')
      ? 'kcal'
      : attribute.endsWith('_kj')
      ? 'kj'
      : attribute.endsWith('_iu')
      ? 'iu'
      : 'g';
  final unit = row['unit']?.toString().trim().toLowerCase();
  if (unit != null && unit.isNotEmpty && unit != expectedUnit) return false;
  final basis = row['basis_type']?.toString().trim();
  if (basis != null &&
      basis.isNotEmpty &&
      basis != 'per_100g' &&
      basis != 'per_100g_edible_part') {
    return false;
  }
  final amount = row['basis_amount'];
  if (amount != null && (amount is! num || !amount.isFinite || amount != 100)) {
    return false;
  }
  // Missing legacy metadata is not reconstructed or promoted to source proof.
  return true;
}
