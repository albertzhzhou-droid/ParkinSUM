// Independent release-only synthetic engineering diagnostic.
// Its build/source receipt is supplied by the supervising runner, never invented here.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/core/services/portable_data_export_sink.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_factory.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_indexeddb.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/portable_data_restore_coordinator.dart';
import 'package:parkinsum_companion/domain/entities/portable_schema_migration.dart';
import 'package:parkinsum_companion/domain/usecases/portable_data_compact_transport_service.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';
import 'package:parkinsum_companion/engineering/personal_log_view_benchmark_fixture.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:web/web.dart' as web;

const _fixtureSha256 =
    '97db49a275871c8fd1592ff28318a77c0a67400d8390052c74346226b6534eba';
const _pulseKey = 'parkinsum.user_state.revision.v1';
const _ownedPrefix = 'parkinsum.synthetic.user-state.release-probe.';
const _owner = 'local_user';
const _kind = 'local_device_account';
const _packageService = UserPortableDataPackageService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _ProbePage()));
}

_ProbeRun? _activeRun;

class _ProbePage extends StatefulWidget {
  const _ProbePage();
  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  _ProbeRun? _run;
  bool _started = false;
  bool _busy = false;
  bool _downloading = false;
  bool _downloadingReport = false;
  Map<String, Object?>? _reportDownloadReceipt;

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (_started) return;
    setState(() {
      _started = true;
      _busy = true;
    });
    final run = _ProbeRun(_refresh);
    _run = run;
    _activeRun = run;
    await run.execute();
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _download() async {
    final run = _run;
    final artifact = run?.verifiedArtifact;
    if (run == null || artifact == null || _downloading || !run.passed) return;
    setState(() {
      _downloading = true;
    });
    try {
      // A normal user-triggered call to the same public browser export sink.
      // The gateway acknowledgement cannot observe an actual filesystem write.
      final result = await const PortableDataExportSink().save(
        fileName: artifact.fileName,
        contents: artifact.prettyJson,
        authorize: () =>
            run.passed && identical(run.verifiedArtifact, artifact),
      );
      run.report['download'] = <String, Object?>{
        'status': 'gateway_invocation_completed',
        'requestedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'fileName': artifact.fileName,
        'utf8Bytes': utf8.encode(artifact.prettyJson).length,
        'sha256': portableRestoreBytesDigest(artifact.prettyJson),
        'delivery': result.delivery,
        'location': result.location,
        'userVisible': result.userVisible,
        'actualFileWriteObserved': false,
      };
    } catch (error) {
      run.report['download'] = <String, Object?>{
        'status': 'gateway_failed',
        'error': error.toString(),
        'actualFileWriteObserved': false,
      };
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<void> _downloadReport() async {
    final run = _run;
    if (run == null ||
        _busy ||
        _downloadingReport ||
        !const ['passed', 'failed'].contains(run.report['status'])) {
      return;
    }
    // Export the complete terminal report as captured on this user click.
    // Delivery metadata stays separate so the file does not hash itself.
    const fileName =
        'parkinsum-support-synthetic-release-probe-result.support.json';
    final requestedAtUtc = DateTime.now().toUtc().toIso8601String();
    final contents = const JsonEncoder.withIndent('  ').convert(run.report);
    final bytes = utf8.encode(contents).length;
    final digest = portableRestoreBytesDigest(contents);
    setState(() {
      _downloadingReport = true;
    });
    try {
      final result = await const PortableDataExportSink().save(
        fileName: fileName,
        contents: contents,
        authorize: () =>
            identical(_run, run) &&
            !_busy &&
            const ['passed', 'failed'].contains(run.report['status']),
      );
      _reportDownloadReceipt = <String, Object?>{
        'status': 'gateway_invocation_completed',
        'requestedAtUtc': requestedAtUtc,
        'fileName': fileName,
        'utf8Bytes': bytes,
        'sha256': digest,
        'delivery': result.delivery,
        'location': result.location,
        'userVisible': result.userVisible,
        'actualFileWriteObserved': false,
      };
    } catch (error) {
      _reportDownloadReceipt = <String, Object?>{
        'status': 'gateway_failed',
        'error': error.toString(),
        'requestedAtUtc': requestedAtUtc,
        'fileName': fileName,
        'utf8Bytes': bytes,
        'sha256': digest,
        'actualFileWriteObserved': false,
      };
    } finally {
      if (mounted) {
        setState(() {
          _downloadingReport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final json = const JsonEncoder.withIndent('  ').convert(
      run?.report ??
          {
            'kind': 'parkinsum_synthetic_user_state_release_probe',
            'status': 'not_started',
          },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('合成数据持久化诊断')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '独立 release 诊断入口：10000 条饮食 + 2000 条药品记录。仅在隔离的本机回环环境运行，结果用于软件工程验收。',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _started ? null : _start,
                    child: const Text('Run'),
                  ),
                  OutlinedButton(
                    onPressed: run?.passed == true && !_downloading
                        ? _download
                        : null,
                    child: const Text('下载已验证 schema5 合成包'),
                  ),
                  OutlinedButton(
                    onPressed:
                        run != null &&
                            !_busy &&
                            !_downloadingReport &&
                            const [
                              'passed',
                              'failed',
                            ].contains(run.report['status'])
                        ? _downloadReport
                        : null,
                    child: const Text('下载完整 JSON 结果'),
                  ),
                  OutlinedButton(
                    onPressed: run == null || _busy
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: json));
                          },
                    child: const Text('复制完整 JSON 结果'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('阶段：${run?.stage ?? '等待 Run'}'),
              Text('状态：${run?.report['status'] ?? 'not_started'}'),
              if (_reportDownloadReceipt != null)
                SelectableText(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(_reportDownloadReceipt),
                ),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Semantics(
                    label: json,
                    excludeSemantics: true,
                    child: SelectableText(json),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProbeRun {
  _ProbeRun(this.onChanged);
  final void Function() onChanged;
  final startedAt = DateTime.now().toUtc();
  final connections = <IndexedDbWebUserStateStore>[];
  final _pendingSettlements = <Future<void>>{};
  final report = <String, Object?>{
    'kind': 'parkinsum_synthetic_user_state_release_probe',
    'status': 'not_started',
    'scope':
        'independent release binary; synthetic production API persistence diagnostic',
    'formalMainDartUi': false,
    'debugBrowserTestPass': false,
    'clinicalInterpretation': 'None; synthetic software persistence only.',
    'download': <String, Object?>{
      'status': 'not_requested',
      'actualFileWriteObserved': false,
    },
    'stages': <Object?>[],
    'witnesses': <Object?>[],
  };
  Map<String, String>? originalOriginMetadata;
  List<String>? originalDatabaseMetadata;
  String? databaseName;
  String stage = 'not_started';
  bool cancelled = false;
  bool passed = false;
  bool cleaning = false;
  int _assertions = 0;
  Map<String, Object?>? _stageReceipt;
  UserPortableDataPackageArtifact? candidateArtifact;
  UserPortableDataPackageArtifact? verifiedArtifact;

  // Keep the same total eight-minute bound, reserving thirty seconds for
  // owned cleanup. This is a timeout policy, never a performance claim.
  DateTime get operationDeadline =>
      startedAt.add(const Duration(minutes: 7, seconds: 30));
  DateTime get fullDeadline => startedAt.add(const Duration(minutes: 8));

  void checkActive() {
    if (cancelled || DateTime.now().toUtc().isAfter(operationDeadline)) {
      cancelled = true;
      throw TimeoutException(
        'synthetic_probe_operation_deadline',
        const Duration(minutes: 8),
      );
    }
  }

  Future<T> bounded<T>(Future<T> pending) {
    final remaining = operationDeadline.difference(DateTime.now().toUtc());
    // Observe the underlying future even after a timeout. Live legacy checks,
    // publication hooks and coordinator authorization refuse late writes.
    final watched = pending.then<T>(
      (value) {
        if (cancelled) {
          for (final connection in connections) {
            connection.close();
          }
        }
        checkActive();
        return value;
      },
      onError: (Object error, StackTrace trace) {
        if (cancelled) {
          for (final connection in connections) {
            connection.close();
          }
        }
        Error.throwWithStackTrace(error, trace);
      },
    );
    final settlement = watched.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pendingSettlements.add(settlement);
    unawaited(
      settlement.then<void>((_) {
        _pendingSettlements.remove(settlement);
      }),
    );
    return watched.timeout(
      remaining > Duration.zero ? remaining : Duration.zero,
      onTimeout: () {
        cancelled = true;
        // Keep the live connection until the underlying operation settles.
        // Closing early could make its readback reopen the name after deletion.
        throw TimeoutException(
          'synthetic_probe_operation_deadline',
          const Duration(minutes: 8),
        );
      },
    );
  }

  Future<T> cleanupAwait<T>(Future<T> pending) {
    final remaining = fullDeadline.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'synthetic_probe_total_deadline',
        const Duration(minutes: 8),
      );
    }
    return pending.timeout(remaining);
  }

  void finishStage() {
    if (_stageReceipt == null) return;
    _stageReceipt!['status'] = 'completed';
    _stageReceipt!['assertionsActuallyEvaluated'] = _assertions;
    _stageReceipt!['completedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    _stageReceipt = null;
  }

  Future<void> nextStage(String name) async {
    checkActive();
    finishStage();
    stage = name;
    _assertions = 0;
    _stageReceipt = <String, Object?>{
      'stage': name,
      'status': 'running',
      'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    (report['stages']! as List).add(_stageReceipt);
    onChanged();
    // Give Flutter a natural event-loop/frame opportunity between full checks.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    checkActive();
  }

  Future<void> execute() async {
    report['startedAtUtc'] = startedAt.toIso8601String();
    report['status'] = 'running';
    report['timeoutMinutes'] = 8;
    report['reservedCleanupSeconds'] = 30;
    report['runtime'] = <String, Object?>{
      'kIsWeb': kIsWeb,
      'kReleaseMode': kReleaseMode,
      'userAgent': web.window.navigator.userAgent,
      'origin': Uri.base.origin,
    };
    Object? failure;
    try {
      _check(kIsWeb && kReleaseMode, 'release Web binary required');
      _check(
        ['localhost', '127.0.0.1', '[::1]'].contains(Uri.base.host),
        'strict loopback origin required',
      );
      final identity = AlgorithmConfigurationIdentity.defaults();
      _equal(
        identity.version,
        '2026.10.20-v80',
        'current v80 configuration identity',
      );
      report['configurationIdentity'] = <String, Object?>{
        'id': identity.id,
        'version': identity.version,
        'sha256': identity.sha256Digest,
        'registeredAlgorithmSourceBundleSha256': AlgorithmConfigurationIdentity
            .registeredAlgorithmSourceBundleSha256,
        'sourceAndBinaryBinding': 'supplied by supervising build receipt',
      };
      SharedPreferencesPlugin.registerWith(null);
      await nextStage('strict_origin_metadata_guard');
      await lifecycle();
      checkActive();
      finishStage();
    } catch (error, trace) {
      failure = error;
      cancelled = true;
      report['failure'] = <String, Object?>{
        'stage': stage,
        'error': error.toString(),
        'stackTrace': trace.toString(),
        'timeout': error is TimeoutException,
      };
      if (_stageReceipt != null) {
        _stageReceipt!['status'] = 'failed';
        _stageReceipt!['assertionsActuallyEvaluated'] = _assertions;
        _stageReceipt!['completedAtUtc'] = DateTime.now()
            .toUtc()
            .toIso8601String();
        _stageReceipt = null;
      }
    } finally {
      cleaning = true;
      stage = 'owned_cleanup_exact_original_metadata';
      onChanged();
      await Future<void>.delayed(Duration.zero);
      try {
        await cleanup();
      } catch (error, trace) {
        failure ??= error;
        for (final connection in connections) {
          connection.close();
        }
        report['cleanup'] = <String, Object?>{
          'status': 'failed',
          'error': error.toString(),
          'stackTrace': trace.toString(),
          'originalMetadataRestoredExactly': false,
        };
      }
      cleaning = false;
      // A slow synchronous turn cannot silently become a successful deadline.
      if (DateTime.now().toUtc().isAfter(fullDeadline)) {
        failure ??= TimeoutException(
          'synthetic_probe_total_deadline',
          const Duration(minutes: 8),
        );
        report['deadlineExceeded'] = true;
      }
      passed =
          failure == null &&
          candidateArtifact != null &&
          (report['cleanup'] as Map?)?['status'] == 'completed';
      if (passed) verifiedArtifact = candidateArtifact;
      report['status'] = passed ? 'passed' : 'failed';
      report['terminalError'] = failure?.toString();
      report['completedAtUtc'] = DateTime.now().toUtc().toIso8601String();
      report['verifiedDownloadArtifact'] = passed
          ? <String, Object?>{
              'fileName': verifiedArtifact!.fileName,
              'utf8Bytes': utf8.encode(verifiedArtifact!.prettyJson).length,
              'sha256': portableRestoreBytesDigest(
                verifiedArtifact!.prettyJson,
              ),
              'schemaVersion': verifiedArtifact!.document['schemaVersion'],
              'allWireFileCount': verifiedArtifact!.files.length,
            }
          : null;
      stage = passed ? 'completed' : 'failed';
      onChanged();
    }
  }

  Future<void> cleanup() async {
    report['ownedPendingOperationsAtCleanup'] = _pendingSettlements.length;
    // Join only this probe's operations before deletion. If draining itself
    // exceeds the total deadline, cleanup fails visibly; no exact-restoration
    // success or verified download can be reported while work is outstanding.
    while (_pendingSettlements.isNotEmpty) {
      await cleanupAwait(Future.wait<void>(_pendingSettlements.toList()));
    }
    report['ownedPendingOperationsJoined'] = _pendingSettlements.isEmpty;
    for (final connection in connections) {
      connection.close();
    }
    final name = databaseName;
    if (name == null) {
      report['cleanup'] = <String, Object?>{
        'status': 'not_needed',
        'ownedDatabaseWasOpened': false,
        'noStorageMutationDispatched': true,
      };
      return;
    }
    final originBefore = originalOriginMetadata;
    final databasesBefore = originalDatabaseMetadata;
    if (originBefore == null || databasesBefore == null) {
      throw StateError('synthetic_cleanup_original_guard_absent');
    }
    await cleanupAwait(_deleteOwnedDatabase(name));
    final databasesAfter = await cleanupAwait(_databaseMetadataNames());
    _check(
      !databasesAfter.contains(name),
      'owned database absent after deletion',
    );
    _equal(
      databasesAfter,
      databasesBefore,
      'exact original database metadata restored',
    );
    final markerKey = 'parkinsum.indexeddb.migrated.$name';
    final marker = web.window.localStorage.getItem(markerKey);
    _check(
      marker == null || marker == '1',
      'refuse deleting unexpected owned migration marker',
    );
    web.window.localStorage.removeItem(markerKey);
    _check(
      web.window.localStorage.getItem(markerKey) == null,
      'owned migration marker absent',
    );
    _guardedOriginMetadata();
    final originalPulse = originBefore[_pulseKey];
    if (originalPulse == null) {
      web.window.localStorage.removeItem(_pulseKey);
    } else {
      web.window.localStorage.setItem(_pulseKey, originalPulse);
    }
    final originAfter = _guardedOriginMetadata();
    _equal(
      originAfter,
      originBefore,
      'exact original origin metadata restored',
    );
    report['cleanup'] = <String, Object?>{
      'status': 'completed',
      'ownedDatabaseName': name,
      'ownedDatabaseAbsentAfterDelete': !databasesAfter.contains(name),
      'ownedMigrationMarkerAbsent':
          web.window.localStorage.getItem(markerKey) == null,
      'databaseMetadataBefore': databasesBefore,
      'databaseMetadataAfter': databasesAfter,
      'originMetadataBeforeSha256': portableRestoreDigest(originBefore),
      'originMetadataAfterSha256': portableRestoreDigest(originAfter),
      'originalMetadataRestoredExactly':
          _valuesEqual(originBefore, originAfter) &&
          _valuesEqual(databasesBefore, databasesAfter),
      'originalPulsePresent': originalPulse != null,
      'completedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> lifecycle() async {
    // Inspect only metadata before obtaining any existing preference value or
    // opening any database. A known pulse may remain from another test in
    // this disposable origin; nothing is deleted to make the guard succeed.
    _check(
      (['localhost', '127.0.0.1', '[::1]']).contains(Uri.base.host),
      'complete original comparison',
    );
    final originMetadata = _guardedOriginMetadata();
    originalOriginMetadata = originMetadata;
    final databaseMetadata = await bounded(_databaseMetadataNames());
    originalDatabaseMetadata = databaseMetadata;
    _check(
      (databaseMetadata).isEmpty,
      'Refuse an origin containing any pre-existing database.',
    );
    _check(
      SharedPreferencesStorePlatform.instance
          is! InMemorySharedPreferencesStore,
      'complete original comparison',
    );

    _check(
      SharedPreferencesStorePlatform.instance is SharedPreferencesPlugin,
      'official shared preferences plugin actual type',
    );
    report['initialGuard'] = <String, Object?>{
      'strictLoopback': [
        'localhost',
        '127.0.0.1',
        '[::1]',
      ].contains(Uri.base.host),
      'databaseMetadata': databaseMetadata,
      'databaseMetadataEmpty': databaseMetadata.isEmpty,
      'originMetadataSha256': portableRestoreDigest(originMetadata),
      'originKeyCount': originMetadata.length,
      'officialPreferencesPlugin':
          SharedPreferencesStorePlatform.instance is SharedPreferencesPlugin,
    };
    // The default production factory is checked without opening its real
    // database. All actual operations use the synthetic name below.
    final productionChoice = createWebUserStateStore();
    _check(
      (productionChoice) is IndexedDbWebUserStateStore,
      'complete original comparison',
    );
    (productionChoice! as IndexedDbWebUserStateStore).close();

    await nextStage('fixture_complete_original_pins');
    final fixture = PersonalLogBenchmarkFixture.generate(10000);
    _equal(
      PersonalLogBenchmarkFixture.seed,
      31415926,
      'complete original comparison',
    );
    _equal(
      fixture.inputSha256,
      _fixtureSha256,
      'Pin the unchanged Chrome fixture before any durable write.',
    );
    _check((fixture.meals).length == 10000, 'complete original comparison');
    _check((fixture.intakes).length == 2000, 'complete original comparison');
    final mealMetadata = Map<String, String>.unmodifiable({
      for (final row in fixture.meals)
        row.id: portableRestoreCanonicalJson(row.toJson()),
    });
    final intakeMetadata = Map<String, String>.unmodifiable({
      for (final row in fixture.intakes)
        row.id: portableRestoreCanonicalJson(row.toJson()),
    });
    final mealPins = Map<String, String>.unmodifiable({
      for (final entry in mealMetadata.entries)
        entry.key: portableRestoreBytesDigest(entry.value),
    });
    final intakePins = Map<String, String>.unmodifiable({
      for (final entry in intakeMetadata.entries)
        entry.key: portableRestoreBytesDigest(entry.value),
    });
    final beforeWriteWitness = <String, Object?>{
      'stage': 'whole_original_fixture_pinned_before_first_write',
      'fixtureSha256': fixture.inputSha256,
      'seed': PersonalLogBenchmarkFixture.seed,
      'wholeRowCount': mealMetadata.length + intakeMetadata.length,
      'mealMetadataSha256': portableRestoreDigest(mealMetadata),
      'intakeMetadataSha256': portableRestoreDigest(intakeMetadata),
      'allIndividualMealPinsSha256': portableRestoreDigest(mealPins),
      'allIndividualIntakePinsSha256': portableRestoreDigest(intakePins),
      'capturedUnknownRaw999MealCount': fixture.meals
          .where(
            (row) =>
                row.items.single.isNutrientMissing('proteinG') &&
                row.items.single.proteinPer100g == 999,
          )
          .length,
      'reportedZeroMealCount': fixture.meals
          .where(
            (row) =>
                !row.items.single.isNutrientMissing('proteinG') &&
                row.items.single.proteinPer100g == 0,
          )
          .length,
      'invalidQuantityMealCount': fixture.meals
          .where((row) => row.items.single.quantityFactor == 0)
          .length,
      'futureMealCount': fixture.meals
          .where(
            (row) => row.effectiveOccurredAt.isAfter(
              PersonalLogBenchmarkFixture.asOf,
            ),
          )
          .length,
      'unspecifiedDoseIntakeCount': fixture.intakes
          .where((row) => row.doseAmount == null && row.doseUnit == null)
          .length,
    };
    _equal(
      beforeWriteWitness['capturedUnknownRaw999MealCount'],
      1000,
      'complete original comparison',
    );
    _equal(
      beforeWriteWitness['reportedZeroMealCount'],
      1000,
      'complete original comparison',
    );
    _equal(
      beforeWriteWitness['invalidQuantityMealCount'],
      1000,
      'complete original comparison',
    );
    _equal(
      beforeWriteWitness['futureMealCount'],
      500,
      'complete original comparison',
    );
    _equal(
      beforeWriteWitness['unspecifiedDoseIntakeCount'],
      2000,
      'complete original comparison',
    );
    _recordLog(
      'WEB_USER_STATE_12K_PORTABLE_BEFORE_WRITE '
      '${jsonEncode(beforeWriteWitness)}',
    );

    await nextStage('official_preferences_actual_get_instance');
    final preferences = await bounded(SharedPreferences.getInstance());
    await bounded(preferences.reload());
    _check((preferences.getKeys()).isEmpty, 'complete original comparison');
    _check(
      SharedPreferencesStorePlatform.instance
          is! InMemorySharedPreferencesStore,
      'complete original comparison',
    );
    _recordLog(
      'WEB_USER_STATE_12K_PORTABLE_ACTUAL_PLATFORM ${jsonEncode({'runtimeType': SharedPreferencesStorePlatform.instance.runtimeType.toString(), 'getInstanceAndReloadSucceeded': true, 'explicitPreferencesMockInstalled': false, 'actualPreferencesKeyCount': preferences.getKeys().length})}',
    );
    final legacyBefore = _legacySnapshot(preferences);
    databaseName = '$_ownedPrefix${DateTime.now().microsecondsSinceEpoch}';
    var failureMode = '';
    var beforePublicationRefusals = 0;
    var afterQueuedAborts = 0;
    final beforePublicationFailure = StateError(
      'synthetic_12k_before_publication',
    );
    final afterQueuedFailure = StateError(
      'synthetic_12k_abort_after_queued_put',
    );
    IndexedDbWebUserStateStore connect({bool faults = false}) {
      final store = IndexedDbWebUserStateStore(
        databaseName: databaseName!,
        readCurrentLegacy: () {
          checkActive();
          return _legacySnapshot(preferences);
        },
        beforePublication: faults
            ? () {
                checkActive();
                if (failureMode == 'before_publication') {
                  beforePublicationRefusals++;
                  throw beforePublicationFailure;
                }
              }
            : null,
        afterWriteQueued: faults
            ? () {
                checkActive();
                if (failureMode == 'after_queued') {
                  afterQueuedAborts++;
                  // The actual IDB put has been queued. The production store
                  // aborts this transaction and resolves its failure on onabort.
                  throw afterQueuedFailure;
                }
              }
            : null,
      );
      connections.add(store);
      return store;
    }

    await nextStage('seed_complete_original_state_and_two_history_records');
    final firstStore = connect(faults: true);
    final database = WebAppDatabase(userStateStore: firstStore);
    _check(
      (database.userStateBackendId).contains('IndexedDB'),
      'complete original comparison',
    );
    final empty = await bounded(database.loadPortableRestoreState());
    _check(
      (empty.recordIds.values.every((ids) => ids.isEmpty)) == true,
      'complete original comparison',
    );
    final originalProfile = UserProfile.defaults().copyWith(
      timezone: 'Asia/Shanghai',
      displayLocale: 'zh-CN',
    );
    await bounded(database.saveUserProfile(originalProfile));
    await bounded(database.saveOnboarded(true));
    const originalDrugId = 'synthetic-original-medication';
    await bounded(database.saveActiveDrugIds(const [originalDrugId]));
    final originalMeal = fixture.meals[1].copyWith(
      id: 'synthetic-original-meal',
      title: 'Synthetic original unknown meal',
    );
    final originalIntake = fixture.intakes.first.copyWith(
      id: 'synthetic-original-intake',
      drugId: originalDrugId,
    );
    final revisions = [
      RecoverableUserEventRevision.create(
        operationId: 'synthetic_original_meal_create',
        eventType: RecoverableUserEventType.meal,
        recordId: originalMeal.id,
        mutationType: RecoverableUserEventMutationType.create,
        beforePayload: null,
        afterPayload: originalMeal.toJson(),
        recordedAtUtc: PersonalLogBenchmarkFixture.asOf,
        source: 'synthetic_12k_portable_test',
      ),
      RecoverableUserEventRevision.create(
        operationId: 'synthetic_original_intake_create',
        eventType: RecoverableUserEventType.intake,
        recordId: originalIntake.id,
        mutationType: RecoverableUserEventMutationType.create,
        beforePayload: null,
        afterPayload: originalIntake.toJson(),
        recordedAtUtc: PersonalLogBenchmarkFixture.asOf,
        source: 'synthetic_12k_portable_test',
      ),
    ];
    for (final revision in revisions) {
      await bounded(
        database.commitRecoverableUserEventMutation(
          RecoverableUserEventMutation(revision: revision),
        ),
      );
    }
    final originalState = PortableDataRestoreState({
      ...empty.json,
      'onboarded': true,
      'profile': originalProfile.toJson(),
      'activeDrugIds': [originalDrugId],
      'meals': [originalMeal.toJson()],
      'intakes': [originalIntake.toJson()],
      'eventHistory': revisions.map((row) => row.toJson()).toList(),
    });
    await bounded(_requireCompleteState(database, originalState));
    _check(
      (await bounded(
            database.loadPortableRestoreReceipt(ownerScope: _owner),
          )) ==
          null,
      'complete original comparison',
    );
    final originalRaw = await bounded(_readOwnedEnvelope(databaseName!));
    _requireEnvelope(originalRaw, legacyBefore);

    await nextStage('default_schema5_create_inspect_integrity');
    final exportedProfile = UserProfile.defaults().copyWith(
      timezone: 'Etc/UTC',
      displayLocale: 'en-US',
    );
    // Exercise the default production choice: no preferCompactTransport flag
    // and no relaxed service limits. This original input must select schema 5.
    final artifact = _packageService.create(
      snapshot: UserPortableDataSnapshot(
        userScope: _owner,
        doseOwnerScope: _owner,
        scopeKind: _kind,
        profile: exportedProfile,
        activeDrugIds: const [],
        intakes: fixture.intakes,
        meals: fixture.meals,
        medicationCatalog: fixture.drugs,
        foodCatalog: fixture.foods,
        reminders: const [],
        observations: const [],
      ),
      generatedAt: PersonalLogBenchmarkFixture.asOf,
    );
    _equal(
      artifact.document['schemaVersion'],
      5,
      'complete original comparison',
    );
    _requirePackageIntegrity(artifact);
    final wireFiles = Map<String, Object?>.from(
      artifact.document['files'] as Map,
    );
    final logicalFiles = PortableDataCompactTransportService.resolve(wireFiles);
    _check(
      (logicalFiles.files['meals.json'] as List).length == 10000,
      'complete original comparison',
    );
    _check(
      (logicalFiles.files['intakes.json'] as List).length == 2000,
      'complete original comparison',
    );
    _check(
      (logicalFiles.files['reminders.json'] as List).isEmpty,
      'complete original comparison',
    );
    _check(
      ((logicalFiles.files['observations.json'] as Map)['records']).isEmpty,
      'complete original comparison',
    );
    final preview = _packageService.inspect(
      packageJson: artifact.prettyJson,
      currentUserScope: _owner,
      currentDoseOwnerScope: _owner,
      currentScopeKind: _kind,
      existingRecordIds: originalState.recordIds,
    );
    _equal(
      preview.status,
      UserPortableDataPreviewStatus.ready,
      preview.findings.join('; '),
    );
    _equal(preview.schemaVersion, 5, 'complete original comparison');
    _equal(preview.conflictCount, 0, 'complete original comparison');
    _equal(
      preview.recordCounts['meals.json'],
      10000,
      'complete original comparison',
    );
    _equal(
      preview.recordCounts['intakes.json'],
      2000,
      'complete original comparison',
    );
    final schemaReceipt = preview.schemaMigrationReceipt;
    _check((schemaReceipt) != null, 'complete original comparison');
    _equal(schemaReceipt!.sourceVersion, 5, 'complete original comparison');
    _equal(schemaReceipt.targetVersion, 5, 'complete original comparison');
    _equal(
      schemaReceipt.decision,
      'not_required_compact_transport',
      'complete original comparison',
    );
    _equal(
      schemaReceipt.sourceBytesSha256,
      portableRestoreBytesDigest(artifact.prettyJson),
      'complete original comparison',
    );
    _equal(
      schemaReceipt.receiptSha256,
      portableCanonicalSha256(schemaReceipt.toJson(includeDigest: false)),
      'complete original comparison',
    );

    _requireBudgets(artifact, logicalFiles);
    await nextStage('prepare_full_rows_no_durable_write');
    final coordinator = PortableDataRestoreCoordinator(store: database);
    final request = await bounded(
      coordinator.prepare(
        packageJson: artifact.prettyJson,
        ownerScope: _owner,
        effectiveOwnerScope: _owner,
        scopeKind: _kind,
        foodCatalog: fixture.foods,
        medicationCatalog: fixture.drugs,
        authorize: () => !cancelled,
      ),
    );
    _equal(
      request.expectedStateDigest,
      originalState.digest,
      'complete original comparison',
    );
    _equal(
      request.packageJsonSha256,
      portableRestoreBytesDigest(artifact.prettyJson),
      'complete original comparison',
    );
    _equal(
      request.payload.json['profile'],
      exportedProfile.toJson(),
      'complete original comparison',
    );
    _requireRows(
      request.payload.json['meals'] as List,
      mealMetadata,
      mealPins,
      'prepared original meal',
    );
    _requireRows(
      request.payload.json['intakes'] as List,
      intakeMetadata,
      intakePins,
      'prepared original intake',
    );
    await bounded(_requireCompleteState(database, originalState));
    _equal(
      await bounded(_readOwnedEnvelope(databaseName!)),
      originalRaw,
      'Create, inspect and prepare must not publish record changes.',
    );

    for (final mode in ['before_publication', 'after_queued']) {
      await nextStage('actual_transaction_failure_$mode');
      failureMode = mode;
      final expectedFailure = mode == 'before_publication'
          ? beforePublicationFailure
          : afterQueuedFailure;
      await bounded(
        _requireFailure(
          coordinator.commit(
            request: request,
            currentPackageJson: artifact.prettyJson,
            explicitlyConfirmed: true,
            authorize: () => !cancelled,
          ),
          expectedFailure,
        ),
      );
      failureMode = '';
      await bounded(_requireCompleteState(database, originalState));
      _check(
        (await bounded(
              database.loadPortableRestoreReceipt(ownerScope: _owner),
            )) ==
            null,
        'complete original comparison',
      );
      _equal(
        await bounded(_readOwnedEnvelope(databaseName!)),
        originalRaw,
        '$mode must preserve the whole original envelope and receipt.',
      );
      // A new real connection verifies durability, not a cached model string.
      final faultRestart = WebAppDatabase(userStateStore: connect());
      await bounded(_requireCompleteState(faultRestart, originalState));
      _check(
        (await bounded(
              faultRestart.loadPortableRestoreReceipt(ownerScope: _owner),
            )) ==
            null,
        'complete original comparison',
      );
      await bounded(_requireLegacyUnchanged(preferences, legacyBefore));
    }
    _equal(beforePublicationRefusals, 1, 'complete original comparison');
    _equal(afterQueuedAborts, 1, 'complete original comparison');
    _recordLog(
      'WEB_USER_STATE_12K_PORTABLE_REFUSALS ${jsonEncode({'beforePublicationRefusalCount': beforePublicationRefusals, 'afterQueuedActualTransactionAbortCount': afterQueuedAborts, 'completeOriginalStateSha256': originalState.digest, 'originalEnvelopeSha256': portableRestoreBytesDigest(originalRaw), 'completeRecordsHistoryProfileSelectionsAndReceiptPreserved': true, 'verifiedViaNewActualIndexedDbConnection': true})}',
    );

    await nextStage('commit_complete_state_and_receipt');
    final receipt = await bounded(
      coordinator.commit(
        request: request,
        currentPackageJson: artifact.prettyJson,
        explicitlyConfirmed: true,
        authorize: () => !cancelled,
      ),
    );
    final sortedMealIds = mealMetadata.keys.toList()..sort();
    final sortedIntakeIds = intakeMetadata.keys.toList()..sort();
    final expectedRestored = PortableDataRestoreState({
      ...originalState.json,
      'profile': exportedProfile.toJson(),
      'meals': [
        originalMeal.toJson(),
        for (final id in sortedMealIds) jsonDecode(mealMetadata[id]!),
      ],
      'intakes': [
        originalIntake.toJson(),
        for (final id in sortedIntakeIds) jsonDecode(intakeMetadata[id]!),
      ],
    });
    await bounded(_requireCompleteState(database, expectedRestored));
    _requireRestoreReceipt(
      receipt,
      request,
      artifact,
      originalState,
      expectedRestored,
    );
    _equal(
      (await bounded(
        database.loadPortableRestoreReceipt(ownerScope: _owner),
      ))!.canonicalJson,
      receipt.canonicalJson,
      'complete original comparison',
    );
    final restoredDocument = _requireEnvelope(
      await bounded(_readOwnedEnvelope(databaseName!)),
      legacyBefore,
    );
    _equal(
      restoredDocument['portableRestoreReceipt'],
      receipt.json,
      'complete original comparison',
    );

    for (final connection in connections) {
      connection.close();
    }
    await nextStage('actual_connection_reopen_and_all12000_typed_rows');
    final reopened = WebAppDatabase(userStateStore: connect());
    await bounded(_requireCompleteState(reopened, expectedRestored));
    _equal(
      (await bounded(
        reopened.loadPortableRestoreReceipt(ownerScope: _owner),
      ))!.canonicalJson,
      receipt.canonicalJson,
      'complete original comparison',
    );
    _requireRows(
      (await bounded(reopened.loadMeals()))
          .where((row) => mealMetadata.containsKey(row.id))
          .map((row) => row.toJson())
          .toList(),
      mealMetadata,
      mealPins,
      'reopened original meal',
    );
    _requireRows(
      (await bounded(reopened.loadIntakes()))
          .where((row) => intakeMetadata.containsKey(row.id))
          .map((row) => row.toJson())
          .toList(),
      intakeMetadata,
      intakePins,
      'reopened original intake',
    );

    await nextStage('same_schema5_all9_wire_files_exact_reexport');
    // Re-export only the incoming typed IDs. Original existing rows are
    // deliberately retained separately in the restored database merge.
    final reexport = _packageService.create(
      snapshot: UserPortableDataSnapshot(
        userScope: _owner,
        doseOwnerScope: _owner,
        scopeKind: _kind,
        profile: await bounded(reopened.loadUserProfile()),
        activeDrugIds: const [],
        intakes: (await bounded(
          reopened.loadIntakes(),
        )).where((row) => intakeMetadata.containsKey(row.id)),
        meals: (await bounded(
          reopened.loadMeals(),
        )).where((row) => mealMetadata.containsKey(row.id)),
        medicationCatalog: fixture.drugs,
        foodCatalog: fixture.foods,
        reminders: const [],
        observations: const [],
      ),
      generatedAt: PersonalLogBenchmarkFixture.asOf,
    );
    _requirePackageIntegrity(reexport);
    _equal(
      reexport.canonicalJson,
      artifact.canonicalJson,
      'complete original comparison',
    );
    _equal(
      reexport.prettyJson,
      artifact.prettyJson,
      'exact whole exported source bytes',
    );
    _equal(
      reexport.contentSha256,
      artifact.contentSha256,
      'complete original comparison',
    );
    _equal(
      reexport.packageId,
      artifact.packageId,
      'complete original comparison',
    );
    report['reexport'] = <String, Object?>{
      'schemaVersion': reexport.document['schemaVersion'],
      'allWireFileCount': reexport.files.length,
      'canonicalWholePackageEqual':
          reexport.canonicalJson == artifact.canonicalJson,
      'sourceBytesEqual': reexport.prettyJson == artifact.prettyJson,
      'canonicalSha256': portableRestoreBytesDigest(reexport.canonicalJson),
      'sourceBytesSha256': portableRestoreBytesDigest(reexport.prettyJson),
      'contentSha256': reexport.contentSha256,
      'packageId': reexport.packageId,
    };
    await bounded(_requireLegacyUnchanged(preferences, legacyBefore));

    await nextStage('undo_exact_original_state_receipt_and_reopen');
    await bounded(
      reopened.rollbackPortableRestore(
        receipt,
        ownerScope: _owner,
        authorize: () => !cancelled,
      ),
    );
    await bounded(_requireCompleteState(reopened, originalState));
    _check(
      (await bounded(
            reopened.loadPortableRestoreReceipt(ownerScope: _owner),
          )) ==
          null,
      'complete original comparison',
    );
    final undoneDocument = _requireEnvelope(
      await bounded(_readOwnedEnvelope(databaseName!)),
      legacyBefore,
    );
    _equal(undoneDocument['portableRestoreReceipt'], {
      ...receipt.json,
      'rolledBack': true,
    }, 'complete original comparison');
    _equal(
      PortableDataRestoreState(undoneDocument).canonicalJson,
      originalState.canonicalJson,
      'complete original comparison',
    );
    final undoneRaw = await bounded(_readOwnedEnvelope(databaseName!));
    for (final connection in connections) {
      connection.close();
    }
    final undoReopened = WebAppDatabase(userStateStore: connect());
    await bounded(_requireCompleteState(undoReopened, originalState));
    _check(
      await bounded(
            undoReopened.loadPortableRestoreReceipt(ownerScope: _owner),
          ) ==
          null,
      'Undo survives first actual connection reopen',
    );
    _equal(
      await bounded(_readOwnedEnvelope(databaseName!)),
      undoneRaw,
      'Undo reopen preserves entire durable envelope',
    );
    await nextStage('idempotent_undo_and_actual_connection_reopen');
    // The same durable Undo is idempotent and survives another connection
    // close/reopen. No notification permission or cross-store record is used.
    await bounded(
      undoReopened.rollbackPortableRestore(
        receipt,
        ownerScope: _owner,
        authorize: () => !cancelled,
      ),
    );
    for (final connection in connections) {
      connection.close();
    }
    final undoneReopened = WebAppDatabase(userStateStore: connect());
    await bounded(_requireCompleteState(undoneReopened, originalState));
    _check(
      (await bounded(
            undoneReopened.loadPortableRestoreReceipt(ownerScope: _owner),
          )) ==
          null,
      'complete original comparison',
    );
    await bounded(_requireLegacyUnchanged(preferences, legacyBefore));
    _equal(
      await bounded(_readOwnedEnvelope(databaseName!)),
      undoneRaw,
      'idempotent Undo preserves entire durable envelope',
    );
    _equal(
      (await bounded(
        undoneReopened.loadMeals(),
      )).map((row) => row.toJson()).toList(),
      [originalMeal.toJson()],
      'complete original typed meal after final reopen',
    );
    _equal(
      (await bounded(
        undoneReopened.loadIntakes(),
      )).map((row) => row.toJson()).toList(),
      [originalIntake.toJson()],
      'complete original typed intake after final reopen',
    );
    final finalUndone = await bounded(
      undoneReopened.loadPortableRestoreState(),
    );
    final finalUndoneJson = finalUndone.json;
    final restoredJson = expectedRestored.json;
    final originalJson = originalState.json;
    _equal(
      finalUndone.canonicalJson,
      originalState.canonicalJson,
      'whole final Undo preimage',
    );
    _equal(
      (await bounded(undoneReopened.loadUserProfile())).toJson(),
      originalProfile.toJson(),
      'original profile through typed getter',
    );
    _equal(await bounded(undoneReopened.loadActiveDrugIds()), [
      originalDrugId,
    ], 'original selections through typed getter');
    _check(
      await bounded(undoneReopened.loadOnboarded()),
      'original onboarded through typed getter',
    );
    (report['witnesses']! as List).add(<String, Object?>{
      'stage': stage,
      'witness': 'complete_final_undo_reopen',
      'fixtureSha256': fixture.inputSha256,
      'fixtureAsOfUtc': PersonalLogBenchmarkFixture.asOf
          .toUtc()
          .toIso8601String(),
      'schemaVersion': artifact.document['schemaVersion'],
      'packageBytesSha256': request.packageJsonSha256,
      'packageContentSha256': artifact.contentSha256,
      'packageFileChecksumsVerified': artifact.files.length,
      'schemaReceiptSha256': schemaReceipt.receiptSha256,
      'restoreReceiptSha256': portableRestoreBytesDigest(receipt.canonicalJson),
      'originalCompleteStateSha256': originalState.digest,
      'restoredCompleteStateSha256': expectedRestored.digest,
      'undoneCompleteStateSha256': finalUndone.digest,
      'incomingMealCount': mealMetadata.length,
      'incomingIntakeCount': intakeMetadata.length,
      'originalMealCount': (originalJson['meals'] as List).length,
      'originalIntakeCount': (originalJson['intakes'] as List).length,
      'originalRecoveryHistoryCount':
          (originalJson['eventHistory'] as List).length,
      'restoredMealCountIncludingOriginal':
          (restoredJson['meals'] as List).length,
      'restoredIntakeCountIncludingOriginal':
          (restoredJson['intakes'] as List).length,
      'undoneMealCount': (finalUndoneJson['meals'] as List).length,
      'undoneIntakeCount': (finalUndoneJson['intakes'] as List).length,
      'undoneRecoveryHistoryCount':
          (finalUndoneJson['eventHistory'] as List).length,
      'completeOriginalStateRecoveredAfterUndoAndReopen':
          finalUndone.canonicalJson == originalState.canonicalJson,
      'beforePublicationRefusalCount': beforePublicationRefusals,
      'afterQueuedActualTransactionAbortCount': afterQueuedAborts,
      'actualOwnedConnectionCount': connections.length,
      'legacySnapshotSha256': legacyBefore.digest,
      'localStorageDataMirror':
          preferences.getString('db.user_state.v1') != null,
      'actualTwoTabExecution': false,
    });

    candidateArtifact = artifact;
  }
}

void _check(bool condition, String reason) {
  final run = _activeRun;
  if (run != null) {
    if (!run.cleaning) run.checkActive();
    run._assertions++;
  }
  if (!condition) throw StateError('synthetic_probe_assertion_failed: $reason');
}

Object? _comparisonValue(Object? value) {
  if (value is Set) {
    final rows = value.map(_comparisonValue).toList();
    rows.sort(
      (a, b) => portableRestoreCanonicalJson(
        a,
      ).compareTo(portableRestoreCanonicalJson(b)),
    );
    return rows;
  }
  if (value is List) return value.map(_comparisonValue).toList();
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _comparisonValue(entry.value),
    };
  }
  return value;
}

bool _valuesEqual(Object? actual, Object? expected) {
  if (actual is Set || expected is Set) {
    return portableRestoreCanonicalJson(_comparisonValue(actual)) ==
        portableRestoreCanonicalJson(_comparisonValue(expected));
  }
  if (actual is Map || actual is List || expected is Map || expected is List) {
    return portableRestoreCanonicalJson(actual) ==
        portableRestoreCanonicalJson(expected);
  }
  return actual == expected;
}

void _equal(Object? actual, Object? expected, String reason) =>
    _check(_valuesEqual(actual, expected), reason);

void _recordLog(String message) {
  final at = message.indexOf('{');
  if (at < 0) throw StateError('synthetic_probe_witness_invalid');
  final witness = Map<String, Object?>.from(
    jsonDecode(message.substring(at)) as Map,
  );
  witness['witness'] = message.substring(0, at).trim();
  witness['stage'] = _activeRun?.stage;
  (_activeRun!.report['witnesses']! as List).add(witness);
}

Future<void> _requireFailure(Future<Object?> pending, Object expected) async {
  Object? caught;
  try {
    await pending;
  } catch (error) {
    caught = error;
  }
  _check(
    identical(caught, expected),
    'actual injected failure object must propagate from transaction',
  );
}

int _nodes(Object? value) {
  if (value is Map) {
    return 1 + value.values.fold<int>(0, (sum, child) => sum + _nodes(child));
  }
  if (value is List) {
    return 1 + value.fold<int>(0, (sum, child) => sum + _nodes(child));
  }
  return 1;
}

int _depth(Object? value) {
  final children = value is Map
      ? value.values
      : value is List
      ? value
      : const <Object?>[];
  var maximum = 0;
  for (final child in children) {
    final depth = _depth(child);
    if (depth > maximum) maximum = depth;
  }
  return 1 + maximum;
}

void _requireBudgets(
  UserPortableDataPackageArtifact artifact,
  PortableCompactLogicalFiles logical,
) {
  final document = artifact.document;
  final files = Map<String, Object?>.from(document['files'] as Map);
  final wireNodes = _nodes(document);
  final wireDepth = _depth(document);
  final canonicalBytes = utf8.encode(artifact.canonicalJson).length;
  final prettyBytes = utf8.encode(artifact.prettyJson).length;
  final logicalNodes = _nodes(logical.files);
  final logicalBytes = utf8.encode(portableCanonicalJson(logical.files)).length;
  final fullLogicalDepth = _depth(logical.files) + 1;
  final snapshotCount =
      (files[userPortableDataFoodItemSnapshotsPath] as List).length;
  _equal(files.length, 9, 'all nine schema5 wire files');
  _equal(logical.files.length, 8, 'all eight logical files');
  _check(
    wireNodes <= userPortableDataMaxJsonNodes,
    'unchanged 500000 wire node guard',
  );
  _check(
    wireDepth <= userPortableDataMaxJsonDepth,
    'unchanged wire depth guard',
  );
  _check(
    canonicalBytes <= userPortableDataMaxPackageBytes &&
        prettyBytes <= userPortableDataMaxPackageBytes,
    'unchanged package byte guard',
  );
  _equal(
    logicalNodes,
    logical.logicalNodeCount,
    'independent full logical node measure',
  );
  _equal(
    logicalBytes,
    logical.logicalCanonicalBytes,
    'independent full logical canonical byte measure',
  );
  _check(
    logicalNodes <= userPortableDataMaxLogicalFileNodes,
    'independent logical node budget',
  );
  _check(
    logicalBytes <= userPortableDataMaxLogicalFileBytes,
    'independent logical byte budget',
  );
  _check(
    fullLogicalDepth <= userPortableDataMaxLogicalDepth,
    'independent full logical depth budget',
  );
  _check(
    snapshotCount <= userPortableDataMaxFoodItemSnapshots,
    'snapshot record budget',
  );
  _activeRun!.report['packageBudgets'] = <String, Object?>{
    'schemaVersion': document['schemaVersion'],
    'currentDefaultSchemaVersion': userPortableDataPackageSchemaVersion,
    'wireFiles': files.length,
    'logicalFiles': logical.files.length,
    'wireNodes': wireNodes,
    'wireNodeLimit': userPortableDataMaxJsonNodes,
    'wireDepth': wireDepth,
    'wireDepthLimit': userPortableDataMaxJsonDepth,
    'canonicalUtf8Bytes': canonicalBytes,
    'prettyUtf8Bytes': prettyBytes,
    'wireByteLimit': userPortableDataMaxPackageBytes,
    'logicalNodes': logicalNodes,
    'logicalNodeLimit': userPortableDataMaxLogicalFileNodes,
    'logicalCanonicalUtf8Bytes': logicalBytes,
    'logicalByteLimit': userPortableDataMaxLogicalFileBytes,
    'fullLogicalDepth': fullLogicalDepth,
    'logicalDepthLimit': userPortableDataMaxLogicalDepth,
    'snapshotRecords': snapshotCount,
    'snapshotRecordLimit': userPortableDataMaxFoodItemSnapshots,
  };
}

void _requireRows(
  List rows,
  Map<String, String> originalMetadata,
  Map<String, String> originalPins,
  String stage,
) {
  _check((rows).length == originalMetadata.length, stage);
  final seen = <String>{};
  final observedMetadata = <String, String>{};
  final observedPins = <String, String>{};
  for (final raw in rows) {
    final row = Map<String, Object?>.from(raw as Map);
    final id = row['id'] as String;
    _check((seen.add(id)) == true, '$stage duplicate typed id $id');
    _check(
      (originalMetadata.containsKey(id)) == true,
      '$stage unknown typed id $id',
    );
    final canonical = portableRestoreCanonicalJson(row);
    final pin = portableRestoreBytesDigest(canonical);
    _equal(canonical, originalMetadata[id], '$stage complete fields for $id');
    _equal(pin, originalPins[id], '$stage original pin for $id');
    observedMetadata[id] = canonical;
    observedPins[id] = pin;
  }
  // Every row above has a unique known ID and exact full fields/hash. Equal
  // cardinality plus hash membership proves the same complete ID set without
  // the matcher's quadratic unordered-Set comparison at 10,000 rows.
  _equal(seen.length, originalMetadata.length, stage);
  _check((seen.containsAll(originalMetadata.keys)) == true, stage);
  final fieldsEqual =
      observedMetadata.length == originalMetadata.length &&
      observedMetadata.entries.every(
        (entry) => entry.value == originalMetadata[entry.key],
      );
  final pinsEqual =
      observedPins.length == originalPins.length &&
      observedPins.entries.every(
        (entry) => entry.value == originalPins[entry.key],
      );
  _check(
    fieldsEqual && pinsEqual,
    '$stage whole original metadata and individual pins',
  );
  (_activeRun!.report['witnesses']! as List).add(<String, Object?>{
    'stage': _activeRun!.stage,
    'witness': stage,
    'actualRowCount': rows.length,
    'uniqueKnownIdCount': seen.length,
    'wholeFieldsEqual': fieldsEqual,
    'allIndividualPinsEqual': pinsEqual,
    'observedWholeMetadataSha256': portableRestoreDigest(observedMetadata),
    'originalWholeMetadataSha256': portableRestoreDigest(originalMetadata),
    'observedIndividualPinsSha256': portableRestoreDigest(observedPins),
    'originalIndividualPinsSha256': portableRestoreDigest(originalPins),
  });
}

Future<void> _requireCompleteState(
  WebAppDatabase database,
  PortableDataRestoreState expected,
) async {
  final observed = await database.loadPortableRestoreState();
  final observedDocument = observed.json;
  final observedDigest = portableRestoreDigest(observedDocument);
  final expectedDigest = expected.digest;
  // This compares every field of the complete aggregate. Reopened typed meal
  // and intake readers are also checked against all 12,000 original row pins
  // below. Re-reading the full aggregate through six additional getters at
  // every stage duplicated large receipt decoding without adding fields.
  _check(
    (observed.canonicalJson == expected.canonicalJson) == true,
    'Complete state equality: observed $observedDigest, '
    'expected $expectedDigest.',
  );
  _equal(observedDigest, expectedDigest, 'complete original comparison');
  _recordLog(
    'WEB_USER_STATE_12K_PORTABLE_COMPLETE_STATE ${jsonEncode({'completeCanonicalFieldsEqual': observed.canonicalJson == expected.canonicalJson, 'wholeStateSha256': observedDigest, 'expectedWholeStateSha256': expectedDigest, 'canonicalChars': observed.canonicalJson.length, 'mealCount': (observedDocument['meals'] as List).length, 'intakeCount': (observedDocument['intakes'] as List).length, 'recoveryHistoryCount': (observedDocument['eventHistory'] as List).length, 'onboarded': observedDocument['onboarded'], 'profileSha256': portableRestoreDigest(observedDocument['profile']), 'selectionsSha256': portableRestoreDigest(observedDocument['activeDrugIds'])})}',
  );
}

void _requireRestoreReceipt(
  PortableDataRestoreReceipt receipt,
  PortableDataRestoreRequest request,
  UserPortableDataPackageArtifact artifact,
  PortableDataRestoreState original,
  PortableDataRestoreState restored,
) {
  _equal(receipt.json, {
    'version': 1,
    'ownerScope': _owner,
    'operationId': request.operationId,
    'packageJsonSha256': portableRestoreBytesDigest(artifact.prettyJson),
    'sourcePackageJson': artifact.prettyJson,
    'beforeDigest': original.digest,
    'afterDigest': restored.digest,
    'beforeState': original.json,
    'rolledBack': false,
  }, 'complete original comparison');
  _equal(receipt.beforeDigest, original.digest, 'complete original comparison');
  _equal(receipt.afterDigest, restored.digest, 'complete original comparison');
  _equal(
    PortableDataRestoreState(
      Map<String, Object?>.from(receipt.json['beforeState'] as Map),
    ).canonicalJson,
    original.canonicalJson,
    'complete original comparison',
  );
}

void _requirePackageIntegrity(UserPortableDataPackageArtifact artifact) {
  final files = Map<String, Object?>.from(artifact.document['files'] as Map);
  final manifest = artifact.document['manifest'] as Map;
  final summaries = manifest['files'] as List;
  _equal(
    files.keys.toSet(),
    summaries.map((raw) => (raw as Map)['path']).toSet(),
    'complete original comparison',
  );
  _check(
    (summaries).length == artifact.files.length,
    'complete original comparison',
  );
  final verifiedFiles = <Object?>[];
  for (final summary in artifact.files) {
    final raw =
        summaries.singleWhere((row) => (row as Map)['path'] == summary.path)
            as Map;
    _equal(
      raw['sha256'],
      portableCanonicalSha256(files[summary.path]),
      'complete original comparison',
    );
    _equal(raw['sha256'], summary.sha256, 'complete original comparison');
    _equal(
      raw['recordCount'],
      summary.recordCount,
      'complete original comparison',
    );
    final file = files[summary.path];
    final independentlyCounted = file is List
        ? file.length
        : file is Map && file['records'] is List
        ? (file['records'] as List).length
        : file is Map && file['links'] is List
        ? (file['links'] as List).length
        : 1;
    _equal(
      raw['recordCount'],
      independentlyCounted,
      'complete original comparison',
    );
    verifiedFiles.add(<String, Object?>{
      'path': summary.path,
      'actualCanonicalSha256': portableCanonicalSha256(file),
      'manifestSha256': raw['sha256'],
      'actualRecordCount': independentlyCounted,
      'manifestRecordCount': raw['recordCount'],
    });
  }
  _equal(
    artifact.contentSha256,
    portableCanonicalSha256(files),
    'complete original comparison',
  );
  _equal(
    (manifest['integrity'] as Map)['contentSha256'],
    artifact.contentSha256,
    'complete original comparison',
  );
  _equal(
    artifact.packageId,
    portableSha256(
      'parkinsum-portable-package-v${artifact.document['schemaVersion']}|'
      '${artifact.ownerScopeSha256}|${artifact.contentSha256}',
    ),
    'complete original comparison',
  );
  _equal(
    jsonDecode(artifact.prettyJson),
    jsonDecode(artifact.canonicalJson),
    'complete original comparison',
  );
  (_activeRun!.report['witnesses']! as List).add(<String, Object?>{
    'stage': _activeRun!.stage,
    'witness': 'all_package_files_integrity',
    'schemaVersion': artifact.document['schemaVersion'],
    'actualFiles': verifiedFiles,
    'contentSha256': artifact.contentSha256,
    'packageId': artifact.packageId,
    'canonicalWholePackageSha256': portableRestoreBytesDigest(
      artifact.canonicalJson,
    ),
    'sourceBytesSha256': portableRestoreBytesDigest(artifact.prettyJson),
  });
}

Map<String, Object?> _requireEnvelope(
  String raw,
  WebUserStateLegacySnapshot legacy,
) {
  final envelope = Map<String, Object?>.from(jsonDecode(raw) as Map);
  _equal(envelope.keys.toSet(), {
    'schema',
    'legacyKeys',
    'legacyDigest',
    'document',
    'documentDigest',
  }, 'complete original comparison');
  _equal(
    envelope['schema'],
    'parkinsum.indexeddb-user-state/1',
    'complete original comparison',
  );
  _equal(
    portableRestoreCanonicalJson(envelope['legacyKeys']),
    legacy.canonicalJson,
    'complete original comparison',
  );
  _equal(
    envelope['legacyDigest'],
    legacy.digest,
    'complete original comparison',
  );
  final document = envelope['document'] as String;
  _equal(
    envelope['documentDigest'],
    portableRestoreDigest(document),
    'complete original comparison',
  );
  return Map<String, Object?>.from(jsonDecode(document) as Map);
}

Future<void> _requireLegacyUnchanged(
  SharedPreferences preferences,
  WebUserStateLegacySnapshot original,
) async {
  await preferences.reload();
  _equal(
    _legacySnapshot(preferences).canonicalJson,
    original.canonicalJson,
    'complete original comparison',
  );
  _check(
    (preferences.getString('db.user_state.v1')) == null,
    'complete original comparison',
  );
  _check(
    (preferences.getKeys()).isEmpty,
    'No catalog, personal state or package may be mirrored to localStorage.',
  );
}

WebUserStateLegacySnapshot _legacySnapshot(SharedPreferences preferences) =>
    WebUserStateLegacySnapshot({
      for (final key in webUserStateLegacyKeys) key: preferences.getString(key),
    });

Map<String, String> _guardedOriginMetadata() {
  final storage = web.window.localStorage;
  if (storage.length == 0) return const {};
  if (storage.length != 1 || storage.key(0) != _pulseKey) {
    throw StateError('synthetic_origin_contains_unexpected_storage_keys');
  }
  final pulse = storage.getItem(_pulseKey);
  if (pulse == null || !RegExp(r'^[0-9a-f]{20}$').hasMatch(pulse)) {
    throw StateError('synthetic_origin_notification_pulse_invalid');
  }
  return Map<String, String>.unmodifiable({_pulseKey: pulse});
}

Future<List<String>> _databaseMetadataNames() async {
  final metadata = (await web.window.indexedDB.databases().toDart).toDart;
  final names = <String>[for (final database in metadata) database.name]
    ..sort();
  return List<String>.unmodifiable(names);
}

Future<String> _readOwnedEnvelope(String name) async {
  if (!name.startsWith(_ownedPrefix)) {
    throw StateError('Refuse reading an unowned browser database.');
  }
  final opened = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(name);
  request.onupgradeneeded = ((web.Event _) {
    // The database must already exist. Never create it to make a read pass.
    request.transaction?.abort();
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final database = request.result as web.IDBDatabase;
    if (opened.isCompleted || (_activeRun?.cancelled ?? false)) {
      database.close();
      if (!opened.isCompleted) {
        opened.completeError(
          StateError('synthetic_owned_database_read_cancelled'),
        );
      }
    } else {
      opened.complete(database);
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!opened.isCompleted) {
      opened.completeError(
        StateError('synthetic_owned_database_read_open_failed'),
      );
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!opened.isCompleted) {
      opened.completeError(StateError('synthetic_owned_database_read_blocked'));
    }
  }).toJS;
  // The outer bounded read tracks this entire acquisition/read/close lifetime.
  // Enter finally before checking the deadline so an acquired raw handle is
  // closed even when its success callback and this continuation straddle it.
  final database = await opened.future;
  try {
    _activeRun!.checkActive();
    final completed = Completer<String>();
    String? raw;
    final transaction = database.transaction('documents'.toJS, 'readonly');
    transaction.oncomplete = ((web.Event _) {
      if (completed.isCompleted) return;
      if (raw == null) {
        completed.completeError(StateError('synthetic_owned_envelope_absent'));
      } else {
        completed.complete(raw);
      }
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!completed.isCompleted) {
        completed.completeError(
          StateError('synthetic_owned_envelope_read_aborted'),
        );
      }
    }).toJS;
    final read = transaction.objectStore('documents').get('user_state'.toJS);
    read.onsuccess = ((web.Event _) {
      try {
        final result = read.result;
        raw = result == null ? null : (result as JSString).toDart;
      } catch (_) {
        transaction.abort();
      }
    }).toJS;
    return await completed.future;
  } finally {
    database.close();
  }
}

Future<void> _deleteOwnedDatabase(String name) async {
  if (!name.startsWith(_ownedPrefix)) {
    throw StateError('Refuse deleting an unowned browser database.');
  }
  final completed = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase(name);
  request.onsuccess = ((web.Event _) {
    if (!completed.isCompleted) completed.complete();
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completed.isCompleted) {
      completed.completeError(StateError('synthetic_delete_failed'));
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!completed.isCompleted) {
      completed.completeError(StateError('synthetic_delete_blocked'));
    }
  }).toJS;
  await completed.future;
}
