import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/data_service.dart';
import 'package:parkinsum_companion/core/services/portable_data_export_sink.dart';
import 'package:parkinsum_companion/core/services/portable_data_owner_scope_service.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/security/protected_secret_store.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';
import 'package:parkinsum_companion/features/settings/portable_data_package_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/page_test_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserLoggingReminderProcessRevision.debugResetForTesting();
  });

  test(
    'reminder revision advances only after exact repository read-back',
    () async {
      const scope = 'local_revision@example.test';
      final before = UserLoggingReminderProcessRevision.read(scope);
      final successful = UserLoggingReminderRepository(
        storage: _MemoryDataService(),
      );
      await successful.save(scope, const <UserLoggingReminder>[]);
      final afterSuccess = UserLoggingReminderProcessRevision.read(scope);
      expect(afterSuccess, isNot(before));

      final failing = UserLoggingReminderRepository(
        storage: _ThrowingDataService(),
      );
      await expectLater(
        failing.save(scope, const <UserLoggingReminder>[]),
        throwsStateError,
      );
      expect(
        UserLoggingReminderProcessRevision.read(scope),
        afterSuccess,
        reason: 'a failed persistence call must not advance the witness',
      );

      final dropping = UserLoggingReminderRepository(
        storage: _DroppingDataService(),
      );
      await expectLater(
        dropping.save(scope, const <UserLoggingReminder>[]),
        throwsStateError,
      );
      expect(
        UserLoggingReminderProcessRevision.read(scope),
        afterSuccess,
        reason: 'a nonthrowing dropped write must not advance the witness',
      );
    },
  );

  testWidgets(
    'generates, previews explicitly, excludes low-entropy email, and clears on account change',
    (tester) async {
      final clipboard = _FakeClipboard();
      final fixture = await _pumpPortablePage(
        tester,
        clipboard: clipboard,
        exportSink: const _ThrowingExportSink(),
        signInEmail: 'low@example.test',
        usePersistentOwnerResolver: true,
      );

      await _generate(tester);
      expect(find.byKey(const ValueKey('portable-file-name')), findsOneWidget);
      expect(find.text('Integrity self-check passed'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsNothing,
        reason: 'generation self-check must not masquerade as import preview',
      );

      await _tapKey(tester, 'portable-use-generated');
      await _tapKey(tester, 'portable-inspect');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsOneWidget,
      );

      await _tapKey(tester, 'portable-save');
      await tester.pumpAndSettle();
      final copiedJson = clipboard.writes.single;
      expect(copiedJson, contains('parkinsum_user_portable_data_package'));
      expect(copiedJson, isNot(contains('low@example.test')));
      expect(copiedJson, isNot(contains('local_low@example.test')));
      final root = Map<String, Object?>.from(jsonDecode(copiedJson) as Map);
      final manifest = Map<String, Object?>.from(root['manifest'] as Map);
      final owner = Map<String, Object?>.from(manifest['ownerScope'] as Map);
      final naiveBinding = sha256
          .convert(
            utf8.encode(
              'parkinsum-portable-owner-v1|local_device_account|'
              '${fixture.state.currentUserId}',
            ),
          )
          .toString();
      expect(owner['bindingSha256'], isNot(naiveBinding));
      expect(
        find.text(
          'Direct save failed. JSON was copied; no new file was confirmed saved.',
        ),
        findsOneWidget,
      );

      await _switchToAccountB(tester, fixture.state);
      expect(find.byKey(const ValueKey('portable-file-name')), findsNothing);
      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsNothing,
      );
      expect(_importText(tester), isEmpty);
      expectNoWidgetErrors(reason: 'account transition leaked portable state');
    },
  );

  testWidgets('rotating local export identity clears the bound artifact', (
    tester,
  ) async {
    final manager = _FixedOwnerManager();
    await _pumpPortablePage(
      tester,
      ownerScopeResolver: manager,
      clipboard: _FakeClipboard(),
    );
    await _generate(tester);
    final protection = tester.widget<SelectableText>(
      find.byKey(const ValueKey('portable-owner-protection')),
    );
    expect(protection.data, contains('Capability revision 1'));
    expect(protection.data, contains('test_protected_store_v1'));

    await _tapKey(tester, 'portable-rotate-owner-secret');
    await tester.pumpAndSettle();
    await _tapKey(tester, 'portable-rotate-confirm');
    await tester.pumpAndSettle();

    expect(manager.revision, 2);
    expect(find.byKey(const ValueKey('portable-file-name')), findsNothing);
    expect(
      find.text(
        'Local export identity rotated. The current package and preview were cleared.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('import-only text and preview clear on A to B transition', (
    tester,
  ) async {
    final clipboard = _FakeClipboard(readValue: '{}');
    final fixture = await _pumpPortablePage(tester, clipboard: clipboard);

    await _tapKey(tester, 'portable-paste');
    expect(_importText(tester), '{}');
    await _tapKey(tester, 'portable-inspect');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('portable-preview-status')),
      findsOneWidget,
    );
    expect(find.text('Package is corrupt or invalid'), findsOneWidget);

    await _switchToAccountB(tester, fixture.state);
    expect(_importText(tester), isEmpty);
    expect(find.byKey(const ValueKey('portable-preview-status')), findsNothing);
    expect(find.byKey(const ValueKey('portable-file-name')), findsNothing);
  });

  testWidgets('delayed paste cannot write text after account switch', (
    tester,
  ) async {
    final readGate = Completer<String?>();
    final clipboard = _FakeClipboard(readGate: readGate);
    final fixture = await _pumpPortablePage(tester, clipboard: clipboard);

    await _tapKey(tester, 'portable-paste');
    expect(clipboard.readStarted.isCompleted, isTrue);
    await _switchToAccountB(tester, fixture.state);
    readGate.complete('{"private":"account-a"}');
    await tester.pumpAndSettle();

    expect(_importText(tester), isEmpty);
    expect(find.byKey(const ValueKey('portable-preview-status')), findsNothing);
  });

  testWidgets('oversize paste is rejected before controller assignment', (
    tester,
  ) async {
    final clipboard = _FakeClipboard(readValue: List.filled(65, 'x').join());
    await _pumpPortablePage(tester, clipboard: clipboard, inputByteBudget: 64);

    await _tapKey(tester, 'portable-paste');

    expect(_importText(tester), isEmpty);
    expect(
      find.text(
        'The input exceeds the package-size limit and was not loaded or parsed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'delayed copy authorization expires before clipboard side effect',
    (tester) async {
      final writeGate = Completer<void>();
      final clipboard = _FakeClipboard(writeGate: writeGate);
      final fixture = await _pumpPortablePage(tester, clipboard: clipboard);
      await _generate(tester);

      await _tapKey(tester, 'portable-copy');
      expect(clipboard.writeStarted.isCompleted, isTrue);
      await _switchToAccountB(tester, fixture.state);
      writeGate.complete();
      await tester.pumpAndSettle();

      expect(clipboard.writes, isEmpty);
      expect(find.byKey(const ValueKey('portable-file-name')), findsNothing);
    },
  );

  testWidgets('delayed save authorization expires before file side effect', (
    tester,
  ) async {
    final publishGate = Completer<void>();
    final sink = _DelayedExportSink(publishGate);
    final fixture = await _pumpPortablePage(
      tester,
      clipboard: _FakeClipboard(),
      exportSink: sink,
    );
    await _generate(tester);

    await _tapKey(tester, 'portable-save');
    expect(sink.started.isCompleted, isTrue);
    await _switchToAccountB(tester, fixture.state);
    publishGate.complete();
    await tester.pumpAndSettle();

    expect(sink.publishedContents, isEmpty);
    expect(find.byKey(const ValueKey('portable-file-name')), findsNothing);
  });

  testWidgets('read-only existing-file match never claims a new save', (
    tester,
  ) async {
    final clipboard = _FakeClipboard();
    await _pumpPortablePage(
      tester,
      clipboard: clipboard,
      exportSink: const _ExistingVerifiedExportSink(),
    );
    await _generate(tester);

    await _tapKey(tester, 'portable-save');
    await tester.pumpAndSettle();

    expect(clipboard.writes, hasLength(1));
    expect(
      find.text(
        'Direct save is unavailable. JSON was copied; no file is claimed as saved.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'same-account reminder save while inspect is pending rejects stale preview',
    (tester) async {
      final service = _DelayedInspectPackageService();
      final fixture = await _pumpPortablePage(
        tester,
        clipboard: _FakeClipboard(),
        packageService: service,
      );
      await _generate(tester);
      await _tapKey(tester, 'portable-use-generated');

      service.delayNextInspection();
      await _tapKey(tester, 'portable-inspect');
      expect(service.started.isCompleted, isTrue);
      await fixture.reminderRepository.save(
        fixture.state.currentUserId!,
        const <UserLoggingReminder>[_changedReminder],
      );
      service.releaseInspection();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsNothing,
      );
      expect(
        find.text(
          'The package could not be inspected safely. No data was written.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'same-account reminder save after preview immediately hides stale result',
    (tester) async {
      final fixture = await _pumpPortablePage(
        tester,
        clipboard: _FakeClipboard(),
      );
      await _generate(tester);
      await _tapKey(tester, 'portable-use-generated');
      await _tapKey(tester, 'portable-inspect');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsOneWidget,
      );

      await fixture.reminderRepository.save(
        fixture.state.currentUserId!,
        const <UserLoggingReminder>[_changedReminder],
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'same-account AppState record-id change is rejected by display getter',
    (tester) async {
      final fixture = await _pumpPortablePage(
        tester,
        clipboard: _FakeClipboard(),
      );
      await _generate(tester);
      await _tapKey(tester, 'portable-use-generated');
      await _tapKey(tester, 'portable-inspect');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsOneWidget,
      );

      final medicationId = fixture.state.medRepo.allDrugs.first.id;
      await fixture.state.setActiveDrugIds(<String>[medicationId]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'incoming historical-only medication selection is reported as conflict',
    (tester) async {
      final service = _DelayedInspectPackageService();
      final fixture = await _pumpPortablePage(
        tester,
        clipboard: _FakeClipboard(),
        packageService: service,
      );
      final drugId = fixture.state.medRepo.allDrugs.first.id;
      expect(fixture.state.activeDrugIds, isEmpty);
      await fixture.state.addIntake(
        _intake(id: 'intake_historical_only', drugId: drugId),
      );
      await tester.pumpAndSettle();
      await _generate(tester);
      await _tapKey(tester, 'portable-use-generated');
      await _tapKey(tester, 'portable-inspect');
      await tester.pumpAndSettle();

      expect(service.lastPreview?.status, UserPortableDataPreviewStatus.ready);
      expect(
        service.lastPreview?.conflicts['medication_selections.json'],
        <String>[drugId],
      );
      expect(service.lastPreview?.conflicts['intakes.json'], <String>[
        'intake_historical_only',
      ]);
    },
  );

  testWidgets(
    'same intake id changing drug during inspect rejects stale preview',
    (tester) async {
      final service = _DelayedInspectPackageService();
      final fixture = await _pumpPortablePage(
        tester,
        clipboard: _FakeClipboard(),
        packageService: service,
      );
      final drugs = fixture.state.medRepo.allDrugs.take(2).toList();
      expect(drugs, hasLength(2));
      const intakeId = 'intake_same_id_pending';
      await fixture.state.addIntake(_intake(id: intakeId, drugId: drugs[0].id));
      await tester.pumpAndSettle();
      await _generate(tester);
      await _tapKey(tester, 'portable-use-generated');

      service.delayNextInspection();
      await _tapKey(tester, 'portable-inspect');
      expect(service.started.isCompleted, isTrue);
      await fixture.state.updateIntake(
        _intake(id: intakeId, drugId: drugs[1].id),
      );
      await tester.pump();
      service.releaseInspection();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsNothing,
      );
      expect(
        find.text(
          'The package could not be inspected safely. No data was written.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'same intake id changing drug after preview hides stale conflict result',
    (tester) async {
      final fixture = await _pumpPortablePage(
        tester,
        clipboard: _FakeClipboard(),
      );
      final drugs = fixture.state.medRepo.allDrugs.take(2).toList();
      expect(drugs, hasLength(2));
      const intakeId = 'intake_same_id_ready';
      await fixture.state.addIntake(_intake(id: intakeId, drugId: drugs[0].id));
      await tester.pumpAndSettle();
      await _generate(tester);
      await _tapKey(tester, 'portable-use-generated');
      await _tapKey(tester, 'portable-inspect');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsOneWidget,
      );

      await fixture.state.updateIntake(
        _intake(id: intakeId, drugId: drugs[1].id),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('portable-preview-status')),
        findsNothing,
      );
    },
  );
}

Intake _intake({required String id, required String drugId}) => Intake(
  id: id,
  drugId: drugId,
  takenAt: DateTime.utc(2026, 8, 17, 12),
  dosageNote: 'synthetic fixture',
  doseAmount: 100,
  doseUnit: 'mg',
);

const _changedReminder = UserLoggingReminder(
  id: 'reminder_changed_after_snapshot',
  kind: UserLoggingReminderKind.intakeLog,
  label: 'Changed private reminder',
  minuteOfDay: 840,
  weekdays: <int>{2, 4},
  enabled: true,
  activationToken: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
);

Object? _decodeInTest(String source) => jsonDecode(source);

Future<_PageFixture> _pumpPortablePage(
  WidgetTester tester, {
  required _FakeClipboard clipboard,
  PortableDataExportSink exportSink = const _ThrowingExportSink(),
  String? signInEmail,
  bool usePersistentOwnerResolver = false,
  PortableDataOwnerScopeResolver? ownerScopeResolver,
  int? inputByteBudget,
  UserPortableDataPackageService? packageService,
}) async {
  final services = Services.createEphemeral();
  await services.ready;
  await services.userDataService.saveOnboarded(true);
  final state = AppState(services: services);
  addTearDown(state.dispose);
  await state.bootstrap();
  if (signInEmail != null) {
    await state.signInWithEmail(
      email: signInEmail,
      password: 'not-used-in-local-test',
    );
  }

  final storage = _MemoryDataService();
  final reminders = UserLoggingReminderRepository(storage: storage);
  await reminders.save(state.currentUserId!, const <UserLoggingReminder>[
    UserLoggingReminder(
      id: 'reminder_export_fixture',
      kind: UserLoggingReminderKind.mealLog,
      label: 'Private fixture label',
      minuteOfDay: 720,
      weekdays: <int>{1, 3},
      enabled: true,
      activationToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
  ]);

  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: PortableDataPackagePage(
          packageService:
              packageService ??
              UserPortableDataPackageService(decodeJson: _decodeInTest),
          reminderRepository: reminders,
          exportSink: exportSink,
          ownerScopeResolver:
              ownerScopeResolver ??
              (usePersistentOwnerResolver
                  ? _FixedOwnerManager()
                  : const _FixedOwnerResolver()),
          clipboard: clipboard,
          inputByteBudget: inputByteBudget,
          now: _fixedNow,
        ),
      ),
    ),
  );
  await tester.pump();
  return _PageFixture(state, reminders);
}

Future<void> _generate(WidgetTester tester) async {
  await _tapKey(tester, 'portable-generate');
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('portable-file-name')), findsOneWidget);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _switchToAccountB(WidgetTester tester, AppState state) async {
  await state.signOut();
  await tester.pump();
  await state.signInWithEmail(
    email: 'account-b@example.test',
    password: 'not-used-in-local-test',
  );
  await tester.pumpAndSettle();
  expect(state.currentUserId, 'local_account-b@example.test');
}

String _importText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('portable-import-json')))
    .controller!
    .text;

class _PageFixture {
  const _PageFixture(this.state, this.reminderRepository);

  final AppState state;
  final UserLoggingReminderRepository reminderRepository;
}

class _FixedOwnerResolver implements PortableDataOwnerScopeResolver {
  const _FixedOwnerResolver();

  @override
  Future<PortableDataResolvedOwner> resolve({
    required String rawScope,
    required String scopeKind,
  }) async => PortableDataResolvedOwner(
    scopeKind: scopeKind,
    effectiveOpaqueScope:
        'odt_${sha256.convert(utf8.encode('test-owner|$rawScope'))}',
    protectionClass: 'test_fixed_owner_v1',
    revision: 1,
    migratedFromLegacy: false,
  );
}

class _FixedOwnerManager implements PortableDataOwnerScopeManager {
  int revision = 1;

  @override
  ProtectedSecretStoreCapability get capability =>
      const ProtectedSecretStoreCapability(
        id: 'test_protected_store_v1',
        storageMechanism: 'test_memory',
        binding: 'test_process',
        backupBehavior: 'not_applicable',
        availabilityBoundary: 'test_only',
        isEncryptedAtRest: true,
        isHardwareBackedVerified: false,
      );

  @override
  Future<PortableDataResolvedOwner> resolve({
    required String rawScope,
    required String scopeKind,
  }) async => _owner(scopeKind);

  @override
  Future<PortableDataResolvedOwner> rotate({
    required String rawScope,
    required String scopeKind,
  }) async {
    revision += 1;
    return _owner(scopeKind);
  }

  @override
  Future<void> revoke({
    required String rawScope,
    required String scopeKind,
  }) async {}

  PortableDataResolvedOwner _owner(String scopeKind) =>
      PortableDataResolvedOwner(
        scopeKind: scopeKind,
        effectiveOpaqueScope:
            'odt_${revision.toRadixString(16).padLeft(64, '0')}',
        protectionClass: capability.id,
        revision: revision,
        migratedFromLegacy: false,
        keyId: 'pok_${revision.toRadixString(16).padLeft(32, '0')}',
      );
}

class _FakeClipboard implements PortableDataClipboard {
  _FakeClipboard({this.readValue, this.readGate, this.writeGate});

  final String? readValue;
  final Completer<String?>? readGate;
  final Completer<void>? writeGate;
  final Completer<void> readStarted = Completer<void>();
  final Completer<void> writeStarted = Completer<void>();
  final List<String> writes = <String>[];

  @override
  Future<String?> readText() async {
    if (!readStarted.isCompleted) readStarted.complete();
    return readGate == null ? readValue : readGate!.future;
  }

  @override
  Future<void> writeText(
    String text, {
    required bool Function() authorize,
  }) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (writeGate != null) await writeGate!.future;
    if (!authorize()) {
      throw StateError('expired clipboard authorization');
    }
    writes.add(text);
  }
}

class _ThrowingExportSink extends PortableDataExportSink {
  const _ThrowingExportSink();

  @override
  Future<PortableDataExportResult> save({
    required String fileName,
    required String contents,
    required bool Function() authorize,
  }) async {
    if (!authorize()) {
      throw const PortableDataExportException(residualFilePossible: false);
    }
    throw const PortableDataExportException(residualFilePossible: false);
  }
}

class _DelayedExportSink extends PortableDataExportSink {
  _DelayedExportSink(this.gate);

  final Completer<void> gate;
  final Completer<void> started = Completer<void>();
  final List<String> publishedContents = <String>[];

  @override
  Future<PortableDataExportResult> save({
    required String fileName,
    required String contents,
    required bool Function() authorize,
  }) async {
    started.complete();
    await gate.future;
    if (!authorize()) {
      throw const PortableDataExportException(residualFilePossible: false);
    }
    publishedContents.add(contents);
    return const PortableDataExportResult(
      delivery: 'test',
      location: 'test',
      userVisible: true,
    );
  }
}

class _ExistingVerifiedExportSink extends PortableDataExportSink {
  const _ExistingVerifiedExportSink();

  @override
  Future<PortableDataExportResult> save({
    required String fileName,
    required String contents,
    required bool Function() authorize,
  }) async {
    if (!authorize()) {
      throw const PortableDataExportException(residualFilePossible: false);
    }
    return const PortableDataExportResult(
      delivery: 'existing_verified',
      location: 'existing.parkinsum.json',
      userVisible: true,
    );
  }
}

class _DelayedInspectPackageService extends UserPortableDataPackageService {
  _DelayedInspectPackageService() : super(decodeJson: _decodeInTest);

  Completer<void>? _gate;
  Completer<void> started = Completer<void>();
  UserPortableDataImportPreview? lastPreview;

  void delayNextInspection() {
    _gate = Completer<void>();
    started = Completer<void>();
  }

  void releaseInspection() => _gate!.complete();

  @override
  Future<UserPortableDataImportPreview> inspectAsync({
    required String packageJson,
    required String currentUserScope,
    required String currentScopeKind,
    Map<String, Set<String>> existingRecordIds = const <String, Set<String>>{},
  }) async {
    final gate = _gate;
    if (gate != null) {
      started.complete();
      await gate.future;
      if (identical(_gate, gate)) _gate = null;
    }
    final preview = await super.inspectAsync(
      packageJson: packageJson,
      currentUserScope: currentUserScope,
      currentScopeKind: currentScopeKind,
      existingRecordIds: existingRecordIds,
    );
    if (existingRecordIds.isNotEmpty) lastPreview = preview;
    return preview;
  }
}

DateTime _fixedNow() => DateTime.utc(2026, 8, 17, 15);

class _MemoryDataService extends DataService {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _ThrowingDataService extends DataService {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> setString(String key, String value) async {
    throw StateError('injected repository write failure');
  }
}

class _DroppingDataService extends DataService {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> setString(String key, String value) async {}
}
