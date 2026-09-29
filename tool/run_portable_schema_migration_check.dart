import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/portable_schema_migration.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/domain/usecases/portable_schema_migration_registry.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';

void main() {
  test('portable schema migration Dart corpus and production preview', () {
    _runCheck();
  });
}

void _runCheck() {
  const packageService = UserPortableDataPackageService();
  final artifact = packageService.create(
    snapshot: _snapshot(),
    generatedAt: DateTime.utc(2026, 8, 31, 20),
  );
  final v2Json = _legacyV2(artifact.canonicalJson);
  final v2Document = _map(jsonDecode(v2Json));
  final v3Json = _legacyV3(artifact.canonicalJson);
  final v3Document = _map(jsonDecode(v3Json));
  final v4Document = _map(jsonDecode(artifact.canonicalJson));
  final v2Assessment = PortableSchemaMigrationRegistry.assess(
    sourceJson: v2Json,
    sourceDocument: v2Document,
  );
  final v3Assessment = PortableSchemaMigrationRegistry.assess(
    sourceJson: v3Json,
    sourceDocument: v3Document,
  );
  final v4Assessment = PortableSchemaMigrationRegistry.assess(
    sourceJson: artifact.canonicalJson,
    sourceDocument: v4Document,
  );
  final v2Preview = packageService.inspect(
    packageJson: v2Json,
    currentUserScope: _userScope,
    currentDoseOwnerScope: _doseScope,
    currentScopeKind: _scopeKind,
  );
  final v3Preview = packageService.inspect(
    packageJson: v3Json,
    currentUserScope: _userScope,
    currentDoseOwnerScope: _doseScope,
    currentScopeKind: _scopeKind,
  );
  final v4Preview = packageService.inspect(
    packageJson: artifact.canonicalJson,
    currentUserScope: _userScope,
    currentDoseOwnerScope: _doseScope,
    currentScopeKind: _scopeKind,
  );

  final failures = <String>[];
  if (!v2Assessment.accepted || v2Assessment.receipt == null) {
    failures.add('v2_registry_rejected');
  }
  if (!v3Assessment.accepted || v3Assessment.receipt == null) {
    failures.add('v3_registry_rejected');
  }
  if (!v4Assessment.accepted || v4Assessment.receipt == null) {
    failures.add('v4_registry_rejected');
  }
  if (v2Preview.status != UserPortableDataPreviewStatus.ready ||
      v2Preview.schemaMigrationReceipt == null) {
    failures.add('v2_production_preview_rejected');
  }
  if (v3Preview.status != UserPortableDataPreviewStatus.ready ||
      v3Preview.schemaMigrationReceipt == null) {
    failures.add('v3_production_preview_rejected');
  }
  if (v4Preview.status != UserPortableDataPreviewStatus.ready ||
      v4Preview.schemaMigrationReceipt == null) {
    failures.add('v4_production_preview_rejected');
  }
  final v2OutputFiles = _map(v2Assessment.outputDocument?['files']);
  final v3OutputFiles = _map(v3Assessment.outputDocument?['files']);
  if (_map(v2OutputFiles['observations.json'])['availability'] !=
          'unavailable_in_source_schema' ||
      _map(v3OutputFiles['observations.json'])['availability'] !=
          'unavailable_in_source_schema' ||
      v4Assessment.receipt?.targetVersion != 4) {
    failures.add('legacy_observation_gap_marker_drift');
  }

  final reordered = <String, Object?>{
    for (final entry in v2Document.entries.toList().reversed)
      entry.key: entry.value,
  };
  final reorderedAssessment = PortableSchemaMigrationRegistry.assess(
    sourceJson: jsonEncode(reordered),
    sourceDocument: reordered,
  );
  final unknown = _clone(v2Document)..['futureField'] = true;
  final missing = _clone(v2Document);
  final missingFiles = _map(missing['files']);
  final missingRows = List<Object?>.from(
    missingFiles['reminders.json'] as List,
  );
  missingRows[0] = _map(missingRows.single)..remove('enabled');
  missingFiles['reminders.json'] = missingRows;
  missing['files'] = missingFiles;
  final mixed = _clone(v2Document);
  final mixedFiles = _map(mixed['files']);
  final mixedRows = List<Object?>.from(mixedFiles['reminders.json'] as List);
  mixedRows[0] = _map(mixedRows.single)
    ..['notificationPrivacyMode'] = 'minimal';
  mixedFiles['reminders.json'] = mixedRows;
  mixed['files'] = mixedFiles;
  final duplicateJson = v2Json.replaceFirst(
    '"schemaVersion":2',
    '"schemaVersion":2,"schemaVersion":2',
  );
  final duplicatePreview = packageService.inspect(
    packageJson: duplicateJson,
    currentUserScope: _userScope,
    currentDoseOwnerScope: _doseScope,
    currentScopeKind: _scopeKind,
  );
  final future = _clone(v4Document)..['schemaVersion'] = 5;
  final futureAssessment = PortableSchemaMigrationRegistry.assess(
    sourceJson: portableCanonicalJson(future),
    sourceDocument: future,
  );
  final mutatedReceipt = v2Assessment.receipt!.toJson()
    ..['outputCanonicalSha256'] = List<String>.filled(64, '0').join();
  var receiptMutationBlocked = false;
  try {
    PortableSchemaMigrationReceipt.fromJson(mutatedReceipt);
  } on FormatException {
    receiptMutationBlocked = true;
  }

  final mutationResults = <String, bool>{
    'property_reordering_preserves_canonical_output':
        reorderedAssessment.accepted &&
        reorderedAssessment.receipt?.sourceCanonicalSha256 ==
            v2Assessment.receipt?.sourceCanonicalSha256 &&
        reorderedAssessment.receipt?.outputCanonicalSha256 ==
            v2Assessment.receipt?.outputCanonicalSha256,
    'unknown_root_field_blocked': !_assess(unknown).accepted,
    'omitted_required_field_blocked': !_assess(missing).accepted,
    'mixed_version_field_blocked': !_assess(mixed).accepted,
    'duplicate_object_member_blocked_before_decode':
        duplicatePreview.status == UserPortableDataPreviewStatus.corrupt,
    'future_schema_blocked': !futureAssessment.accepted,
    'receipt_digest_mutation_blocked': receiptMutationBlocked,
    'null_and_zero_preserved':
        _profile(v2Assessment.outputDocument)['dietProfileRegion'] == null &&
        _reminder(v2Assessment.outputDocument)['minuteOfDay'] == 0,
  };
  for (final entry in mutationResults.entries) {
    if (!entry.value) failures.add('mutation:${entry.key}');
  }

  final reportWithoutDigest = <String, Object?>{
    'schema': portableSchemaMigrationCrossRuntimeVectorsSchema,
    'schemaVersion': portableSchemaMigrationCrossRuntimeVectorsSchemaVersion,
    'pass': failures.isEmpty,
    'failures': failures,
    'registry': PortableSchemaMigrationRegistry.registryDocument(),
    'fixtures': <Object?>[
      <String, Object?>{
        'id': 'portable_schema_v2_minimal_reminder',
        'sourceJson': v2Json,
        'sourceDocument': v2Document,
        'outputDocument': v2Assessment.outputDocument,
        'receipt': v2Assessment.receipt?.toJson(),
      },
      <String, Object?>{
        'id': 'portable_schema_v3_current_noop',
        'sourceJson': v3Json,
        'sourceDocument': v3Document,
        'outputDocument': v3Assessment.outputDocument,
        'receipt': v3Assessment.receipt?.toJson(),
      },
      <String, Object?>{
        'id': 'portable_schema_v4_current_noop',
        'sourceJson': artifact.canonicalJson,
        'sourceDocument': v4Document,
        'outputDocument': v4Assessment.outputDocument,
        'receipt': v4Assessment.receipt?.toJson(),
      },
    ],
    'numericCanonicalizationFixtures': <Object?>[
      _numericCanonicalizationFixture(),
    ],
    'dartMutationResults': mutationResults,
    'boundary':
        'Frozen synthetic migration fixtures and deterministic no-write receipts only; not issuer authenticity, encryption, durable import, FHIR conformance, clinical correctness, or medical advice.',
  };
  final report = <String, Object?>{
    ...reportWithoutDigest,
    'reportSha256': portableCanonicalSha256(reportWithoutDigest),
  };
  final file = File('build/portable_schema_migration/dart_vectors.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'Portable schema migration Dart corpus: '
    '${failures.isEmpty ? 'pass' : 'FAIL'}; '
    '${mutationResults.length} mutation/invariant checks; '
    'registry=${PortableSchemaMigrationRegistry.registryDigest}; '
    'artifact=${file.path}',
  );
  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    throw StateError('Portable schema migration Dart corpus failed.');
  }
}

const _userScope = 'opaque_fixture_owner_capability';
const _doseScope = 'local_fixture@example.test';
const _scopeKind = 'local_device_account';

PortableSchemaMigrationAssessment _assess(Map<String, Object?> document) =>
    PortableSchemaMigrationRegistry.assess(
      sourceJson: portableCanonicalJson(document),
      sourceDocument: document,
    );

UserPortableDataSnapshot _snapshot() {
  final defaults = UserProfile.defaults();
  final profile = UserProfile(
    patientId: defaults.patientId,
    registrationRegion: defaults.registrationRegion,
    displayLocale: defaults.displayLocale,
    contentJurisdictionOverride: defaults.contentJurisdictionOverride,
    dietProfileRegion: null,
    timezone: defaults.timezone,
    swallowingTextureMode: defaults.swallowingTextureMode,
    localAiConsentEnabled: defaults.localAiConsentEnabled,
    localAiProviderPreference: defaults.localAiProviderPreference,
    localAiModel: defaults.localAiModel,
    localAiMedicalModel: defaults.localAiMedicalModel,
    localAiOllamaEndpoint: defaults.localAiOllamaEndpoint,
    localAiOpenAiCompatEndpoint: defaults.localAiOpenAiCompatEndpoint,
    localAiTimeoutMs: defaults.localAiTimeoutMs,
  );
  return UserPortableDataSnapshot(
    userScope: _userScope,
    doseOwnerScope: _doseScope,
    scopeKind: _scopeKind,
    profile: profile,
    activeDrugIds: const <String>[],
    intakes: <Intake>[
      Intake(
        id: 'intake_numeric_zero',
        drugId: 'drug_numeric_fixture',
        takenAt: DateTime.utc(2026, 8, 31, 19),
        dosageNote: '0 mg',
        doseAmount: 0.0,
        doseUnit: 'mg',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate_release',
      ),
    ],
    meals: const [],
    medicationCatalog: const [],
    foodCatalog: const [],
    reminders: const <UserLoggingReminder>[
      UserLoggingReminder(
        id: 'reminder_zero',
        kind: UserLoggingReminderKind.mealLog,
        label: 'Fixture reminder',
        minuteOfDay: 0,
        weekdays: <int>{1},
        enabled: false,
      ),
    ],
    observations: <PersonalObservation>[
      PersonalObservation.create(
        id: 'fixture_observation',
        kind: PersonalObservationKind.symptom,
        occurredAt: DateTime.utc(2026, 8, 31, 18),
        recordedAt: DateTime.utc(2026, 8, 31, 18, 1),
        originalTimezone: 'America/Toronto',
        source: PersonalObservationSource.selfReported,
        recorderId: 'fixture_private_recorder',
        status: PersonalObservationStatus.recorded,
        symptomLabel: 'Tremor',
        severity: 3,
        notes: 'Synthetic cross-runtime fixture.',
      ),
    ],
  );
}

Map<String, Object?> _numericCanonicalizationFixture() {
  const sourceJson =
      '{"decimalZero":0.0,"integer":0,"integerValuedDouble":1.0,'
      '"maximumInt":9223372036854775807,'
      '"minimumInt":-9223372036854775808,'
      '"aboveMaximumInt":9223372036854775808,'
      '"belowMinimumInt":-9223372036854775809,'
      '"hugeInteger":999999999999999999999999,'
      '"negativeZero":-0.0,"smallExponent":1e-7}';
  final sourceDocument = _map(jsonDecode(sourceJson));
  return <String, Object?>{
    'id': 'dart_json_number_lexical_types',
    'sourceJson': sourceJson,
    'sourceDocument': sourceDocument,
    'canonicalJson': portableCanonicalJson(sourceDocument),
    'boundary':
        'Dart VM jsonDecode numeric type and jsonEncode representation, '
        'including signed-64-bit integer boundaries, only; not Dart web, '
        'arbitrary-precision or RFC 8785/JCS conformance.',
  };
}

String _legacyV2(String source) {
  final root = _map(jsonDecode(source))..['schemaVersion'] = 2;
  final files = _map(root['files']);
  final rows = List<Object?>.from(files['reminders.json'] as List);
  for (var index = 0; index < rows.length; index++) {
    final row = _map(rows[index]);
    for (final field in const <String>[
      'notificationPrivacyMode',
      'notificationLocaleCode',
      'notificationLocaleDecisionCode',
      'sourcePresentationSchema',
      'sourcePresentationSha256',
      'presentationIdentityStatus',
      'targetSchedulingConsentStatus',
    ]) {
      row.remove(field);
    }
    rows[index] = row;
  }
  files['reminders.json'] = rows;
  files.remove('observations.json');
  root['files'] = files;
  final manifest = _map(root['manifest']);
  final privacy = _map(manifest['privacyBoundary'])
    ..['scope'] =
        'Current loaded profile, selections, intakes, meals, this-device reminders, and relationship audit links.'
    ..['excluded'] = PortableSchemaMigrationRegistry.excludedValuesForVersion(
      2,
    );
  manifest['privacyBoundary'] = privacy;
  root['manifest'] = manifest;
  _reseal(root);
  return portableCanonicalJson(root);
}

String _legacyV3(String source) {
  final root = _map(jsonDecode(source))..['schemaVersion'] = 3;
  final files = _map(root['files'])..remove('observations.json');
  root['files'] = files;
  final manifest = _map(root['manifest']);
  final privacy = _map(manifest['privacyBoundary'])
    ..['scope'] =
        'Current loaded profile, selections, intakes, meals, this-device reminders, and relationship audit links.'
    ..['excluded'] = PortableSchemaMigrationRegistry.excludedValuesForVersion(
      3,
    );
  manifest['privacyBoundary'] = privacy;
  root['manifest'] = manifest;
  _reseal(root);
  return portableCanonicalJson(root);
}

void _reseal(Map<String, Object?> root) {
  final files = _map(root['files']);
  final manifest = _map(root['manifest']);
  final owner = _map(manifest['ownerScope']);
  final integrity = _map(manifest['integrity']);
  final contentSha = portableCanonicalSha256(files);
  integrity['contentSha256'] = contentSha;
  manifest['integrity'] = integrity;
  manifest['files'] = <Object?>[
    for (final path in PortableSchemaMigrationRegistry.filePathsForVersion(
      root['schemaVersion'] as int,
    ))
      <String, Object?>{
        'path': path,
        'sha256': portableCanonicalSha256(files[path]),
        'recordCount': _recordCount(files[path]),
      },
  ];
  manifest['packageId'] = portableSha256(
    'parkinsum-portable-package-v${root['schemaVersion']}|'
    '${owner['bindingSha256']}|$contentSha',
  );
  root['manifest'] = manifest;
}

Map<String, Object?> _profile(Map<String, Object?>? root) {
  final files = _map(root?['files']);
  return _map(files['profile.json']);
}

Map<String, Object?> _reminder(Map<String, Object?>? root) {
  final files = _map(root?['files']);
  return _map((files['reminders.json'] as List).single);
}

int _recordCount(Object? value) {
  if (value is List) return value.length;
  if (value is Map && value['records'] is List) {
    return (value['records'] as List).length;
  }
  if (value is Map && value['links'] is List) {
    return (value['links'] as List).length;
  }
  return value is Map ? 1 : 0;
}

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value as Map);

Map<String, Object?> _clone(Map<String, Object?> value) =>
    _map(jsonDecode(jsonEncode(value)));
