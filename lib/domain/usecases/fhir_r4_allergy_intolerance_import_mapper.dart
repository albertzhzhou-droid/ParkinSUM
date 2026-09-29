import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/fhir_r4_allergy_intolerance_import_preview.dart';

/// Offline, bounded FHIR R4 AllergyIntolerance projection.
///
/// It copies only the explicitly supported source fields. It does not resolve
/// terminology or identity, infer allergy conclusions, persist input, or call
/// the CDSS rule engine.
final class FhirR4AllergyIntoleranceImportMapper {
  const FhirR4AllergyIntoleranceImportMapper();

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
    'clinicalStatus',
    'verificationStatus',
    'type',
    'category',
    'criticality',
    'code',
    'patient',
    'encounter',
    'onsetDateTime',
    'onsetAge',
    'onsetPeriod',
    'onsetRange',
    'onsetString',
    'recordedDate',
    'recorder',
    'asserter',
    'lastOccurrence',
    'note',
    'reaction',
  };
  static const _supportedResourceKeys = <String>{
    'resourceType',
    'id',
    'meta',
    'clinicalStatus',
    'verificationStatus',
    'type',
    'category',
    'criticality',
    'code',
    'patient',
    'onsetDateTime',
    'recordedDate',
    'lastOccurrence',
    'reaction',
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
  static const _supportedBundleKeys = <String>{
    'resourceType',
    'meta',
    'type',
    'entry',
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
  static const _codingKeys = <String>{
    'id',
    'extension',
    'system',
    'version',
    'code',
    'display',
    'userSelected',
  };
  static const _reactionKeys = <String>{
    'id',
    'extension',
    'modifierExtension',
    'substance',
    'manifestation',
    'description',
    'onset',
    'severity',
    'exposureRoute',
    'note',
  };

  static const _clinicalSystem =
      'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical';
  static const _verificationSystem =
      'http://terminology.hl7.org/CodeSystem/allergyintolerance-verification';
  static const _clinicalCodes = <String>{'active', 'inactive', 'resolved'};
  static const _verificationCodes = <String>{
    'unconfirmed',
    'confirmed',
    'refuted',
    'entered-in-error',
  };
  static const _types = <String>{'allergy', 'intolerance'};
  static const _categories = <String>{
    'food',
    'medication',
    'environment',
    'biologic',
  };
  static const _criticalities = <String>{'low', 'high', 'unable-to-assess'};
  static const _reactionSeverities = <String>{'mild', 'moderate', 'severe'};
  static const _resourceIdPattern = r'^[A-Za-z0-9.-]{1,64}$';
  static const _patientReferencePattern =
      r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
  static const _datePattern =
      r'^(\d{4})(?:-(\d{2})(?:-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))?)?)?)?$';
  static const _instantPattern =
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):(\d{2}))$';
  static const _absoluteUriPattern = r'^[A-Za-z][A-Za-z0-9+.-]*:';

  FhirR4AllergyIntoleranceImportPreview previewJson({
    required String input,
    required FhirR4AllergyPreviewContext context,
  }) {
    if (utf8.encode(input).length >
        FhirR4AllergyIntoleranceImportPreview.maximumInputBytes) {
      throw const FormatException('FHIR input exceeds the byte limit.');
    }
    final root = _map(jsonDecode(input));
    if (root == null) {
      throw const FormatException('FHIR input must be a JSON object.');
    }

    final reasons = <String>{};
    final unmapped = <String>{};
    _validateContext(context, reasons);
    final List<FhirR4AllergyIntoleranceEntryPreview> entries;
    final String containerType;
    if (root['resourceType'] == 'AllergyIntolerance') {
      containerType = 'AllergyIntolerance';
      entries = <FhirR4AllergyIntoleranceEntryPreview>[
        _previewResource(root, context: context, path: 'AllergyIntolerance'),
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
        'FHIR input must be an AllergyIntolerance or collection Bundle.',
      );
    }
    for (final entry in entries) {
      unmapped.addAll(entry.unmappedPaths);
    }

    return FhirR4AllergyIntoleranceImportPreview(
      context: context,
      inputSha256: sha256.convert(utf8.encode(input)).toString(),
      containerType: containerType,
      entries: List.unmodifiable(entries),
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
    );
  }

  List<FhirR4AllergyIntoleranceEntryPreview> _previewBundle(
    Map<String, Object?> bundle, {
    required FhirR4AllergyPreviewContext context,
    required Set<String> reasons,
    required Set<String> unmapped,
  }) {
    _scanFields(
      bundle,
      known: _bundleKeys,
      supported: _supportedBundleKeys,
      path: 'Bundle',
      unmapped: unmapped,
    );
    if (bundle['type'] != 'collection') {
      reasons.add('fhir.bundle_type_not_collection');
    }
    _readMeta(
      bundle,
      path: 'Bundle.meta',
      unmapped: unmapped,
      reasons: reasons,
    );

    final rawEntries = bundle['entry'];
    if (rawEntries is! List ||
        rawEntries.isEmpty ||
        rawEntries.length >
            FhirR4AllergyIntoleranceImportPreview.maximumEntries) {
      reasons.add('fhir.bundle_entry_count_out_of_bounds');
      return const <FhirR4AllergyIntoleranceEntryPreview>[];
    }

    final output = <FhirR4AllergyIntoleranceEntryPreview>[];
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
      );
      if (entry.containsKey('fullUrl')) {
        final fullUrl = entry['fullUrl'];
        if (fullUrl is! String ||
            !_validText(fullUrl, 2048) ||
            !_isAbsoluteUri(fullUrl)) {
          reasons.add('fhir.bundle_full_url_invalid');
        } else if (!fullUrls.add(fullUrl)) {
          reasons.add('fhir.bundle_full_url_duplicate');
        }
      }
      final resource = _map(entry['resource']);
      if (resource == null ||
          resource['resourceType'] != 'AllergyIntolerance') {
        reasons.add('fhir.bundle_resource_unsupported');
        continue;
      }
      final preview = _previewResource(
        resource,
        context: context,
        path: '$path.resource',
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

  FhirR4AllergyIntoleranceEntryPreview _previewResource(
    Map<String, Object?> resource, {
    required FhirR4AllergyPreviewContext context,
    required String path,
  }) {
    final reasons = <String>{};
    final unmapped = <String>{};
    _scanFields(
      resource,
      known: _resourceKeys,
      supported: _supportedResourceKeys,
      path: path,
      unmapped: unmapped,
    );

    final resourceId = _optionalText(
      resource,
      'id',
      '$path.id',
      reasons,
      maxLength: 64,
    );
    if (resourceId != null &&
        !RegExp(_resourceIdPattern).hasMatch(resourceId)) {
      reasons.add('fhir.resource_id_invalid');
    }
    final meta = _readMeta(
      resource,
      path: '$path.meta',
      unmapped: unmapped,
      reasons: reasons,
    );

    final patient = _map(resource['patient']);
    String? patientReference;
    var patientReferenceMatched = false;
    if (patient == null) {
      reasons.add('fhir.patient_reference_missing_or_invalid');
    } else {
      _scanFields(
        patient,
        known: _referenceKeys,
        supported: const {'reference'},
        path: '$path.patient',
        unmapped: unmapped,
      );
      patientReference = _optionalText(
        patient,
        'reference',
        '$path.patient.reference',
        reasons,
        maxLength: 2048,
      );
      if (patientReference == null ||
          !RegExp(_patientReferencePattern).hasMatch(patientReference)) {
        reasons.add('fhir.patient_reference_missing_or_invalid');
      } else {
        patientReferenceMatched =
            RegExp(
              _patientReferencePattern,
            ).hasMatch(context.expectedPatientReference) &&
            patientReference == context.expectedPatientReference;
        if (!patientReferenceMatched) {
          reasons.add('fhir.patient_reference_mismatch');
        }
      }
    }

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
    final clinicalCode = _requiredBoundCode(
      clinicalStatus,
      system: _clinicalSystem,
      allowed: _clinicalCodes,
    );
    final verificationCode = _requiredBoundCode(
      verificationStatus,
      system: _verificationSystem,
      allowed: _verificationCodes,
    );
    if (resource.containsKey('clinicalStatus') && clinicalCode == null) {
      reasons.add('fhir.clinical_status_binding_invalid');
    }
    if (resource.containsKey('verificationStatus') &&
        verificationCode == null) {
      reasons.add('fhir.verification_status_binding_invalid');
    }
    final enteredInError = verificationCode == 'entered-in-error';
    if (!enteredInError && clinicalStatus == null) {
      reasons.add('fhir.clinical_status_required');
    }
    if (enteredInError) {
      reasons.add('fhir.verification_entered_in_error');
      if (resource.containsKey('clinicalStatus')) {
        reasons.add('fhir.entered_in_error_clinical_status_forbidden');
      }
    }

    final type = _optionalText(
      resource,
      'type',
      '$path.type',
      reasons,
      maxLength: 32,
    );
    if (type != null && !_types.contains(type)) {
      reasons.add('fhir.type_code_unsupported');
    }
    final category = _readCodeList(
      resource,
      'category',
      reasons,
      allowed: _categories,
      mayBeEmpty: true,
    );
    final criticality = _optionalText(
      resource,
      'criticality',
      '$path.criticality',
      reasons,
      maxLength: 32,
    );
    if (criticality != null && !_criticalities.contains(criticality)) {
      reasons.add('fhir.criticality_code_unsupported');
    }
    final code = _readConcept(
      resource,
      'code',
      '$path.code',
      reasons,
      unmapped,
    );

    final onsetChoiceKeys = const <String>{
      'onsetDateTime',
      'onsetAge',
      'onsetPeriod',
      'onsetRange',
      'onsetString',
    }.where(resource.containsKey).length;
    if (onsetChoiceKeys > 1) reasons.add('fhir.onset_choice_conflict');
    final onset = _readDateTime(
      resource,
      'onsetDateTime',
      '$path.onsetDateTime',
      reasons,
    );
    final recordedDate = _readDateTime(
      resource,
      'recordedDate',
      '$path.recordedDate',
      reasons,
    );
    final lastOccurrence = _readDateTime(
      resource,
      'lastOccurrence',
      '$path.lastOccurrence',
      reasons,
    );

    final reactions = _readReactions(resource, path, reasons, unmapped);
    if (unmapped.isNotEmpty) reasons.add('fhir.unmapped_fields');
    return FhirR4AllergyIntoleranceEntryPreview(
      disposition: reasons.isEmpty
          ? FhirR4AllergyPreviewDisposition.previewable
          : FhirR4AllergyPreviewDisposition.held,
      reasonCodes: List.unmodifiable(reasons.toList()..sort()),
      unmappedPaths: List.unmodifiable(unmapped.toList()..sort()),
      patientReferenceMatched: patientReferenceMatched,
      resourceId: resourceId,
      resourceVersionId: meta.versionId,
      metaSource: meta.source,
      metaLastUpdated: meta.lastUpdated,
      clinicalStatus: clinicalStatus,
      verificationStatus: verificationStatus,
      type: type,
      category: List.unmodifiable(category),
      criticality: criticality,
      code: code,
      onset: onset,
      recordedDate: recordedDate,
      lastOccurrence: lastOccurrence,
      reactions: List.unmodifiable(reactions),
    );
  }

  List<FhirR4AllergyReactionPreview> _readReactions(
    Map<String, Object?> resource,
    String resourcePath,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (!resource.containsKey('reaction')) return const [];
    final raw = resource['reaction'];
    if (raw is! List) {
      reasons.add('fhir.reaction_invalid');
      return const [];
    }
    final output = <FhirR4AllergyReactionPreview>[];
    for (var index = 0; index < raw.length; index++) {
      final path = '$resourcePath.reaction[$index]';
      final reaction = _map(raw[index]);
      if (reaction == null) {
        reasons.add('fhir.reaction_invalid');
        continue;
      }
      final reactionUnmapped = <String>{};
      _scanFields(
        reaction,
        known: _reactionKeys,
        supported: const {
          'substance',
          'manifestation',
          'onset',
          'severity',
          'exposureRoute',
        },
        path: path,
        unmapped: reactionUnmapped,
      );
      final substance = _readConcept(
        reaction,
        'substance',
        '$path.substance',
        reasons,
        reactionUnmapped,
      );
      final manifestations = _readConceptList(
        reaction,
        'manifestation',
        '$path.manifestation',
        reasons,
        reactionUnmapped,
      );
      if (manifestations.isEmpty) {
        reasons.add('fhir.reaction_manifestation_required');
      }
      final onset = _readDateTime(reaction, 'onset', '$path.onset', reasons);
      final severity = _optionalText(
        reaction,
        'severity',
        '$path.severity',
        reasons,
        maxLength: 32,
      );
      if (severity != null && !_reactionSeverities.contains(severity)) {
        reasons.add('fhir.reaction_severity_unsupported');
      }
      final exposureRoute = _readConcept(
        reaction,
        'exposureRoute',
        '$path.exposureRoute',
        reasons,
        reactionUnmapped,
      );
      if (reactionUnmapped.isNotEmpty) {
        unmapped.addAll(reactionUnmapped);
        reasons.add('fhir.unmapped_fields');
      }
      output.add(
        FhirR4AllergyReactionPreview(
          substance: substance,
          manifestations: List.unmodifiable(manifestations),
          onset: onset,
          severity: severity,
          exposureRoute: exposureRoute,
          unmappedPaths: List.unmodifiable(reactionUnmapped.toList()..sort()),
        ),
      );
    }
    return output;
  }

  FhirR4AllergyConceptPreview? _readConcept(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (!parent.containsKey(key)) return null;
    final concept = _map(parent[key]);
    if (concept == null) {
      reasons.add('fhir.concept_invalid');
      return null;
    }
    _scanFields(
      concept,
      known: _conceptKeys,
      supported: const {'coding', 'text'},
      path: path,
      unmapped: unmapped,
    );
    final text = _optionalText(
      concept,
      'text',
      '$path.text',
      reasons,
      maxLength: 512,
    );
    final rawCodings = concept['coding'];
    if (!concept.containsKey('coding')) {
      return FhirR4AllergyConceptPreview(codings: const [], text: text);
    }
    if (rawCodings is! List) {
      reasons.add('fhir.concept_coding_invalid');
      return FhirR4AllergyConceptPreview(codings: const [], text: text);
    }
    final codings = <FhirR4AllergyCodingPreview>[];
    for (var index = 0; index < rawCodings.length; index++) {
      final codingPath = '$path.coding[$index]';
      final coding = _map(rawCodings[index]);
      if (coding == null) {
        reasons.add('fhir.concept_coding_invalid');
        continue;
      }
      _scanFields(
        coding,
        known: _codingKeys,
        supported: const {
          'system',
          'version',
          'code',
          'display',
          'userSelected',
        },
        path: codingPath,
        unmapped: unmapped,
      );
      final system = _optionalText(
        coding,
        'system',
        '$codingPath.system',
        reasons,
        maxLength: 512,
      );
      if (system != null && !_isAbsoluteUri(system)) {
        reasons.add('fhir.coding_system_invalid');
      }
      final version = _optionalText(
        coding,
        'version',
        '$codingPath.version',
        reasons,
        maxLength: 128,
      );
      final code = _optionalText(
        coding,
        'code',
        '$codingPath.code',
        reasons,
        maxLength: 256,
      );
      final display = _optionalText(
        coding,
        'display',
        '$codingPath.display',
        reasons,
        maxLength: 512,
      );
      final userSelectedRaw = coding['userSelected'];
      bool? userSelected;
      if (coding.containsKey('userSelected')) {
        if (userSelectedRaw is bool) {
          userSelected = userSelectedRaw;
        } else {
          reasons.add('fhir.coding_user_selected_invalid');
        }
      }
      codings.add(
        FhirR4AllergyCodingPreview(
          system: system,
          version: version,
          code: code,
          display: display,
          userSelected: userSelected,
        ),
      );
    }
    return FhirR4AllergyConceptPreview(
      codings: List.unmodifiable(codings),
      text: text,
    );
  }

  List<FhirR4AllergyConceptPreview> _readConceptList(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons,
    Set<String> unmapped,
  ) {
    if (!parent.containsKey(key)) return const [];
    final raw = parent[key];
    if (raw is! List) {
      reasons.add('fhir.concept_list_invalid');
      return const [];
    }
    final output = <FhirR4AllergyConceptPreview>[];
    for (var index = 0; index < raw.length; index++) {
      final item = <String, Object?>{'value': raw[index]};
      final concept = _readConcept(
        item,
        'value',
        '$path[$index]',
        reasons,
        unmapped,
      );
      if (concept != null) output.add(concept);
    }
    return output;
  }

  List<String> _readCodeList(
    Map<String, Object?> parent,
    String key,
    Set<String> reasons, {
    required Set<String> allowed,
    required bool mayBeEmpty,
  }) {
    if (!parent.containsKey(key)) return const [];
    final raw = parent[key];
    if (raw is! List || (!mayBeEmpty && raw.isEmpty)) {
      reasons.add('fhir.code_list_invalid');
      return const [];
    }
    final values = <String>[];
    final seen = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      if (item is! String || !_validText(item, 32)) {
        reasons.add('fhir.code_list_invalid');
        continue;
      }
      values.add(item);
      if (!allowed.contains(item)) reasons.add('fhir.code_unsupported');
      if (!seen.add(item)) reasons.add('fhir.code_list_duplicate');
    }
    return values;
  }

  FhirR4AllergyTimePreview? _readDateTime(
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
                    ? FhirR4AllergyTimePrecision.year
                    : FhirR4AllergyTimePrecision.month
              : FhirR4AllergyTimePrecision.day
        : match.group(7) == null
        ? FhirR4AllergyTimePrecision.second
        : FhirR4AllergyTimePrecision.fractionalSecond;
    return FhirR4AllergyTimePreview(lexical: value, precision: precision);
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

  ({String? versionId, String? source, FhirR4AllergyTimePreview? lastUpdated})
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
    final lastUpdated = _readDateTime(
      meta,
      'lastUpdated',
      '$path.lastUpdated',
      reasons,
      requireInstant: true,
    );
    return (versionId: versionId, source: source, lastUpdated: lastUpdated);
  }

  String? _requiredBoundCode(
    FhirR4AllergyConceptPreview? concept, {
    required String system,
    required Set<String> allowed,
  }) {
    if (concept == null) return null;
    final codes = concept.codings
        .where((coding) => coding.system == system)
        .map((coding) => coding.code)
        .toSet();
    if (codes.length != 1) return null;
    final code = codes.single;
    return code != null && allowed.contains(code) ? code : null;
  }

  String? _optionalText(
    Map<String, Object?> parent,
    String key,
    String path,
    Set<String> reasons, {
    required int maxLength,
  }) {
    if (!parent.containsKey(key)) return null;
    final raw = parent[key];
    if (raw is String && _validText(raw, maxLength)) return raw;
    reasons.add('fhir.text_invalid');
    return null;
  }

  void _validateContext(
    FhirR4AllergyPreviewContext context,
    Set<String> reasons,
  ) {
    if (context.fhirVersion !=
        FhirR4AllergyIntoleranceImportPreview.supportedFhirVersion) {
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

  void _scanFields(
    Map<String, Object?> object, {
    required Set<String> known,
    required Set<String> supported,
    required String path,
    required Set<String> unmapped,
  }) {
    for (final key in object.keys) {
      if (!known.contains(key) || !supported.contains(key)) {
        unmapped.add('$path.$key');
      }
    }
  }

  bool _validText(String value, int maximumLength) =>
      value.isNotEmpty &&
      value.length <= maximumLength &&
      value.trim() == value;

  bool _isAbsoluteUri(String value) =>
      _validText(value, 2048) &&
      !RegExp(r'\s').hasMatch(value) &&
      RegExp(_absoluteUriPattern).hasMatch(value) &&
      (Uri.tryParse(value)?.hasScheme ?? false);

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
