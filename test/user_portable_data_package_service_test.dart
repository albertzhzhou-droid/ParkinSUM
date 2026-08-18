import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';

void main() {
  const service = UserPortableDataPackageService();
  final generatedAt = DateTime.utc(2026, 8, 17, 14, 30);

  test('build is deterministic under input reordering and self-verifies', () {
    final first = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final second = service.create(
      snapshot: _snapshot(reverse: true),
      generatedAt: generatedAt,
    );

    expect(second.canonicalJson, first.canonicalJson);
    expect(second.packageId, first.packageId);
    expect(second.contentSha256, first.contentSha256);
    expect(first.files.map((file) => file.path), userPortableDataFilePaths);

    final preview = service.inspect(
      packageJson: first.prettyJson,
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.ready);
    expect(preview.mayProceedToFutureImport, isTrue);
    expect(preview.findings.last, contains('no record'));
  });

  test(
    'async inspection preserves the synchronous validation result',
    () async {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );

      final preview = await service.inspectAsync(
        packageJson: artifact.prettyJson,
        currentUserScope: _scope,
        currentScopeKind: _scopeKind,
      );

      expect(preview.status, UserPortableDataPreviewStatus.ready);
      expect(preview.packageId, artifact.packageId);
      expect(preview.recordCounts.keys, userPortableDataFilePaths);
    },
  );

  test(
    'round-trip preserves null versus zero, timestamp, unit, provenance, and audit links',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final files = _files(artifact.prettyJson);
      final intakes = (files['intakes.json'] as List).cast<Map>();
      final nullDose = intakes.singleWhere((row) => row['id'] == 'intake_null');
      final zeroDose = intakes.singleWhere((row) => row['id'] == 'intake_zero');

      expect((nullDose['dose'] as Map)['amount'], isNull);
      expect((zeroDose['dose'] as Map)['amount'], 0.0);
      expect((zeroDose['dose'] as Map)['unit'], 'mg');
      expect(zeroDose['takenAt'], '2026-08-17T12:00:00.000Z');
      expect(
        (zeroDose['medicationCatalogProvenance'] as Map)['sourceSystem'],
        'TEST_LABEL',
      );

      final meals = (files['meals.json'] as List).cast<Map>();
      final items = (meals.single['items'] as List).cast<Map>();
      final missing = items.singleWhere(
        (row) => row['foodId'] == 'food_missing',
      );
      final trueZero = items.singleWhere((row) => row['foodId'] == 'food_zero');
      final missingProtein =
          ((missing['nutrientsPer100g'] as Map)['protein'] as Map);
      final zeroProtein =
          ((trueZero['nutrientsPer100g'] as Map)['protein'] as Map);
      expect(missingProtein['value'], isNull);
      expect(missingProtein['rawCompatibilityValue'], 0.0);
      expect(missingProtein['missing'], isTrue);
      expect(missingProtein['status'], 'source_missing_not_zero');
      expect(zeroProtein['value'], 0.0);
      expect(zeroProtein['missing'], isFalse);
      expect(
        (missing['catalogProvenance'] as Map)['qualifierKind'],
        'analytical',
      );

      final audit = files['audit_links.json'] as Map;
      expect(audit['clinicalAuditRecordsIncluded'], isFalse);
      expect(
        (audit['links'] as List).where(
          (row) => (row as Map)['relationship'] == 'contains_food',
        ),
        hasLength(2),
      );
    },
  );

  test(
    'historical intake medication remains a truthful inactive selection target',
    () {
      final historical = Intake(
        id: 'intake_historical',
        drugId: 'drug_deselected',
        takenAt: generatedAt,
        dosageNote: '',
      );
      final artifact = service.create(
        snapshot: _snapshot(intakes: <Intake>[..._intakes, historical]),
        generatedAt: generatedAt,
      );
      final files = _files(artifact.prettyJson);
      final selections = (files['medication_selections.json'] as List)
          .cast<Map>();
      final historicalSelection = selections.singleWhere(
        (row) => row['id'] == 'drug_deselected',
      );
      expect(historicalSelection['activeAtExport'], isFalse);
      expect(historicalSelection['catalogStatus'], 'unresolved');
      final links = ((files['audit_links.json'] as Map)['links'] as List)
          .cast<Map>();
      expect(
        links.any(
          (row) =>
              row['recordType'] == 'intake' &&
              row['recordId'] == 'intake_historical' &&
              row['relationship'] == 'references_medication_selection' &&
              row['targetType'] == 'medication_selection' &&
              row['targetId'] == 'drug_deselected',
        ),
        isTrue,
      );
      expect(
        service
            .inspect(
              packageJson: artifact.prettyJson,
              currentUserScope: _scope,
              currentScopeKind: _scopeKind,
            )
            .status,
        UserPortableDataPreviewStatus.ready,
      );
    },
  );

  test('mechanical secret scan excludes raw account and capability values', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    const forbiddenValues = <String>[
      _scope,
      _patientId,
      _email,
      _activationToken,
      _ollamaEndpoint,
      _openAiEndpoint,
    ];
    for (final value in forbiddenValues) {
      expect(
        artifact.prettyJson,
        isNot(contains(value)),
        reason: 'portable JSON leaked "$value"',
      );
    }
    final profile = _files(artifact.prettyJson)['profile.json'] as Map;
    expect(profile, isNot(contains('email')));
    expect(profile['identityFieldStatus'], {
      'patientId': 'excluded_from_portable_package',
    });
    final reminder =
        (_files(artifact.prettyJson)['reminders.json'] as List).single as Map;
    expect(reminder, isNot(contains('activationToken')));
    expect(reminder['activationTokenStatus'], 'excluded_from_portable_package');
  });

  test('owner mismatch and checksum tampering fail closed', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final wrongOwner = service.inspect(
      packageJson: artifact.prettyJson,
      currentUserScope: 'different_scope',
      currentScopeKind: _scopeKind,
    );
    expect(wrongOwner.status, UserPortableDataPreviewStatus.wrongOwner);
    expect(wrongOwner.mayProceedToFutureImport, isFalse);

    final tampered = _root(artifact.prettyJson);
    final files = Map<String, Object?>.from(tampered['files'] as Map);
    final intakes = List<Object?>.from(files['intakes.json'] as List);
    intakes.add(<String, Object?>{'id': 'intake_tampered'});
    files['intakes.json'] = intakes;
    tampered['files'] = files;
    final corrupt = service.inspect(
      packageJson: jsonEncode(tampered),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(corrupt.status, UserPortableDataPreviewStatus.corrupt);
    expect(corrupt.findings.join(' '), contains('checksum'));
  });

  test('new schema and unsupported fields never become import-ready', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final newer = _root(artifact.prettyJson)..['schemaVersion'] = 2;
    final newerPreview = service.inspect(
      packageJson: jsonEncode(newer),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(
      newerPreview.status,
      UserPortableDataPreviewStatus.unsupportedSchema,
    );
    expect(newerPreview.mayProceedToFutureImport, isFalse);

    final fractional = _root(artifact.prettyJson)..['schemaVersion'] = 1.5;
    final fractionalPreview = service.inspect(
      packageJson: jsonEncode(fractional),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(
      fractionalPreview.status,
      UserPortableDataPreviewStatus.unsupportedSchema,
    );

    final unknown = _root(artifact.prettyJson)..['futureField'] = true;
    final unknownPreview = service.inspect(
      packageJson: jsonEncode(unknown),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(
      unknownPreview.status,
      UserPortableDataPreviewStatus.unsupportedSchema,
    );
    expect(unknownPreview.unsupportedFields, contains(r'$.futureField'));
    expect(unknownPreview.mayProceedToFutureImport, isFalse);
  });

  test('manifest privacy and owner semantics fail closed', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final root = _root(artifact.prettyJson);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map);
    final privacy = Map<String, Object?>.from(
      manifest['privacyBoundary'] as Map,
    )..['encryption'] = 'misleading-encrypted-claim';
    manifest['privacyBoundary'] = privacy;
    root['manifest'] = manifest;

    final preview = service.inspect(
      packageJson: jsonEncode(root),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.mayProceedToFutureImport, isFalse);

    expect(
      () => service.create(
        snapshot: UserPortableDataSnapshot(
          userScope: _scope,
          scopeKind: 'unreviewed_scope',
          profile: UserProfile.defaults(),
          activeDrugIds: const <String>[],
          intakes: const <Intake>[],
          meals: const <Meal>[],
          medicationCatalog: const <DrugDefinition>[],
          foodCatalog: const <FoodItem>[],
          reminders: const <UserLoggingReminder>[],
        ),
        generatedAt: generatedAt,
      ),
      throwsArgumentError,
    );
  });

  test('deep unknown field is reported after a self-consistent rehash', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final root = _root(artifact.prettyJson);
    final files = Map<String, Object?>.from(root['files'] as Map);
    final intakes = List<Object?>.from(files['intakes.json'] as List);
    final first = Map<String, Object?>.from(intakes.first as Map);
    final dose = Map<String, Object?>.from(first['dose'] as Map)
      ..['futureDoseSemantics'] = 'must_not_be_ignored';
    first['dose'] = dose;
    intakes[0] = first;
    files['intakes.json'] = intakes;
    root['files'] = files;

    final preview = service.inspect(
      packageJson: _resign(root),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.unsupportedSchema);
    expect(
      preview.unsupportedFields,
      contains(r'$.files.intakes.json[0].dose.futureDoseSemantics'),
    );
  });

  test('self-resigned scalar and domain violations never become ready', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );

    final mutations = <String, void Function(Map<String, Object?> root)>{
      'non-string intake timestamp': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['intakes.json'] as List);
        rows[0] = Map<String, Object?>.from(rows[0] as Map)..['takenAt'] = 123;
        files['intakes.json'] = rows;
        root['files'] = files;
      },
      'non-numeric dose': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['intakes.json'] as List);
        final row = Map<String, Object?>.from(rows[0] as Map);
        row['dose'] = Map<String, Object?>.from(row['dose'] as Map)
          ..['amount'] = 'x';
        rows[0] = row;
        files['intakes.json'] = rows;
        root['files'] = files;
      },
      'missing required dose key': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['intakes.json'] as List);
        final row = Map<String, Object?>.from(rows[0] as Map);
        row['dose'] = Map<String, Object?>.from(row['dose'] as Map)
          ..remove('unit');
        rows[0] = row;
        files['intakes.json'] = rows;
        root['files'] = files;
      },
      'invalid reminder weekdays': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['reminders.json'] as List);
        rows[0] = Map<String, Object?>.from(rows[0] as Map)
          ..['weekdays'] = <int>[0, 8];
        files['reminders.json'] = rows;
        root['files'] = files;
      },
      'invalid reminder minute': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['reminders.json'] as List);
        rows[0] = Map<String, Object?>.from(rows[0] as Map)
          ..['minuteOfDay'] = 1440;
        files['reminders.json'] = rows;
        root['files'] = files;
      },
      'nutrient null-zero contradiction': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final meals = List<Object?>.from(files['meals.json'] as List);
        final meal = Map<String, Object?>.from(meals[0] as Map);
        final items = List<Object?>.from(meal['items'] as List);
        final item = Map<String, Object?>.from(items[0] as Map);
        final nutrients = Map<String, Object?>.from(
          item['nutrientsPer100g'] as Map,
        );
        nutrients['protein'] =
            Map<String, Object?>.from(nutrients['protein'] as Map)
              ..['missing'] = false
              ..['value'] = 0.0;
        item['nutrientsPer100g'] = nutrients;
        items[0] = item;
        meal['items'] = items;
        meals[0] = meal;
        files['meals.json'] = meals;
        root['files'] = files;
      },
      'quantity cross-field mismatch': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final meals = List<Object?>.from(files['meals.json'] as List);
        final meal = Map<String, Object?>.from(meals[0] as Map);
        final items = List<Object?>.from(meal['items'] as List);
        final item = Map<String, Object?>.from(items[0] as Map);
        item['quantity'] = Map<String, Object?>.from(item['quantity'] as Map)
          ..['grams'] = -1.0;
        items[0] = item;
        meal['items'] = items;
        meals[0] = meal;
        files['meals.json'] = meals;
        root['files'] = files;
      },
      'audit relationship mismatch': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final audit = Map<String, Object?>.from(
          files['audit_links.json'] as Map,
        );
        final links = List<Object?>.from(audit['links'] as List);
        links.removeLast();
        audit['links'] = links;
        files['audit_links.json'] = audit;
        root['files'] = files;
      },
    };

    for (final mutation in mutations.entries) {
      final root = _root(artifact.prettyJson);
      mutation.value(root);
      final preview = service.inspect(
        packageJson: _resign(root),
        currentUserScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(
        preview.status,
        isNot(UserPortableDataPreviewStatus.ready),
        reason: mutation.key,
      );
      expect(preview.mayProceedToFutureImport, isFalse, reason: mutation.key);
    }
  });

  test('manifest hash/count types and owner kind fail closed', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );

    final countRoot = _root(artifact.prettyJson);
    final countManifest = Map<String, Object?>.from(
      countRoot['manifest'] as Map,
    );
    final manifestFiles = List<Object?>.from(countManifest['files'] as List);
    manifestFiles[0] = Map<String, Object?>.from(manifestFiles[0] as Map)
      ..['recordCount'] = 1.0;
    countManifest['files'] = manifestFiles;
    countRoot['manifest'] = countManifest;
    final countPreview = service.inspect(
      packageJson: jsonEncode(countRoot),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(countPreview.status, UserPortableDataPreviewStatus.corrupt);

    final kindRoot = _root(artifact.prettyJson);
    final kindManifest = Map<String, Object?>.from(kindRoot['manifest'] as Map);
    kindManifest['ownerScope'] = Map<String, Object?>.from(
      kindManifest['ownerScope'] as Map,
    )..['kind'] = 'local_device_account';
    kindRoot['manifest'] = kindManifest;
    final kindPreview = service.inspect(
      packageJson: jsonEncode(kindRoot),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(kindPreview.status, isNot(UserPortableDataPreviewStatus.ready));
  });

  test('unexpected structural exceptions never echo private input', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    const privateSentinel = '/private/account/path/secret-value';
    final root = _root(artifact.prettyJson);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map)
      ..['packageId'] = <String, Object?>{'private': privateSentinel};
    root['manifest'] = manifest;

    final preview = service.inspect(
      packageJson: jsonEncode(root),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings, isNotEmpty);
    expect(preview.findings.join(' '), isNot(contains(privateSentinel)));
  });

  test('malformed JSON errors do not reflect private source text', () {
    const privateSentinel = 'private-email@example.test';
    final preview = service.inspect(
      packageJson: '{"private":"$privateSentinel","invalid":tru}',
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(
      preview.findings.single,
      'The package is not valid JSON or exceeds a structural safety budget.',
    );
    expect(preview.findings.single, isNot(contains(privateSentinel)));
  });

  test('duplicate JSON keys are rejected before document decoding', () {
    var decodeCalls = 0;
    final guarded = UserPortableDataPackageService(
      decodeJson: (source) {
        decodeCalls += 1;
        return jsonDecode(source);
      },
    );
    final preview = guarded.inspect(
      packageJson: '{"format":"a","\\u0066ormat":"b"}',
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings.single, contains('Duplicate JSON object keys'));
    expect(decodeCalls, 0);
  });

  test('oversize numeric token is rejected before document decoding', () {
    var decodeCalls = 0;
    final decoderSpy = UserPortableDataPackageService(
      decodeJson: (source) {
        decodeCalls += 1;
        return jsonDecode(source);
      },
    );
    final preview = decoderSpy.inspect(
      packageJson:
          '{"value":${List<String>.filled(userPortableDataMaxNumberTokenChars + 1, '1').join()}}',
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings.single, contains('number'));
    expect(decodeCalls, 0);
  });

  test('shallow over-node input is rejected before document decoding', () {
    var decodeCalls = 0;
    final guarded = UserPortableDataPackageService(
      decodeJson: (source) {
        decodeCalls += 1;
        throw StateError('full decoder must not run');
      },
    );
    final source =
        '[${List<String>.filled(userPortableDataMaxJsonNodes, '0').join(',')}]';
    final stopwatch = Stopwatch()..start();
    final preview = guarded.inspect(
      packageJson: source,
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    stopwatch.stop();
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings.single, contains('node JSON budget'));
    expect(decodeCalls, 0);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test(
    'preview reports conflicts while remaining a pure no-write operation',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final before = artifact.canonicalJson;
      final preview = service.inspect(
        packageJson: artifact.canonicalJson,
        currentUserScope: _scope,
        currentScopeKind: _scopeKind,
        existingRecordIds: const <String, Set<String>>{
          'intakes.json': <String>{'intake_zero'},
          'meals.json': <String>{'meal_1'},
        },
      );
      expect(preview.status, UserPortableDataPreviewStatus.ready);
      expect(preview.conflictCount, 2);
      expect(preview.conflicts['intakes.json'], ['intake_zero']);
      expect(artifact.canonicalJson, before);
      expect(preview.findings.last, contains('no record'));
    },
  );

  test('generation rejects duplicate and unsafe stable ids', () {
    expect(
      () => service.create(
        snapshot: _snapshot(activeDrugIds: const ['drug_test', 'drug_test']),
        generatedAt: generatedAt,
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(
          intakes: <Intake>[
            ..._intakes,
            Intake(
              id: '../unsafe',
              drugId: 'drug_test',
              takenAt: generatedAt,
              dosageNote: '',
            ),
          ],
        ),
        generatedAt: generatedAt,
      ),
      throwsFormatException,
    );
  });

  test(
    'self-consistent unsafe input id is rejected after integrity checks',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final root = _root(artifact.prettyJson);
      final files = Map<String, Object?>.from(root['files'] as Map);
      final rows = List<Object?>.from(files['intakes.json'] as List);
      final first = Map<String, Object?>.from(rows.first as Map)
        ..['id'] = '../unsafe';
      rows[0] = first;
      files['intakes.json'] = rows;
      root['files'] = files;
      final resigned = _resign(root);

      final preview = service.inspect(
        packageJson: resigned,
        currentUserScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(preview.status, UserPortableDataPreviewStatus.corrupt);
      expect(preview.findings.join(' '), contains('unsafe id'));
    },
  );

  test('input byte, depth, string, map, and record budgets fail closed', () {
    const tiny = UserPortableDataPackageService(maxPackageBytes: 64);
    final bytes = tiny.inspect(
      packageJson: '{"padding":"${List.filled(80, 'x').join()}"}',
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(bytes.status, UserPortableDataPreviewStatus.corrupt);
    expect(bytes.findings.single, contains('byte input budget'));

    var decodedOversizeSource = false;
    final decoderSpy = UserPortableDataPackageService(
      maxPackageBytes: 64,
      decodeJson: (source) {
        decodedOversizeSource = true;
        return jsonDecode(source);
      },
    );
    final obviousOversize = decoderSpy.inspect(
      packageJson: List<String>.filled(65, 'x').join(),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(obviousOversize.status, UserPortableDataPreviewStatus.corrupt);
    expect(decodedOversizeSource, isFalse);

    final deep = service.inspect(
      packageJson:
          '${List.filled(userPortableDataMaxJsonDepth + 1, '[').join()}'
          '${List.filled(userPortableDataMaxJsonDepth + 1, ']').join()}',
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(deep.status, UserPortableDataPreviewStatus.corrupt);
    expect(deep.findings.single, contains('nesting depth'));

    final longString = service.inspect(
      packageJson: jsonEncode(<String, Object?>{
        'value': List.filled(userPortableDataMaxStringBytes + 1, 'x').join(),
      }),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(longString.status, UserPortableDataPreviewStatus.corrupt);
    expect(longString.findings.single, contains('string limit'));

    final wideMap = service.inspect(
      packageJson: jsonEncode(<String, Object?>{
        for (var i = 0; i <= userPortableDataMaxMapFields; i++) 'f$i': i,
      }),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(wideMap.status, UserPortableDataPreviewStatus.corrupt);
    expect(wideMap.findings.single, contains('fields'));

    final overRecords = <String, Object?>{
      'format': userPortableDataPackageFormat,
      'schemaVersion': userPortableDataPackageSchemaVersion,
      'manifest': <String, Object?>{},
      'files': <String, Object?>{
        'profile.json': <String, Object?>{},
        'preferences.json': <String, Object?>{},
        'medication_selections.json': <Object?>[
          for (
            var i = 0;
            i <= userPortableDataRecordLimits['medication_selections.json']!;
            i++
          )
            <String, Object?>{'id': 'drug_$i'},
        ],
        'intakes.json': <Object?>[],
        'meals.json': <Object?>[],
        'reminders.json': <Object?>[],
        'audit_links.json': <String, Object?>{'links': <Object?>[]},
      },
    };
    final records = service.inspect(
      packageJson: jsonEncode(overRecords),
      currentUserScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(records.status, UserPortableDataPreviewStatus.corrupt);
    expect(records.findings.single, contains('limit is'));
  });
}

const _scope = 'firebase_uid_Q7yN8Zx5X2';
const _scopeKind = 'firebase_authenticated_account';
const _patientId = 'patient-id-that-must-not-export';
const _email = 'sensitive@example.test';
const _activationToken = '0123456789abcdef0123456789abcdef';
const _ollamaEndpoint = 'http://127.0.0.1:11434/private-test';
const _openAiEndpoint = 'http://127.0.0.1:8080/private-test';

final _intakes = <Intake>[
  Intake(
    id: 'intake_null',
    drugId: 'drug_test',
    takenAt: DateTime.utc(2026, 8, 17, 11),
    dosageNote: 'unknown amount',
  ),
  Intake(
    id: 'intake_zero',
    drugId: 'drug_test',
    takenAt: DateTime.utc(2026, 8, 17, 12),
    dosageNote: 'explicit zero fixture',
    doseAmount: 0,
    doseUnit: 'mg',
    dosageForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate_release',
  ),
];

UserPortableDataSnapshot _snapshot({
  bool reverse = false,
  Iterable<String>? activeDrugIds,
  Iterable<Intake>? intakes,
}) {
  var values = intakes?.toList() ?? List<Intake>.from(_intakes);
  if (reverse) values = values.reversed.toList();
  final foods = <FoodItem>[
    FoodItem(
      id: 'food_missing',
      name: 'Missing protein fixture',
      category: FoodCategory.other,
      proteinG: 0,
      carbsG: 2,
      fatG: 1,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: const {'proteinG'},
      sourceSystem: 'TEST_FOOD',
      sourceFoodCode: 'MISSING-1',
      jurisdiction: 'CA',
      basisType: 'per_100g',
      preparationState: 'cooked',
      qualifierKind: 'analytical',
    ),
    FoodItem(
      id: 'food_zero',
      name: 'True zero fixture',
      category: FoodCategory.other,
      proteinG: 0,
      carbsG: 3,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: const {},
      sourceSystem: 'TEST_FOOD',
      sourceFoodCode: 'ZERO-1',
      jurisdiction: 'CA',
      basisType: 'per_100g',
      preparationState: 'raw',
      qualifierKind: 'analytical',
    ),
  ];
  final meal = Meal(
    id: 'meal_1',
    eatenAt: DateTime.utc(2026, 8, 17, 13),
    recordedAt: DateTime.utc(2026, 8, 17, 13, 5),
    occurredAt: DateTime.utc(2026, 8, 17, 12, 55),
    timeSource: 'user_entered',
    timePrecision: 'exact',
    title: 'Fixture meal',
    items: <MealItem>[
      MealItem.fromFood(food: foods[0], quantityFactor: 1),
      MealItem.fromFood(food: foods[1], quantityFactor: 0.5),
    ],
  );
  final reminders = <UserLoggingReminder>[
    const UserLoggingReminder(
      id: 'reminder_1',
      kind: UserLoggingReminderKind.intakeLog,
      label: 'User-authored label',
      minuteOfDay: 540,
      weekdays: {1, 3, 5},
      enabled: true,
      activationToken: _activationToken,
    ),
  ];
  final drugs = <DrugDefinition>[
    DrugDefinition(
      id: 'drug_test',
      genericName: 'Test medicine',
      brandNames: const ['Fixture'],
      tags: const [DrugTag.unknown],
      notes: 'Fixture only',
      sourceSystem: 'TEST_LABEL',
      sourceProductCode: 'LABEL-1',
      jurisdiction: 'CA',
      route: 'oral',
      dosageForm: 'tablet',
      releaseType: 'immediate_release',
    ),
  ];
  if (reverse) {
    foods.setAll(0, foods.reversed.toList());
    drugs.setAll(0, drugs.reversed.toList());
    reminders.setAll(0, reminders.reversed.toList());
  }
  return UserPortableDataSnapshot(
    userScope: _scope,
    scopeKind: _scopeKind,
    profile: UserProfile.defaults()
        .copyWith(
          patientId: _patientId,
          displayLocale: 'en-US',
          contentJurisdictionOverride: const ['US', 'CA'],
          localAiOllamaEndpoint: _ollamaEndpoint,
          localAiOpenAiCompatEndpoint: _openAiEndpoint,
        )
        .withLocalAiConsentDecision(
          enabled: true,
          recordedAt: DateTime.utc(2026, 8, 18),
          source: 'test_fixture',
        ),
    activeDrugIds: activeDrugIds ?? const ['drug_test'],
    intakes: values,
    meals: <Meal>[meal],
    medicationCatalog: drugs,
    foodCatalog: foods,
    reminders: reminders,
  );
}

Map<String, Object?> _root(String json) =>
    Map<String, Object?>.from(jsonDecode(json) as Map);

Map<String, Object?> _files(String json) =>
    Map<String, Object?>.from(_root(json)['files'] as Map);

String _resign(Map<String, Object?> root) {
  final files = Map<String, Object?>.from(root['files'] as Map);
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final owner = Map<String, Object?>.from(manifest['ownerScope'] as Map);
  final integrity = Map<String, Object?>.from(manifest['integrity'] as Map);
  final contentSha = _digest(_canonical(files));
  integrity['contentSha256'] = contentSha;
  final packageId = _digest(
    'parkinsum-portable-package-v1|${owner['bindingSha256']}|$contentSha',
  );
  manifest['packageId'] = packageId;
  manifest['integrity'] = integrity;
  manifest['files'] = <Object?>[
    for (final path in userPortableDataFilePaths)
      <String, Object?>{
        'path': path,
        'sha256': _digest(_canonical(files[path])),
        'recordCount': _count(files[path]),
      },
  ];
  root['manifest'] = manifest;
  return _canonical(root);
}

int _count(Object? value) {
  if (value is List) return value.length;
  if (value is Map && value['links'] is List) {
    return (value['links'] as List).length;
  }
  return value is Map ? 1 : 0;
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();

String _canonical(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{for (final key in keys) key: _sorted(value[key])};
  }
  if (value is Iterable) return value.map(_sorted).toList();
  return value;
}
