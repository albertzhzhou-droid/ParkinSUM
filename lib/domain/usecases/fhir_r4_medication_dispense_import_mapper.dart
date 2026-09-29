import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/fhir_r4_medication_dispense_import_preview.dart';

/// Bounded offline preview of a FHIR R4 MedicationDispense source.
///
/// This mapper retains source claims only. It does not authenticate the
/// source, resolve references or terminology, reconcile prescriptions, infer
/// pickup/use, persist data, or call a decision-support algorithm.
final class FhirR4MedicationDispenseImportMapper {
  const FhirR4MedicationDispenseImportMapper();

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
    'partOf',
    'status',
    'statusReasonCodeableConcept',
    'statusReasonReference',
    'category',
    'medicationCodeableConcept',
    'medicationReference',
    'subject',
    'context',
    'supportingInformation',
    'performer',
    'location',
    'authorizingPrescription',
    'type',
    'quantity',
    'daysSupply',
    'whenPrepared',
    'whenHandedOver',
    'destination',
    'receiver',
    'note',
    'dosageInstruction',
    'substitution',
    'detectedIssue',
    'eventHistory',
  };
  static const _supportedResourceKeys = <String>{
    'resourceType',
    'id',
    'meta',
    'status',
    'statusReasonCodeableConcept',
    'category',
    'medicationCodeableConcept',
    'subject',
    'type',
    'quantity',
    'daysSupply',
    'whenPrepared',
    'whenHandedOver',
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
  static const _quantityKeys = <String>{
    'id',
    'extension',
    'value',
    'comparator',
    'unit',
    'system',
    'code',
  };
  static const _statuses = <String>{
    'preparation',
    'in-progress',
    'cancelled',
    'on-hold',
    'completed',
    'entered-in-error',
    'stopped',
    'declined',
    'unknown',
  };
  static const _resourceIdPattern = r'^[A-Za-z0-9.-]{1,64}$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static const _dateTimePattern =
      r'^(\d{4})(?:-(\d{2})(?:-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))?)?)?)?$';

  FhirR4MedicationDispenseImportPreview previewJson({
    required String input,
    required FhirR4MedicationDispenseImportContext context,
  }) {
    final bytes = utf8.encode(input);
    if (bytes.length >
        FhirR4MedicationDispenseImportPreview.maximumInputBytes) {
      throw const FormatException('FHIR input exceeds the byte limit.');
    }
    final root = _map(jsonDecode(input));
    if (root == null) {
      throw const FormatException('FHIR input must be a JSON object.');
    }
    final reasons = <String>{};
    final unmapped = <String>{};
    _validateContext(context, reasons);
    final List<FhirR4MedicationDispenseImportEntryPreview> entries;
    final String containerType;
    if (root['resourceType'] == 'MedicationDispense') {
      containerType = 'MedicationDispense';
      entries = <FhirR4MedicationDispenseImportEntryPreview>[
        _previewDispense(root, context: context, path: 'MedicationDispense'),
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
        'FHIR input must be a MedicationDispense or collection Bundle.',
      );
    }
    for (final entry in entries) {
      reasons.addAll(entry.reasonCodes);
      unmapped.addAll(entry.unmappedPaths);
    }
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    return FhirR4MedicationDispenseImportPreview(
      context: context,
      inputSha256: sha256.convert(bytes).toString(),
      containerType: containerType,
      entries: List.unmodifiable(entries),
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  List<FhirR4MedicationDispenseImportEntryPreview> _previewBundle(
    Map<String, Object?> bundle, {
    required FhirR4MedicationDispenseImportContext context,
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
            FhirR4MedicationDispenseImportPreview.maximumEntries) {
      reasons.add('fhir.bundle_entry_count_out_of_bounds');
      return const <FhirR4MedicationDispenseImportEntryPreview>[];
    }
    final output = <FhirR4MedicationDispenseImportEntryPreview>[];
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
        final raw = entry['fullUrl'];
        final uri = raw is String ? Uri.tryParse(raw) : null;
        if (raw is! String ||
            raw.isEmpty ||
            uri == null ||
            !uri.hasScheme ||
            RegExp(r'\s').hasMatch(raw)) {
          reasons.add('fhir.bundle_full_url_invalid');
        } else if (!fullUrls.add(raw)) {
          reasons.add('fhir.bundle_full_url_duplicate');
        } else {
          fullUrl = raw;
        }
      }
      final resource = _map(entry['resource']);
      if (resource == null ||
          resource['resourceType'] != 'MedicationDispense') {
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
        _previewDispense(
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

  FhirR4MedicationDispenseImportEntryPreview _previewDispense(
    Map<String, Object?> resource, {
    required FhirR4MedicationDispenseImportContext context,
    required String path,
    String? bundleEntryFullUrl,
  }) {
    final reasons = <String>{};
    final unmapped = <String>{};
    _validateContext(context, reasons);
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
    var medicationCodings = const <FhirR4MedicationDispenseCodingPreview>[];
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

    final statusReasonConceptPresent = resource.containsKey(
      'statusReasonCodeableConcept',
    );
    final statusReasonReferencePresent = resource.containsKey(
      'statusReasonReference',
    );
    if (statusReasonConceptPresent && statusReasonReferencePresent) {
      reasons.add('fhir.status_reason_choice_invalid');
    }
    final statusReason = statusReasonConceptPresent
        ? _readConcept(
            resource['statusReasonCodeableConcept'],
            '$path.statusReasonCodeableConcept',
            reasons,
            unmapped,
          )
        : null;

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

    final category = resource.containsKey('category')
        ? _readConcept(
            resource['category'],
            '$path.category',
            reasons,
            unmapped,
          )
        : null;
    final type = resource.containsKey('type')
        ? _readConcept(resource['type'], '$path.type', reasons, unmapped)
        : null;
    final quantity = _readQuantity(
      resource,
      'quantity',
      '$path.quantity',
      reasons,
      unmapped,
    );
    final daysSupply = _readQuantity(
      resource,
      'daysSupply',
      '$path.daysSupply',
      reasons,
      unmapped,
    );
    final whenPrepared = _readTime(
      resource,
      'whenPrepared',
      '$path.whenPrepared',
      reasons,
    );
    final whenHandedOver = _readTime(
      resource,
      'whenHandedOver',
      '$path.whenHandedOver',
      reasons,
    );
    if (whenPrepared?.utc != null &&
        whenHandedOver?.utc != null &&
        _instantIsBefore(whenHandedOver!.lexical, whenPrepared!.lexical)) {
      reasons.add('fhir.handed_over_before_prepared');
    }
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');

    final sortedReasons = reasons.toList()..sort();
    final sortedUnmapped = unmapped.toList()..sort();
    return FhirR4MedicationDispenseImportEntryPreview(
      disposition: sortedReasons.isEmpty
          ? FhirR4MedicationDispenseDisposition.previewable
          : FhirR4MedicationDispenseDisposition.held,
      status: status,
      patientReferenceMatched: patientMatched,
      resourceId: id,
      bundleEntryFullUrl: bundleEntryFullUrl,
      resourceVersionId: meta.versionId,
      metaSource: meta.source,
      metaLastUpdated: meta.lastUpdated,
      medicationConceptText: medicationText,
      medicationCodings: List.unmodifiable(medicationCodings),
      subjectReference: subjectReference,
      statusReason: statusReason,
      category: category,
      type: type,
      quantity: quantity,
      daysSupply: daysSupply,
      whenPrepared: whenPrepared,
      whenHandedOver: whenHandedOver,
      reasonCodes: List.unmodifiable(sortedReasons),
      unmappedPaths: List.unmodifiable(sortedUnmapped),
    );
  }

  FhirR4MedicationDispenseConceptPreview? _readConcept(
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
    final codings = <FhirR4MedicationDispenseCodingPreview>[];
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
            FhirR4MedicationDispenseCodingPreview(
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
    return FhirR4MedicationDispenseConceptPreview(
      codings: List.unmodifiable(codings),
      text: text,
    );
  }

  FhirR4MedicationDispenseQuantityPreview? _readQuantity(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (!parent.containsKey(key)) return null;
    final quantity = _map(parent[key]);
    if (quantity == null) {
      reasons.add('fhir.quantity_invalid');
      return null;
    }
    _scan(
      quantity,
      known: _quantityKeys,
      supported: const <String>{'value', 'unit', 'system', 'code'},
      path: path,
      reasons: reasons,
      unmapped: unmapped,
    );
    num? value;
    if (quantity.containsKey('value')) {
      final raw = quantity['value'];
      if (raw is! num || !raw.isFinite) {
        reasons.add('fhir.quantity_value_invalid');
      } else {
        value = raw;
      }
    }
    final unit = _optionalText(quantity, 'unit', '$path.unit', reasons, 128);
    final system = _optionalText(
      quantity,
      'system',
      '$path.system',
      reasons,
      2048,
    );
    if (system != null && !_isAbsoluteUri(system)) {
      reasons.add('fhir.quantity_system_invalid');
    }
    final code = _optionalText(quantity, 'code', '$path.code', reasons, 128);
    if (value == null && unit == null && system == null && code == null) {
      reasons.add('fhir.quantity_empty');
    }
    return FhirR4MedicationDispenseQuantityPreview(
      value: value,
      unit: unit,
      system: system,
      code: code,
    );
  }

  ({
    String? versionId,
    String? source,
    FhirR4MedicationDispenseTimePreview? lastUpdated,
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

  FhirR4MedicationDispenseTimePreview? _readTime(
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
    final offsetHour = match.group(10) == null
        ? null
        : int.parse(match.group(10)!);
    final offsetMinute = match.group(11) == null
        ? null
        : int.parse(match.group(11)!);
    if (year < 1 ||
        (month != null && (month < 1 || month > 12)) ||
        (day != null && (day < 1 || day > 31)) ||
        (hour != null && (hour > 23 || minute! > 59 || second! > 59)) ||
        (hour != null && zone == null) ||
        (offsetHour != null &&
            (offsetHour > 14 ||
                offsetMinute! > 59 ||
                (offsetHour == 14 && offsetMinute != 0))) ||
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
              ? FhirR4MedicationDispenseTimePrecision.second
              : FhirR4MedicationDispenseTimePrecision.fractionalSecond)
        : day != null
        ? FhirR4MedicationDispenseTimePrecision.day
        : month != null
        ? FhirR4MedicationDispenseTimePrecision.month
        : FhirR4MedicationDispenseTimePrecision.year;
    return FhirR4MedicationDispenseTimePreview(
      lexical: value,
      precision: precision,
      utc: utc,
    );
  }

  /// Compares arbitrary FHIR fractional-second precision without truncating it
  /// to Dart DateTime's microsecond resolution.
  bool _instantIsBefore(String first, String second) {
    final firstMatch = RegExp(_dateTimePattern).firstMatch(first)!;
    final secondMatch = RegExp(_dateTimePattern).firstMatch(second)!;
    int epochSeconds(Match match) {
      final localSeconds =
          DateTime.utc(
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
            int.parse(match.group(3)!),
            int.parse(match.group(4)!),
            int.parse(match.group(5)!),
            int.parse(match.group(6)!),
          ).millisecondsSinceEpoch ~/
          1000;
      if (match.group(8) == 'Z') return localSeconds;
      final sign = match.group(9) == '+' ? 1 : -1;
      final offsetSeconds =
          (int.parse(match.group(10)!) * 60 + int.parse(match.group(11)!)) *
          60 *
          sign;
      return localSeconds - offsetSeconds;
    }

    final firstSeconds = epochSeconds(firstMatch);
    final secondSeconds = epochSeconds(secondMatch);
    if (firstSeconds != secondSeconds) return firstSeconds < secondSeconds;
    final firstFraction = (firstMatch.group(7) ?? '').replaceFirst(
      RegExp(r'0+$'),
      '',
    );
    final secondFraction = (secondMatch.group(7) ?? '').replaceFirst(
      RegExp(r'0+$'),
      '',
    );
    final scale = firstFraction.length > secondFraction.length
        ? firstFraction.length
        : secondFraction.length;
    return firstFraction
            .padRight(scale, '0')
            .compareTo(secondFraction.padRight(scale, '0')) <
        0;
  }

  void _validateContext(
    FhirR4MedicationDispenseImportContext context,
    Set<String> reasons,
  ) {
    if (context.fhirVersion !=
        FhirR4MedicationDispenseImportPreview.supportedFhirVersion) {
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
