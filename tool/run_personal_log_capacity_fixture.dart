import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/portable_schema_migration.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';
import 'package:parkinsum_companion/domain/usecases/portable_data_compact_transport_service.dart';
import 'package:parkinsum_companion/domain/usecases/portable_schema_migration_registry.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';
import 'package:parkinsum_companion/engineering/personal_log_view_benchmark_fixture.dart';

const _fixturePath = 'lib/engineering/personal_log_view_benchmark_fixture.dart';
const _fixtureSourceSha256 =
    '4c3d7746f28d49da50bb5e5dd0118f6a9c8ec6adf40d3a66684704432ef9c687';
const _vmRawInputSha256 =
    '523447a7df5cd46c195fbdfb063cb6d10a7fe6253954fb5171c094e69973a228';
const _originalReleaseWebRawInputSha256 =
    '97db49a275871c8fd1592ff28318a77c0a67400d8390052c74346226b6534eba';
const _owner = 'local_user';
const _scopeKind = 'local_device_account';
const _outputDirectory = 'build/personal_log_capacity/035';

void main() {
  test(
    'production synthetic 10000-meal/2000-intake capacity artifact',
    _produceFixture,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

void _produceFixture() {
  // These checks precede every artifact write. Raw JSON byte hashes qualify
  // their runtime: VM retains integral-double .0 tokens, while the historical
  // 034 release-Web hash came from browser jsonEncode. Neither is rewritten.
  _require(
    !const bool.fromEnvironment('dart.library.js_interop'),
    'capacity_fixture_producer_requires_vm',
  );
  final fixtureSourceBytes = File(_fixturePath).readAsBytesSync();
  _require(fixtureSourceBytes.length == 7096, 'fixture_source_size_changed');
  _require(
    _bytesSha256(fixtureSourceBytes) == _fixtureSourceSha256,
    'fixture_source_sha256_changed',
  );
  final fixture = PersonalLogBenchmarkFixture.generate(10000);
  final asOf = PersonalLogBenchmarkFixture.asOf;
  _require(fixture.meals.length == 10000, 'fixture_meal_count_changed');
  _require(fixture.intakes.length == 2000, 'fixture_intake_count_changed');
  _require(fixture.parameters['seed'] == 31415926, 'fixture_seed_changed');
  _require(
    asOf == DateTime.utc(2026, 9, 30, 12),
    'fixture_observation_time_changed',
  );
  _require(
    fixture.inputSha256 == _vmRawInputSha256,
    'fixture_vm_raw_input_sha256_changed',
  );
  final fixtureInput = <String, Object?>{
    'parameters': fixture.parameters,
    'foods': fixture.foods.map((row) => row.toJson()).toList(),
    'drugs': fixture.drugs.map((row) => row.toJson()).toList(),
    'meals': fixture.meals.map((row) => row.toJson()).toList(),
    'intakes': fixture.intakes.map((row) => row.toJson()).toList(),
  };
  final rawInput = jsonEncode(fixtureInput);
  _require(
    portableSha256(rawInput) == _vmRawInputSha256,
    'fixture_original_raw_encoding_changed',
  );
  final scalarValueSha256 = portableSha256(
    jsonEncode(_scalarValueWitness(fixtureInput)),
  );

  final sourcePins = <String, Object?>{
    for (final path in _sourcePaths) path: _sourcePin(path),
  };
  final configuration = <String, Object?>{
    'currentVersion': PortableSchemaMigrationRegistry.currentVersion,
    'defaultExportVersion': userPortableDataPackageSchemaVersion,
    'optionalCompactTransportVersion': userPortableDataCompactSchemaVersion,
    'readableVersions': PortableSchemaMigrationRegistry.validators
        .map((descriptor) => descriptor.version)
        .toList(),
    'compactValidator': PortableSchemaMigrationRegistry.v5.toJson(),
    'registryDigest': PortableSchemaMigrationRegistry.registryDigest,
    'dosageParser': DosageNoteParser.configurationIdentity,
    'canonicalization': userPortableDataCanonicalization,
    'wireLimits': <String, int>{
      'bytes': userPortableDataMaxPackageBytes,
      'nodes': userPortableDataMaxJsonNodes,
      'depth': userPortableDataMaxJsonDepth,
      'stringBytes': userPortableDataMaxStringBytes,
      'keyBytes': userPortableDataMaxKeyBytes,
      'numberTokenChars': userPortableDataMaxNumberTokenChars,
      'mapFields': userPortableDataMaxMapFields,
      'totalRecords': userPortableDataMaxTotalRecords,
    },
    'additionalLogicalFileLimits': <String, int>{
      'nodes': userPortableDataMaxLogicalFileNodes,
      'canonicalBytes': userPortableDataMaxLogicalFileBytes,
      'fullEnvelopeDepth': userPortableDataMaxLogicalDepth,
      'snapshotRecords': userPortableDataMaxFoodItemSnapshots,
    },
  };
  const service = UserPortableDataPackageService();
  final profile = UserProfile.defaults();
  final artifact = service.create(
    snapshot: UserPortableDataSnapshot(
      userScope: _owner,
      doseOwnerScope: _owner,
      scopeKind: _scopeKind,
      profile: profile,
      activeDrugIds: const [],
      intakes: fixture.intakes,
      meals: fixture.meals,
      medicationCatalog: fixture.drugs,
      foodCatalog: fixture.foods,
      reminders: const [],
    ),
    generatedAt: asOf,
  );
  _require(
    artifact.document['schemaVersion'] == userPortableDataCompactSchemaVersion,
    'default_export_did_not_use_compact_fallback',
  );
  final decoded = Map<String, Object?>.from(
    decodeBoundedPortableJson(artifact.canonicalJson) as Map,
  );
  final wireFiles = Map<String, Object?>.from(decoded['files'] as Map);
  final logical = PortableDataCompactTransportService.resolve(wireFiles);
  final wireNodes = _nodes(decoded);
  final wireDepth = _depth(decoded);
  final logicalNodes = _nodes(logical.files);
  final logicalCanonicalBytes = utf8
      .encode(portableCanonicalJson(logical.files))
      .length;
  final logicalEnvelopeDepth = _depth(logical.files) + 1;
  _require(wireNodes <= userPortableDataMaxJsonNodes, 'wire_nodes_exceeded');
  _require(wireDepth <= userPortableDataMaxJsonDepth, 'wire_depth_exceeded');
  _require(
    utf8.encode(artifact.canonicalJson).length <=
            userPortableDataMaxPackageBytes &&
        utf8.encode(artifact.prettyJson).length <=
            userPortableDataMaxPackageBytes,
    'wire_bytes_exceeded',
  );
  _require(
    logicalNodes == logical.logicalNodeCount,
    'independent_logical_node_count_mismatch',
  );
  _require(
    logicalCanonicalBytes == logical.logicalCanonicalBytes,
    'independent_logical_byte_count_mismatch',
  );
  _require(
    logicalNodes <= userPortableDataMaxLogicalFileNodes &&
        logicalCanonicalBytes <= userPortableDataMaxLogicalFileBytes,
    'independent_logical_budget_exceeded',
  );
  _require(
    logicalEnvelopeDepth <= userPortableDataMaxLogicalDepth,
    'independent_logical_depth_exceeded',
  );
  final inspection = service.inspect(
    packageJson: artifact.canonicalJson,
    currentUserScope: _owner,
    currentDoseOwnerScope: _owner,
    currentScopeKind: _scopeKind,
  );
  _require(
    inspection.status == UserPortableDataPreviewStatus.ready &&
        inspection.schemaVersion == userPortableDataCompactSchemaVersion &&
        inspection.conflictCount == 0 &&
        inspection.schemaMigrationReceipt?.decision ==
            'not_required_compact_transport',
    'production_inspection_rejected',
  );
  final emptyState = PortableDataRestoreState(<String, Object?>{
    'profile': profile.toJson(),
    'activeDrugIds': <String>[],
    'intakes': <Object?>[],
    'meals': <Object?>[],
    'eventHistory': <Object?>[],
  });
  final payload = service.prepareLocalRestore(
    packageJson: artifact.canonicalJson,
    currentUserScope: _owner,
    currentDoseOwnerScope: _owner,
    currentScopeKind: _scopeKind,
    currentState: emptyState,
    foodCatalog: fixture.foods,
    medicationCatalog: fixture.drugs,
  );
  final payloadJson = payload.json;
  final originalMeals = _rowsById(
    fixture.meals.map((row) => row.toJson()).toList(),
  );
  final originalIntakes = _rowsById(
    fixture.intakes.map((row) => row.toJson()).toList(),
  );
  final restoredMeals = _rowsById(payloadJson['meals'] as List);
  final restoredIntakes = _rowsById(payloadJson['intakes'] as List);
  _require(
    portableCanonicalJson(originalMeals) ==
        portableCanonicalJson(restoredMeals),
    'whole_meal_row_roundtrip_mismatch',
  );
  _require(
    portableCanonicalJson(originalIntakes) ==
        portableCanonicalJson(restoredIntakes),
    'whole_intake_row_roundtrip_mismatch',
  );
  _require(
    portableCanonicalJson(payloadJson['profile']) ==
            portableCanonicalJson(profile.toJson()) &&
        (payloadJson['activeDrugIds'] as List).isEmpty,
    'profile_or_selection_roundtrip_mismatch',
  );
  final reexport = service.create(
    snapshot: UserPortableDataSnapshot(
      userScope: _owner,
      doseOwnerScope: _owner,
      scopeKind: _scopeKind,
      profile: UserProfile.fromJson(
        Map<String, dynamic>.from(payloadJson['profile'] as Map),
      ),
      activeDrugIds: (payloadJson['activeDrugIds'] as List).cast<String>(),
      intakes: (payloadJson['intakes'] as List).map(
        (raw) => Intake.fromJson(Map<String, dynamic>.from(raw as Map)),
      ),
      meals: (payloadJson['meals'] as List).map(
        (raw) => Meal.fromJson(Map<String, dynamic>.from(raw as Map)),
      ),
      medicationCatalog: fixture.drugs,
      foodCatalog: fixture.foods,
      reminders: const [],
    ),
    generatedAt: asOf,
    preferCompactTransport: true,
  );
  _require(
    reexport.canonicalJson == artifact.canonicalJson,
    'whole_package_same_version_reexport_mismatch',
  );
  final originalEvidence = _capturedEvidence(logical.files, asOf);
  final restoredEvidence = _capturedEvidence(
    PortableDataCompactTransportService.resolve(
      Map<String, Object?>.from(reexport.document['files'] as Map),
    ).files,
    asOf,
  );
  _require(
    portableCanonicalJson(originalEvidence) ==
        portableCanonicalJson(restoredEvidence),
    'unknown_zero_quantity_or_time_roundtrip_mismatch',
  );
  for (final key in const [
    'unknownProteinItems',
    'raw999ProteinItems',
    'reportedZeroProteinItems',
    'invalidZeroQuantityItems',
  ]) {
    _require(originalEvidence[key] == 1000, 'fixture_evidence_changed:$key');
  }

  // Only the isolated synthetic input and package are saved. Existing bytes
  // may be reused after complete equality; a different artifact is never
  // overwritten, and each execution receives its own report file.
  final inputFile = _preserveArtifact(
    '$_outputDirectory/fixture_input.json',
    utf8.encode(rawInput),
  );
  final packageFile = _preserveArtifact(
    '$_outputDirectory/fixture.parkinsum.json',
    utf8.encode(artifact.canonicalJson),
  );
  final reportBody = <String, Object?>{
    'pass': true,
    'executedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'runtime': <String, Object?>{
      'dartVersion': Platform.version,
      'operatingSystem': Platform.operatingSystem,
      'isWeb': false,
      'hashDomain': 'Dart VM original jsonEncode bytes including .0 tokens',
    },
    'fixture': <String, Object?>{
      'parameters': fixture.parameters,
      'generatorSource': _sourcePin(_fixturePath),
      'inputSha256': fixture.inputSha256,
      'rawVmInputSha256': _vmRawInputSha256,
      'historical034ReleaseWebRawInputSha256':
          _originalReleaseWebRawInputSha256,
      'historicalRawHashDomain':
          'Original 034 Chrome 154 release-Web isWeb:true jsonEncode bytes; '
          'different runtime encoding, not this VM input file SHA.',
      'canonicalSnapshotSha256': portableCanonicalSha256(fixtureInput),
      'scalarValueSha256': scalarValueSha256,
      'scalarValueContract':
          'Every value is tagged: null=[null], bool=[bool,value], '
          'string=[string,value], list=[list,tagged children], '
          'map=[map,sorted [string key,tagged value] pairs], '
          'number=[number-f64be,16 lowercase hex IEEE754 binary64 '
          'big-endian bits]. Finite numeric values only; integers must fit '
          'the exact 53-bit range. Numeric types normalize by full binary64 '
          'value; negative zero retains its sign bit. SHA256 of UTF8 '
          'jsonEncode of the complete tagged input. This domain is separate '
          'from raw JSON and sorted-key wire canonicalization.',
      'originalInputArtifact': inputFile,
    },
    'configuration': configuration,
    'configurationSha256': portableCanonicalSha256(configuration),
    'selectedSourcePins': sourcePins,
    'selectedSourcePinsSha256': portableCanonicalSha256(sourcePins),
    'artifact': <String, Object?>{
      ...packageFile,
      'schemaVersion': artifact.document['schemaVersion'],
      'defaultCreateFallbackUsed': true,
      'packageId': artifact.packageId,
      'contentSha256': artifact.contentSha256,
      'ownerScopeSha256': artifact.ownerScopeSha256,
      'wireNodeCount': wireNodes,
      'wireMaxDepth': wireDepth,
      'prettyJsonBytes': utf8.encode(artifact.prettyJson).length,
      'logicalFileNodeCount': logicalNodes,
      'logicalFileCanonicalBytes': logicalCanonicalBytes,
      'logicalFullEnvelopeMaxDepth': logicalEnvelopeDepth,
      'snapshotCount':
          (wireFiles[userPortableDataFoodItemSnapshotsPath] as List).length,
      'files': <Object?>[
        for (final file in artifact.files)
          <String, Object?>{
            'path': file.path,
            'recordCount': file.recordCount,
            'sha256': file.sha256,
            'canonicalBytes': utf8
                .encode(portableCanonicalJson(wireFiles[file.path]))
                .length,
          },
      ],
      'inspection': <String, Object?>{
        'status': inspection.status.name,
        'schemaVersion': inspection.schemaVersion,
        'packageId': inspection.packageId,
        'recordCounts': inspection.recordCounts,
        'conflicts': inspection.conflicts,
        'unsupportedFields': inspection.unsupportedFields,
        'proposedMigrations': inspection.proposedMigrations,
        'findings': inspection.findings,
        'schemaMigrationReceipt': inspection.schemaMigrationReceipt?.toJson(),
      },
    },
    'restoreProjection': <String, Object?>{
      'mealCount': restoredMeals.length,
      'intakeCount': restoredIntakes.length,
      'all12000WholeRowsComparedByTypedId': true,
      'originalMealRowsSha256': portableCanonicalSha256(originalMeals),
      'restoredMealRowsSha256': portableCanonicalSha256(restoredMeals),
      'originalIntakeRowsSha256': portableCanonicalSha256(originalIntakes),
      'restoredIntakeRowsSha256': portableCanonicalSha256(restoredIntakes),
      'payloadSha256': portableSha256(payload.canonicalJson),
      'emptyTargetStateDigest': emptyState.digest,
      'sameVersionWholePackageReexportExact': true,
      'sameVersionReexportJsonSha256': portableSha256(reexport.canonicalJson),
      'capturedEvidence': originalEvidence,
      'durableWritePerformed': false,
      'rollbackExecuted': false,
    },
    'boundary':
        'Synthetic fixed-fixture production create, bounded decode, inspect, '
        'restore projection and exact same-version re-export only. Full row '
        'comparison includes captured unknowns, raw compatibility values, '
        'reference quantities and times. No real user data, durable storage '
        'commit/readback/rollback, performance measurement, clinical '
        'effectiveness, issuer authenticity or medical correctness claim. '
        'Selected source pins bind this producer; a whole-workspace QA receipt '
        'is a separate evidence scope.',
  };
  final report = <String, Object?>{
    ...reportBody,
    'reportSha256': portableCanonicalSha256(reportBody),
  };
  final reportPath =
      '$_outputDirectory/report-'
      '${DateTime.now().toUtc().microsecondsSinceEpoch}-$pid.json';
  final reportFile = _preserveArtifact(
    reportPath,
    utf8.encode('${const JsonEncoder.withIndent('  ').convert(report)}\n'),
  );
  stdout.writeln(
    'Synthetic capacity fixture PASS: '
    '10000 meals / 2000 intakes; wire=$wireNodes nodes; '
    'logical=$logicalNodes nodes / $logicalCanonicalBytes bytes; '
    'input=${fixture.inputSha256}; report=${reportFile['path']}; '
    'reportFileSha256=${reportFile['sha256']}',
  );
}

const _sourcePaths = <String>[
  _fixturePath,
  'tool/run_personal_log_capacity_fixture.dart',
  'lib/core/models/food_item.dart',
  'lib/core/models/drug_definition.dart',
  'lib/core/models/intake.dart',
  'lib/core/models/meal.dart',
  'lib/core/models/user_profile.dart',
  'lib/core/models/portable_data_restore.dart',
  'lib/domain/entities/portable_schema_migration.dart',
  'lib/domain/entities/dose_expression.dart',
  'lib/domain/entities/versioned_dose_unit_mapping.dart',
  'lib/domain/usecases/dosage_note_parser.dart',
  'lib/domain/usecases/administration_dose_confirmation_coordinator.dart',
  'lib/domain/usecases/portable_schema_migration_registry.dart',
  'lib/domain/usecases/portable_data_compact_transport_service.dart',
  'lib/domain/usecases/user_portable_data_package_service.dart',
];

void _require(bool condition, String code) {
  if (!condition) throw StateError(code);
}

String _bytesSha256(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, Object?> _sourcePin(String path) {
  final bytes = File(path).readAsBytesSync();
  return <String, Object?>{
    'bytes': bytes.length,
    'sha256': _bytesSha256(bytes),
  };
}

Map<String, Object?> _preserveArtifact(String path, List<int> bytes) {
  final file = File(path);
  var reused = false;
  if (file.existsSync()) {
    final previous = file.readAsBytesSync();
    _require(
      previous.length == bytes.length &&
          _bytesSha256(previous) == _bytesSha256(bytes) &&
          _equalBytes(previous, bytes),
      'existing_artifact_differs:$path',
    );
    reused = true;
  } else {
    file.parent.createSync(recursive: true);
    file.createSync(exclusive: true);
    final handle = file.openSync(mode: FileMode.append);
    try {
      _require(handle.lengthSync() == 0, 'artifact_raced_before_write:$path');
      handle.writeFromSync(bytes);
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
  }
  final actual = file.readAsBytesSync();
  _require(_equalBytes(actual, bytes), 'artifact_readback_mismatch:$path');
  return <String, Object?>{
    'path': path,
    'bytes': actual.length,
    'sha256': _bytesSha256(actual),
    'reusedExistingExactBytes': reused,
  };
}

bool _equalBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

int _nodes(Object? value) =>
    1 +
    (value is Map
        ? value.values.fold<int>(0, (sum, child) => sum + _nodes(child))
        : value is List
        ? value.fold<int>(0, (sum, child) => sum + _nodes(child))
        : 0);

int _depth(Object? value) {
  final children = value is Map
      ? value.values
      : value is List
      ? value
      : const <Object?>[];
  var childDepth = 0;
  for (final child in children) {
    final measured = _depth(child);
    if (measured > childDepth) childDepth = measured;
  }
  return childDepth + 1;
}

Map<String, Object?> _rowsById(List rows) {
  final result = <String, Object?>{};
  for (final raw in rows) {
    final row = Map<String, Object?>.from(raw as Map);
    final id = row['id'] as String;
    _require(!result.containsKey(id), 'duplicate_typed_row_id:$id');
    result[id] = row;
  }
  return result;
}

Map<String, int> _capturedEvidence(Map<String, Object?> files, DateTime asOf) {
  var unknown = 0;
  var raw999 = 0;
  var reportedZero = 0;
  var invalidQuantity = 0;
  var futureMeals = 0;
  var futureIntakes = 0;
  for (final raw in files['meals.json'] as List) {
    final meal = raw as Map;
    final time = meal['time'] as Map;
    if (DateTime.parse(time['eatenAt'] as String).isAfter(asOf)) futureMeals++;
    for (final rawItem in meal['items'] as List) {
      final item = rawItem as Map;
      final protein = (item['nutrientsPer100g'] as Map)['protein'] as Map;
      if (protein['missing'] == true && protein['value'] == null) unknown++;
      if (protein['rawCompatibilityValue'] == 999) raw999++;
      if (protein['missing'] == false && protein['value'] == 0) reportedZero++;
      if ((item['quantity'] as Map)['factorPer100g'] == 0) invalidQuantity++;
    }
  }
  for (final raw in files['intakes.json'] as List) {
    final intake = raw as Map;
    if (DateTime.parse(intake['takenAt'] as String).isAfter(asOf)) {
      futureIntakes++;
    }
  }
  return <String, int>{
    'unknownProteinItems': unknown,
    'raw999ProteinItems': raw999,
    'reportedZeroProteinItems': reportedZero,
    'invalidZeroQuantityItems': invalidQuantity,
    'futureMealRows': futureMeals,
    'futureIntakeRows': futureIntakes,
  };
}

Object _scalarValueWitness(Object? value) {
  if (value == null) return <Object?>['null'];
  if (value is bool) return <Object?>['bool', value];
  if (value is String) return <Object?>['string', value];
  if (value is num) {
    _require(value.isFinite, 'nonfinite_fixture_scalar');
    if (value is int) {
      _require(
        value >= -9007199254740991 && value <= 9007199254740991,
        'fixture_integer_outside_exact_binary64_range',
      );
    }
    final bits = ByteData(8)..setFloat64(0, value.toDouble(), Endian.big);
    return <Object?>[
      'number-f64be',
      <String>[
        for (var index = 0; index < 8; index++)
          bits.getUint8(index).toRadixString(16).padLeft(2, '0'),
      ].join(),
    ];
  }
  if (value is List) {
    return <Object?>[
      'list',
      value.map(_scalarValueWitness).toList(growable: false),
    ];
  }
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <Object?>[
      'map',
      <Object?>[
        for (final key in keys) <Object?>[key, _scalarValueWitness(value[key])],
      ],
    ];
  }
  throw StateError('unsupported_fixture_scalar_type:${value.runtimeType}');
}
