/// Provenance and exact dimensional conversion for the closed local dose
/// vocabulary. This is a ParkinSUM-owned contract, not a UCUM implementation.
enum DoseUnitMappingType {
  exactIdentity,
  exactAlias,
  exactConversion,
  exactAliasAndConversion,
  approximate,
  ambiguous,
}

enum DoseUnitMappingDimension { mass, volume }

final class VersionedDoseUnitMapping {
  const VersionedDoseUnitMapping({
    required this.sourceSystemUri,
    required this.sourceCode,
    required this.sourceDisplay,
    required this.sourceTerminologyVersion,
    required this.canonicalSystemUri,
    required this.canonicalCode,
    required this.canonicalDisplay,
    required this.canonicalTerminologyVersion,
    required this.baseUnitSystemUri,
    required this.baseUnitCode,
    required this.baseUnitDisplay,
    required this.baseUnitTerminologyVersion,
    required this.sourceRevision,
    required this.mappingType,
    required this.jurisdiction,
    required this.reviewDate,
    required this.licenseState,
    required this.sourceDimension,
    required this.targetDimension,
    required this.conversionNumerator,
    required this.conversionDenominator,
  });

  static const String schema = 'parkinsum.versioned-dose-unit-mapping/1';
  static const String tokenSystemUri = 'urn:parkinsum:dose-unit-token';
  static const String localUnitSystemUri = 'urn:parkinsum:dose-unit';
  static const String terminologyVersion = '2';
  static const String localJurisdiction =
      'not_applicable_user_entered_local_vocabulary';
  static const String localLicenseState = 'local_authored_no_external_asset';
  static const String reviewedOn = '2026-09-23';
  static const int maxReviewAgeDays = 365;

  final String sourceSystemUri;
  final String sourceCode;
  final String sourceDisplay;
  final String sourceTerminologyVersion;
  final String canonicalSystemUri;
  final String canonicalCode;
  final String canonicalDisplay;
  final String canonicalTerminologyVersion;
  final String baseUnitSystemUri;
  final String baseUnitCode;
  final String baseUnitDisplay;
  final String baseUnitTerminologyVersion;
  final String sourceRevision;
  final DoseUnitMappingType mappingType;
  final String jurisdiction;
  final String reviewDate;
  final String licenseState;
  final DoseUnitMappingDimension sourceDimension;
  final DoseUnitMappingDimension targetDimension;
  final int conversionNumerator;
  final int conversionDenominator;

  static const Map<String, _DoseUnitTokenSpec>
  _tokens = <String, _DoseUnitTokenSpec>{
    'mg': _DoseUnitTokenSpec('mg', 'milligram', 'mg', 1, 1, false),
    'milligram': _DoseUnitTokenSpec('mg', 'milligram', 'mg', 1, 1, true),
    'milligrams': _DoseUnitTokenSpec('mg', 'milligram', 'mg', 1, 1, true),
    'g': _DoseUnitTokenSpec('g', 'gram', 'mg', 1000, 1, false),
    'gram': _DoseUnitTokenSpec('g', 'gram', 'mg', 1000, 1, true),
    'grams': _DoseUnitTokenSpec('g', 'gram', 'mg', 1000, 1, true),
    'mcg': _DoseUnitTokenSpec('mcg', 'microgram', 'mg', 1, 1000, false),
    'ug': _DoseUnitTokenSpec('mcg', 'microgram', 'mg', 1, 1000, true),
    'µg': _DoseUnitTokenSpec('mcg', 'microgram', 'mg', 1, 1000, true),
    'μg': _DoseUnitTokenSpec('mcg', 'microgram', 'mg', 1, 1000, true),
    'microgram': _DoseUnitTokenSpec('mcg', 'microgram', 'mg', 1, 1000, true),
    'micrograms': _DoseUnitTokenSpec('mcg', 'microgram', 'mg', 1, 1000, true),
    'ml': _DoseUnitTokenSpec('mL', 'milliliter', 'mL', 1, 1, false),
    'milliliter': _DoseUnitTokenSpec('mL', 'milliliter', 'mL', 1, 1, true),
    'milliliters': _DoseUnitTokenSpec('mL', 'milliliter', 'mL', 1, 1, true),
  };

  static VersionedDoseUnitMapping? forLocalToken(
    String sourceDisplay, {
    required String sourceRevision,
  }) {
    final sourceCode = sourceDisplay.trim().toLowerCase();
    final spec = _tokens[sourceCode];
    if (spec == null) return null;
    final sourceDimension = spec.baseCode == 'mL'
        ? DoseUnitMappingDimension.volume
        : DoseUnitMappingDimension.mass;
    final hasLexicalAlias = spec.isAlias || sourceCode != sourceDisplay.trim();
    final mappingType = switch ((hasLexicalAlias, spec.requiresConversion)) {
      (false, false) => DoseUnitMappingType.exactIdentity,
      (true, false) => DoseUnitMappingType.exactAlias,
      (false, true) => DoseUnitMappingType.exactConversion,
      (true, true) => DoseUnitMappingType.exactAliasAndConversion,
    };
    return VersionedDoseUnitMapping(
      sourceSystemUri: tokenSystemUri,
      sourceCode: sourceCode,
      sourceDisplay: sourceDisplay,
      sourceTerminologyVersion: terminologyVersion,
      canonicalSystemUri: localUnitSystemUri,
      canonicalCode: spec.canonicalCode,
      canonicalDisplay: spec.canonicalDisplay,
      canonicalTerminologyVersion: terminologyVersion,
      baseUnitSystemUri: localUnitSystemUri,
      baseUnitCode: spec.baseCode,
      baseUnitDisplay: spec.baseCode == 'mL' ? 'milliliter' : 'milligram',
      baseUnitTerminologyVersion: terminologyVersion,
      sourceRevision: sourceRevision,
      mappingType: mappingType,
      jurisdiction: localJurisdiction,
      reviewDate: reviewedOn,
      licenseState: localLicenseState,
      sourceDimension: sourceDimension,
      targetDimension: sourceDimension,
      conversionNumerator: spec.numerator,
      conversionDenominator: spec.denominator,
    );
  }

  List<String> validationErrors({
    required String expectedSourceRevision,
    required DateTime evaluatedAt,
  }) {
    final errors = <String>{};
    final expected = forLocalToken(
      sourceDisplay,
      sourceRevision: expectedSourceRevision,
    );
    if (expected == null) {
      errors.add('dose.unit_mapping_unrecognized');
    } else if (!_sameMappingContract(expected)) {
      errors.add('dose.unit_mapping_contract_mismatch');
    }
    if (sourceRevision != expectedSourceRevision ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceRevision)) {
      errors.add('dose.unit_mapping_source_revision_mismatch');
    }
    if (mappingType == DoseUnitMappingType.approximate ||
        mappingType == DoseUnitMappingType.ambiguous) {
      errors.add('dose.unit_mapping_not_exact');
    }
    if (licenseState != localLicenseState) {
      errors.add('dose.unit_mapping_license_not_cleared');
    }
    if (jurisdiction.trim().isEmpty || jurisdiction != localJurisdiction) {
      errors.add('dose.unit_mapping_jurisdiction_unknown');
    }
    if (sourceDimension != targetDimension) {
      errors.add('dose.unit_mapping_dimension_mismatch');
    }
    if (conversionNumerator <= 0 || conversionDenominator <= 0) {
      errors.add('dose.unit_mapping_conversion_invalid');
    }
    final parsedReviewDate = DateTime.tryParse(reviewDate);
    if (parsedReviewDate == null ||
        parsedReviewDate.toUtc().toIso8601String().substring(0, 10) !=
            reviewDate) {
      errors.add('dose.unit_mapping_review_date_invalid');
    } else {
      final reviewUtc = DateTime.utc(
        parsedReviewDate.year,
        parsedReviewDate.month,
        parsedReviewDate.day,
      );
      final evaluatedUtc = evaluatedAt.toUtc();
      if (reviewUtc.isAfter(evaluatedUtc)) {
        errors.add('dose.unit_mapping_review_not_yet_effective');
      } else if (evaluatedUtc.difference(reviewUtc).inDays > maxReviewAgeDays) {
        errors.add('dose.unit_mapping_review_stale');
      }
    }
    return errors.toList()..sort();
  }

  double? convertToBaseUnit(
    double value, {
    required String expectedSourceRevision,
    required DateTime evaluatedAt,
  }) {
    if (!value.isFinite ||
        value <= 0 ||
        validationErrors(
          expectedSourceRevision: expectedSourceRevision,
          evaluatedAt: evaluatedAt,
        ).isNotEmpty) {
      return null;
    }
    final converted = value * conversionNumerator / conversionDenominator;
    return converted.isFinite && converted > 0 ? converted : null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'sourceSystemUri': sourceSystemUri,
    'sourceCode': sourceCode,
    'sourceDisplay': sourceDisplay,
    'sourceTerminologyVersion': sourceTerminologyVersion,
    'canonicalSystemUri': canonicalSystemUri,
    'canonicalCode': canonicalCode,
    'canonicalDisplay': canonicalDisplay,
    'canonicalTerminologyVersion': canonicalTerminologyVersion,
    'baseUnitSystemUri': baseUnitSystemUri,
    'baseUnitCode': baseUnitCode,
    'baseUnitDisplay': baseUnitDisplay,
    'baseUnitTerminologyVersion': baseUnitTerminologyVersion,
    'sourceRevision': sourceRevision,
    'mappingType': mappingType.name,
    'jurisdiction': jurisdiction,
    'reviewDate': reviewDate,
    'licenseState': licenseState,
    'sourceDimension': sourceDimension.name,
    'targetDimension': targetDimension.name,
    'conversionNumerator': conversionNumerator,
    'conversionDenominator': conversionDenominator,
  };

  static VersionedDoseUnitMapping? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final json = Map<String, Object?>.from(raw);
      const expectedKeys = <String>{
        'schema',
        'sourceSystemUri',
        'sourceCode',
        'sourceDisplay',
        'sourceTerminologyVersion',
        'canonicalSystemUri',
        'canonicalCode',
        'canonicalDisplay',
        'canonicalTerminologyVersion',
        'baseUnitSystemUri',
        'baseUnitCode',
        'baseUnitDisplay',
        'baseUnitTerminologyVersion',
        'sourceRevision',
        'mappingType',
        'jurisdiction',
        'reviewDate',
        'licenseState',
        'sourceDimension',
        'targetDimension',
        'conversionNumerator',
        'conversionDenominator',
      };
      if (json.keys.toSet().length != expectedKeys.length ||
          !json.keys.toSet().containsAll(expectedKeys) ||
          json['schema'] != schema) {
        return null;
      }
      final mappingTypes = DoseUnitMappingType.values
          .where((value) => value.name == json['mappingType'])
          .toList(growable: false);
      final sourceDimensions = DoseUnitMappingDimension.values
          .where((value) => value.name == json['sourceDimension'])
          .toList(growable: false);
      final targetDimensions = DoseUnitMappingDimension.values
          .where((value) => value.name == json['targetDimension'])
          .toList(growable: false);
      final mappingType = mappingTypes.isEmpty ? null : mappingTypes.single;
      final sourceDimension = sourceDimensions.isEmpty
          ? null
          : sourceDimensions.single;
      final targetDimension = targetDimensions.isEmpty
          ? null
          : targetDimensions.single;
      if (mappingType == null ||
          sourceDimension == null ||
          targetDimension == null ||
          json.values.any((value) => value is! String && value is! int)) {
        return null;
      }
      String string(String key) => json[key] as String;
      int integer(String key) => json[key] as int;
      return VersionedDoseUnitMapping(
        sourceSystemUri: string('sourceSystemUri'),
        sourceCode: string('sourceCode'),
        sourceDisplay: string('sourceDisplay'),
        sourceTerminologyVersion: string('sourceTerminologyVersion'),
        canonicalSystemUri: string('canonicalSystemUri'),
        canonicalCode: string('canonicalCode'),
        canonicalDisplay: string('canonicalDisplay'),
        canonicalTerminologyVersion: string('canonicalTerminologyVersion'),
        baseUnitSystemUri: string('baseUnitSystemUri'),
        baseUnitCode: string('baseUnitCode'),
        baseUnitDisplay: string('baseUnitDisplay'),
        baseUnitTerminologyVersion: string('baseUnitTerminologyVersion'),
        sourceRevision: string('sourceRevision'),
        mappingType: mappingType,
        jurisdiction: string('jurisdiction'),
        reviewDate: string('reviewDate'),
        licenseState: string('licenseState'),
        sourceDimension: sourceDimension,
        targetDimension: targetDimension,
        conversionNumerator: integer('conversionNumerator'),
        conversionDenominator: integer('conversionDenominator'),
      );
    } on Object {
      return null;
    }
  }

  bool _sameMappingContract(VersionedDoseUnitMapping other) =>
      sourceSystemUri == other.sourceSystemUri &&
      sourceCode == other.sourceCode &&
      sourceDisplay == other.sourceDisplay &&
      sourceTerminologyVersion == other.sourceTerminologyVersion &&
      canonicalSystemUri == other.canonicalSystemUri &&
      canonicalCode == other.canonicalCode &&
      canonicalDisplay == other.canonicalDisplay &&
      canonicalTerminologyVersion == other.canonicalTerminologyVersion &&
      baseUnitSystemUri == other.baseUnitSystemUri &&
      baseUnitCode == other.baseUnitCode &&
      baseUnitDisplay == other.baseUnitDisplay &&
      baseUnitTerminologyVersion == other.baseUnitTerminologyVersion &&
      sourceRevision == other.sourceRevision &&
      mappingType == other.mappingType &&
      jurisdiction == other.jurisdiction &&
      reviewDate == other.reviewDate &&
      licenseState == other.licenseState &&
      sourceDimension == other.sourceDimension &&
      targetDimension == other.targetDimension &&
      conversionNumerator == other.conversionNumerator &&
      conversionDenominator == other.conversionDenominator;
}

final class _DoseUnitTokenSpec {
  const _DoseUnitTokenSpec(
    this.canonicalCode,
    this.canonicalDisplay,
    this.baseCode,
    this.numerator,
    this.denominator,
    this.isAlias,
  );

  final String canonicalCode;
  final String canonicalDisplay;
  final String baseCode;
  final int numerator;
  final int denominator;
  final bool isAlias;

  bool get requiresConversion => numerator != denominator;
}
