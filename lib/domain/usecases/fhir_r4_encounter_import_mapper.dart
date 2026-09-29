import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/fhir_r4_encounter_import_preview.dart';

/// Projects a deliberately small FHIR R4 Encounter subset for local review.
/// No references are resolved, terminology is looked up, data is persisted,
/// or CDSS algorithm is called. Known fields outside the subset are held.
final class FhirR4EncounterImportMapper {
  const FhirR4EncounterImportMapper();

  static const _statuses = <String>{
    'planned',
    'arrived',
    'triaged',
    'in-progress',
    'onleave',
    'finished',
    'cancelled',
    'entered-in-error',
    'unknown',
  };
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
    'status',
    'statusHistory',
    'class',
    'classHistory',
    'type',
    'serviceType',
    'priority',
    'subject',
    'episodeOfCare',
    'basedOn',
    'participant',
    'appointment',
    'period',
    'length',
    'reasonCode',
    'reasonReference',
    'diagnosis',
    'account',
    'hospitalization',
    'location',
    'serviceProvider',
    'partOf',
  };
  static const _supportedResourceKeys = <String>{
    'resourceType',
    'id',
    'status',
    'class',
    'subject',
    'period',
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
  static const _codingKeys = <String>{
    'id',
    'extension',
    'system',
    'version',
    'code',
    'display',
    'userSelected',
  };
  static const _subjectKeys = <String>{
    'id',
    'extension',
    'reference',
    'type',
    'identifier',
    'display',
  };
  static const _periodKeys = <String>{'id', 'extension', 'start', 'end'};
  static const _resourceIdPattern = r'^[A-Za-z0-9.-]{1,64}$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static final _dateTimePattern = RegExp(
    r'^(\d{4})(?:-(\d{2})(?:-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|([+-])(\d{2}):(\d{2}))?)?)?)?$',
  );

  FhirR4EncounterImportPreview previewJson({
    required String input,
    required FhirR4EncounterImportContext context,
  }) {
    final bytes = utf8.encode(input);
    if (bytes.length > FhirR4EncounterImportPreview.maximumInputBytes) {
      throw const FormatException('FHIR input exceeds the byte limit.');
    }
    final root = _map(jsonDecode(input));
    if (root == null) {
      throw const FormatException('FHIR input must be a JSON object.');
    }

    final contextReasons = <String>{};
    _validateContext(context, contextReasons);
    final reasons = <String>{...contextReasons};
    final unmapped = <String>{};
    final List<FhirR4EncounterEntryPreview> entries;
    final String containerType;
    if (root['resourceType'] == 'Encounter') {
      containerType = 'Encounter';
      entries = <FhirR4EncounterEntryPreview>[
        _previewEncounter(
          root,
          context: context,
          contextReasons: contextReasons,
        ),
      ];
    } else if (root['resourceType'] == 'Bundle') {
      containerType = 'Bundle';
      entries = _previewBundle(
        root,
        context: context,
        contextReasons: contextReasons,
        reasons: reasons,
        unmapped: unmapped,
      );
    } else {
      throw const FormatException(
        'FHIR input must be an Encounter or collection Bundle.',
      );
    }
    for (final entry in entries) {
      reasons.addAll(entry.reasonCodes);
      unmapped.addAll(entry.unmappedPaths);
    }
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');

    return FhirR4EncounterImportPreview(
      context: context,
      inputSha256: sha256.convert(bytes).toString(),
      containerType: containerType,
      entries: List.unmodifiable(entries),
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  List<FhirR4EncounterEntryPreview> _previewBundle(
    Map<String, Object?> bundle, {
    required FhirR4EncounterImportContext context,
    required Set<String> contextReasons,
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
        rawEntries.length > FhirR4EncounterImportPreview.maximumEntries) {
      reasons.add('fhir.bundle_entry_count_out_of_bounds');
      return const <FhirR4EncounterEntryPreview>[];
    }

    final output = <FhirR4EncounterEntryPreview>[];
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
      final rawFullUrl = entry['fullUrl'];
      if (entry.containsKey('fullUrl')) {
        final uri = rawFullUrl is String ? Uri.tryParse(rawFullUrl) : null;
        if (rawFullUrl is! String ||
            rawFullUrl.isEmpty ||
            uri == null ||
            !uri.hasScheme ||
            RegExp(r'\s').hasMatch(rawFullUrl)) {
          reasons.add('fhir.bundle_full_url_invalid');
        } else if (!fullUrls.add(rawFullUrl)) {
          reasons.add('fhir.bundle_full_url_duplicate');
        }
      }
      final resource = _map(entry['resource']);
      if (resource == null || resource['resourceType'] != 'Encounter') {
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
        _previewEncounter(
          resource,
          context: context,
          contextReasons: contextReasons,
          path: '$path.resource',
        ),
      );
    }
    return output;
  }

  FhirR4EncounterEntryPreview _previewEncounter(
    Map<String, Object?> resource, {
    required FhirR4EncounterImportContext context,
    required Set<String> contextReasons,
    String path = 'Encounter',
  }) {
    final reasons = <String>{...contextReasons};
    final unmapped = <String>{};
    _scan(
      resource,
      known: _resourceKeys,
      supported: _supportedResourceKeys,
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    if (resource['resourceType'] != 'Encounter') {
      reasons.add('fhir.resource_type_mismatch');
    }
    final id = resource['id'];
    if (resource.containsKey('id') &&
        (id is! String || !_matches(_resourceIdPattern, id))) {
      reasons.add('fhir.resource_id_invalid');
    }

    final rawStatus = resource['status'];
    String? status;
    if (rawStatus is! String || !_statuses.contains(rawStatus)) {
      reasons.add('fhir.status_invalid');
    } else {
      status = rawStatus;
      if (status == 'entered-in-error') reasons.add('fhir.entered_in_error');
    }

    final encounterClass = _previewClass(
      resource['class'],
      path: '$path.class',
      reasons: reasons,
      unmapped: unmapped,
    );
    if (encounterClass != null && encounterClass.code == null) {
      reasons.add('fhir.class_code_absent');
    }
    final subject = _map(resource['subject']);
    final rawReference = subject?['reference'];
    final patientMatched =
        rawReference is String &&
        rawReference == context.expectedPatientReference &&
        _matches(_patientReferencePattern, rawReference);
    if (!patientMatched) reasons.add('fhir.patient_reference_mismatch');
    if (subject != null) {
      _scan(
        subject,
        known: _subjectKeys,
        supported: const <String>{'reference'},
        path: '$path.subject',
        reasons: reasons,
        unmapped: unmapped,
      );
    }
    final period = resource.containsKey('period')
        ? _previewPeriod(
            resource['period'],
            path: '$path.period',
            reasons: reasons,
            unmapped: unmapped,
          )
        : (null, null);
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    return FhirR4EncounterEntryPreview(
      disposition: reasons.isEmpty && unmapped.isEmpty
          ? FhirR4EncounterDisposition.previewable
          : FhirR4EncounterDisposition.held,
      patientReferenceMatched: patientMatched,
      status: status,
      encounterClass: encounterClass,
      periodStart: period.$1,
      periodEnd: period.$2,
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  FhirR4EncounterClassPreview? _previewClass(
    Object? value, {
    required String path,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    final coding = _map(value);
    if (coding == null) {
      reasons.add('fhir.class_missing_or_invalid');
      return null;
    }
    _scan(
      coding,
      known: _codingKeys,
      supported: const <String>{'system', 'version', 'code', 'display'},
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    return FhirR4EncounterClassPreview(
      system: _optionalString(
        coding['system'],
        '$path.system',
        reasons,
        present: coding.containsKey('system'),
      ),
      version: _optionalString(
        coding['version'],
        '$path.version',
        reasons,
        present: coding.containsKey('version'),
      ),
      code: _optionalString(
        coding['code'],
        '$path.code',
        reasons,
        present: coding.containsKey('code'),
      ),
      display: _optionalString(
        coding['display'],
        '$path.display',
        reasons,
        present: coding.containsKey('display'),
      ),
    );
  }

  (FhirR4EncounterTimePreview?, FhirR4EncounterTimePreview?) _previewPeriod(
    Object? value, {
    required String path,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    final period = _map(value);
    if (period == null) {
      reasons.add('fhir.period_invalid');
      return (null, null);
    }
    _scan(
      period,
      known: _periodKeys,
      supported: const <String>{'start', 'end'},
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    final start = _dateTime(period['start'], '$path.start', reasons);
    final end = _dateTime(period['end'], '$path.end', reasons);
    if (period.containsKey('start') && period['start'] == null ||
        period.containsKey('end') && period['end'] == null) {
      reasons.add('fhir.datetime_invalid');
    }
    if (period.isEmpty) reasons.add('fhir.period_empty');
    return (start, end);
  }

  FhirR4EncounterTimePreview? _dateTime(
    Object? value,
    String path,
    Set<String> reasons,
  ) {
    if (value == null) return null;
    if (value is! String || !_validDateTime(value)) {
      reasons.add('fhir.datetime_invalid');
      return null;
    }
    return FhirR4EncounterTimePreview(value);
  }

  bool _validDateTime(String value) {
    final match = _dateTimePattern.firstMatch(value);
    if (match == null) return false;
    final month = match[2] == null ? 1 : int.parse(match[2]!);
    final day = match[3] == null ? 1 : int.parse(match[3]!);
    final hour = match[4] == null ? 0 : int.parse(match[4]!);
    final minute = match[5] == null ? 0 : int.parse(match[5]!);
    final second = match[6] == null ? 0 : int.parse(match[6]!);
    final year = int.parse(match[1]!);
    if (year < 1 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return false;
    }
    if (match[4] != null && match[8] == null) return false;
    final offsetHour = match[10] == null ? 0 : int.parse(match[10]!);
    final offsetMinute = match[11] == null ? 0 : int.parse(match[11]!);
    return offsetHour <= 14 &&
        offsetMinute <= 59 &&
        (offsetHour < 14 || offsetMinute == 0);
  }

  void _validateContext(
    FhirR4EncounterImportContext context,
    Set<String> reasons,
  ) {
    if (context.fhirVersion !=
        FhirR4EncounterImportPreview.supportedFhirVersion) {
      reasons.add('fhir.release_unsupported');
    }
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(context.jurisdiction)) {
      reasons.add('fhir.jurisdiction_invalid');
    }
    if (!_matches(_patientReferencePattern, context.expectedPatientReference)) {
      reasons.add('fhir.patient_context_invalid');
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
      if (supported.contains(key)) continue;
      unmapped.add('$path.$key');
      reasons.add(
        known.contains(key) ? 'fhir.unmapped_fields' : 'fhir.unknown_field',
      );
    }
  }

  String? _optionalString(
    Object? value,
    String path,
    Set<String> reasons, {
    required bool present,
  }) {
    if (value == null) {
      if (present) reasons.add('fhir.value_invalid');
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      reasons.add('fhir.value_invalid');
      return null;
    }
    return value;
  }

  static Map<String, Object?>? _map(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static bool _matches(String pattern, String value) =>
      RegExp(pattern).hasMatch(value);
}
