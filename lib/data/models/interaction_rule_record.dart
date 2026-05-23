class InteractionRuleRecord {
  final String id;
  final String drugId;
  final String ruleType;
  final String target;
  final int severity;
  final double weight;
  final String description;

  const InteractionRuleRecord({
    required this.id,
    required this.drugId,
    required this.ruleType,
    required this.target,
    required this.severity,
    required this.weight,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'drugId': drugId,
        'ruleType': ruleType,
        'target': target,
        'severity': severity,
        'weight': weight,
        'description': description,
      };

  factory InteractionRuleRecord.fromJson(Map<String, dynamic> json) {
    return InteractionRuleRecord(
      id: json['id'] as String,
      drugId: json['drugId'] as String,
      ruleType: json['ruleType'] as String,
      target: json['target'] as String,
      severity: (json['severity'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      description: (json['description'] as String?) ?? '',
    );
  }
}
