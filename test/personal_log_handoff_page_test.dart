import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_document_service.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';
import 'package:parkinsum_companion/features/settings/personal_log_handoff_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'system renderer creates an offline bounded PDF from page canvas',
    (tester) async {
      late BuildContext renderContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              renderContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      const artifact = PersonalLogHandoffArtifact(
        artifactId: 'artifact',
        ownerBindingSha256: 'owner',
        sourceRevisionSha256: 'source',
        contentSha256: 'content',
        fileName: 'parkinsum-personal-log-test.pdf',
        plainText: 'USER-ENTERED PERSONAL LOG',
        pages: <PersonalLogHandoffDocumentPage>[
          PersonalLogHandoffDocumentPage(
            number: 1,
            lines: <String>[
              '# ParkinSUM personal log handoff',
              '! USER-ENTERED PERSONAL LOG — NOT CLINICALLY VERIFIED',
              'Known zero: 0 g; unknown value: unknown',
            ],
          ),
        ],
        recordCounts: <String, int>{},
        unsupportedFields: <String>[],
        semanticDocument: <String, Object?>{},
      );

      final bytes = await tester.runAsync(
        () => const SystemPersonalLogHandoffPdfRenderer(
          pixelRatio: 1,
        ).render(context: renderContext, artifact: artifact),
      );

      expect(bytes, isNotNull);
      expect(bytes!.length, lessThan(personalLogHandoffMaxPdfBytes));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preview, copy, print and share use one frozen artifact', (
    tester,
  ) async {
    final renderer = _FakeRenderer();
    final delivery = _FakeDelivery();
    final clipboard = _FakeClipboard();
    final fixture = await _pumpPage(
      tester,
      renderer: renderer,
      delivery: delivery,
      clipboard: clipboard,
    );

    await _tap(tester, 'handoff-generate');
    expect(find.byKey(const ValueKey('handoff-preview-meta')), findsOneWidget);
    expect(renderer.artifacts, hasLength(1));
    final artifact = renderer.artifacts.single;
    expect(
      find.byKey(const ValueKey('handoff-preview-page-1')),
      findsOneWidget,
    );

    await _tap(tester, 'handoff-copy');
    expect(clipboard.values, <String>[artifact.plainText]);
    await _tap(tester, 'handoff-print');
    await _tap(tester, 'handoff-save-share');

    expect(delivery.printed, <String>[artifact.fileName]);
    expect(delivery.shared, <String>[artifact.fileName]);
    expect(delivery.bytes.first, renderer.bytes);
    expect(delivery.bytes.last, renderer.bytes);
    expect(fixture.state.currentUserId, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-id record content change invalidates preview and delivery',
    (tester) async {
      final renderer = _FakeRenderer();
      final delivery = _FakeDelivery();
      final fixture = await _pumpPage(
        tester,
        renderer: renderer,
        delivery: delivery,
        clipboard: _FakeClipboard(),
      );
      await _tap(tester, 'handoff-generate');
      expect(
        find.byKey(const ValueKey('handoff-preview-meta')),
        findsOneWidget,
      );

      final original = fixture.state.intakes.single;
      await fixture.state.updateIntake(
        original.copyWith(dosageNote: 'same id, changed content'),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('handoff-preview-meta')), findsNothing);
      expect(find.byKey(const ValueKey('handoff-error')), findsOneWidget);
      expect(delivery.shared, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account switch expires delayed save authorization', (
    tester,
  ) async {
    final gate = Completer<void>();
    final delivery = _FakeDelivery(saveGate: gate);
    final fixture = await _pumpPage(
      tester,
      renderer: _FakeRenderer(),
      delivery: delivery,
      clipboard: _FakeClipboard(),
    );
    await _tap(tester, 'handoff-generate');

    await tester.ensureVisible(
      find.byKey(const ValueKey('handoff-save-share')),
    );
    await tester.tap(find.byKey(const ValueKey('handoff-save-share')));
    await tester.pump();
    expect(delivery.saveStarted.isCompleted, isTrue);

    await fixture.state.signOut();
    await fixture.state.signInWithEmail(
      email: 'account-b@example.test',
      password: 'not-used-in-local-test',
    );
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(delivery.shared, isEmpty);
    expect(find.byKey(const ValueKey('handoff-preview-meta')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing a section invalidates generated preview', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      renderer: _FakeRenderer(),
      delivery: _FakeDelivery(),
      clipboard: _FakeClipboard(),
    );
    await _tap(tester, 'handoff-generate');
    expect(find.byKey(const ValueKey('handoff-preview-meta')), findsOneWidget);

    await _tap(tester, 'handoff-section-mealLog');
    expect(find.byKey(const ValueKey('handoff-preview-meta')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled system sheet never reports save success', (
    tester,
  ) async {
    final delivery = _FakeDelivery(
      saveStatus: PersonalLogHandoffDeliveryStatus.cancelled,
    );
    await _pumpPage(
      tester,
      renderer: _FakeRenderer(),
      delivery: delivery,
      clipboard: _FakeClipboard(),
    );
    await _tap(tester, 'handoff-generate');
    await _tap(tester, 'handoff-save-share');

    expect(
      find.text('The action was cancelled; no save or print is claimed.'),
      findsOneWidget,
    );
    expect(find.text('The system save / share flow completed.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _Fixture {
  const _Fixture(this.state);

  final AppState state;
}

Future<_Fixture> _pumpPage(
  WidgetTester tester, {
  required _FakeRenderer renderer,
  required _FakeDelivery delivery,
  required _FakeClipboard clipboard,
}) async {
  final services = Services.createEphemeral();
  await services.ready;
  await services.userDataService.saveOnboarded(true);
  final state = AppState(services: services);
  addTearDown(state.dispose);
  await state.bootstrap();
  final drug = state.medRepo.allDrugs.first;
  await state.addIntake(
    Intake(
      id: 'handoff_intake',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 8, 10, 12),
      dosageNote: '',
      doseAmount: 25,
      doseUnit: 'mg',
      dosageForm: drug.dosageForm,
      route: drug.route,
      releaseType: drug.releaseType,
    ),
  );
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: PersonalLogHandoffPage(
          renderer: renderer,
          delivery: delivery,
          clipboard: clipboard,
          now: () => DateTime.utc(2026, 8, 18, 12),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Fixture(state);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final class _FakeRenderer implements PersonalLogHandoffRenderer {
  final Uint8List bytes = Uint8List.fromList(<int>[37, 80, 68, 70, 45, 49]);
  final List<PersonalLogHandoffArtifact> artifacts =
      <PersonalLogHandoffArtifact>[];

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  }) async {
    artifacts.add(artifact);
    return bytes;
  }
}

final class _FakeDelivery implements PersonalLogHandoffDelivery {
  _FakeDelivery({
    this.saveGate,
    this.saveStatus = PersonalLogHandoffDeliveryStatus.completed,
  });

  final Completer<void>? saveGate;
  final PersonalLogHandoffDeliveryStatus saveStatus;
  final Completer<void> saveStarted = Completer<void>();
  final List<String> printed = <String>[];
  final List<String> shared = <String>[];
  final List<Uint8List> bytes = <Uint8List>[];

  @override
  Future<PersonalLogHandoffDeliveryStatus> printPdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('authorization_expired');
    printed.add(fileName);
    this.bytes.add(bytes);
    return PersonalLogHandoffDeliveryStatus.completed;
  }

  @override
  Future<PersonalLogHandoffDeliveryStatus> saveOrSharePdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  }) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    if (saveGate != null) await saveGate!.future;
    if (!authorize()) throw StateError('authorization_expired');
    if (saveStatus == PersonalLogHandoffDeliveryStatus.completed) {
      shared.add(fileName);
      this.bytes.add(bytes);
    }
    return saveStatus;
  }
}

final class _FakeClipboard implements PersonalLogHandoffClipboard {
  final List<String> values = <String>[];

  @override
  Future<void> writeText(
    String text, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('authorization_expired');
    values.add(text);
  }
}
