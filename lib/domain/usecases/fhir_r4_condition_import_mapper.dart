import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/fhir_r4_condition_import_preview.dart';

/// Offline, bounded Condition source-field preview.
///
/// The mapper does not resolve terminology or identity, persist input, or call
/// the CDSS rule engine. Known R4 fields outside this projection remain held.
final class FhirR4ConditionImportMapper {
  const FhirR4ConditionImportMapper();

  static const _conditionKeys = <String>{
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
    'clinicalStatus',
    'verificationStatus',
    'category',
    'severity',
    'code',
    'bodySite',
    'subject',
    'encounter',
    'onsetDateTime',
    'onsetAge',
    'onsetPeriod',
    'onsetRange',
    'onsetString',
    'abatementDateTime',
    'abatementAge',
    'abatementPeriod',
    'abatementRange',
    'abatementString',
    'recordedDate',
    'recorder',
    'asserter',
    'stage',
    'evidence',
    'note',
  };
  static const _supportedConditionKeys = <String>{
    'resourceType',
    'id',
    'meta',
    'clinicalStatus',
    'verificationStatus',
    'category',
    'code',
    'subject',
    'onsetDateTime',
    'abatementDateTime',
    'recordedDate',
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
  static const _supportedBundleKeys = <String>{'resourceType', 'type', 'entry'};
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
  static const _supportedBundleEntryKeys = <String>{'fullUrl', 'resource'};
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
  static const _supportedMetaKeys = <String>{
    'versionId',
    'lastUpdated',
    'source',
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
  static const _supportedConceptKeys = <String>{'coding', 'text'};
  static const _codingKeys = <String>{
    'id',
    'extension',
    'system',
    'version',
    'code',
    'display',
    'userSelected',
  };
  static const _supportedCodingKeys = <String>{
    'system',
    'version',
    'code',
    'display',
    'userSelected',
  };

  static const _clinicalStatusSystem =
      'http://terminology.hl7.org/CodeSystem/condition-clinical';
  static const _verificationStatusSystem =
      'http://terminology.hl7.org/CodeSystem/condition-ver-status';
  static const _categorySystem =
      'http://terminology.hl7.org/CodeSystem/condition-category';
  static const _clinicalStatusCodes = <String>{
    'active',
    'recurrence',
    'relapse',
    'inactive',
    'remission',
    'resolved',
  };
  static const _verificationStatusCodes = <String>{
    'unconfirmed',
    'provisional',
    'differential',
    'confirmed',
    'refuted',
    'entered-in-error',
  };
  static const _resourceIdPattern = r'^[A-Za-z0-9.-]{1,64}$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static const _datePattern =
      r'^(\d{4})(?:-(\d{2})(?:-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))?)?)?)?$';
  static const _instantPattern =
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))$';

  FhirR4ConditionImportPreview previewJson({
    required String input,
    required FhirR4ConditionPreviewContext context,
  }) {
    if (utf8.encode(input).length >
        FhirR4ConditionImportPreview.maximumInputBytes) {
      throw const FormatException('FHIR input exceeds the byte limit.');
    }
    final root = _map(jsonDecode(input));
    if (root == null) {
      throw const FormatException('FHIR input must be a JSON object.');
    }

    final reasons = <String>{};
    final unmapped = <String>{};
    _validateContext(context, reasons);
    final List<FhirR4ConditionEntryPreview> entries;
    final String containerType;
    if (root['resourceType'] == 'Condition') {
      containerType = 'Condition';
      entries = <FhirR4ConditionEntryPreview>[
        _previewCondition(root, context: context, path: 'Condition'),
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
        'FHIR input must be a Condition or collection Bundle.',
      );
    }
    for (final entry in entries) {
      reasons.addAll(entry.reasonCodes);
      unmapped.addAll(entry.unmappedPaths);
    }
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');

    return FhirR4ConditionImportPreview(
      context: context,
      inputSha256: sha256.convert(utf8.encode(input)).toString(),
      containerType: containerType,
      entries: List.unmodifiable(entries),
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  List<FhirR4ConditionEntryPreview> _previewBundle(
    Map<String, Object?> bundle, {
    required FhirR4ConditionPreviewContext context,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    _scanFields(
      bundle,
      known: _bundleKeys,
      supported: _supportedBundleKeys,
      path: 'Bundle',
      unmapped: unmapped,
      reasons: reasons,
    );
    if (bundle['type'] != 'collection') {
      reasons.add('fhir.bundle_type_not_collection');
    }
    final rawEntries = bundle['entry'];
    if (rawEntries is! List ||
        rawEntries.isEmpty ||
        rawEntries.length > FhirR4ConditionImportPreview.maximumEntries) {
      reasons.add('fhir.bundle_entry_count_out_of_bounds');
      return const <FhirR4ConditionEntryPreview>[];
    }

    final output = <FhirR4ConditionEntryPreview>[];
    final fullUrls = <String>{};
    final resourceIds = <String>{};
    for (var index = 0; index < rawEntries.length; index++) {
      final path = 'Bundle.entry[$index]';
      final entry = _map(rawEntries[index]);
      if (entry == null) {
        reasons.add('fhir.bundle_entry_invalid');
        continue;
      }
      _scanFields(
        entry,
        known: _bundleEntryKeys,
        supported: _supportedBundleEntryKeys,
        path: path,
        unmapped: unmapped,
        reasons: reasons,
      );
      String? sourceFullUrl;
      if (entry.containsKey('fullUrl')) {
        final fullUrl = entry['fullUrl'];
        if (fullUrl is! String || !_isAbsoluteUri(fullUrl)) {
          reasons.add('fhir.bundle_full_url_invalid');
        } else if (!fullUrls.add(fullUrl)) {
          reasons.add('fhir.bundle_full_url_duplicate');
        } else {
          sourceFullUrl = fullUrl;
        }
      }
      final resource = _map(entry['resource']);
      if (resource == null || resource['resourceType'] != 'Condition') {
        reasons.add('fhir.bundle_resource_unsupported');
        continue;
      }
      final id = resource['id'];
      if (id != null) {
        if (id is! String ||
            !_validText(id, 64) ||
            !_matches(_resourceIdPattern, id)) {
          reasons.add('fhir.resource_id_invalid');
        } else if (!resourceIds.add(id)) {
          reasons.add('fhir.resource_id_duplicate');
        }
      }
      output.add(
        _previewCondition(
          resource,
          context: context,
          path: '$path.resource',
          entryFullUrl: sourceFullUrl,
        ),
      );
    }
    if (output.length != rawEntries.length) {
      reasons.add('fhir.bundle_entry_missing_resource');
    }
    return output;
  }

  FhirR4ConditionEntryPreview _previewCondition(
    Map<String, Object?> resource, {
    required FhirR4ConditionPreviewContext context,
    required String path,
    String? entryFullUrl,
  }) {
    final reasons = <String>{};
    final unmapped = <String>{};
    _scanFields(
      resource,
      known: _conditionKeys,
      supported: _supportedConditionKeys,
      path: path,
      unmapped: unmapped,
      reasons: reasons,
    );
    if (resource['resourceType'] != 'Condition') {
      reasons.add('fhir.condition_resource_type_invalid');
    }
    final id = _optionalText(
      resource,
      'id',
      '$path.id',
      reasons,
      maxLength: 64,
    );
    if (id != null && !_matches(_resourceIdPattern, id)) {
      reasons.add('fhir.resource_id_invalid');
    }
    final meta = _readMeta(
      resource,
      path: '$path.meta',
      unmapped: unmapped,
      reasons: reasons,
    );
    final patientReferenceMatched = _readPatientReference(
      resource,
      context: context,
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    final clinicalStatus = _readConcept(
      resource,
      'clinicalStatus',
      '$path.clinicalStatus',
      reasons,
      unmapped,
    );
    final verificationStatus = _readConcept(
      resource,
      'verificationStatus',
      '$path.verificationStatus',
      reasons,
      unmapped,
    );
    final categories = _readConceptList(
      resource,
      'category',
      '$path.category',
      reasons,
      unmapped,
    );
    final code = _readConcept(
      resource,
      'code',
      '$path.code',
      reasons,
      unmapped,
    );
    final onset = _readDateTime(
      resource,
      'onsetDateTime',
      '$path.onsetDateTime',
      reasons,
    );
    final abatement = _readDateTime(
      resource,
      'abatementDateTime',
      '$path.abatementDateTime',
      reasons,
    );
    final recordedDate = _readDateTime(
      resource,
      'recordedDate',
      '$path.recordedDate',
      reasons,
    );

    final verificationCode = _boundStatusCode(
      verificationStatus,
      expectedSystem: _verificationStatusSystem,
      allowedCodes: _verificationStatusCodes,
      fieldPath: '$path.verificationStatus',
      reasons: reasons,
    );
    final clinicalCode = _boundStatusCode(
      clinicalStatus,
      expectedSystem: _clinicalStatusSystem,
      allowedCodes: _clinicalStatusCodes,
      fieldPath: '$path.clinicalStatus',
      reasons: reasons,
    );
    final isProblemListItem = categories.any(
      (category) => category.codings.any(
        (coding) =>
            coding.system == _categorySystem &&
            coding.code == 'problem-list-item',
      ),
    );
    if (verificationCode == 'entered-in-error' && clinicalStatus != null) {
      reasons.add('fhir.entered_in_error_has_clinical_status');
    }
    if (isProblemListItem &&
        verificationCode != 'entered-in-error' &&
        clinicalStatus == null) {
      reasons.add('fhir.problem_list_requires_clinical_status');
    }
    if (abatement != null &&
        clinicalCode != null &&
        !const <String>{
          'inactive',
          'remission',
          'resolved',
        }.contains(clinicalCode)) {
      reasons.add('fhir.abatement_status_inconsistent');
    }

    return FhirR4ConditionEntryPreview(
      disposition: reasons.isEmpty && unmapped.isEmpty
          ? FhirR4ConditionDisposition.previewable
          : FhirR4ConditionDisposition.held,
      patientReferenceMatched: patientReferenceMatched,
      resourceId: id,
      entryFullUrl: entryFullUrl,
      resourceVersionId: meta.versionId,
      metaSource: meta.source,
      metaLastUpdated: meta.lastUpdated,
      clinicalStatus: clinicalStatus,
      verificationStatus: verificationStatus,
      categories: List.unmodifiable(categories),
      code: code,
      onsetDateTime: onset,
      abatementDateTime: abatement,
      recordedDate: recordedDate,
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  bool _readPatientReference(
    Map<String, Object?> resource, {
    required FhirR4ConditionPreviewContext context,
    required String path,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    final raw = resource['subject'];
    if (raw == null) {
      reasons.add('fhir.subject_missing');
      return false;
    }
    final subject = _map(raw);
    if (subject == null) {
      reasons.add('fhir.subject_invalid');
      return false;
    }
    _scanFields(
      subject,
      known: _referenceKeys,
      supported: const <String>{'reference'},
      path: '$path.subject',
      unmapped: unmapped,
      reasons: reasons,
    );
    final reference = _optionalText(
      subject,
      'reference',
      '$path.subject.reference',
      reasons,
      maxLength: 2048,
    );
    if (reference == null ||
        !_matches(_patientReferencePattern, reference) ||
        reference != context.expectedPatientReference) {
      reasons.add('fhir.patient_reference_mismatch_or_unsupported');
      return false;
    }
    return true;
  }

  FhirR4ConditionConceptPreview? _readConcept(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (!parent.containsKey(key)) return null;
    final value = _map(parent[key]);
    if (value == null) {
      reasons.add('fhir.concept_invalid');
      return null;
    }
    _scanFields(
      value,
      known: _conceptKeys,
      supported: _supportedConceptKeys,
      path: path,
      unmapped: unmapped,
      reasons: reasons,
    );
    final text = _optionalText(
      value,
      'text',
      '$path.text',
      reasons,
      maxLength: 512,
    );
    final rawCodings = value['coding'];
    final codings = <FhirR4ConditionCodingPreview>[];
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
          _scanFields(
            coding,
            known: _codingKeys,
            supported: _supportedCodingKeys,
            path: codingPath,
            unmapped: unmapped,
            reasons: reasons,
          );
          final system = _optionalText(
            coding,
            'system',
            '$codingPath.system',
            reasons,
            maxLength: 2048,
          );
          if (system != null && !_isAbsoluteUri(system)) {
            reasons.add('fhir.coding_system_invalid');
          }
          codings.add(
            FhirR4ConditionCodingPreview(
              system: system,
              version: _optionalText(
                coding,
                'version',
                '$codingPath.version',
                reasons,
                maxLength: 128,
              ),
              code: _optionalText(
                coding,
                'code',
                '$codingPath.code',
                reasons,
                maxLength: 256,
              ),
              display: _optionalText(
                coding,
                'display',
                '$codingPath.display',
                reasons,
                maxLength: 512,
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
    return FhirR4ConditionConceptPreview(
      codings: List.unmodifiable(codings),
      text: text,
    );
  }

  List<FhirR4ConditionConceptPreview> _readConceptList(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (!parent.containsKey(key)) {
      return const <FhirR4ConditionConceptPreview>[];
    }
    final raw = parent[key];
    if (raw is! List || raw.length > 12) {
      reasons.add('fhir.category_list_invalid');
      return const <FhirR4ConditionConceptPreview>[];
    }
    final concepts = <FhirR4ConditionConceptPreview>[];
    for (var index = 0; index < raw.length; index++) {
      final concept = _readConcept(
        <String, Object?>{key: raw[index]},
        key,
        '$path[$index]',
        reasons,
        unmapped,
      );
      if (concept != null) concepts.add(concept);
    }
    return List.unmodifiable(concepts);
  }

  String? _boundStatusCode(
    FhirR4ConditionConceptPreview? concept, {
    required String expectedSystem,
    required Set<String> allowedCodes,
    required String fieldPath,
    required Set<String> reasons,
  }) {
    if (concept == null) return null;
    if (concept.codings.length != 1) {
      reasons.add('fhir.status_coding_ambiguous');
      return null;
    }
    final coding = concept.codings.single;
    final code = coding.code;
    if (coding.system != expectedSystem ||
        code == null ||
        !allowedCodes.contains(code)) {
      final statusName = fieldPath.endsWith('.clinicalStatus')
          ? 'clinical_status'
          : 'verification_status';
      reasons.add('fhir.${statusName}_unsupported');
      return null;
    }
    return code;
  }

  ({String? versionId, String? source, FhirR4ConditionTimePreview? lastUpdated})
  _readMeta(
    Map<String, Object?> parent, {
    required String path,
    required Set<String> unmapped,
    required Set<String> reasons,
  }) {
    if (!parent.containsKey('meta')) {
      return (versionId: null, source: null, lastUpdated: null);
    }
    final meta = _map(parent['meta']);
    if (meta == null) {
      reasons.add('fhir.meta_invalid');
      return (versionId: null, source: null, lastUpdated: null);
    }
    _scanFields(
      meta,
      known: _metaKeys,
      supported: _supportedMetaKeys,
      path: path,
      unmapped: unmapped,
      reasons: reasons,
    );
    final versionId = _optionalText(
      meta,
      'versionId',
      '$path.versionId',
      reasons,
      maxLength: 64,
    );
    final source = _optionalText(
      meta,
      'source',
      '$path.source',
      reasons,
      maxLength: 2048,
    );
    if (source != null && !_isAbsoluteUri(source)) {
      reasons.add('fhir.meta_source_invalid');
    }
    final lastUpdated = _readDateTime(
      meta,
      'lastUpdated',
      '$path.lastUpdated',
      reasons,
      requireInstant: true,
    );
    return (versionId: versionId, source: source, lastUpdated: lastUpdated);
  }

  FhirR4ConditionTimePreview? _readDateTime(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons, {
    bool requireInstant = false,
  }) {
    final value = _optionalText(parent, key, path, reasons, maxLength: 64);
    if (value == null) return null;
    final match = RegExp(
      requireInstant ? _instantPattern : _datePattern,
    ).firstMatch(value);
    if (match == null || !_validDateParts(match)) {
      reasons.add('fhir.date_time_invalid');
      return null;
    }
    final precision = match.group(4) == null
        ? match.group(3) == null
              ? match.group(2) == null
                    ? FhirR4ConditionDatePrecision.year
                    : FhirR4ConditionDatePrecision.month
              : FhirR4ConditionDatePrecision.day
        : match.group(7) == null
        ? FhirR4ConditionDatePrecision.second
        : FhirR4ConditionDatePrecision.fractionalSecond;
    return FhirR4ConditionTimePreview(lexical: value, precision: precision);
  }

  bool _validDateParts(RegExpMatch match) {
    int? part(int index) => int.tryParse(match.group(index) ?? '');
    final year = part(1);
    if (year == null) return false;
    final month = part(2);
    final day = part(3);
    if (month != null && (month < 1 || month > 12)) return false;
    if (day != null) {
      if (month == null || day < 1) return false;
      final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
      final daysInMonth = switch (month) {
        2 => leap ? 29 : 28,
        4 || 6 || 9 || 11 => 30,
        _ => 31,
      };
      if (day > daysInMonth) return false;
    }
    final hour = part(4);
    if (hour != null) {
      final minute = part(5);
      final second = part(6);
      if (hour > 23 ||
          minute == null ||
          minute > 59 ||
          second == null ||
          second > 59) {
        return false;
      }
      if (match.group(8) == null) return false;
      if (match.group(8) != 'Z') {
        final zoneHour = part(10);
        final zoneMinute = part(11);
        if (zoneHour == null || zoneMinute == null || zoneMinute > 59) {
          return false;
        }
        if (zoneHour > 14 || (zoneHour == 14 && zoneMinute != 0)) return false;
      }
    }
    return true;
  }

  void _validateContext(
    FhirR4ConditionPreviewContext context,
    Set<String> reasons,
  ) {
    if (context.fhirVersion !=
        FhirR4ConditionImportPreview.supportedFhirVersion) {
      reasons.add('fhir.release_unsupported');
    }
    if (!_matches(r'^[A-Z]{2}$', context.jurisdiction)) {
      reasons.add('fhir.jurisdiction_invalid');
    }
    if (!_matches(_patientReferencePattern, context.expectedPatientReference)) {
      reasons.add('fhir.patient_reference_invalid');
    }
  }

  void _scanFields(
    Map<String, Object?> value, {
    required Set<String> known,
    required Set<String> supported,
    required String path,
    required Set<String> unmapped,
    required Set<String> reasons,
  }) {
    for (final key in value.keys) {
      if (!known.contains(key)) {
        reasons.add('fhir.unknown_field');
      } else if (!supported.contains(key)) {
        unmapped.add('$path.$key');
      }
    }
  }

  String? _optionalText(
    Map<String, Object?> value,
    String key,
    String path,
    Set<String> reasons, {
    required int maxLength,
  }) {
    if (!value.containsKey(key)) return null;
    final item = value[key];
    if (item is! String || !_validText(item, maxLength)) {
      reasons.add('fhir.text_invalid');
      return null;
    }
    return item;
  }

  bool? _optionalBool(
    Map<String, Object?> value,
    String key,
    String path,
    Set<String> reasons,
  ) {
    if (!value.containsKey(key)) return null;
    final item = value[key];
    if (item is! bool) {
      reasons.add('fhir.boolean_invalid');
      return null;
    }
    return item;
  }

  bool _validText(String value, int maxLength) =>
      value.isNotEmpty && value.trim() == value && value.length <= maxLength;

  bool _isAbsoluteUri(String value) {
    final uri = Uri.tryParse(value);
    return _validText(value, 2048) &&
        uri != null &&
        uri.hasScheme &&
        !value.contains(RegExp(r'\s'));
  }

  bool _matches(String pattern, String value) =>
      RegExp(pattern).hasMatch(value);

  Map<String, Object?>? _map(Object? value) {
    if (value is! Map) return null;
    final output = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) return null;
      output[entry.key as String] = entry.value;
    }
    return output;
  }
}
