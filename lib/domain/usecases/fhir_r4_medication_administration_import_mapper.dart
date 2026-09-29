import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/fhir_r4_medication_administration_import_preview.dart';

/// Bounded offline preview of a FHIR R4 MedicationAdministration source.
///
/// It preserves source claims only. It does not authenticate the source,
/// resolve references or terminology, parse dosage, persist data, or invoke a
/// decision-support algorithm. Known R4 fields outside this subset are held.
final class FhirR4MedicationAdministrationImportMapper {
  const FhirR4MedicationAdministrationImportMapper();

  static const _resourceKeys = <String>{
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
    'instantiates',
    'partOf',
    'status',
    'statusReason',
    'category',
    'medicationCodeableConcept',
    'medicationReference',
    'subject',
    'context',
    'supportingInformation',
    'effectiveDateTime',
    'effectivePeriod',
    'performer',
    'reasonCode',
    'reasonReference',
    'request',
    'device',
    'note',
    'dosage',
    'eventHistory',
  };
  static const _supportedResourceKeys = <String>{
    'resourceType',
    'id',
    'meta',
    'status',
    'statusReason',
    'category',
    'medicationCodeableConcept',
    'subject',
    'effectiveDateTime',
    'effectivePeriod',
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
  static const _bundleEntryKeys = <String>{
    'id',
    'extension',
    'modifierExtension',
    'fullUrl',
    'resource',
    'search',
    'request',
    'response',
  };
  static const _metaKeys = <String>{
    'id',
    'extension',
    'versionId',
    'lastUpdated',
    'source',
    'profile',
    'security',
    'tag',
  };
  static const _referenceKeys = <String>{
    'id',
    'extension',
    'reference',
    'type',
    'identifier',
    'display',
  };
  static const _conceptKeys = <String>{'id', 'extension', 'coding', 'text'};
  static const _codingKeys = <String>{
    'id',
    'extension',
    'system',
    'version',
    'code',
    'display',
    'userSelected',
  };
  static const _statuses = <String>{
    'in-progress',
    'not-done',
    'on-hold',
    'completed',
    'entered-in-error',
    'stopped',
    'unknown',
  };
  static const _resourceIdPattern = r'^[A-Za-z0-9.-]{1,64}$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static const _dateTimePattern =
      r'^(\d{4})(?:-(\d{2})(?:-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))?)?)?)?$';

  FhirR4MedicationAdministrationImportPreview previewJson({
    required String input,
    required FhirR4MedicationAdministrationImportContext context,
  }) {
    final bytes = utf8.encode(input);
    if (bytes.length >
        FhirR4MedicationAdministrationImportPreview.maximumInputBytes) {
      throw const FormatException('FHIR input exceeds the byte limit.');
    }
    final root = _map(jsonDecode(input));
    if (root == null) {
      throw const FormatException('FHIR input must be a JSON object.');
    }

    final reasons = <String>{};
    final unmapped = <String>{};
    _validateContext(context, reasons);
    final List<FhirR4MedicationAdministrationImportEntryPreview> entries;
    final String containerType;
    if (root['resourceType'] == 'MedicationAdministration') {
      containerType = 'MedicationAdministration';
      entries = <FhirR4MedicationAdministrationImportEntryPreview>[
        _previewAdministration(
          root,
          context: context,
          path: 'MedicationAdministration',
        ),
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
        'FHIR input must be a MedicationAdministration or collection Bundle.',
      );
    }
    for (final entry in entries) {
      reasons.addAll(entry.reasonCodes);
      unmapped.addAll(entry.unmappedPaths);
    }
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');

    return FhirR4MedicationAdministrationImportPreview(
      context: context,
      inputSha256: sha256.convert(bytes).toString(),
      containerType: containerType,
      entries: List.unmodifiable(entries),
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  List<FhirR4MedicationAdministrationImportEntryPreview> _previewBundle(
    Map<String, Object?> bundle, {
    required FhirR4MedicationAdministrationImportContext context,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    _scan(
      bundle,
      known: _bundleKeys,
      supported: const <String>{'resourceType', 'type', 'entry'},
      path: 'Bundle',
      reasons: reasons,
      unmapped: unmapped,
    );
    if (bundle['type'] != 'collection') {
      reasons.add('fhir.bundle_type_not_collection');
    }
    final rawEntries = bundle['entry'];
    if (rawEntries is! List ||
        rawEntries.isEmpty ||
        rawEntries.length >
            FhirR4MedicationAdministrationImportPreview.maximumEntries) {
      reasons.add('fhir.bundle_entry_count_out_of_bounds');
      return const <FhirR4MedicationAdministrationImportEntryPreview>[];
    }

    final output = <FhirR4MedicationAdministrationImportEntryPreview>[];
    final fullUrls = <String>{};
    final resourceIds = <String>{};
    for (var index = 0; index < rawEntries.length; index++) {
      final path = 'Bundle.entry[$index]';
      final entry = _map(rawEntries[index]);
      if (entry == null) {
        reasons.add('fhir.bundle_entry_invalid');
        continue;
      }
      _scan(
        entry,
        known: _bundleEntryKeys,
        supported: const <String>{'fullUrl', 'resource'},
        path: path,
        reasons: reasons,
        unmapped: unmapped,
      );
      String? fullUrl;
      if (entry.containsKey('fullUrl')) {
        final rawFullUrl = entry['fullUrl'];
        final uri = rawFullUrl is String ? Uri.tryParse(rawFullUrl) : null;
        if (rawFullUrl is! String ||
            rawFullUrl.isEmpty ||
            uri == null ||
            !uri.hasScheme ||
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
          resource['resourceType'] != 'MedicationAdministration') {
        reasons.add('fhir.bundle_resource_unsupported');
        continue;
      }
      final rawId = resource['id'];
      if (rawId is String && !_matches(_resourceIdPattern, rawId)) {
        reasons.add('fhir.resource_id_invalid');
      } else if (rawId is String && !resourceIds.add(rawId)) {
        reasons.add('fhir.resource_id_duplicate');
      }
      output.add(
        _previewAdministration(
          resource,
          context: context,
          path: '$path.resource',
          bundleEntryFullUrl: fullUrl,
        ),
      );
    }
    if (output.length != rawEntries.length) {
      reasons.add('fhir.bundle_entry_missing_resource');
    }
    return output;
  }

  FhirR4MedicationAdministrationImportEntryPreview _previewAdministration(
    Map<String, Object?> resource, {
    required FhirR4MedicationAdministrationImportContext context,
    required String path,
    String? bundleEntryFullUrl,
  }) {
    final reasons = <String>{};
    final unmapped = <String>{};
    _scan(
      resource,
      known: _resourceKeys,
      supported: _supportedResourceKeys,
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    final id = _optionalText(resource, 'id', '$path.id', reasons, 64);
    if (id != null && !_matches(_resourceIdPattern, id)) {
      reasons.add('fhir.resource_id_invalid');
    }
    final meta = _readMeta(
      resource,
      path: '$path.meta',
      reasons: reasons,
      unmapped: unmapped,
    );
    final status = _optionalText(
      resource,
      'status',
      '$path.status',
      reasons,
      64,
    );
    if (status == null || !_statuses.contains(status)) {
      reasons.add('fhir.status_missing_or_unsupported');
    } else if (status == 'entered-in-error') {
      reasons.add('fhir.entered_in_error');
    }

    final hasMedicationConcept = resource.containsKey(
      'medicationCodeableConcept',
    );
    final hasMedicationReference = resource.containsKey('medicationReference');
    if (hasMedicationConcept == hasMedicationReference) {
      reasons.add('fhir.medication_choice_invalid');
    }
    String? medicationText;
    var medicationCodings =
        const <FhirR4MedicationAdministrationCodingPreview>[];
    if (hasMedicationConcept) {
      final concept = _readConcept(
        resource['medicationCodeableConcept'],
        '$path.medicationCodeableConcept',
        reasons,
        unmapped,
      );
      medicationText = concept?.text;
      medicationCodings = concept?.codings ?? const [];
      if (concept == null ||
          (concept.text == null && concept.codings.isEmpty)) {
        reasons.add('fhir.medication_concept_empty');
      }
    }

    final subject = _map(resource['subject']);
    String? subjectReference;
    var patientMatched = false;
    if (subject == null) {
      reasons.add('fhir.subject_missing_or_invalid');
    } else {
      _scan(
        subject,
        known: _referenceKeys,
        supported: const <String>{'reference'},
        path: '$path.subject',
        reasons: reasons,
        unmapped: unmapped,
      );
      subjectReference = _optionalText(
        subject,
        'reference',
        '$path.subject.reference',
        reasons,
        2048,
      );
      patientMatched =
          subjectReference != null &&
          _matches(_patientReferencePattern, subjectReference) &&
          subjectReference == context.expectedPatientReference;
      if (!patientMatched) reasons.add('fhir.patient_reference_mismatch');
    }

    final hasDateTime = resource.containsKey('effectiveDateTime');
    final hasPeriod = resource.containsKey('effectivePeriod');
    if (hasDateTime == hasPeriod) {
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
    FhirR4MedicationAdministrationTimePreview? periodStart;
    FhirR4MedicationAdministrationTimePreview? periodEnd;
    if (hasPeriod) {
      final period = _map(resource['effectivePeriod']);
      if (period == null) {
        reasons.add('fhir.effective_period_invalid');
      } else {
        _scan(
          period,
          known: const <String>{'id', 'extension', 'start', 'end'},
          supported: const <String>{'start', 'end'},
          path: '$path.effectivePeriod',
          reasons: reasons,
          unmapped: unmapped,
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

    final category = resource.containsKey('category')
        ? _readConcept(
            resource['category'],
            '$path.category',
            reasons,
            unmapped,
          )
        : null;
    final statusReasons = _readConceptList(
      resource,
      'statusReason',
      '$path.statusReason',
      reasons,
      unmapped,
    );
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');

    final sortedReasons = reasons.toList()..sort();
    final sortedUnmapped = unmapped.toList()..sort();
    return FhirR4MedicationAdministrationImportEntryPreview(
      disposition: sortedReasons.isEmpty
          ? FhirR4MedicationAdministrationDisposition.previewable
          : FhirR4MedicationAdministrationDisposition.held,
      patientReferenceMatched: patientMatched,
      status: status,
      resourceId: id,
      bundleEntryFullUrl: bundleEntryFullUrl,
      resourceVersionId: meta.versionId,
      metaSource: meta.source,
      metaLastUpdated: meta.lastUpdated,
      medicationConceptText: medicationText,
      medicationCodings: List.unmodifiable(medicationCodings),
      subjectReference: subjectReference,
      category: category,
      statusReasons: List.unmodifiable(statusReasons),
      effectiveDateTime: effectiveDateTime,
      effectivePeriodStart: periodStart,
      effectivePeriodEnd: periodEnd,
      reasonCodes: List.unmodifiable(sortedReasons),
      unmappedPaths: List.unmodifiable(sortedUnmapped),
    );
  }

  List<FhirR4MedicationAdministrationConceptPreview> _readConceptList(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (!parent.containsKey(key)) {
      return const <FhirR4MedicationAdministrationConceptPreview>[];
    }
    final raw = parent[key];
    if (raw is! List || raw.length > 12) {
      reasons.add('fhir.status_reason_list_invalid');
      return const <FhirR4MedicationAdministrationConceptPreview>[];
    }
    final result = <FhirR4MedicationAdministrationConceptPreview>[];
    for (var index = 0; index < raw.length; index++) {
      final concept = _readConcept(
        raw[index],
        '$path[$index]',
        reasons,
        unmapped,
      );
      if (concept != null) result.add(concept);
    }
    return result;
  }

  FhirR4MedicationAdministrationConceptPreview? _readConcept(
    Object? raw,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    final concept = _map(raw);
    if (concept == null) {
      reasons.add('fhir.concept_invalid');
      return null;
    }
    _scan(
      concept,
      known: _conceptKeys,
      supported: const <String>{'coding', 'text'},
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    final text = _optionalText(concept, 'text', '$path.text', reasons, 512);
    final codings = <FhirR4MedicationAdministrationCodingPreview>[];
    final rawCodings = concept['coding'];
    if (rawCodings != null) {
      if (rawCodings is! List || rawCodings.length > 16) {
        reasons.add('fhir.coding_list_invalid');
      } else {
        for (var index = 0; index < rawCodings.length; index++) {
          final codingPath = '$path.coding[$index]';
          final coding = _map(rawCodings[index]);
          if (coding == null) {
            reasons.add('fhir.coding_invalid');
            continue;
          }
          _scan(
            coding,
            known: _codingKeys,
            supported: const <String>{
              'system',
              'version',
              'code',
              'display',
              'userSelected',
            },
            path: codingPath,
            reasons: reasons,
            unmapped: unmapped,
          );
          final system = _optionalText(
            coding,
            'system',
            '$codingPath.system',
            reasons,
            2048,
          );
          if (system != null && !_isAbsoluteUri(system)) {
            reasons.add('fhir.coding_system_invalid');
          }
          codings.add(
            FhirR4MedicationAdministrationCodingPreview(
              system: system,
              version: _optionalText(
                coding,
                'version',
                '$codingPath.version',
                reasons,
                128,
              ),
              code: _optionalText(
                coding,
                'code',
                '$codingPath.code',
                reasons,
                256,
              ),
              display: _optionalText(
                coding,
                'display',
                '$codingPath.display',
                reasons,
                512,
              ),
              userSelected: _optionalBool(
                coding,
                'userSelected',
                '$codingPath.userSelected',
                reasons,
              ),
            ),
          );
        }
      }
    }
    if (text == null && codings.isEmpty) reasons.add('fhir.concept_empty');
    return FhirR4MedicationAdministrationConceptPreview(
      codings: List.unmodifiable(codings),
      text: text,
    );
  }

  ({
    String? versionId,
    String? source,
    FhirR4MedicationAdministrationTimePreview? lastUpdated,
  })
  _readMeta(
    Map<String, Object?> parent, {
    required String path,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    if (!parent.containsKey('meta')) {
      return (versionId: null, source: null, lastUpdated: null);
    }
    final meta = _map(parent['meta']);
    if (meta == null) {
      reasons.add('fhir.meta_invalid');
      return (versionId: null, source: null, lastUpdated: null);
    }
    _scan(
      meta,
      known: _metaKeys,
      supported: const <String>{'versionId', 'source', 'lastUpdated'},
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    final versionId = _optionalText(
      meta,
      'versionId',
      '$path.versionId',
      reasons,
      128,
    );
    final source = _optionalText(meta, 'source', '$path.source', reasons, 2048);
    if (source != null && !_isAbsoluteUri(source)) {
      reasons.add('fhir.meta_source_invalid');
    }
    final lastUpdated = _readTime(
      meta,
      'lastUpdated',
      '$path.lastUpdated',
      reasons,
      requireInstant: true,
    );
    return (versionId: versionId, source: source, lastUpdated: lastUpdated);
  }

  FhirR4MedicationAdministrationTimePreview? _readTime(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons, {
    bool requireInstant = false,
  }) {
    if (!parent.containsKey(key)) return null;
    final value = parent[key];
    if (value is! String || value.isEmpty || value.length > 64) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    final match = RegExp(_dateTimePattern).firstMatch(value);
    if (match == null) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = match.group(2) == null ? null : int.parse(match.group(2)!);
    final day = match.group(3) == null ? null : int.parse(match.group(3)!);
    final hour = match.group(4) == null ? null : int.parse(match.group(4)!);
    final minute = match.group(5) == null ? null : int.parse(match.group(5)!);
    final second = match.group(6) == null ? null : int.parse(match.group(6)!);
    final fraction = match.group(7);
    final zone = match.group(8);
    if (year < 1 ||
        (month != null && (month < 1 || month > 12)) ||
        (day != null && (day < 1 || day > 31)) ||
        (hour != null && (hour > 23 || minute! > 59 || second! > 59)) ||
        (hour != null && zone == null) ||
        (requireInstant && (hour == null || zone == null))) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    final normalized = DateTime.utc(year, month ?? 1, day ?? 1);
    if (normalized.year != year ||
        normalized.month != (month ?? 1) ||
        normalized.day != (day ?? 1)) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    DateTime? utc;
    if (hour != null) {
      try {
        utc = DateTime.parse(value).toUtc();
      } on FormatException {
        reasons.add('fhir.datetime_invalid');
        return null;
      }
    }
    final precision = hour != null
        ? (fraction == null
              ? FhirR4MedicationAdministrationTimePrecision.second
              : FhirR4MedicationAdministrationTimePrecision.fractionalSecond)
        : day != null
        ? FhirR4MedicationAdministrationTimePrecision.day
        : month != null
        ? FhirR4MedicationAdministrationTimePrecision.month
        : FhirR4MedicationAdministrationTimePrecision.year;
    return FhirR4MedicationAdministrationTimePreview(
      lexical: value,
      precision: precision,
      utc: utc,
    );
  }

  void _validateContext(
    FhirR4MedicationAdministrationImportContext context,
    Set<String> reasons,
  ) {
    if (context.fhirVersion !=
        FhirR4MedicationAdministrationImportPreview.supportedFhirVersion) {
      reasons.add('fhir.release_unsupported');
    }
    if (!_matches(r'^[A-Z]{2}$', context.jurisdiction)) {
      reasons.add('fhir.jurisdiction_invalid');
    }
    if (!_matches(_patientReferencePattern, context.expectedPatientReference)) {
      reasons.add('fhir.expected_patient_reference_invalid');
    }
  }

  void _scan(
    Map<String, Object?> value, {
    required Set<String> known,
    required Set<String> supported,
    required String path,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    for (final key in value.keys) {
      if (!known.contains(key)) reasons.add('fhir.unknown_field');
      if (!supported.contains(key)) unmapped.add('$path.$key');
    }
  }

  String? _optionalText(
    Map<String, Object?> value,
    String key,
    String path,
    Set<String> reasons,
    int maximumLength,
  ) {
    if (!value.containsKey(key)) return null;
    final raw = value[key];
    if (raw is! String ||
        raw.trim().isEmpty ||
        raw.length > maximumLength ||
        raw != raw.trim()) {
      reasons.add('fhir.text_invalid:$path');
      return null;
    }
    return raw;
  }

  bool? _optionalBool(
    Map<String, Object?> value,
    String key,
    String path,
    Set<String> reasons,
  ) {
    if (!value.containsKey(key)) return null;
    final raw = value[key];
    if (raw is! bool) {
      reasons.add('fhir.boolean_invalid:$path');
      return null;
    }
    return raw;
  }

  bool _isAbsoluteUri(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && !RegExp(r'\s').hasMatch(value);
  }

  bool _matches(String pattern, String value) =>
      RegExp(pattern).hasMatch(value);

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
