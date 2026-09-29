import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/portable_schema_migration.dart';
import 'package:parkinsum_companion/domain/usecases/portable_schema_migration_registry.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';

void main() {
  test('fixed portable-schema differential fuzz campaign', _runCampaign);
}

void _runCampaign() {
  final plan = _readMap('config/portable_schema_fuzz_plan.json');
  final corpus = _readMap(
    'test/fixtures/portable_schema_regression_corpus.json',
  );
  final vectors = _readMap('build/portable_schema_migration/dart_vectors.json');
  _requirePlan(plan, corpus);

  final fixtures = (vectors['fixtures'] as List).cast<Map>();
  final v2 = Map<String, Object?>.from(fixtures[0]);
  final v3 = Map<String, Object?>.from(fixtures[1]);
  final v4 = Map<String, Object?>.from(fixtures[2]);
  final cases = <Map<String, Object?>>[];

  for (final rawCase in (corpus['cases'] as List).cast<Map>()) {
    final entry = Map<String, Object?>.from(rawCase);
    cases.add(<String, Object?>{
      'id': entry['id'],
      'partition': entry['partition'],
      'seed': null,
      'rawJson': _materializeCorpusCase(entry, v3['sourceJson'] as String),
      'expectedDisposition': entry['expectedDisposition'],
      'expectedReasonCode': entry['expectedReasonCode'],
      'origin': 'retained_synthetic_regression_corpus',
    });
  }

  final seeds = (plan['fixedRegressionSeeds'] as List).cast<int>();
  for (var seedIndex = 0; seedIndex < seeds.length; seedIndex++) {
    final seed = seeds[seedIndex];
    final v2Source = v2['sourceJson'] as String;
    final v3Source = v3['sourceJson'] as String;
    final selectedVersion = switch (seedIndex) {
      0 => 2,
      1 => 3,
      _ => 4,
    };
    final selected = switch (selectedVersion) {
      2 => v2Source,
      3 => v3Source,
      _ => v4['sourceJson'] as String,
    };
    final selectedDocument = Map<String, Object?>.from(
      jsonDecode(selected) as Map,
    );
    final rotationOffset = seedIndex + 1;
    final rotated = _rotateRoot(selectedDocument, rotationOffset);
    if (_sameOrder(selectedDocument.keys, rotated.keys)) {
      throw StateError('Property-order mutation did not change root order.');
    }
    final future = Map<String, Object?>.from(selectedDocument)
      ..['schemaVersion'] = 5;
    final unknown = Map<String, Object?>.from(selectedDocument)
      ..['syntheticFutureField'] = seed;
    cases.addAll(<Map<String, Object?>>[
      _case(
        id: 'seed_${seed}_current_or_legacy',
        partition: switch (selectedVersion) {
          2 => 'legacy_v2_valid_migration',
          3 => 'legacy_v3_valid_migration',
          _ => 'current_v4_valid',
        },
        seed: seed,
        rawJson: selected,
        expected: 'ready',
        expectedReason: selectedVersion < 4
            ? 'ready_migrated_preview'
            : 'ready_current',
      ),
      _case(
        id: 'seed_${seed}_order_whitespace',
        partition: 'property_order_and_json_whitespace',
        seed: seed,
        rawJson: '${' ' * ((seed % 3) + 1)}${jsonEncode(rotated)}\n',
        expected: 'ready',
        expectedReason: selectedVersion < 4
            ? 'ready_migrated_preview'
            : 'ready_current',
        mutationWitness: 'root_rotation_$rotationOffset',
      ),
      _case(
        id: 'seed_${seed}_future_version',
        partition: 'unsupported_future_version',
        seed: seed,
        rawJson: portableCanonicalJson(future),
        expected: 'unsupportedSchema',
        expectedReason: 'unsupported_schema_version',
      ),
      _case(
        id: 'seed_${seed}_unknown_field',
        partition: 'unknown_or_mixed_schema_field',
        seed: seed,
        rawJson: portableCanonicalJson(unknown),
        expected: 'unsupportedSchema',
        expectedReason: 'unsupported_fields',
      ),
      _case(
        id: 'seed_${seed}_receipt_output',
        partition: 'canonical_output_and_receipt_drift',
        seed: seed,
        rawJson: v2Source,
        expected: 'ready',
        expectedReason: 'ready_migrated_preview',
      ),
    ]);
  }
  cases.add(
    _case(
      id: 'string_over_utf8_budget',
      partition: 'maximum_string_bytes',
      seed: null,
      rawJson: jsonEncode(<String, Object?>{
        'value': List<String>.filled(65537, 'a').join(),
      }),
      expected: 'corrupt',
      expectedReason: 'string_budget',
    ),
  );

  const service = UserPortableDataPackageService();
  final failures = <String>[];
  final results = <Object?>[];
  final coveredPartitions = <String>{};
  final budgets = Map<String, Object?>.from(plan['resourceBudgets'] as Map);
  final caseObservationBudget = Duration(
    milliseconds: budgets['caseObservationMilliseconds'] as int,
  );
  for (final testCase in cases) {
    final rawJson = testCase['rawJson'] as String;
    final stopwatch = Stopwatch()..start();
    final preview = service.inspect(
      packageJson: rawJson,
      currentUserScope: 'opaque_fixture_owner_capability',
      currentDoseOwnerScope: 'local_fixture@example.test',
      currentScopeKind: 'local_device_account',
    );
    stopwatch.stop();
    final actual = preview.status.name;
    final actualReason = _reasonCode(preview);
    final expected = testCase['expectedDisposition'] as String;
    final expectedReason = testCase['expectedReasonCode'] as String;
    final id = testCase['id'] as String;
    coveredPartitions.add(testCase['partition'] as String);
    if (actual != expected) failures.add('$id:$expected->$actual');
    if (actualReason != expectedReason) {
      failures.add('$id:reason:$expectedReason->$actualReason');
    }
    if (stopwatch.elapsed > caseObservationBudget) {
      failures.add('$id:case_observation_overrun');
    }
    results.add(<String, Object?>{
      ...testCase,
      'sourceSha256': portableSha256(rawJson),
      'dartDisposition': actual,
      'dartReasonCode': actualReason,
      'schemaVersion': preview.schemaVersion,
      'outputCanonicalSha256':
          preview.schemaMigrationReceipt?.outputCanonicalSha256,
      'receiptSha256': preview.schemaMigrationReceipt?.receiptSha256,
    });
  }

  final declaredPartitions = (plan['partitions'] as List)
      .cast<String>()
      .toSet();
  final missingPartitions = declaredPartitions.difference(coveredPartitions);
  if (missingPartitions.isNotEmpty) {
    failures.add('uncovered_partitions:${missingPartitions.toList()..sort()}');
  }
  final withoutDigest = <String, Object?>{
    'schema': portableSchemaDifferentialFuzzReportSchema,
    'schemaVersion': portableSchemaDifferentialFuzzReportSchemaVersion,
    'generatorVersion': plan['generatorVersion'],
    'planSha256': portableCanonicalSha256(plan),
    'corpusSha256': portableCanonicalSha256(corpus),
    'registryIdentity': PortableSchemaMigrationRegistry.registryDigest,
    'pass': failures.isEmpty,
    'failures': failures,
    'fixedSeeds': seeds,
    'declaredPartitionCount': declaredPartitions.length,
    'coveredPartitions': coveredPartitions.toList()..sort(),
    'caseCount': results.length,
    'cases': results,
    'boundary': plan['boundary'],
  };
  final report = <String, Object?>{
    ...withoutDigest,
    'reportSha256': portableCanonicalSha256(withoutDigest),
  };
  final output = File('build/portable_schema_fuzz/dart_campaign.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'Portable schema Dart differential campaign: '
    '${failures.isEmpty ? 'pass' : 'FAIL'}; ${results.length} cases; '
    '${coveredPartitions.length}/${declaredPartitions.length} partitions; '
    'artifact=${output.path}',
  );
  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    throw StateError('Portable schema differential fuzz campaign failed.');
  }
}

Map<String, Object?> _case({
  required String id,
  required String partition,
  required int? seed,
  required String rawJson,
  required String expected,
  required String expectedReason,
  String? mutationWitness,
}) => <String, Object?>{
  'id': id,
  'partition': partition,
  'seed': seed,
  'rawJson': rawJson,
  'expectedDisposition': expected,
  'expectedReasonCode': expectedReason,
  'mutationWitness': ?mutationWitness,
  'origin': 'fixed_seed_synthetic_generator_v1',
};

String _materializeCorpusCase(Map<String, Object?> entry, String v3Source) {
  if (entry['rawJson'] case final String rawJson) return rawJson;
  if (entry['generatorRecipe'] == 'object_with_129_integer_fields') {
    return jsonEncode(<String, Object?>{
      for (var index = 0; index < 129; index++) 'field_$index': index,
    });
  }
  if (entry['generatorRecipe'] == 'number_token_129_characters') {
    return '{"value":${List<String>.filled(129, '7').join()}}';
  }
  if (entry['generatorRecipe'] ==
      'escaped_ascii_string_token_10923_characters') {
    return '{"value":"${List<String>.filled(10923, r'\u0061').join()}"}';
  }
  if (entry['generatorRecipe'] == 'decoded_key_257_ascii_bytes') {
    return '{"${List<String>.filled(257, 'k').join()}":0}';
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_duplicate_manifest_path') {
    final root = Map<String, Object?>.from(jsonDecode(v3Source) as Map);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map);
    final rows = List<Object?>.from(
      manifest['files'] as List,
    )..add(Map<String, Object?>.from((manifest['files'] as List).first as Map));
    manifest['files'] = rows;
    root['manifest'] = manifest;
    return portableCanonicalJson(root);
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_md5_integrity_algorithm') {
    final root = Map<String, Object?>.from(jsonDecode(v3Source) as Map);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map);
    final integrity = Map<String, Object?>.from(manifest['integrity'] as Map)
      ..['algorithm'] = 'MD5';
    manifest['integrity'] = integrity;
    root['manifest'] = manifest;
    return portableCanonicalJson(root);
  }
  if (entry['generatorRecipe'] == 'invalid_escape_after_65535_ascii_bytes') {
    return '{"value":"${List<String>.filled(65535, 'a').join()}${r'\x'}"}';
  }
  if (entry['generatorRecipe'] ==
      'unpaired_surrogate_before_65537_ascii_bytes') {
    return '{"value":"${r'\ud800'}${List<String>.filled(65537, 'a').join()}"}';
  }
  if (entry['generatorRecipe'] == 'object_with_long_129th_key') {
    return jsonEncode(<String, Object?>{
      for (var index = 0; index < 128; index++) 'field_$index': index,
      List<String>.filled(257, 'k').join(): 129,
    });
  }
  if (entry['generatorRecipe'] == 'nbsp_before_depth_25_array') {
    return '\u00a0${List<String>.filled(25, '[').join()}null'
        '${List<String>.filled(25, ']').join()}';
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_included_activation_token') {
    return _mutateFirstReminder(
      v3Source,
      (reminder) =>
          reminder['activationTokenStatus'] = 'included_in_portable_package',
    );
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_bypassed_target_consent') {
    return _mutateFirstReminder(
      v3Source,
      (reminder) => reminder['targetSchedulingConsentStatus'] = 'not_required',
    );
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_invalid_presentation_digest') {
    return _mutateFirstReminder(
      v3Source,
      (reminder) => reminder['sourcePresentationSha256'] = 'not-a-sha',
    );
  }
  if (entry['generatorRecipe'] == 'trailing_comma_after_499999_array_items') {
    return '[${List<String>.filled(499999, '0').join(',')} ,';
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_empty_reminder_label') {
    return _mutateFirstReminder(v3Source, (reminder) => reminder['label'] = '');
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_double_reminder_minute') {
    return _mutateFirstReminder(
      v3Source,
      (reminder) =>
          reminder['minuteOfDay'] = (reminder['minuteOfDay'] as num).toDouble(),
    );
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_double_reminder_weekday') {
    return _mutateFirstReminder(v3Source, (reminder) {
      final weekdays = List<Object?>.from(reminder['weekdays'] as List);
      weekdays[0] = (weekdays[0] as num).toDouble();
      reminder['weekdays'] = weekdays;
    });
  }
  if (entry['generatorRecipe'] ==
      'valid_v3_with_duplicate_reminder_identifier') {
    final root = Map<String, Object?>.from(jsonDecode(v3Source) as Map);
    final files = Map<String, Object?>.from(root['files'] as Map);
    final reminders = List<Object?>.from(files['reminders.json'] as List);
    reminders.add(Map<String, Object?>.from(reminders.first as Map));
    files['reminders.json'] = reminders;
    root['files'] = files;
    _resealPortablePackage(root);
    return portableCanonicalJson(root);
  }
  if (entry['generatorRecipe'] == 'valid_v3_with_double_schema_version') {
    return v3Source.replaceFirst('"schemaVersion":3', '"schemaVersion":3.0');
  }
  if (entry['generatorRecipe'] ==
      'valid_v3_with_double_manifest_record_count') {
    final root = Map<String, Object?>.from(jsonDecode(v3Source) as Map);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map);
    final rows = List<Object?>.from(manifest['files'] as List);
    final first = Map<String, Object?>.from(rows.first as Map);
    first['recordCount'] = (first['recordCount'] as num).toDouble();
    rows[0] = first;
    manifest['files'] = rows;
    root['manifest'] = manifest;
    return portableCanonicalJson(root);
  }
  if (entry['generatorRecipe'] == 'valid_v3_reminder_label_escaped_non_bmp') {
    final root = Map<String, Object?>.from(jsonDecode(v3Source) as Map);
    final files = Map<String, Object?>.from(root['files'] as Map);
    final reminders = List<Object?>.from(files['reminders.json'] as List);
    final firstReminder = Map<String, Object?>.from(reminders.first as Map)
      ..['label'] = 'Synthetic rocket 🚀';
    reminders[0] = firstReminder;
    files['reminders.json'] = reminders;
    root['files'] = files;
    _resealPortablePackage(root);
    return portableCanonicalJson(root).replaceAll('🚀', r'\ud83d\ude80');
  }
  throw FormatException('Unsupported corpus recipe for ${entry['id']}.');
}

String _mutateFirstReminder(
  String v3Source,
  void Function(Map<String, Object?> reminder) mutate,
) {
  final root = Map<String, Object?>.from(jsonDecode(v3Source) as Map);
  final files = Map<String, Object?>.from(root['files'] as Map);
  final reminders = List<Object?>.from(files['reminders.json'] as List);
  final first = Map<String, Object?>.from(reminders.first as Map);
  mutate(first);
  reminders[0] = first;
  files['reminders.json'] = reminders;
  root['files'] = files;
  _resealPortablePackage(root);
  return portableCanonicalJson(root);
}

Map<String, Object?> _rotateRoot(Map<String, Object?> source, int offset) {
  final entries = source.entries.toList();
  final normalizedOffset = offset % entries.length;
  return <String, Object?>{
    for (var index = 0; index < entries.length; index++)
      entries[(index + normalizedOffset) % entries.length].key:
          entries[(index + normalizedOffset) % entries.length].value,
  };
}

bool _sameOrder(Iterable<String> left, Iterable<String> right) {
  final leftList = left.toList();
  final rightList = right.toList();
  if (leftList.length != rightList.length) return false;
  for (var index = 0; index < leftList.length; index++) {
    if (leftList[index] != rightList[index]) return false;
  }
  return true;
}

void _resealPortablePackage(Map<String, Object?> root) {
  final files = Map<String, Object?>.from(root['files'] as Map);
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final integrity = Map<String, Object?>.from(manifest['integrity'] as Map);
  final owner = Map<String, Object?>.from(manifest['ownerScope'] as Map);
  final contentSha256 = portableCanonicalSha256(files);
  integrity['contentSha256'] = contentSha256;
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
    '${owner['bindingSha256']}|$contentSha256',
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

String _reasonCode(UserPortableDataImportPreview preview) {
  if (preview.status == UserPortableDataPreviewStatus.ready) {
    return preview.schemaMigrationReceipt?.decision == 'preview_only_no_write'
        ? 'ready_migrated_preview'
        : 'ready_current';
  }
  if (preview.status == UserPortableDataPreviewStatus.wrongOwner) {
    return 'wrong_owner';
  }
  if (preview.status == UserPortableDataPreviewStatus.unsupportedSchema) {
    if (preview.schemaVersion != userPortableDataPackageSchemaVersion &&
        !userPortableDataLegacyReadableVersions.contains(
          preview.schemaVersion,
        )) {
      return 'unsupported_schema_version';
    }
    return preview.unsupportedFields.isNotEmpty
        ? 'unsupported_fields'
        : 'unsupported_schema_version';
  }
  final finding = preview.findings.isEmpty ? '' : preview.findings.first;
  if (finding.contains('Duplicate JSON object keys')) {
    return 'duplicate_member';
  }
  if (finding.contains('paired Unicode scalar values')) {
    return 'non_interoperable_unicode';
  }
  if (finding.contains('input budget')) return 'package_bytes_budget';
  if (finding.contains('nesting depth')) return 'depth_budget';
  if (finding.contains('-node JSON budget')) return 'node_budget';
  if (finding.contains('too many fields') ||
      finding.contains('fields; limit is')) {
    return 'object_width_budget';
  }
  if (finding.contains('string limit')) return 'string_budget';
  if (finding.contains('field name exceeds')) return 'key_utf8_budget';
  if (finding.contains('number exceeds')) return 'number_token_budget';
  if (finding.contains('not valid JSON or exceeds a structural safety')) {
    return 'malformed_or_structural_budget';
  }
  return 'contract_or_integrity_invalid';
}

Map<String, Object?> _readMap(String path) =>
    Map<String, Object?>.from(jsonDecode(File(path).readAsStringSync()) as Map);

void _requirePlan(Map<String, Object?> plan, Map<String, Object?> corpus) {
  final budgets = Map<String, Object?>.from(plan['resourceBudgets'] as Map);
  if (plan[r'$schema'] != portableSchemaDifferentialFuzzPlanSchema ||
      plan['schemaVersion'] !=
          portableSchemaDifferentialFuzzPlanSchemaVersion ||
      plan['generatorVersion'] !=
          PortableSchemaFuzzCampaignSummary.generatorVersion ||
      (plan['fixedRegressionSeeds'] as List).length !=
          PortableSchemaFuzzCampaignSummary.fixedSeedCount ||
      (plan['partitions'] as List).length !=
          PortableSchemaFuzzCampaignSummary.lexicalAndSemanticPartitionCount ||
      corpus[r'$schema'] != portableSchemaFuzzRegressionCorpusSchema ||
      corpus['schemaVersion'] !=
          portableSchemaFuzzRegressionCorpusSchemaVersion ||
      (corpus['cases'] as List).length !=
          PortableSchemaFuzzCampaignSummary.retainedSyntheticCaseCount ||
      budgets['packageBytes'] != userPortableDataMaxPackageBytes ||
      budgets['jsonNodes'] != userPortableDataMaxJsonNodes ||
      budgets['jsonDepth'] != userPortableDataMaxJsonDepth ||
      budgets['objectFields'] != userPortableDataMaxMapFields ||
      budgets['stringTokenBytes'] != userPortableDataMaxStringBytes ||
      budgets['decodedStringUtf8Bytes'] != userPortableDataMaxStringBytes ||
      budgets['keyUtf8Bytes'] != userPortableDataMaxKeyBytes ||
      budgets['numberTokenCharacters'] != userPortableDataMaxNumberTokenChars ||
      budgets['caseObservationMilliseconds'] is! int ||
      (budgets['caseObservationMilliseconds'] as int) <= 0) {
    throw const FormatException('Portable schema fuzz plan/corpus drift.');
  }
  final privacy = Map<String, Object?>.from(corpus['privacy'] as Map);
  if (privacy['syntheticOnly'] != true ||
      privacy['privacyReviewed'] != true ||
      privacy['userDerived'] != false) {
    throw const FormatException('Portable schema corpus privacy drift.');
  }
}
