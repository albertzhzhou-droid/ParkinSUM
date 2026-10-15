import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_document_service.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_html_download.dart'
    if (dart.library.js_interop) 'package:parkinsum_companion/core/services/personal_log_handoff_html_download_web.dart'
    as html_download;
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';
import 'package:parkinsum_companion/features/settings/personal_log_handoff_page.dart';
import 'package:provider/provider.dart';

void main() {
  for (final invalid in <({String name, Uint8List bytes, String code})>[
    (name: '../unsafe.html', bytes: Uint8List(1), code: 'invalid_file_name'),
    (
      name: 'parkinsum-personal-log-test.html',
      bytes: Uint8List(0),
      code: 'invalid_html_bytes',
    ),
  ]) {
    test(
      'HTML delivery rejects ${invalid.code} before a system action',
      () async {
        await expectLater(
          const SystemPersonalLogHandoffDelivery().shareHtml(
            bytes: invalid.bytes,
            fileName: invalid.name,
            sharePositionOrigin: null,
            authorize: () => true,
          ),
          throwsA(
            isA<PersonalLogHandoffDeliveryException>().having(
              (error) => error.code,
              'code',
              invalid.code,
            ),
          ),
        );
      },
    );
  }
  test(
    'HTML delivery declines an expired lease before a system action',
    () async {
      await expectLater(
        const SystemPersonalLogHandoffDelivery().shareHtml(
          bytes: Uint8List(1),
          fileName: 'parkinsum-personal-log-test.html',
          sharePositionOrigin: null,
          authorize: () => false,
        ),
        throwsA(
          isA<PersonalLogHandoffDeliveryException>().having(
            (error) => error.code,
            'code',
            'authorization_expired',
          ),
        ),
      );
    },
  );
  test(
    'browser HTML download rejects initial or changed authorization',
    () async {
      for (final firstCheckAccepted in <bool>[false, true]) {
        var checks = 0;
        await expectLater(
          html_download.downloadHtml(
            bytes: Uint8List(1),
            fileName: 'parkinsum-personal-log-test.html',
            authorize: () => ++checks == 1 && firstCheckAccepted,
          ),
          throwsA(
            isA<html_download.HandoffHtmlDownloadException>().having(
              (error) => error.code,
              'code',
              'authorization_expired',
            ),
          ),
        );
        expect(checks, firstCheckAccepted ? 2 : 1);
      }
    },
    skip: !kIsWeb,
  );
  test(
    'browser HTML download validates filenames and byte budget first',
    () async {
      for (final invalid in <({String name, Uint8List bytes, String code})>[
        (
          name: '../unsafe.html',
          bytes: Uint8List(1),
          code: 'invalid_file_name',
        ),
        (
          name: 'parkinsum-personal-log-test.html',
          bytes: Uint8List(personalLogHandoffMaxHtmlBytes + 1),
          code: 'invalid_html_bytes',
        ),
      ]) {
        await expectLater(
          html_download.downloadHtml(
            bytes: invalid.bytes,
            fileName: invalid.name,
            authorize: () => throw StateError('unexpected_authorization'),
          ),
          throwsA(
            isA<html_download.HandoffHtmlDownloadException>().having(
              (error) => error.code,
              'code',
              invalid.code,
            ),
          ),
        );
      }
    },
    skip: !kIsWeb,
  );

  testWidgets('page canvas retains every warning character', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersonalLogHandoffPageCanvas(
          page: PersonalLogHandoffDocumentPage(
            number: 1,
            lines: <String>[
              '# Personal log handoff',
              '## Evidence boundary',
              '! USER-ENTERED PERSONAL LOG — NOT CLINICALLY VERIFIED',
              '! Not a medical recommendation.',
              '! Missing values remain unknown.',
            ],
          ),
          totalPages: 1,
        ),
      ),
    );
    expect(find.text('Personal log handoff'), findsOneWidget);
    expect(find.text('Evidence boundary'), findsOneWidget);
    expect(
      find.text('USER-ENTERED PERSONAL LOG — NOT CLINICALLY VERIFIED'),
      findsOneWidget,
    );
    expect(find.text('Not a medical recommendation.'), findsOneWidget);
    expect(find.text('Missing values remain unknown.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system renderer creates an offline bounded PDF from page canvas',
    (tester) async {
      // The report page must retain its fixed A4 canvas even on a small view.
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
        documentBlocks: <PersonalLogHandoffDocumentBlock>[
          PersonalLogHandoffHeadingBlock(level: 1, text: 'Handoff'),
        ],
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
      final pdfText = String.fromCharCodes(bytes);
      expect(pdfText, matches(RegExp(r'/Width\s+595\b')));
      expect(pdfText, matches(RegExp(r'/Height\s+842\b')));
      // A second render exercises disposal of the detached tree and image.
      final again = await tester.runAsync(
        () => const SystemPersonalLogHandoffPdfRenderer(
          pixelRatio: 1,
        ).render(context: renderContext, artifact: artifact),
      );
      expect(String.fromCharCodes(again!.take(4)), '%PDF');
      expect(tester.takeException(), isNull);
    },
  );

  test('failure diagnostics preserve only stable types and source locations', () {
    final diagnostic = PersonalLogHandoffFailureDiagnostic.capture(
      stage: PersonalLogHandoffFailureStage.renderPdf,
      error: const _PrivateFailure(),
      stackTrace: StackTrace.fromString(
        '#0 patient_payload token=secret '
        '(package:parkinsum_companion/core/services/'
        'personal_log_handoff_document_service.dart:301:12)\n'
        '#1 patient_payload (https://user:token@example.invalid/'
        'main.dart.js:457:8)\n'
        '#2 patient_payload (file:///private/patient_payload.dart:1:2)\n'
        '#3 patient_payload (package:parkinsum_companion/'
        'patient_payload.dart:3:4)',
      ),
    );
    expect(diagnostic.failureType, 'Exception');
    expect(diagnostic.sourceFrames, <String>[
      'personal_log_handoff_document_service.dart:301:12',
      'main.dart.js:457:8',
    ]);
    expect(
      diagnostic.logLine,
      '[PersonalLogHandoff] failed stage=renderPdf type=Exception '
      'source=personal_log_handoff_document_service.dart:301:12,main.dart.js:457:8',
    );
    for (final secret in <String>[
      'patient_payload',
      'token',
      'example.invalid',
      '/private/',
    ]) {
      expect(diagnostic.logLine, isNot(contains(secret)));
    }
  });

  testWidgets('renderer failure stays blocked and logs no private message', (
    tester,
  ) async {
    final messages = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      final delivery = _FakeDelivery();
      final clipboard = _FakeClipboard();
      await _pumpPage(
        tester,
        renderer: _FakeRenderer(
          failure: const FormatException('private_health_payload'),
        ),
        delivery: delivery,
        clipboard: clipboard,
      );
      await _tap(tester, 'handoff-generate');
      expect(find.byKey(const ValueKey('handoff-preview-meta')), findsNothing);
      expect(find.byKey(const ValueKey('handoff-save-share')), findsNothing);
      expect(find.byKey(const ValueKey('handoff-error')), findsOneWidget);
      expect(find.textContaining('format_failed'), findsOneWidget);
      expect(find.textContaining('private_health_payload'), findsNothing);
      expect(delivery.printed, isEmpty);
      expect(delivery.shared, isEmpty);
      expect(delivery.htmlShared, isEmpty);
      expect(clipboard.values, isEmpty);
      expect(
        messages.join('\n'),
        contains('failed stage=renderPdf type=FormatException source='),
      );
      expect(messages.join('\n'), isNot(contains('private_health_payload')));
      expect(tester.takeException(), isNull);
    } finally {
      // Flutter verifies foundation globals before running addTearDown hooks.
      debugPrint = oldDebugPrint;
    }
  });

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
    await _tap(tester, 'handoff-reading-preview');
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SelectionArea),
        matching: find.text('Medication intake log'),
      ),
      findsOneWidget,
    );

    await _tap(tester, 'handoff-copy');
    expect(clipboard.values, <String>[artifact.plainText]);
    await _tap(tester, 'handoff-share-html');
    await _tap(tester, 'handoff-print');
    await _tap(tester, 'handoff-save-share');

    expect(delivery.printed, <String>[artifact.fileName]);
    expect(delivery.shared, <String>[artifact.fileName]);
    expect(delivery.htmlShared, <String>[artifact.htmlFileName]);
    expect(delivery.htmlBytes, hasLength(1));
    expect(
      String.fromCharCodes(delivery.htmlBytes.single),
      contains('parkinsum-document-schema'),
    );
    expect(delivery.bytes.first, renderer.bytes);
    expect(delivery.bytes.last, renderer.bytes);
    expect(fixture.state.currentUserId, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final code in [
    'handoff_pdf_font_unavailable',
    'handoff_pdf_glyph_unavailable',
  ]) {
    testWidgets('$code preserves current HTML and disables PDF delivery', (
      tester,
    ) async {
      final renderer = _FakeRenderer(failure: FormatException(code));
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
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('handoff-print')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('handoff-save-share')),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, 'handoff-share-html');
      expect(delivery.htmlShared, hasLength(1));
      expect(delivery.printed, isEmpty);
      expect(delivery.shared, isEmpty);
      expect(fixture.state.currentUserId, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

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

    await _tapAndPump(tester, 'handoff-save-share');
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

  testWidgets('account switch expires delayed HTML share authorization', (
    tester,
  ) async {
    final gate = Completer<void>();
    final delivery = _FakeDelivery(htmlGate: gate);
    final fixture = await _pumpPage(
      tester,
      renderer: _FakeRenderer(),
      delivery: delivery,
      clipboard: _FakeClipboard(),
    );
    await _tap(tester, 'handoff-generate');

    await _tapAndPump(tester, 'handoff-share-html');
    expect(delivery.htmlStarted.isCompleted, isTrue);

    await fixture.state.signOut();
    await fixture.state.signInWithEmail(
      email: 'account-b@example.test',
      password: 'not-used-in-local-test',
    );
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(delivery.htmlShared, isEmpty);
    expect(find.byKey(const ValueKey('handoff-preview-meta')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same UID without an intermediate frame expires delayed renderer',
    (tester) async {
      final gate = Completer<void>();
      final renderer = _FakeRenderer(renderGate: gate);
      final delivery = _FakeDelivery();
      final fixture = await _pumpPage(
        tester,
        renderer: renderer,
        delivery: delivery,
        clipboard: _FakeClipboard(),
      );
      await _tapAndPump(tester, 'handoff-generate');
      expect(renderer.artifacts, hasLength(1));

      await _restartSameOwnerWithoutFrame(fixture, renderer.artifacts.single);
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('handoff-preview-meta')), findsNothing);
      expect(find.byKey(const ValueKey('handoff-share-html')), findsNothing);
      expect(delivery.htmlShared, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same UID without an intermediate frame expires stored preview action',
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
      final oldAction = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('handoff-share-html')),
          )
          .onPressed!;

      await _restartSameOwnerWithoutFrame(fixture, renderer.artifacts.single);
      // Invoke the previously rendered callback before Provider can rebuild it.
      oldAction();
      await tester.pumpAndSettle();

      expect(delivery.htmlStarted.isCompleted, isFalse);
      expect(delivery.htmlShared, isEmpty);
      expect(find.byKey(const ValueKey('handoff-preview-meta')), findsNothing);

      // A newly generated artifact and explicit action in the renewed session
      // remain allowed; only the previous session's authorization was revoked.
      await _tap(tester, 'handoff-generate');
      expect(
        find.byKey(const ValueKey('handoff-preview-meta')),
        findsOneWidget,
      );
      await _tap(tester, 'handoff-share-html');
      expect(delivery.htmlShared, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final html in <bool>[false, true]) {
    testWidgets(
      'same UID without an intermediate frame expires delayed ${html ? 'HTML download' : 'PDF delivery'}',
      (tester) async {
        final gate = Completer<void>();
        final renderer = _FakeRenderer();
        final delivery = _FakeDelivery(
          saveGate: html ? null : gate,
          htmlGate: html ? gate : null,
          htmlStatus: PersonalLogHandoffDeliveryStatus.downloadRequested,
        );
        final fixture = await _pumpPage(
          tester,
          renderer: renderer,
          delivery: delivery,
          clipboard: _FakeClipboard(),
        );
        await _tap(tester, 'handoff-generate');
        await _tapAndPump(
          tester,
          html ? 'handoff-share-html' : 'handoff-save-share',
        );
        expect(
          (html ? delivery.htmlStarted : delivery.saveStarted).isCompleted,
          isTrue,
        );

        await _restartSameOwnerWithoutFrame(fixture, renderer.artifacts.single);
        gate.complete();
        await tester.pumpAndSettle();

        expect(delivery.shared, isEmpty);
        expect(delivery.htmlShared, isEmpty);
        expect(
          find.byKey(const ValueKey('handoff-preview-meta')),
          findsNothing,
        );
        expect(
          find.textContaining('A browser download was requested'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  testWidgets('personal observations are opt-in and edits expire the preview', (
    tester,
  ) async {
    final renderer = _FakeRenderer();
    final fixture = await _pumpPage(
      tester,
      renderer: renderer,
      delivery: _FakeDelivery(),
      clipboard: _FakeClipboard(),
    );
    const sectionKey = ValueKey('handoff-section-personalObservations');
    expect(
      tester.widget<CheckboxListTile>(find.byKey(sectionKey)).value,
      isFalse,
    );

    final owner = fixture.state.currentUserId!;
    final observation = PersonalObservation.create(
      id: 'handoff-observation-private-id',
      kind: PersonalObservationKind.symptom,
      occurredAt: DateTime.utc(2026, 8, 10, 9),
      recordedAt: DateTime.utc(2026, 8, 10, 9, 5),
      originalTimezone: 'America/Toronto',
      source: PersonalObservationSource.selfReported,
      recorderId: owner,
      status: PersonalObservationStatus.recorded,
      symptomLabel: 'Tremor',
      severity: 5,
    );
    expect(await fixture.state.saveObservation(observation), isTrue);
    await tester.pump();

    await _tap(tester, 'handoff-generate');
    final omitted = renderer.artifacts.single;
    expect(omitted.recordCounts['personalObservations'], 0);
    expect(omitted.plainText, isNot(contains('Tremor')));

    await _tap(tester, 'handoff-section-personalObservations');
    await _tap(tester, 'handoff-generate');
    final included = renderer.artifacts.last;
    expect(included.recordCounts['personalObservations'], 1);
    expect(included.plainText, contains('Tremor'));
    expect(included.plainText, contains('severity=5/10'));
    expect(
      included.plainText,
      isNot(contains('handoff-observation-private-id')),
    );
    expect(included.plainText, isNot(contains(owner)));

    final edited = PersonalObservation.create(
      id: observation.id,
      kind: observation.kind,
      occurredAt: observation.occurredAt,
      recordedAt: observation.recordedAt,
      originalTimezone: observation.originalTimezone,
      source: observation.source,
      recorderId: owner,
      status: observation.status,
      symptomLabel: observation.symptomLabel,
      severity: 6,
    );
    expect(await fixture.state.saveObservation(edited), isTrue);
    await tester.pump();
    await tester.pump();
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
  testWidgets('HTML browser download is a request rather than saved success', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      renderer: _FakeRenderer(),
      delivery: _FakeDelivery(
        htmlStatus: PersonalLogHandoffDeliveryStatus.downloadRequested,
      ),
      clipboard: _FakeClipboard(),
    );
    await _tap(tester, 'handoff-generate');
    await _tap(tester, 'handoff-share-html');
    expect(
      find.text(
        'A browser download was requested. Confirm that the file appears in your downloads.',
      ),
      findsOneWidget,
    );
    expect(find.text('The system save / share flow completed.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelled HTML share never reports a browser download', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      renderer: _FakeRenderer(),
      delivery: _FakeDelivery(
        htmlStatus: PersonalLogHandoffDeliveryStatus.cancelled,
      ),
      clipboard: _FakeClipboard(),
    );
    await _tap(tester, 'handoff-generate');
    await _tap(tester, 'handoff-share-html');
    expect(
      find.text('The action was cancelled; no save or print is claimed.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('A browser download was requested'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

final class _Fixture {
  const _Fixture(this.state);

  final AppState state;
}

Future<void> _restartSameOwnerWithoutFrame(
  _Fixture fixture,
  PersonalLogHandoffArtifact artifact,
) async {
  final state = fixture.state;
  final owner = state.currentUserId!;
  final epoch = state.mealDraftSessionEpoch;
  await state.signOut();
  await state.bootstrap();
  expect(state.currentUserId, owner);
  expect(state.mealDraftSessionEpoch, greaterThan(epoch));
  // The persisted content is identical: a source-revision check alone cannot
  // distinguish the previous session from the new same-owner session.
  final digest = const PersonalLogHandoffSummaryService().sourceRevisionDigest(
    snapshot: PersonalLogHandoffSnapshot(
      ownerScope: owner,
      profile: state.userProfile,
      activeDrugIds: state.activeDrugIds,
      intakes: state.intakes,
      meals: state.meals,
      observations: state.observations,
      medicationCatalog: state.medRepo.allDrugs,
      foodCatalog: state.foodRepo.allFoods,
    ),
    options: PersonalLogHandoffOptions(
      startDate: DateTime(2026, 7, 20),
      endDateInclusive: DateTime(2026, 8, 18),
      sections: PersonalLogHandoffSection.values
          .where(
            (section) =>
                section != PersonalLogHandoffSection.personalObservations,
          )
          .toSet(),
      redaction: PersonalLogHandoffRedaction.standard,
    ),
  );
  expect(digest, artifact.sourceRevisionSha256);
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
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapAndPump(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

final class _FakeRenderer implements PersonalLogHandoffRenderer {
  _FakeRenderer({this.failure, this.renderGate});

  final Object? failure;
  final Completer<void>? renderGate;
  final Uint8List bytes = Uint8List.fromList(<int>[37, 80, 68, 70, 45, 49]);
  final List<PersonalLogHandoffArtifact> artifacts =
      <PersonalLogHandoffArtifact>[];

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  }) async {
    artifacts.add(artifact);
    if (renderGate != null) await renderGate!.future;
    if (failure case final error?) throw error;
    return bytes;
  }
}

final class _PrivateFailure implements Exception {
  const _PrivateFailure();

  @override
  String toString() => throw StateError('exception messages must not be read');
}

final class _FakeDelivery implements PersonalLogHandoffDelivery {
  _FakeDelivery({
    this.saveGate,
    this.htmlGate,
    this.saveStatus = PersonalLogHandoffDeliveryStatus.completed,
    this.htmlStatus = PersonalLogHandoffDeliveryStatus.completed,
  });

  final Completer<void>? saveGate;
  final Completer<void>? htmlGate;
  final PersonalLogHandoffDeliveryStatus saveStatus;
  final PersonalLogHandoffDeliveryStatus htmlStatus;
  final Completer<void> saveStarted = Completer<void>();
  final Completer<void> htmlStarted = Completer<void>();
  final List<String> printed = <String>[];
  final List<String> shared = <String>[];
  final List<String> htmlShared = <String>[];
  final List<Uint8List> bytes = <Uint8List>[];
  final List<Uint8List> htmlBytes = <Uint8List>[];

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

  @override
  Future<PersonalLogHandoffDeliveryStatus> shareHtml({
    required Uint8List bytes,
    required String fileName,
    required Rect? sharePositionOrigin,
    required bool Function() authorize,
  }) async {
    if (!htmlStarted.isCompleted) htmlStarted.complete();
    if (htmlGate != null) await htmlGate!.future;
    if (!authorize()) throw StateError('authorization_expired');
    if (htmlStatus == PersonalLogHandoffDeliveryStatus.completed ||
        htmlStatus == PersonalLogHandoffDeliveryStatus.downloadRequested) {
      htmlShared.add(fileName);
      htmlBytes.add(bytes);
    }
    return htmlStatus;
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
