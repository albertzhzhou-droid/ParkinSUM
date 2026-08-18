import 'dart:convert';

const int openSourceInfluenceInventorySchemaVersion = 1;
const String openSourceInfluenceInventorySchema =
    'parkinsum.open-source-influence-inventory/1';

enum ProductUpgradeStatus {
  shipped,
  inProgress,
  queued,
  researchRequired,
  externalDependency;

  static ProductUpgradeStatus parse(String value) {
    return switch (value) {
      'shipped' => shipped,
      'in_progress' => inProgress,
      'queued' => queued,
      'research_required' => researchRequired,
      'external_dependency' => externalDependency,
      _ => throw FormatException('Unknown product upgrade status: $value'),
    };
  }
}

class ProductUpgradeItem {
  const ProductUpgradeItem({
    required this.id,
    required this.title,
    required this.area,
    required this.status,
    required this.priority,
    required this.impact,
    required this.risk,
    required this.effort,
    required this.score,
    required this.currentGap,
    required this.evidenceUrls,
    required this.dependencies,
    required this.acceptanceCriteria,
  });

  final String id;
  final String title;
  final String area;
  final ProductUpgradeStatus status;
  final String priority;
  final int impact;
  final int risk;
  final int effort;
  final int score;
  final String currentGap;
  final List<String> evidenceUrls;
  final List<String> dependencies;
  final List<String> acceptanceCriteria;

  factory ProductUpgradeItem.fromJson(Map<String, dynamic> json) {
    final impact = _requiredInt(json, 'impact');
    final risk = _requiredInt(json, 'risk');
    final effort = _requiredInt(json, 'effort');
    final score = _requiredInt(json, 'score');
    final expectedScore = (impact + risk) * (6 - effort);
    if (score != expectedScore) {
      throw FormatException(
        '${json['id']} score $score does not match $expectedScore',
      );
    }
    return ProductUpgradeItem(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      area: _requiredString(json, 'area'),
      status: ProductUpgradeStatus.parse(_requiredString(json, 'status')),
      priority: _requiredString(json, 'priority'),
      impact: impact,
      risk: risk,
      effort: effort,
      score: score,
      currentGap: _requiredString(json, 'currentGap'),
      evidenceUrls: _stringList(json, 'evidenceUrls'),
      dependencies: _stringList(json, 'dependencies'),
      acceptanceCriteria: _stringList(json, 'acceptanceCriteria'),
    );
  }
}

class ProductUpgradeQueue {
  const ProductUpgradeQueue({
    required this.schemaVersion,
    required this.reviewedAt,
    required this.productMode,
    required this.scoringFormula,
    required this.boundary,
    required this.items,
  });

  final int schemaVersion;
  final String reviewedAt;
  final String productMode;
  final String scoringFormula;
  final String boundary;
  final List<ProductUpgradeItem> items;

  factory ProductUpgradeQueue.fromJsonText(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Upgrade queue root must be an object.');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported upgrade queue schema.');
    }
    final rawItems = decoded['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw const FormatException('Upgrade queue needs at least one item.');
    }
    final items = rawItems
        .map(
          (item) => ProductUpgradeItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    final ids = <String>{};
    for (final item in items) {
      if (!ids.add(item.id)) {
        throw FormatException('Duplicate upgrade queue id: ${item.id}');
      }
    }
    return ProductUpgradeQueue(
      schemaVersion: 1,
      reviewedAt: _requiredString(decoded, 'reviewedAt'),
      productMode: _requiredString(decoded, 'productMode'),
      scoringFormula: _requiredString(decoded, 'scoringFormula'),
      boundary: _requiredString(decoded, 'boundary'),
      items: List<ProductUpgradeItem>.unmodifiable(items),
    );
  }

  List<ProductUpgradeItem> get activeItems => items
      .where((item) => item.status != ProductUpgradeStatus.shipped)
      .toList(growable: false);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a list.');
  return List<String>.unmodifiable(value.map((entry) => entry.toString()));
}
