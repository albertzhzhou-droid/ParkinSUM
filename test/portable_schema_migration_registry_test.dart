import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/portable_schema_migration.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/domain/usecases/portable_schema_migration_registry.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';

void main() {
  const packageService = UserPortableDataPackageService();

  test(
    'registry exposes three frozen validators and reviewed migration paths',
    () {
      expect(
        PortableSchemaMigrationRegistry.validators.map((item) => item.version),
        <int>[2, 3, 4],
      );
      expect(PortableSchemaMigrationRegistry.migrations, hasLength(3));
      expect(PortableSchemaMigrationRegistry.v2ToV3.semanticDiff, hasLength(8));
      expect(PortableSchemaMigrationRegistry.v3ToV4.semanticDiff, hasLength(5));
      expect(
        PortableSchemaMigrationRegistry.v2.validatorIdentity,
        '45f73a0b502bbdb88a05dec355c307a7bc9f845a523a486253c780f7371b4e9f',
      );
      expect(
        PortableSchemaMigrationRegistry.v3.validatorIdentity,
        '73a20c10fbd58809e7db835a17876bf9f61d295c9d76378643b72177f7b1d223',
      );
      expect(
        PortableSchemaMigrationRegistry.v2ToV3.migrationIdentity,
        'd0b446a0477483b0dde813974c0735224cba6d7fc7eb611a4fc6881698199349',
      );
      expect(
        PortableSchemaMigrationRegistry.v2.validatorIdentity,
        isNot(PortableSchemaMigrationRegistry.v3.validatorIdentity),
      );
    },
  );

  test('v2 migration reaches v4 and marks older observations unavailable', () {
    final v4 = packageService.create(
      snapshot: _snapshot(),
      generatedAt: DateTime.utc(2026, 8, 31, 20),
    );
    final v2Json = _legacyV2(v4.canonicalJson);
    final source = Map<String, Object?>.from(jsonDecode(v2Json) as Map);

    final first = PortableSchemaMigrationRegistry.assess(
      sourceJson: v2Json,
      sourceDocument: source,
    );
    final second = PortableSchemaMigrationRegistry.assess(
      sourceJson: v2Json,
      sourceDocument: source,
    );

    expect(first.accepted, isTrue);
    expect(first.findings, isEmpty);
    expect(first.receipt?.toJson(), second.receipt?.toJson());
    expect(first.receipt?.sourceVersion, 2);
    expect(first.receipt?.targetVersion, 4);
    expect(first.receipt?.decision, 'preview_only_no_write');
    expect(first.receipt?.heldFields, contains('durable_import'));
    expect(first.receipt?.warnings, hasLength(2));
    expect(first.receipt?.warnings.first, contains('1 legacy reminder'));
    expect(first.receipt?.warnings.last, contains('marks them unavailable'));
    expect(
      PortableSchemaMigrationReceipt.fromJson(
        first.receipt!.toJson(),
      ).receiptSha256,
      first.receipt!.receiptSha256,
    );

    final output = first.outputDocument!;
    final files = Map<String, Object?>.from(output['files'] as Map);
    final profile = Map<String, Object?>.from(files['profile.json'] as Map);
    final reminder = Map<String, Object?>.from(
      (files['reminders.json'] as List).single as Map,
    );
    expect(profile['dietProfileRegion'], isNull);
    expect(reminder['minuteOfDay'], 0);
    expect(reminder['notificationPrivacyMode'], 'minimal');
    expect(reminder['notificationLocaleCode'], 'en');
    expect(
      reminder['targetSchedulingConsentStatus'],
      'required_before_target_permission_or_scheduling',
    );
    final observations = Map<String, Object?>.from(
      files['observations.json'] as Map,
    );
    expect(observations['availability'], 'unavailable_in_source_schema');
    expect(observations['records'], isEmpty);

    final productionPreview = packageService.inspect(
      packageJson: v2Json,
      currentUserScope: _userScope,
      currentDoseOwnerScope: _doseScope,
      currentScopeKind: _scopeKind,
    );
    expect(productionPreview.status, UserPortableDataPreviewStatus.ready);
    expect(
      productionPreview.schemaMigrationReceipt?.receiptSha256,
      first.receipt?.receiptSha256,
    );
  });

  test('v3 migration updates package scope and records the source gap', () {
    final v4 = packageService.create(
      snapshot: _snapshot(),
      generatedAt: DateTime.utc(2026, 8, 31, 20),
    );
    final v3Json = _legacyV3(v4.canonicalJson);
    final source = Map<String, Object?>.from(jsonDecode(v3Json) as Map);
    final assessment = PortableSchemaMigrationRegistry.assess(
      sourceJson: v3Json,
      sourceDocument: source,
    );

    expect(assessment.accepted, isTrue, reason: assessment.findings.join('\n'));
    expect(assessment.receipt?.sourceVersion, 3);
    expect(assessment.receipt?.targetVersion, 4);
    expect(assessment.receipt?.semanticDiffSha256, isNotEmpty);
    final output = assessment.outputDocument!;
    final files = Map<String, Object?>.from(output['files'] as Map);
    final observations = Map<String, Object?>.from(
      files['observations.json'] as Map,
    );
    expect(observations['availability'], 'unavailable_in_source_schema');
    final manifest = Map<String, Object?>.from(output['manifest'] as Map);
    final privacy = Map<String, Object?>.from(
      manifest['privacyBoundary'] as Map,
    );
    expect(privacy['scope'], contains('owner-entered personal observations'));
    expect(privacy['excluded'], contains('personalObservation.recorderId'));
  });

  test('unknown, missing, mixed-version and receipt mutations fail closed', () {
    final v3 = packageService.create(
      snapshot: _snapshot(),
      generatedAt: DateTime.utc(2026, 8, 31, 20),
    );
    final v2Json = _legacyV2(v3.canonicalJson);
    final source = Map<String, Object?>.from(jsonDecode(v2Json) as Map);

    final unknown = _clone(source)..['futureField'] = true;
    final unknownAssessment = PortableSchemaMigrationRegistry.assess(
      sourceJson: portableCanonicalJson(unknown),
      sourceDocument: unknown,
    );
    expect(unknownAssessment.accepted, isFalse);
    expect(unknownAssessment.findings.join(' '), contains('futureField'));

    final missing = _clone(source);
    final missingFiles = Map<String, Object?>.from(missing['files'] as Map);
    final missingRows = List<Object?>.from(
      missingFiles['reminders.json'] as List,
    );
    missingRows[0] = Map<String, Object?>.from(missingRows.single as Map)
      ..remove('enabled');
    missingFiles['reminders.json'] = missingRows;
    missing['files'] = missingFiles;
    final missingAssessment = PortableSchemaMigrationRegistry.assess(
      sourceJson: portableCanonicalJson(missing),
      sourceDocument: missing,
    );
    expect(missingAssessment.accepted, isFalse);
    expect(missingAssessment.findings.join(' '), contains('enabled'));

    final mixed = _clone(source);
    final mixedFiles = Map<String, Object?>.from(mixed['files'] as Map);
    final mixedRows = List<Object?>.from(mixedFiles['reminders.json'] as List);
    mixedRows[0] = Map<String, Object?>.from(mixedRows.single as Map)
      ..['notificationPrivacyMode'] = 'minimal';
    mixedFiles['reminders.json'] = mixedRows;
    mixed['files'] = mixedFiles;
    final mixedAssessment = PortableSchemaMigrationRegistry.assess(
      sourceJson: portableCanonicalJson(mixed),
      sourceDocument: mixed,
    );
    expect(mixedAssessment.accepted, isFalse);
    expect(
      mixedAssessment.findings.join(' '),
      contains('notificationPrivacyMode'),
    );

    final accepted = PortableSchemaMigrationRegistry.assess(
      sourceJson: v2Json,
      sourceDocument: source,
    );
    final receiptMutation = accepted.receipt!.toJson()
      ..['outputCanonicalSha256'] = List<String>.filled(64, '0').join();
    expect(
      () => PortableSchemaMigrationReceipt.fromJson(receiptMutation),
      throwsFormatException,
    );
  });
}

const _userScope = 'opaque_fixture_owner_capability';
const _doseScope = 'local_fixture@example.test';
const _scopeKind = 'local_device_account';

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
    intakes: const [],
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
  );
}

String _legacyV2(String source) {
  final root = Map<String, Object?>.from(jsonDecode(source) as Map)
    ..['schemaVersion'] = 2;
  final files = Map<String, Object?>.from(root['files'] as Map);
  files.remove('observations.json');
  final rows = List<Object?>.from(files['reminders.json'] as List);
  for (var index = 0; index < rows.length; index++) {
    final row = Map<String, Object?>.from(rows[index] as Map);
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
  root['files'] = files;
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final privacy = Map<String, Object?>.from(manifest['privacyBoundary'] as Map)
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
  final root = Map<String, Object?>.from(jsonDecode(source) as Map)
    ..['schemaVersion'] = 3;
  final files = Map<String, Object?>.from(root['files'] as Map)
    ..remove('observations.json');
  root['files'] = files;
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final privacy = Map<String, Object?>.from(manifest['privacyBoundary'] as Map)
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
  final files = Map<String, Object?>.from(root['files'] as Map);
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final owner = Map<String, Object?>.from(manifest['ownerScope'] as Map);
  final integrity = Map<String, Object?>.from(manifest['integrity'] as Map);
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

Map<String, Object?> _clone(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);
