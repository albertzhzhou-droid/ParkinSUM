import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/fhir_r4_medication_statement_import_preview.dart';

/// A bounded, offline preview for one FHIR R4 MedicationStatement or a
/// collection Bundle containing only MedicationStatement resources.
///
/// This mapper does not resolve references, normalize medication identities,
/// interpret status as administration, parse dosage quantities, persist input,
/// or feed the result-producing rule engine.
final class FhirR4MedicationStatementImportMapper {
  const FhirR4MedicationStatementImportMapper();

  static const _statementKeys = <String>{
    'resourceType',
    'id',
    'meta',
    'implicitRules',
    'language',
    'text',
    'contained',
    'extension',
    'modifierExtension',
    'identifier',
    'basedOn',
    'partOf',
    'status',
    'statusReason',
    'category',
    'medicationCodeableConcept',
    'medicationReference',
    'subject',
    'context',
    'effectiveDateTime',
    'effectivePeriod',
    'dateAsserted',
    'informationSource',
    'derivedFrom',
    'reasonCode',
    'reasonReference',
    'note',
    'dosage',
  };
  static const _bundleKeys = <String>{
    'resourceType',
    'id',
    'meta',
    'implicitRules',
    'language',
    'identifier',
    'type',
    'timestamp',
    'total',
    'link',
    'entry',
    'signature',
    'issues',
  };
  static const _metaKeys = {'versionId', 'source', 'lastUpdated'};
  static const _supportedBundleKeys = {'resourceType', 'meta', 'type', 'entry'};
  static const _supportedStatementKeys = {
    'resourceType',
    'id',
    'meta',
    'status',
    'medicationCodeableConcept',
    'medicationReference',
    'subject',
    'effectiveDateTime',
    'effectivePeriod',
    'dateAsserted',
    'informationSource',
    'dosage',
  };
  static const _referenceKeys = {'reference', 'display'};
  static const _conceptKeys = {'coding', 'text'};
  static const _codingKeys = {
    'system',
    'version',
    'code',
    'display',
    'userSelected',
  };
  static const _dosageTextKeys = {'text'};
  static const _instantPattern =
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static const _resourceIdPattern = r'^[A-Za-z0-9.-]{1,64}$';
  static const _supportedStatuses = <String>{
    'active',
    'completed',
    'entered-in-error',
    'intended',
    'stopped',
    'on-hold',
    'unknown',
    'not-taken',
  };

  FhirR4MedicationStatementImportPreview previewJson({
    required String input,
    required FhirR4MedicationStatementImportContext context,
  }) {
    if (utf8.encode(input).length >
        FhirR4MedicationStatementImportPreview.maximumInputBytes) {
      throw const FormatException('FHIR input exceeds the byte limit.');
    }
    final decoded = jsonDecode(input);
    final root = _map(decoded);
    if (root == null) {
      throw const FormatException('FHIR input must be a JSON object.');
    }

    final reasons = <String>{};
    final unmapped = <String>{};
    _validateContext(context, reasons);
    final List<FhirR4MedicationStatementImportEntryPreview> entries;
    final String containerType;
    if (root['resourceType'] == 'MedicationStatement') {
      containerType = 'MedicationStatement';
      entries = <FhirR4MedicationStatementImportEntryPreview>[
        _previewStatement(root, context: context, path: 'MedicationStatement'),
      ];
    } else if (root['resourceType'] == 'Bundle') {
      containerType = 'Bundle';
      entries = _previewBundle(
        root,
        context: context,
        reasons: reasons,
        unmapped: unmapped,
      );
    } else {
      throw const FormatException(
        'FHIR input must be a MedicationStatement or collection Bundle.',
      );
    }

    return FhirR4MedicationStatementImportPreview(
      context: context,
      inputSha256: sha256.convert(utf8.encode(input)).toString(),
      containerType: containerType,
      entries: List.unmodifiable(entries),
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  List<FhirR4MedicationStatementImportEntryPreview> _previewBundle(
    Map<String, Object?> bundle, {
    required FhirR4MedicationStatementImportContext context,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    _addUnknownKeys(bundle, _bundleKeys, 'Bundle', unmapped);
    _addUnprojectedKnownKeys(
      bundle,
      _bundleKeys,
      _supportedBundleKeys,
      'Bundle',
      unmapped,
    );
    if (bundle['resourceType'] != 'Bundle') {
      reasons.add('fhir.bundle_resource_type_invalid');
    }
    if (bundle['type'] != 'collection') {
      reasons.add('fhir.bundle_type_not_collection');
    }
    if (bundle.containsKey('meta')) {
      _validateMeta(bundle['meta'], 'Bundle.meta', reasons, unmapped);
      final meta = _map(bundle['meta']);
      if (meta != null) {
        _addUnprojectedKnownKeys(
          meta,
          _metaKeys,
          const <String>{},
          'Bundle.meta',
          unmapped,
        );
      }
    }
    final entries = bundle['entry'];
    if (entries is! List ||
        entries.isEmpty ||
        entries.length >
            FhirR4MedicationStatementImportPreview.maximumEntries) {
      reasons.add('fhir.bundle_entry_count_out_of_bounds');
      return const <FhirR4MedicationStatementImportEntryPreview>[];
    }

    final output = <FhirR4MedicationStatementImportEntryPreview>[];
    final fullUrls = <String>{};
    final resourceIds = <String>{};
    for (var index = 0; index < entries.length; index++) {
      final path = 'Bundle.entry[$index]';
      final entry = _map(entries[index]);
      if (entry == null) {
        reasons.add('fhir.bundle_entry_invalid');
        continue;
      }
      _addUnknownKeys(entry, const {'fullUrl', 'resource'}, path, unmapped);
      String? fullUrl;
      if (entry.containsKey('fullUrl')) {
        final rawFullUrl = entry['fullUrl'];
        final parsedFullUrl = rawFullUrl is String
            ? Uri.tryParse(rawFullUrl)
            : null;
        if (rawFullUrl is! String ||
            !_validText(rawFullUrl, 2048) ||
            parsedFullUrl == null ||
            !parsedFullUrl.hasScheme ||
            RegExp(r'\s').hasMatch(rawFullUrl)) {
          reasons.add('fhir.bundle_full_url_invalid');
        } else if (!fullUrls.add(rawFullUrl)) {
          reasons.add('fhir.bundle_full_url_duplicate');
        } else {
          fullUrl = rawFullUrl;
        }
      }
      final resource = _map(entry['resource']);
      if (resource == null ||
          resource['resourceType'] != 'MedicationStatement') {
        reasons.add('fhir.bundle_resource_unsupported');
        continue;
      }
      final preview = _previewStatement(
        resource,
        context: context,
        path: '$path.resource',
        bundleEntryFullUrl: fullUrl,
      );
      final id = preview.resourceId;
      if (id != null && !resourceIds.add(id)) {
        reasons.add('fhir.resource_id_duplicate');
      }
      output.add(preview);
    }
    if (output.length != entries.length) {
      reasons.add('fhir.bundle_entry_missing_resource');
    }
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    return output;
  }

  FhirR4MedicationStatementImportEntryPreview _previewStatement(
    Map<String, Object?> resource, {
    required FhirR4MedicationStatementImportContext context,
    required String path,
    String? bundleEntryFullUrl,
  }) {
    final reasons = <String>{};
    final unmapped = <String>{};
    _addUnknownKeys(resource, _statementKeys, path, unmapped);
    _addUnprojectedKnownKeys(
      resource,
      _statementKeys,
      _supportedStatementKeys,
      path,
      unmapped,
    );
    if (resource['resourceType'] != 'MedicationStatement') {
      reasons.add('fhir.resource_type_unsupported');
    }
    final resourceId = resource['id'];
    String? parsedId;
    if (resourceId != null) {
      if (resourceId is String &&
          RegExp(_resourceIdPattern).hasMatch(resourceId)) {
        parsedId = resourceId;
      } else {
        reasons.add('fhir.resource_id_invalid');
      }
    }

    final meta = _map(resource['meta']);
    String? versionId;
    String? metaSource;
    FhirR4MedicationStatementTimePreview? metaLastUpdated;
    if (meta != null) {
      _addUnknownKeys(meta, _metaKeys, '$path.meta', unmapped);
      versionId = _readOptionalText(
        meta,
        'versionId',
        '$path.meta.versionId',
        reasons,
      );
      metaSource = _readOptionalText(
        meta,
        'source',
        '$path.meta.source',
        reasons,
      );
      metaLastUpdated = _readTime(
        meta,
        'lastUpdated',
        '$path.meta.lastUpdated',
        reasons,
        requireInstant: true,
      );
    } else if (resource.containsKey('meta')) {
      reasons.add('fhir.meta_invalid');
    }

    final status = _readOptionalText(
      resource,
      'status',
      '$path.status',
      reasons,
    );
    if (status == null || !_supportedStatuses.contains(status)) {
      reasons.add('fhir.status_missing_or_unsupported');
    }

    final hasConcept = resource.containsKey('medicationCodeableConcept');
    final hasReference = resource.containsKey('medicationReference');
    if (hasConcept == hasReference) {
      reasons.add('fhir.medication_choice_invalid');
    }
    String? medicationText;
    final codings = <FhirR4MedicationStatementCodingPreview>[];
    String? medicationReference;
    String? medicationReferenceDisplay;
    if (hasConcept) {
      final conceptResult = _readConcept(
        resource['medicationCodeableConcept'],
        '$path.medicationCodeableConcept',
        reasons,
        unmapped,
      );
      medicationText = conceptResult.text;
      codings.addAll(conceptResult.codings);
      if (conceptResult.text == null && conceptResult.codings.isEmpty) {
        reasons.add('fhir.medication_identity_missing');
      }
    } else if (hasReference) {
      final reference = _readReference(
        resource['medicationReference'],
        '$path.medicationReference',
        reasons,
        unmapped,
      );
      medicationReference = reference.reference;
      medicationReferenceDisplay = reference.display;
      if (medicationReference == null) {
        reasons.add('fhir.medication_reference_missing');
      }
    }

    final subject = _readReference(
      resource['subject'],
      '$path.subject',
      reasons,
      unmapped,
    );
    if (subject.reference == null) {
      reasons.add('fhir.subject_reference_missing');
    } else if (subject.reference != context.expectedPatientReference) {
      reasons.add('fhir.patient_reference_mismatch');
    }

    final hasDateTime = resource.containsKey('effectiveDateTime');
    final hasPeriod = resource.containsKey('effectivePeriod');
    if (hasDateTime && hasPeriod) {
      reasons.add('fhir.effective_choice_invalid');
    }
    final effectiveDateTime = hasDateTime
        ? _readTime(
            resource,
            'effectiveDateTime',
            '$path.effectiveDateTime',
            reasons,
          )
        : null;
    FhirR4MedicationStatementTimePreview? periodStart;
    FhirR4MedicationStatementTimePreview? periodEnd;
    if (hasPeriod) {
      final period = _map(resource['effectivePeriod']);
      if (period == null) {
        reasons.add('fhir.effective_period_invalid');
      } else {
        _addUnknownKeys(
          period,
          const {'start', 'end'},
          '$path.effectivePeriod',
          unmapped,
        );
        periodStart = _readTime(
          period,
          'start',
          '$path.effectivePeriod.start',
          reasons,
        );
        periodEnd = _readTime(
          period,
          'end',
          '$path.effectivePeriod.end',
          reasons,
        );
        if (periodStart == null && periodEnd == null) {
          reasons.add('fhir.effective_period_unbounded');
        } else if (periodStart?.utc != null &&
            periodEnd?.utc != null &&
            periodStart!.utc!.isAfter(periodEnd!.utc!)) {
          reasons.add('fhir.effective_period_order_invalid');
        }
      }
    }
    final dateAsserted = _readTime(
      resource,
      'dateAsserted',
      '$path.dateAsserted',
      reasons,
    );
    final informationSource = resource.containsKey('informationSource')
        ? _readReference(
            resource['informationSource'],
            '$path.informationSource',
            reasons,
            unmapped,
          )
        : const _ReferenceResult();
    final dosageTexts = _readDosageTexts(
      resource.containsKey('dosage') ? resource['dosage'] : null,
      '$path.dosage',
      reasons,
      unmapped,
      present: resource.containsKey('dosage'),
    );

    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    final sortedReasons = reasons.toList()..sort();
    final sortedUnmapped = unmapped.toList()..sort();
    return FhirR4MedicationStatementImportEntryPreview(
      disposition: sortedReasons.isEmpty
          ? FhirR4MedicationStatementImportDisposition.previewable
          : FhirR4MedicationStatementImportDisposition.held,
      status: status,
      bundleEntryFullUrl: bundleEntryFullUrl,
      resourceId: parsedId,
      resourceVersionId: versionId,
      metaSource: metaSource,
      metaLastUpdated: metaLastUpdated,
      medicationConceptText: medicationText,
      medicationCodings: List.unmodifiable(codings),
      medicationReference: medicationReference,
      medicationReferenceDisplay: medicationReferenceDisplay,
      subjectReference: subject.reference,
      effectiveDateTime: effectiveDateTime,
      effectivePeriodStart: periodStart,
      effectivePeriodEnd: periodEnd,
      dateAsserted: dateAsserted,
      informationSourceReference: informationSource.reference,
      informationSourceDisplay: informationSource.display,
      dosageTexts: List.unmodifiable(dosageTexts),
      reasonCodes: List.unmodifiable(sortedReasons),
      unmappedPaths: List.unmodifiable(sortedUnmapped),
    );
  }

  void _validateContext(
    FhirR4MedicationStatementImportContext context,
    Set<String> reasons,
  ) {
    if (context.fhirVersion !=
        FhirR4MedicationStatementImportPreview.supportedFhirVersion) {
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

  void _validateMeta(
    Object? raw,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (raw == null) {
      reasons.add('fhir.meta_invalid');
      return;
    }
    final meta = _map(raw);
    if (meta == null) {
      reasons.add('fhir.meta_invalid');
      return;
    }
    _addUnknownKeys(meta, _metaKeys, path, unmapped);
    _readOptionalText(meta, 'versionId', '$path.versionId', reasons);
    _readOptionalText(meta, 'source', '$path.source', reasons);
    _readTime(
      meta,
      'lastUpdated',
      '$path.lastUpdated',
      reasons,
      requireInstant: true,
    );
  }

  _ConceptResult _readConcept(
    Object? raw,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    final concept = _map(raw);
    if (concept == null) {
      reasons.add('fhir.codeable_concept_invalid');
      return const _ConceptResult();
    }
    _addUnknownKeys(concept, _conceptKeys, path, unmapped);
    final text = _readOptionalText(concept, 'text', '$path.text', reasons);
    final rawCodings = concept['coding'];
    final codings = <FhirR4MedicationStatementCodingPreview>[];
    if (rawCodings != null) {
      if (rawCodings is! List || rawCodings.length > 32) {
        reasons.add('fhir.coding_count_invalid');
      } else {
        for (var index = 0; index < rawCodings.length; index++) {
          final codingPath = '$path.coding[$index]';
          final coding = _map(rawCodings[index]);
          if (coding == null) {
            reasons.add('fhir.coding_invalid');
            continue;
          }
          _addUnknownKeys(coding, _codingKeys, codingPath, unmapped);
          final userSelected = coding['userSelected'];
          if (userSelected != null && userSelected is! bool) {
            reasons.add('fhir.coding_user_selected_invalid');
          }
          final item = FhirR4MedicationStatementCodingPreview(
            system: _readOptionalText(
              coding,
              'system',
              '$codingPath.system',
              reasons,
            ),
            version: _readOptionalText(
              coding,
              'version',
              '$codingPath.version',
              reasons,
            ),
            code: _readOptionalText(
              coding,
              'code',
              '$codingPath.code',
              reasons,
            ),
            display: _readOptionalText(
              coding,
              'display',
              '$codingPath.display',
              reasons,
            ),
            userSelected: userSelected is bool ? userSelected : null,
          );
          codings.add(item);
        }
      }
    }
    return _ConceptResult(text: text, codings: codings);
  }

  _ReferenceResult _readReference(
    Object? raw,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    final reference = _map(raw);
    if (reference == null) {
      reasons.add('fhir.reference_invalid');
      return const _ReferenceResult();
    }
    _addUnknownKeys(reference, _referenceKeys, path, unmapped);
    return _ReferenceResult(
      reference: _readOptionalText(
        reference,
        'reference',
        '$path.reference',
        reasons,
      ),
      display: _readOptionalText(
        reference,
        'display',
        '$path.display',
        reasons,
      ),
    );
  }

  List<String> _readDosageTexts(
    Object? raw,
    String path,
    Set<String> reasons,
    Set<String> unmapped, {
    required bool present,
  }) {
    if (!present) return const <String>[];
    if (raw == null) {
      reasons.add('fhir.dosage_shape_invalid');
      return const <String>[];
    }
    if (raw is! List || raw.length > 32) {
      reasons.add('fhir.dosage_shape_invalid');
      return const <String>[];
    }
    final result = <String>[];
    for (var index = 0; index < raw.length; index++) {
      final itemPath = '$path[$index]';
      final dosage = _map(raw[index]);
      if (dosage == null) {
        reasons.add('fhir.dosage_invalid');
        continue;
      }
      _addUnknownKeys(dosage, _dosageTextKeys, itemPath, unmapped);
      final text = _readOptionalText(dosage, 'text', '$itemPath.text', reasons);
      if (text != null) result.add(text);
    }
    return result;
  }

  FhirR4MedicationStatementTimePreview? _readTime(
    Map<String, Object?> source,
    String key,
    String path,
    Set<String> reasons, {
    bool requireInstant = false,
  }) {
    if (!source.containsKey(key)) return null;
    final raw = source[key];
    if (raw is! String) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    final parsed = _parseDateTime(raw);
    if (parsed == null) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    if (requireInstant && parsed.utc == null) {
      reasons.add('fhir.instant_requires_full_timezone');
      return null;
    }
    if (raw.length > 80 || raw.trim() != raw) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    return parsed;
  }

  FhirR4MedicationStatementTimePreview? _parseDateTime(String value) {
    final year = int.tryParse(value);
    if (year != null && value.length == 4 && year >= 1 && year <= 9999) {
      return FhirR4MedicationStatementTimePreview(
        lexical: value,
        precision: FhirR4MedicationStatementTimePrecision.year,
      );
    }
    final monthMatch = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
    if (monthMatch != null) {
      final month = int.parse(monthMatch.group(2)!);
      if (month < 1 || month > 12) return null;
      return FhirR4MedicationStatementTimePreview(
        lexical: value,
        precision: FhirR4MedicationStatementTimePrecision.month,
      );
    }
    final dayMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (dayMatch != null) {
      final y = int.parse(dayMatch.group(1)!);
      final m = int.parse(dayMatch.group(2)!);
      final d = int.parse(dayMatch.group(3)!);
      final date = DateTime.utc(y, m, d);
      if (date.year != y || date.month != m || date.day != d) return null;
      return FhirR4MedicationStatementTimePreview(
        lexical: value,
        precision: FhirR4MedicationStatementTimePrecision.day,
      );
    }
    final match = RegExp(_instantPattern).firstMatch(value);
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final zoneHour = int.tryParse(match.group(10) ?? '0') ?? 0;
    final zoneMinute = int.tryParse(match.group(11) ?? '0') ?? 0;
    final fraction = match.group(7);
    final date = DateTime.utc(y, m, d);
    if (date.year != y ||
        date.month != m ||
        date.day != d ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        zoneHour > 14 ||
        zoneMinute > 59 ||
        (zoneHour == 14 && zoneMinute != 0) ||
        (fraction?.length ?? 0) > 6) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return FhirR4MedicationStatementTimePreview(
      lexical: value,
      utc: parsed.toUtc(),
      precision: fraction == null
          ? FhirR4MedicationStatementTimePrecision.second
          : FhirR4MedicationStatementTimePrecision.fractionalSecond,
    );
  }

  String? _readOptionalText(
    Map<String, Object?> source,
    String key,
    String path,
    Set<String> reasons,
  ) {
    if (!source.containsKey(key)) return null;
    final raw = source[key];
    if (raw is! String || !_validText(raw, 2048)) {
      reasons.add('fhir.text_field_invalid');
      return null;
    }
    return raw;
  }

  bool _validText(String value, int maxLength) =>
      value.trim().isNotEmpty &&
      value.length <= maxLength &&
      !RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(value);

  void _addUnknownKeys(
    Map<String, Object?> source,
    Set<String> supported,
    String path,
    Set<String> unmapped,
  ) {
    for (final key in source.keys) {
      if (!supported.contains(key)) unmapped.add('$path.$key');
    }
  }

  void _addUnprojectedKnownKeys(
    Map<String, Object?> source,
    Set<String> known,
    Set<String> supported,
    String path,
    Set<String> unmapped,
  ) {
    for (final key in known) {
      if (source.containsKey(key) && !supported.contains(key)) {
        unmapped.add('$path.$key');
      }
    }
  }

  Map<String, Object?>? _map(Object? value) {
    if (value is! Map) return null;
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) return null;
      result[entry.key as String] = entry.value;
    }
    return result;
  }
}

final class _ConceptResult {
  const _ConceptResult({this.text, this.codings = const []});

  final String? text;
  final List<FhirR4MedicationStatementCodingPreview> codings;
}

final class _ReferenceResult {
  const _ReferenceResult({this.reference, this.display});

  final String? reference;
  final String? display;
}
