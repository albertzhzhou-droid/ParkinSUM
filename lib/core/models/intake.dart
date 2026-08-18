import 'medication_product_pack.dart';

/// Intake：一次“用药/补充剂摄入”记录
class Intake {
  final String id;
  final String drugId;
  final DateTime takenAt;
  final String dosageNote;
  final double? doseAmount;
  final String? doseUnit;
  final String? dosageForm;
  final String? route;
  final String? releaseType;
  final MedicationProductSelection? productSelection;

  Intake({
    required this.id,
    required this.drugId,
    required this.takenAt,
    required this.dosageNote,
    this.doseAmount,
    this.doseUnit,
    this.dosageForm,
    this.route,
    this.releaseType,
    this.productSelection,
  });

  /// User-facing dose text with the free-text source taking precedence.
  ///
  /// Legacy records contain only [dosageNote]. New records also persist an
  /// explicit amount/unit pair when one was unambiguously present, allowing
  /// computation without making old data disappear from the timeline.
  String get doseDisplayText {
    final note = dosageNote.trim();
    if (note.isNotEmpty) return note;
    if (doseAmount == null || doseUnit == null || doseUnit!.trim().isEmpty) {
      return '';
    }
    final amount = doseAmount! % 1 == 0
        ? doseAmount!.toInt().toString()
        : doseAmount!.toString();
    return '$amount ${doseUnit!.trim()}';
  }

  Intake copyWith({
    String? id,
    String? drugId,
    DateTime? takenAt,
    String? dosageNote,
    double? doseAmount,
    String? doseUnit,
    String? dosageForm,
    String? route,
    String? releaseType,
    MedicationProductSelection? productSelection,
  }) {
    return Intake(
      id: id ?? this.id,
      drugId: drugId ?? this.drugId,
      takenAt: takenAt ?? this.takenAt,
      dosageNote: dosageNote ?? this.dosageNote,
      doseAmount: doseAmount ?? this.doseAmount,
      doseUnit: doseUnit ?? this.doseUnit,
      dosageForm: dosageForm ?? this.dosageForm,
      route: route ?? this.route,
      releaseType: releaseType ?? this.releaseType,
      productSelection: productSelection ?? this.productSelection,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'drugId': drugId,
    'takenAt': takenAt.toIso8601String(),
    'dosageNote': dosageNote,
    if (doseAmount != null) 'doseAmount': doseAmount,
    if (doseUnit != null) 'doseUnit': doseUnit,
    if (dosageForm != null) 'dosageForm': dosageForm,
    if (route != null) 'route': route,
    if (releaseType != null) 'releaseType': releaseType,
    if (productSelection != null)
      'productSelection': productSelection!.toJson(),
  };

  static Intake fromJson(Map<String, dynamic> json) {
    return Intake(
      id: json['id'] as String,
      drugId: json['drugId'] as String,
      takenAt: DateTime.parse(json['takenAt'] as String),
      dosageNote: (json['dosageNote'] as String?) ?? '',
      doseAmount: _positiveDouble(json['doseAmount']),
      doseUnit: _optionalString(json['doseUnit']),
      dosageForm: _optionalString(json['dosageForm']),
      route: _optionalString(json['route']),
      releaseType: _optionalString(json['releaseType']),
      productSelection: MedicationProductSelection.fromJson(
        json['productSelection'],
      ),
    );
  }

  static double? _positiveDouble(Object? raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    return value.isFinite && value > 0 ? value : null;
  }

  static String? _optionalString(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
}
