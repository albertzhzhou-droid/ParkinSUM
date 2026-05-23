/// Intake：一次“用药/补充剂摄入”记录
class Intake {
  final String id;
  final String drugId;
  final DateTime takenAt;
  final String dosageNote;

  Intake({
    required this.id,
    required this.drugId,
    required this.takenAt,
    required this.dosageNote,
  });

  Intake copyWith({
    String? id,
    String? drugId,
    DateTime? takenAt,
    String? dosageNote,
  }) {
    return Intake(
      id: id ?? this.id,
      drugId: drugId ?? this.drugId,
      takenAt: takenAt ?? this.takenAt,
      dosageNote: dosageNote ?? this.dosageNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'drugId': drugId,
        'takenAt': takenAt.toIso8601String(),
        'dosageNote': dosageNote,
      };

  static Intake fromJson(Map<String, dynamic> json) {
    return Intake(
      id: json['id'] as String,
      drugId: json['drugId'] as String,
      takenAt: DateTime.parse(json['takenAt'] as String),
      dosageNote: (json['dosageNote'] as String?) ?? '',
    );
  }
}
