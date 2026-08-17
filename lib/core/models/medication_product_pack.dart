enum MedicationIdentifierSystem {
  ndcProduct,
  ndcPackage,
  din,
  gtin,
  rxcui,
  dailymedSetId,
  dpdDrugCode,
}

enum MedicationIdentifierLevel { concept, product, package }

class MedicationProductIdentifier {
  final MedicationIdentifierSystem system;
  final MedicationIdentifierLevel level;
  final String value;

  const MedicationProductIdentifier({
    required this.system,
    required this.level,
    required this.value,
  });

  String get normalizedValue => normalizeMedicationIdentifier(value);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'system': system.name,
    'level': level.name,
    'value': value,
  };

  static MedicationProductIdentifier fromJson(Map<String, dynamic> json) {
    return MedicationProductIdentifier(
      system: MedicationIdentifierSystem.values.firstWhere(
        (item) => item.name == json['system'],
      ),
      level: MedicationIdentifierLevel.values.firstWhere(
        (item) => item.name == json['level'],
      ),
      value: json['value'] as String,
    );
  }
}

/// A strength copied from product metadata, not the amount a person took.
class MedicationIngredientStrength {
  final String ingredientName;
  final double? numeratorValue;
  final String? numeratorUnit;
  final double? denominatorValue;
  final String? denominatorUnit;
  final String rawStrength;

  const MedicationIngredientStrength({
    required this.ingredientName,
    required this.numeratorValue,
    required this.numeratorUnit,
    required this.denominatorValue,
    required this.denominatorUnit,
    required this.rawStrength,
  });

  String get displayText {
    if (numeratorValue == null || numeratorUnit == null) return rawStrength;
    final numerator = '${_formatNumber(numeratorValue!)} $numeratorUnit';
    if (denominatorValue == null && denominatorUnit == null) return numerator;
    if (denominatorValue == 1 && denominatorUnit == null) return numerator;
    final denominatorValueText = denominatorValue == null
        ? null
        : _formatNumber(denominatorValue!);
    final denominator = <String>[
      ?denominatorValueText,
      ?denominatorUnit,
    ].join(' ');
    return denominator.isEmpty ? numerator : '$numerator/$denominator';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ingredient_name': ingredientName,
    'numerator_value': numeratorValue,
    'numerator_unit': numeratorUnit,
    'denominator_value': denominatorValue,
    'denominator_unit': denominatorUnit,
    'raw_strength': rawStrength,
  };
}

class MedicationProductPack {
  final String id;
  final String genericName;
  final String? brandName;

  /// The organization named by the official product record. For NDC this can
  /// be a manufacturer, repackager, relabeler, or another label entity.
  final String? labelerName;
  final String jurisdiction;
  final List<MedicationProductIdentifier> identifiers;
  final List<MedicationIngredientStrength> ingredients;
  final String dosageForm;
  final List<String> routes;
  final String packageDescription;
  final String? marketingStartDate;
  final String? marketingEndDate;
  final String? marketingStatus;
  final String sourceSystem;
  final String sourceUrl;
  final DateTime? retrievedAt;

  const MedicationProductPack({
    required this.id,
    required this.genericName,
    required this.brandName,
    required this.labelerName,
    required this.jurisdiction,
    required this.identifiers,
    required this.ingredients,
    required this.dosageForm,
    required this.routes,
    required this.packageDescription,
    required this.marketingStartDate,
    required this.marketingEndDate,
    this.marketingStatus,
    required this.sourceSystem,
    required this.sourceUrl,
    required this.retrievedAt,
  });

  String get strengthDisplay => ingredients
      .map((item) => '${item.ingredientName} ${item.displayText}'.trim())
      .where((item) => item.isNotEmpty)
      .join(' + ');

  String get primaryDisplayName {
    final brand = brandName?.trim() ?? '';
    return brand.isEmpty ? genericName : '$brand ($genericName)';
  }

  String get searchableText => <String>[
    id,
    genericName,
    brandName ?? '',
    labelerName ?? '',
    jurisdiction,
    dosageForm,
    ...routes,
    packageDescription,
    strengthDisplay,
    marketingStatus ?? '',
    ...identifiers.expand((item) => <String>[item.value, item.normalizedValue]),
  ].join(' ').toLowerCase();

  bool matchesIdentifier(String query) {
    final normalized = normalizeMedicationIdentifier(query);
    return normalized.isNotEmpty &&
        identifiers.any((item) => item.normalizedValue == normalized);
  }
}

/// Immutable product metadata captured alongside an intake. This snapshot is
/// intentionally separate from the actual amount taken: package strength
/// alone is never evidence that a person consumed one package unit.
class MedicationProductSelection {
  final String packId;
  final String identifierSystem;
  final String identifierValue;
  final String displayName;
  final String? labelerName;
  final String strengthDisplay;
  final String packageDescription;
  final String? doseBasisIngredient;
  final double? unitQuantity;
  final String? unitLabel;

  const MedicationProductSelection({
    required this.packId,
    required this.identifierSystem,
    required this.identifierValue,
    required this.displayName,
    required this.labelerName,
    required this.strengthDisplay,
    required this.packageDescription,
    this.doseBasisIngredient,
    this.unitQuantity,
    this.unitLabel,
  });

  factory MedicationProductSelection.fromPack(MedicationProductPack pack) {
    final identifier = pack.identifiers.firstWhere(
      (item) => item.system == MedicationIdentifierSystem.ndcPackage,
      orElse: () => pack.identifiers.firstWhere(
        (item) => item.level == MedicationIdentifierLevel.package,
        orElse: () => pack.identifiers.first,
      ),
    );
    return MedicationProductSelection(
      packId: pack.id,
      identifierSystem: identifier.system.name,
      identifierValue: identifier.value,
      displayName: pack.primaryDisplayName,
      labelerName: pack.labelerName,
      strengthDisplay: pack.strengthDisplay,
      packageDescription: pack.packageDescription,
    );
  }

  MedicationProductSelection withConfirmedQuantity({
    required String doseBasisIngredient,
    required double unitQuantity,
    required String unitLabel,
  }) {
    return MedicationProductSelection(
      packId: packId,
      identifierSystem: identifierSystem,
      identifierValue: identifierValue,
      displayName: displayName,
      labelerName: labelerName,
      strengthDisplay: strengthDisplay,
      packageDescription: packageDescription,
      doseBasisIngredient: doseBasisIngredient,
      unitQuantity: unitQuantity,
      unitLabel: unitLabel,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'packId': packId,
    'identifierSystem': identifierSystem,
    'identifierValue': identifierValue,
    'displayName': displayName,
    if (labelerName != null) 'labelerName': labelerName,
    'strengthDisplay': strengthDisplay,
    'packageDescription': packageDescription,
    if (doseBasisIngredient != null) 'doseBasisIngredient': doseBasisIngredient,
    if (unitQuantity != null) 'unitQuantity': unitQuantity,
    if (unitLabel != null) 'unitLabel': unitLabel,
  };

  static MedicationProductSelection? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final packId = _nonEmptyString(json['packId']);
    final identifierSystem = _nonEmptyString(json['identifierSystem']);
    final identifierValue = _nonEmptyString(json['identifierValue']);
    final displayName = _nonEmptyString(json['displayName']);
    if (packId == null ||
        identifierSystem == null ||
        identifierValue == null ||
        displayName == null) {
      return null;
    }
    final quantity = json['unitQuantity'];
    return MedicationProductSelection(
      packId: packId,
      identifierSystem: identifierSystem,
      identifierValue: identifierValue,
      displayName: displayName,
      labelerName: _nonEmptyString(json['labelerName']),
      strengthDisplay: _nonEmptyString(json['strengthDisplay']) ?? '',
      packageDescription: _nonEmptyString(json['packageDescription']) ?? '',
      doseBasisIngredient: _nonEmptyString(json['doseBasisIngredient']),
      unitQuantity: quantity is num && quantity > 0
          ? quantity.toDouble()
          : null,
      unitLabel: _nonEmptyString(json['unitLabel']),
    );
  }
}

/// Returns possible systems without pretending that an unprefixed 8-digit
/// code is unambiguous: it can be a Canadian DIN or a GTIN-8.
List<MedicationIdentifierSystem> classifyMedicationIdentifier(
  String input, {
  String? jurisdiction,
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const <MedicationIdentifierSystem>[];
  final lower = trimmed.toLowerCase();
  const prefixes = <String, MedicationIdentifierSystem>{
    'ndc:': MedicationIdentifierSystem.ndcProduct,
    'din:': MedicationIdentifierSystem.din,
    'gtin:': MedicationIdentifierSystem.gtin,
    'rxcui:': MedicationIdentifierSystem.rxcui,
    'setid:': MedicationIdentifierSystem.dailymedSetId,
  };
  for (final entry in prefixes.entries) {
    if (lower.startsWith(entry.key)) {
      return <MedicationIdentifierSystem>[entry.value];
    }
  }
  if (RegExp(r'^\d{4,5}-\d{3,4}-\d{1,2}$').hasMatch(trimmed)) {
    return const <MedicationIdentifierSystem>[
      MedicationIdentifierSystem.ndcPackage,
    ];
  }
  if (RegExp(r'^\d{4,5}-\d{3,4}$').hasMatch(trimmed)) {
    return const <MedicationIdentifierSystem>[
      MedicationIdentifierSystem.ndcProduct,
    ];
  }
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 8) {
    if (jurisdiction?.toUpperCase() == 'CA') {
      return const <MedicationIdentifierSystem>[
        MedicationIdentifierSystem.din,
        MedicationIdentifierSystem.gtin,
      ];
    }
    return const <MedicationIdentifierSystem>[
      MedicationIdentifierSystem.din,
      MedicationIdentifierSystem.gtin,
    ];
  }
  if (<int>{12, 13, 14}.contains(digits.length)) {
    return const <MedicationIdentifierSystem>[MedicationIdentifierSystem.gtin];
  }
  return const <MedicationIdentifierSystem>[];
}

String normalizeMedicationIdentifier(String input) {
  final lower = input.trim().toLowerCase();
  final colon = lower.indexOf(':');
  final value = colon >= 0 ? lower.substring(colon + 1) : lower;
  return value.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String? _nonEmptyString(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

String _formatNumber(double value) => value % 1 == 0
    ? value.toInt().toString()
    : value
          .toString()
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
