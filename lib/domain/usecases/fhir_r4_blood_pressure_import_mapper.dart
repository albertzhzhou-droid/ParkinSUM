import '../entities/fhir_r4_observation_import_preview.dart';

/// Validates and previews only the FHIR R4 vital-signs BP panel subset.
///
/// The mapper is intentionally read-only. It requires explicit source, FHIR
/// release, jurisdiction, and Patient-reference context, preserves absent-data
/// codes and source versions, and holds unsupported fields rather than
/// silently dropping them. It does not write to the database or run CDSS rules.
final class FhirR4BloodPressureImportMapper {
  const FhirR4BloodPressureImportMapper();

  static const _instantPattern =
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static const _allowedAbsentReasons = {'unknown', 'not-performed'};
  static const _knownResourceKeys = {
    'resourceType',
    'id',
    'meta',
    'status',
    'code',
    'subject',
    'effectiveDateTime',
    'issued',
    'component',
  };
  static const _knownMetaKeys = {'versionId', 'lastUpdated', 'source'};
  static const _knownCodeableConceptKeys = {'coding', 'text'};
  static const _knownCodingKeys = {'system', 'version', 'code', 'display'};
  static const _knownComponentKeys = {
    'code',
    'valueQuantity',
    'dataAbsentReason',
  };
  static const _knownQuantityKeys = {
    'value',
    'comparator',
    'unit',
    'system',
    'code',
  };
  static const _knownAbsentReasonKeys = {'coding', 'text'};

  FhirR4ObservationImportPreview previewObservation({
    required Map<String, dynamic> resource,
    required FhirR4ObservationImportContext context,
  }) {
    final reasons = <String>{};
    final unmapped = <String>{};
    final meta = _map(resource['meta']);

    _validateContext(context, reasons);
    if (resource['resourceType'] != 'Observation') {
      reasons.add('fhir.resource_type_unsupported');
    }
    _addUnknownKeys(resource, _knownResourceKeys, 'Observation', unmapped);

    final status = _string(resource['status']);
    if (!{'final', 'amended', 'corrected'}.contains(status)) {
      reasons.add('fhir.observation_status_not_final');
    }

    final resourceId = _readOptionalString(
      resource,
      'id',
      'fhir.resource_id_invalid',
      reasons,
    );
    final resourceVersionId = meta == null
        ? null
        : _readOptionalString(
            meta,
            'versionId',
            'fhir.meta_version_id_invalid',
            reasons,
          );
    final metaSource = meta == null
        ? null
        : _readOptionalString(
            meta,
            'source',
            'fhir.meta_source_invalid',
            reasons,
          );
    final lastUpdatedLexical = meta == null
        ? null
        : _readOptionalString(
            meta,
            'lastUpdated',
            'fhir.meta_last_updated_invalid',
            reasons,
          );
    final lastUpdatedUtc = _parseInstant(lastUpdatedLexical);
    if (lastUpdatedLexical != null && lastUpdatedUtc == null) {
      reasons.add('fhir.meta_last_updated_invalid');
    }
    if (meta != null) {
      _addUnknownKeys(meta, _knownMetaKeys, 'Observation.meta', unmapped);
    } else if (resource.containsKey('meta')) {
      reasons.add('fhir.meta_invalid');
    }

    final subject = _map(resource['subject']);
    final subjectReference = _string(subject?['reference']);
    if (subjectReference != context.expectedPatientReference) {
      reasons.add('fhir.patient_reference_mismatch');
    }
    if (subject == null && resource.containsKey('subject')) {
      reasons.add('fhir.subject_invalid');
    }
    if (subject != null) {
      _addUnknownKeys(subject, {'reference'}, 'Observation.subject', unmapped);
    }

    final effectiveLexical = _readOptionalString(
      resource,
      'effectiveDateTime',
      'fhir.effective_datetime_invalid',
      reasons,
    );
    final effectiveUtc = _parseInstant(effectiveLexical);
    if (effectiveLexical == null) {
      reasons.add('fhir.effective_datetime_missing');
    } else if (effectiveUtc == null) {
      reasons.add('fhir.effective_datetime_requires_full_offset');
    }
    final issuedLexical = _readOptionalString(
      resource,
      'issued',
      'fhir.issued_invalid',
      reasons,
    );
    final issuedUtc = _parseInstant(issuedLexical);
    if (issuedLexical != null && issuedUtc == null) {
      reasons.add('fhir.issued_invalid');
    }

    final observationCode = _readCoding(
      resource['code'],
      path: 'Observation.code',
      expectedCode: FhirR4ObservationImportPreview.bloodPressurePanelCode,
      reasons: reasons,
      unmapped: unmapped,
    );
    if (observationCode != null && observationCode.systemVersion == null) {
      reasons.add('fhir.loinc_version_missing');
    }

    final components = <FhirR4ObservationComponentPreview>[];
    final rawComponents = resource['component'];
    if (rawComponents is! List || rawComponents.length != 2) {
      reasons.add('fhir.bp_requires_two_components');
    } else {
      for (var index = 0; index < rawComponents.length; index++) {
        final raw = _map(rawComponents[index]);
        if (raw == null) {
          reasons.add('fhir.component_invalid');
          continue;
        }
        _addUnknownKeys(
          raw,
          _knownComponentKeys,
          'Observation.component[$index]',
          unmapped,
        );
        if (raw.containsKey('valueQuantity') && raw['valueQuantity'] == null) {
          reasons.add('fhir.quantity_explicit_null');
        }
        if (raw.containsKey('dataAbsentReason') &&
            raw['dataAbsentReason'] == null) {
          reasons.add('fhir.data_absent_reason_explicit_null');
        }
        final code = _readCoding(
          raw['code'],
          path: 'Observation.component[$index].code',
          expectedCode: null,
          reasons: reasons,
          unmapped: unmapped,
        );
        if (code == null) continue;
        if (code.system != FhirR4ObservationImportPreview.loincSystem ||
            !{
              FhirR4ObservationImportPreview.systolicCode,
              FhirR4ObservationImportPreview.diastolicCode,
            }.contains(code.code)) {
          reasons.add('fhir.bp_component_code_unsupported');
        }
        if (code.systemVersion == null) {
          reasons.add('fhir.bp_component_loinc_version_missing');
        }
        if (observationCode?.systemVersion != null &&
            code.systemVersion != observationCode!.systemVersion) {
          reasons.add('fhir.loinc_version_mismatch');
        }
        final quantity = _readQuantity(
          raw['valueQuantity'],
          dataAbsentReason: raw['dataAbsentReason'],
          path: 'Observation.component[$index]',
          reasons: reasons,
          unmapped: unmapped,
        );
        if (quantity == null) continue;
        components.add(
          FhirR4ObservationComponentPreview(
            code: code.code,
            codeSystem: code.system,
            codeSystemVersion: code.systemVersion,
            codeDisplay: code.display,
            codeConceptText: code.conceptText,
            value: quantity.value,
            comparator: quantity.comparator,
            unitDisplay: quantity.unitDisplay,
            unitSystem: quantity.unitSystem,
            unitCode: quantity.unitCode,
            dataAbsentReasonCode: quantity.absentReason,
            dataAbsentReasonSystem: quantity.absentReasonSystem,
            dataAbsentReasonVersion: quantity.absentReasonVersion,
            dataAbsentReasonDisplay: quantity.absentReasonDisplay,
            dataAbsentReasonText: quantity.absentReasonText,
          ),
        );
      }
    }

    if (components.map((value) => value.code).toSet().length !=
        components.length) {
      reasons.add('fhir.bp_component_duplicate');
    }
    if (!components.any(
      (value) => value.code == FhirR4ObservationImportPreview.systolicCode,
    )) {
      reasons.add('fhir.bp_systolic_missing');
    }
    if (!components.any(
      (value) => value.code == FhirR4ObservationImportPreview.diastolicCode,
    )) {
      reasons.add('fhir.bp_diastolic_missing');
    }

    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    final sortedReasons = reasons.toList()..sort();
    final sortedUnmapped = unmapped.toList()..sort();
    return FhirR4ObservationImportPreview(
      disposition: sortedReasons.isEmpty
          ? FhirR4ObservationImportDisposition.previewable
          : FhirR4ObservationImportDisposition.held,
      context: context,
      resourceId: resourceId,
      resourceVersionId: resourceVersionId,
      metaSource: metaSource,
      metaLastUpdatedLexical: lastUpdatedLexical,
      metaLastUpdatedUtc: lastUpdatedUtc,
      status: status,
      observationCodeVersion: observationCode?.systemVersion,
      observationCodeDisplay: observationCode?.display,
      observationCodeText: observationCode?.conceptText,
      subjectReference: subjectReference,
      effectiveDateTimeLexical: effectiveLexical,
      effectiveAtUtc: effectiveUtc,
      issuedLexical: issuedLexical,
      issuedAtUtc: issuedUtc,
      components: List<FhirR4ObservationComponentPreview>.unmodifiable(
        components,
      ),
      reasonCodes: List<String>.unmodifiable(sortedReasons),
      unmappedPaths: List<String>.unmodifiable(sortedUnmapped),
    );
  }

  void _validateContext(
    FhirR4ObservationImportContext context,
    Set<String> reasons,
  ) {
    final source = Uri.tryParse(context.sourceFhirBase);
    if (source == null ||
        source.scheme != 'https' ||
        source.host.isEmpty ||
        source.userInfo.isNotEmpty ||
        source.hasQuery ||
        source.hasFragment) {
      reasons.add('fhir.source_base_invalid');
    }
    if (context.fhirVersion !=
        FhirR4ObservationImportPreview.supportedFhirVersion) {
      reasons.add('fhir.release_unsupported');
    }
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(context.jurisdiction)) {
      reasons.add('fhir.jurisdiction_missing_or_invalid');
    }
    if (!RegExp(
      _patientReferencePattern,
    ).hasMatch(context.expectedPatientReference)) {
      reasons.add('fhir.expected_patient_reference_invalid');
    }
  }

  _Coding? _readCoding(
    Object? rawConcept, {
    required String path,
    required String? expectedCode,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    final concept = _map(rawConcept);
    if (concept == null) {
      reasons.add('fhir.codeable_concept_invalid');
      return null;
    }
    _addUnknownKeys(concept, _knownCodeableConceptKeys, path, unmapped);
    final codings = concept['coding'];
    if (codings is! List || codings.length != 1) {
      reasons.add('fhir.coding_requires_one_exact_system');
      return null;
    }
    final coding = _map(codings.single);
    if (coding == null) {
      reasons.add('fhir.coding_invalid');
      return null;
    }
    _addUnknownKeys(coding, _knownCodingKeys, '$path.coding[0]', unmapped);
    final system = _string(coding['system']);
    final code = _string(coding['code']);
    final version = _readOptionalString(
      coding,
      'version',
      'fhir.coding_version_invalid',
      reasons,
    );
    final display = _readOptionalString(
      coding,
      'display',
      'fhir.coding_display_invalid',
      reasons,
    );
    final conceptText = _readOptionalString(
      concept,
      'text',
      'fhir.codeable_concept_text_invalid',
      reasons,
    );
    if (system != FhirR4ObservationImportPreview.loincSystem) {
      reasons.add('fhir.coding_system_unsupported');
    }
    if (expectedCode != null && code != expectedCode) {
      reasons.add('fhir.observation_code_unsupported');
    }
    if (system == null || system.isEmpty || code == null || code.isEmpty) {
      reasons.add('fhir.coding_identity_incomplete');
    }
    return _Coding(
      system: system ?? '',
      code: code ?? '',
      systemVersion: version,
      display: display,
      conceptText: conceptText,
    );
  }

  _QuantityPreview? _readQuantity(
    Object? rawQuantity, {
    required Object? dataAbsentReason,
    required String path,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    if (rawQuantity == null) {
      if (dataAbsentReason == null) {
        reasons.add('fhir.component_value_or_absent_reason_required');
        return null;
      }
      return _readAbsentReason(
        dataAbsentReason,
        path: '$path.dataAbsentReason',
        reasons: reasons,
        unmapped: unmapped,
      );
    }
    if (dataAbsentReason != null) {
      reasons.add('fhir.value_and_absent_reason_conflict');
    }
    final quantity = _map(rawQuantity);
    if (quantity == null) {
      reasons.add('fhir.quantity_invalid');
      return null;
    }
    _addUnknownKeys(
      quantity,
      _knownQuantityKeys,
      '$path.valueQuantity',
      unmapped,
    );
    final rawValue = quantity['value'];
    final value = rawValue is num ? rawValue : null;
    if (value == null || !value.toDouble().isFinite) {
      reasons.add('fhir.quantity_value_invalid');
    }
    final comparator = _readOptionalString(
      quantity,
      'comparator',
      'fhir.quantity_comparator_invalid',
      reasons,
    );
    if (comparator != null) {
      // FHIR Quantity.comparator cannot be ignored or reduced to a point value.
      reasons.add('fhir.quantity_comparator_unsupported');
    }
    final unitSystem = _string(quantity['system']);
    final unitCode = _string(quantity['code']);
    final unitDisplay = _readOptionalString(
      quantity,
      'unit',
      'fhir.quantity_unit_display_invalid',
      reasons,
    );
    if (unitSystem != FhirR4ObservationImportPreview.ucumSystem ||
        unitCode != FhirR4ObservationImportPreview.bloodPressureUnitCode) {
      reasons.add('fhir.quantity_ucum_binding_unsupported');
    }
    return _QuantityPreview(
      value: value,
      comparator: comparator,
      unitDisplay: unitDisplay,
      unitSystem: unitSystem,
      unitCode: unitCode,
    );
  }

  _QuantityPreview? _readAbsentReason(
    Object? rawReason, {
    required String path,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    final concept = _map(rawReason);
    if (concept == null) {
      reasons.add('fhir.data_absent_reason_invalid');
      return null;
    }
    _addUnknownKeys(concept, _knownAbsentReasonKeys, path, unmapped);
    final codings = concept['coding'];
    if (codings is! List || codings.length != 1) {
      reasons.add('fhir.data_absent_reason_requires_one_coding');
      return null;
    }
    final coding = _map(codings.single);
    if (coding == null) {
      reasons.add('fhir.data_absent_reason_coding_invalid');
      return null;
    }
    _addUnknownKeys(coding, _knownCodingKeys, '$path.coding[0]', unmapped);
    final system = _string(coding['system']);
    final code = _string(coding['code']);
    final version = _readOptionalString(
      coding,
      'version',
      'fhir.data_absent_reason_version_invalid',
      reasons,
    );
    final display = _readOptionalString(
      coding,
      'display',
      'fhir.data_absent_reason_display_invalid',
      reasons,
    );
    final conceptText = _readOptionalString(
      concept,
      'text',
      'fhir.data_absent_reason_text_invalid',
      reasons,
    );
    if (system != FhirR4ObservationImportPreview.dataAbsentReasonSystem ||
        !_allowedAbsentReasons.contains(code)) {
      reasons.add('fhir.data_absent_reason_unsupported');
    }
    if (system == null || system.isEmpty || code == null || code.isEmpty) {
      reasons.add('fhir.data_absent_reason_identity_incomplete');
    }
    return _QuantityPreview(
      absentReason: code,
      absentReasonSystem: system,
      absentReasonVersion: version,
      absentReasonDisplay: display,
      absentReasonText: conceptText,
    );
  }

  void _addUnknownKeys(
    Map<String, dynamic> value,
    Set<String> known,
    String prefix,
    Set<String> unmapped,
  ) {
    for (final entry in value.entries) {
      if (!known.contains(entry.key)) {
        unmapped.add('$prefix.${entry.key}');
      }
    }
  }

  Map<String, dynamic>? _map(Object? value) {
    if (value is! Map) return null;
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) return null;
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  String? _string(Object? value) => value is String ? value : null;

  String? _readOptionalString(
    Map<String, dynamic> source,
    String key,
    String reasonCode,
    Set<String> reasons,
  ) {
    if (!source.containsKey(key)) return null;
    final value = source[key];
    if (value is String && value.isNotEmpty) return value;
    reasons.add(reasonCode);
    return null;
  }

  DateTime? _parseInstant(String? value) {
    if (value == null) return null;
    final match = RegExp(_instantPattern).firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final fraction = match.group(7) ?? '';
    if (year == 0 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        fraction.length > 6) {
      return null;
    }
    final leapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    final daysInMonth = <int>[
      31,
      leapYear ? 29 : 28,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ][month - 1];
    if (day > daysInMonth) return null;

    final offsetHours = int.tryParse(match.group(10) ?? '0') ?? 0;
    final offsetMinutes = int.tryParse(match.group(11) ?? '0') ?? 0;
    if (offsetHours > 14 ||
        offsetMinutes > 59 ||
        (offsetHours == 14 && offsetMinutes != 0)) {
      return null;
    }
    final micros = int.parse('${fraction}000000'.substring(0, 6));
    final localInstant = DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
      micros ~/ 1000,
      micros % 1000,
    );
    final offsetSign = match.group(9) == '-' ? -1 : 1;
    final offset = Duration(
      minutes: offsetSign * (offsetHours * 60 + offsetMinutes),
    );
    return localInstant.subtract(offset);
  }
}

final class _Coding {
  const _Coding({
    required this.system,
    required this.code,
    required this.systemVersion,
    required this.display,
    required this.conceptText,
  });

  final String system;
  final String code;
  final String? systemVersion;
  final String? display;
  final String? conceptText;
}

final class _QuantityPreview {
  const _QuantityPreview({
    this.value,
    this.comparator,
    this.unitDisplay,
    this.unitSystem,
    this.unitCode,
    this.absentReason,
    this.absentReasonSystem,
    this.absentReasonVersion,
    this.absentReasonDisplay,
    this.absentReasonText,
  });

  final num? value;
  final String? comparator;
  final String? unitDisplay;
  final String? unitSystem;
  final String? unitCode;
  final String? absentReason;
  final String? absentReasonSystem;
  final String? absentReasonVersion;
  final String? absentReasonDisplay;
  final String? absentReasonText;
}
