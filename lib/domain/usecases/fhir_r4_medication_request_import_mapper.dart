import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/fhir_r4_medication_request_import_preview.dart';

/// Offline, bounded FHIR R4 MedicationRequest preview.
///
/// This is a request projection, not evidence of dispensing, administration,
/// use, adherence, or prescription validity. It does not resolve references,
/// interpret dosage, persist data, or call the rule engine.
final class FhirR4MedicationRequestImportMapper {
  const FhirR4MedicationRequestImportMapper();

  static const _requestKeys = <String>{
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
    'statusReason',
    'intent',
    'category',
    'priority',
    'doNotPerform',
    'reportedBoolean',
    'reportedReference',
    'medicationCodeableConcept',
    'medicationReference',
    'subject',
    'encounter',
    'supportingInformation',
    'authoredOn',
    'requester',
    'performer',
    'performerType',
    'recorder',
    'reasonCode',
    'reasonReference',
    'instantiatesCanonical',
    'instantiatesUri',
    'basedOn',
    'groupIdentifier',
    'courseOfTherapyType',
    'insurance',
    'note',
    'dosageInstruction',
    'dispenseRequest',
    'substitution',
    'detectedIssue',
    'eventHistory',
  };
  static const _supportedRequestKeys = <String>{
    'resourceType',
    'id',
    'meta',
    'status',
    'intent',
    'medicationCodeableConcept',
    'medicationReference',
    'subject',
    'authoredOn',
    'requester',
    'dosageInstruction',
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
  static const _supportedBundleKeys = {'resourceType', 'meta', 'type', 'entry'};
  static const _metaKeys = {'versionId', 'source', 'lastUpdated'};
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
  static const _statuses = <String>{
    'active',
    'on-hold',
    'cancelled',
    'completed',
    'entered-in-error',
    'stopped',
    'draft',
    'unknown',
  };
  static const _intents = <String>{
    'proposal',
    'plan',
    'order',
    'original-order',
    'reflex-order',
    'filler-order',
    'instance-order',
    'option',
  };
  static const _instantPattern =
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static const _resourceIdPattern = r'^[A-Za-z0-9.-]{1,64}$';

  FhirR4MedicationRequestImportPreview previewJson({
    required String input,
    required FhirR4MedicationRequestPreviewContext context,
  }) {
    if (utf8.encode(input).length >
        FhirR4MedicationRequestImportPreview.maximumInputBytes) {
      throw const FormatException('FHIR input exceeds the byte limit.');
    }
    final root = _map(jsonDecode(input));
    if (root == null) {
      throw const FormatException('FHIR input must be a JSON object.');
    }

    final reasons = <String>{};
    final unmapped = <String>{};
    _validateContext(context, reasons);
    final List<FhirR4MedicationRequestEntryPreview> entries;
    final String containerType;
    if (root['resourceType'] == 'MedicationRequest') {
      containerType = 'MedicationRequest';
      entries = <FhirR4MedicationRequestEntryPreview>[
        _previewRequest(root, context: context, path: 'MedicationRequest'),
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
        'FHIR input must be a MedicationRequest or collection Bundle.',
      );
    }

    return FhirR4MedicationRequestImportPreview(
      context: context,
      inputSha256: sha256.convert(utf8.encode(input)).toString(),
      containerType: containerType,
      entries: List.unmodifiable(entries),
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  List<FhirR4MedicationRequestEntryPreview> _previewBundle(
    Map<String, Object?> bundle, {
    required FhirR4MedicationRequestPreviewContext context,
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
    if (bundle['type'] != 'collection') {
      reasons.add('fhir.bundle_type_not_collection');
    }
    if (bundle.containsKey('meta')) {
      final meta = _map(bundle['meta']);
      if (meta == null) {
        reasons.add('fhir.meta_invalid');
      } else {
        _addUnknownKeys(meta, _metaKeys, 'Bundle.meta', unmapped);
        _addUnprojectedKnownKeys(
          meta,
          _metaKeys,
          const <String>{},
          'Bundle.meta',
          unmapped,
        );
      }
    }
    final rawEntries = bundle['entry'];
    if (rawEntries is! List ||
        rawEntries.isEmpty ||
        rawEntries.length >
            FhirR4MedicationRequestImportPreview.maximumEntries) {
      reasons.add('fhir.bundle_entry_count_out_of_bounds');
      return const <FhirR4MedicationRequestEntryPreview>[];
    }

    final output = <FhirR4MedicationRequestEntryPreview>[];
    final fullUrls = <String>{};
    final resourceIds = <String>{};
    for (var index = 0; index < rawEntries.length; index++) {
      final path = 'Bundle.entry[$index]';
      final entry = _map(rawEntries[index]);
      if (entry == null) {
        reasons.add('fhir.bundle_entry_invalid');
        continue;
      }
      _addUnknownKeys(entry, const {'fullUrl', 'resource'}, path, unmapped);
      String? fullUrl;
      if (entry.containsKey('fullUrl')) {
        final rawFullUrl = entry['fullUrl'];
        final parsed = rawFullUrl is String ? Uri.tryParse(rawFullUrl) : null;
        if (rawFullUrl is! String ||
            !_validText(rawFullUrl, 2048) ||
            parsed == null ||
            !parsed.hasScheme ||
            RegExp(r'\s').hasMatch(rawFullUrl)) {
          reasons.add('fhir.bundle_full_url_invalid');
        } else if (!fullUrls.add(rawFullUrl)) {
          reasons.add('fhir.bundle_full_url_duplicate');
        } else {
          fullUrl = rawFullUrl;
        }
      }
      final resource = _map(entry['resource']);
      if (resource == null || resource['resourceType'] != 'MedicationRequest') {
        reasons.add('fhir.bundle_resource_unsupported');
        continue;
      }
      final preview = _previewRequest(
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
    if (output.length != rawEntries.length) {
      reasons.add('fhir.bundle_entry_missing_resource');
    }
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    return output;
  }

  FhirR4MedicationRequestEntryPreview _previewRequest(
    Map<String, Object?> resource, {
    required FhirR4MedicationRequestPreviewContext context,
    required String path,
    String? bundleEntryFullUrl,
  }) {
    final reasons = <String>{};
    final unmapped = <String>{};
    _addUnknownKeys(resource, _requestKeys, path, unmapped);
    _addUnprojectedKnownKeys(
      resource,
      _requestKeys,
      _supportedRequestKeys,
      path,
      unmapped,
    );
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
    FhirR4MedicationRequestTimePreview? metaLastUpdated;
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
    if (status == null || !_statuses.contains(status)) {
      reasons.add('fhir.status_missing_or_unsupported');
    } else if (status == 'entered-in-error') {
      // FHIR marks this status as a modifier: the request must not be treated
      // as valid, so the preview remains held for explicit review.
      reasons.add('fhir.status_entered_in_error');
    }
    final intent = _readOptionalText(
      resource,
      'intent',
      '$path.intent',
      reasons,
    );
    if (intent == null || !_intents.contains(intent)) {
      reasons.add('fhir.intent_missing_or_unsupported');
    }

    final hasConcept = resource.containsKey('medicationCodeableConcept');
    final hasReference = resource.containsKey('medicationReference');
    if (hasConcept == hasReference) {
      reasons.add('fhir.medication_choice_invalid');
    }
    String? medicationText;
    final codings = <FhirR4MedicationRequestCodingPreview>[];
    String? medicationReference;
    String? medicationReferenceDisplay;
    if (hasConcept) {
      final concept = _readConcept(
        resource['medicationCodeableConcept'],
        '$path.medicationCodeableConcept',
        reasons,
        unmapped,
      );
      medicationText = concept.text;
      codings.addAll(concept.codings);
      if (concept.text == null && concept.codings.isEmpty) {
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
    final authoredOn = _readTime(
      resource,
      'authoredOn',
      '$path.authoredOn',
      reasons,
    );
    final requester = resource.containsKey('requester')
        ? _readReference(
            resource['requester'],
            '$path.requester',
            reasons,
            unmapped,
          )
        : const _ReferenceResult();
    final dosageTexts = _readDosageTexts(
      resource['dosageInstruction'],
      '$path.dosageInstruction',
      reasons,
      unmapped,
      present: resource.containsKey('dosageInstruction'),
    );
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    final sortedReasons = reasons.toList()..sort();
    final sortedUnmapped = unmapped.toList()..sort();
    return FhirR4MedicationRequestEntryPreview(
      disposition: sortedReasons.isEmpty
          ? FhirR4MedicationRequestPreviewDisposition.previewable
          : FhirR4MedicationRequestPreviewDisposition.held,
      status: status,
      intent: intent,
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
      authoredOn: authoredOn,
      requesterReference: requester.reference,
      requesterDisplay: requester.display,
      dosageTexts: List.unmodifiable(dosageTexts),
      reasonCodes: List.unmodifiable(sortedReasons),
      unmappedPaths: List.unmodifiable(sortedUnmapped),
    );
  }

  void _validateContext(
    FhirR4MedicationRequestPreviewContext context,
    Set<String> reasons,
  ) {
    if (context.fhirVersion !=
        FhirR4MedicationRequestImportPreview.supportedFhirVersion) {
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
    final codings = <FhirR4MedicationRequestCodingPreview>[];
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
          final selected = coding['userSelected'];
          if (selected != null && selected is! bool) {
            reasons.add('fhir.coding_user_selected_invalid');
          }
          codings.add(
            FhirR4MedicationRequestCodingPreview(
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
              userSelected: selected is bool ? selected : null,
            ),
          );
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
    if (raw is! List || raw.length > 32) {
      reasons.add('fhir.dosage_instruction_shape_invalid');
      return const <String>[];
    }
    final result = <String>[];
    for (var index = 0; index < raw.length; index++) {
      final itemPath = '$path[$index]';
      final dosage = _map(raw[index]);
      if (dosage == null) {
        reasons.add('fhir.dosage_instruction_invalid');
        continue;
      }
      _addUnknownKeys(dosage, _dosageTextKeys, itemPath, unmapped);
      final text = _readOptionalText(dosage, 'text', '$itemPath.text', reasons);
      if (text != null) result.add(text);
    }
    return result;
  }

  FhirR4MedicationRequestTimePreview? _readTime(
    Map<String, Object?> source,
    String key,
    String path,
    Set<String> reasons, {
    bool requireInstant = false,
  }) {
    if (!source.containsKey(key)) return null;
    final raw = source[key];
    if (raw is! String || raw.length > 80 || raw.trim() != raw) {
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
    return parsed;
  }

  FhirR4MedicationRequestTimePreview? _parseDateTime(String value) {
    final year = int.tryParse(value);
    if (year != null && value.length == 4 && year >= 1 && year <= 9999) {
      return FhirR4MedicationRequestTimePreview(
        lexical: value,
        precision: FhirR4MedicationRequestTimePrecision.year,
      );
    }
    final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
    if (month != null) {
      final monthNumber = int.parse(month.group(2)!);
      if (monthNumber < 1 || monthNumber > 12) return null;
      return FhirR4MedicationRequestTimePreview(
        lexical: value,
        precision: FhirR4MedicationRequestTimePrecision.month,
      );
    }
    final day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (day != null) {
      final yearNumber = int.parse(day.group(1)!);
      final monthNumber = int.parse(day.group(2)!);
      final dayNumber = int.parse(day.group(3)!);
      final date = DateTime.utc(yearNumber, monthNumber, dayNumber);
      if (date.year != yearNumber ||
          date.month != monthNumber ||
          date.day != dayNumber) {
        return null;
      }
      return FhirR4MedicationRequestTimePreview(
        lexical: value,
        precision: FhirR4MedicationRequestTimePrecision.day,
      );
    }
    final instant = RegExp(_instantPattern).firstMatch(value);
    if (instant == null) return null;
    final y = int.parse(instant.group(1)!);
    final m = int.parse(instant.group(2)!);
    final d = int.parse(instant.group(3)!);
    final hour = int.parse(instant.group(4)!);
    final minute = int.parse(instant.group(5)!);
    final second = int.parse(instant.group(6)!);
    final zoneHour = int.tryParse(instant.group(10) ?? '0') ?? 0;
    final zoneMinute = int.tryParse(instant.group(11) ?? '0') ?? 0;
    final fraction = instant.group(7);
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
    return FhirR4MedicationRequestTimePreview(
      lexical: value,
      utc: parsed.toUtc(),
      precision: fraction == null
          ? FhirR4MedicationRequestTimePrecision.second
          : FhirR4MedicationRequestTimePrecision.fractionalSecond,
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
    Set<String> known,
    String path,
    Set<String> unmapped,
  ) {
    for (final key in source.keys) {
      if (!known.contains(key)) unmapped.add('$path.$key');
    }
  }

  void _addUnprojectedKnownKeys(
    Map<String, Object?> source,
    Set<String> known,
    Set<String> projected,
    String path,
    Set<String> unmapped,
  ) {
    for (final key in known) {
      if (source.containsKey(key) && !projected.contains(key)) {
        unmapped.add('$path.$key');
      }
    }
  }

  Map<String, Object?>? _map(Object? raw) {
    if (raw is! Map) return null;
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) return null;
      result[entry.key as String] = entry.value;
    }
    return result;
  }
}

final class _ConceptResult {
  const _ConceptResult({this.text, this.codings = const []});

  final String? text;
  final List<FhirR4MedicationRequestCodingPreview> codings;
}

final class _ReferenceResult {
  const _ReferenceResult({this.reference, this.display});

  final String? reference;
  final String? display;
}
