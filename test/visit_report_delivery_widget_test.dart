import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_document_service.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/services/care_workspace_service.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';
import 'package:parkinsum_companion/features/care_workspace/care_workspace_page.dart';
import 'package:parkinsum_companion/features/care_workspace/visit_report_selection_page.dart';
import 'package:provider/provider.dart';

Future<AppState> _fixture(WidgetTester tester) async {
  final state = await tester.runAsync(() async {
    final services = Services.createEphemeral();
    await services.ready;
    await services.userDataService.saveOnboarded(true);
    final state = AppState(services: services);
    await state.bootstrap();
    final owner = state.currentUserId!;
    await services.careWorkspaceService.mutate(
      owner,
      (current) => current.copyWith(
        notes: [
          CareDiscussionNote(
            id: 'selected_question',
            text: 'Selected explicit question',
            recordedAt: DateTime.utc(2026, 9, 30, 12),
            recorderId: owner,
          ),
          CareDiscussionNote(
            id: 'unselected_question',
            text: 'UNSELECTED_PRIVATE_QUESTION',
            recordedAt: DateTime.utc(2026, 9, 30, 13),
            recorderId: owner,
          ),
        ],
      ),
      authorize: () => state.currentUserId == owner,
    );
    await state.reloadCareWorkspace();
    await Future<void>.delayed(Duration.zero);
    return state;
  });
  if (state == null) throw StateError('Synthetic fixture unavailable');
  addTearDown(state.dispose);
  return state;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      400,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(target);
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

Future<void> _preview(
  WidgetTester tester,
  AppState state,
  _Delivery delivery, {
  PersonalLogHandoffRenderer renderer = const _Renderer(),
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: VisitReportSelectionPage(
          renderer: renderer,
          delivery: delivery,
          now: () => DateTime.utc(2026, 10, 1, 23, 59),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, 'visit-selection-question');
  await _tap(tester, 'visit-select-none-question');
  await _tap(tester, 'visit-select-question-${state.discussionNotes.first.id}');
  await _tap(tester, 'visit-selected-preview');
  expect(find.byType(VisitPreparationPreview), findsOneWidget);
}

void main() {
  testWidgets(
    'source reload clears selection and uses the changed profile timezone',
    (tester) async {
      final state = await _fixture(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            home: VisitReportSelectionPage(
              renderer: const _Renderer(),
              delivery: _Delivery(),
              now: () => DateTime.utc(2026, 10, 1, 23, 59),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () =>
            state.saveUserProfile(state.userProfile.copyWith(timezone: 'UTC')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('visit-selected-preview')),
        findsNothing,
      );
      await _tap(tester, 'visit-selection-reload');
      await _tap(tester, 'visit-selected-preview');
      final preview = tester.widget<VisitPreparationPreview>(
        find.byType(VisitPreparationPreview),
      );
      expect(preview.report.userNotes, isEmpty);
      expect(
        (preview.handoffArtifact!.semanticDocument['selection']
            as Map)['zoneId'],
        'UTC',
      );
      expect(state.discussionNotes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en-US', 'zh-CN']) {
    testWidgets(
      'selection remains operable at 390 pixels and 200 percent text for $locale',
      (tester) async {
        final state = await _fixture(tester);
        await tester.runAsync(
          () => state.saveUserProfile(
            state.userProfile.copyWith(displayLocale: locale),
          ),
        );
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: VisitReportSelectionPage(
                renderer: const _Renderer(),
                delivery: _Delivery(),
                now: () => DateTime.utc(2026, 10, 1, 23, 59),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'visit-selection-question');
        await _tap(tester, 'visit-select-none-question');
        await _tap(tester, 'visit-selected-preview');
        expect(find.byType(VisitPreparationPreview), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selection, preview and HTML delivery retain the same chosen question',
    (tester) async {
      final state = await _fixture(tester);
      final delivery = _Delivery();
      await _preview(tester, state, delivery);
      final preview = tester.widget<VisitPreparationPreview>(
        find.byType(VisitPreparationPreview),
      );
      expect(preview.report.plainText, contains('Selected explicit question'));
      expect(
        preview.report.plainText,
        isNot(contains('UNSELECTED_PRIVATE_QUESTION')),
      );
      expect(
        preview.handoffArtifact!.plainText,
        isNot(contains('UNSELECTED_PRIVATE_QUESTION')),
      );
      await _tap(tester, 'visit-export-html');
      expect(delivery.calls, 1);
      expect(delivery.html, contains('Selected explicit question'));
      expect(delivery.html, isNot(contains('UNSELECTED_PRIVATE_QUESTION')));
      expect(delivery.html, contains('<html lang="en" dir="auto">'));
      expect(state.discussionNotes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelled PDF delivery reports cancellation and preserves source records',
    (tester) async {
      final state = await _fixture(tester);
      final delivery = _Delivery(
        status: PersonalLogHandoffDeliveryStatus.cancelled,
      );
      await _preview(tester, state, delivery);
      await _tap(tester, 'visit-export-pdf');
      expect(delivery.calls, 1);
      expect(find.text('Cancelled; no save success reported.'), findsOneWidget);
      expect(find.text('Delivery completed.'), findsNothing);
      expect(state.discussionNotes, hasLength(2));
    },
  );

  testWidgets(
    'source change during PDF rendering hides preview and dispatches no delivery',
    (tester) async {
      final state = await _fixture(tester);
      final delivery = _Delivery();
      final renderer = _PausedRenderer();
      await _preview(tester, state, delivery, renderer: renderer);
      await _tap(tester, 'visit-export-pdf');
      await renderer.started.future;
      await tester.runAsync(
        () => state.addDiscussionNote('New source record while rendering'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('visit-export-html')), findsNothing);
      renderer.complete();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(delivery.calls, 0);
      expect(find.text('Delivery completed.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Delivery implements PersonalLogHandoffDelivery {
  _Delivery({this.status = PersonalLogHandoffDeliveryStatus.completed});
  final PersonalLogHandoffDeliveryStatus status;
  int calls = 0;
  String? html;
  void check(bool Function() authorize) {
    if (!authorize()) {
      throw const PersonalLogHandoffDeliveryException('authorization_expired');
    }
    calls++;
  }

  @override
  Future<PersonalLogHandoffDeliveryStatus> shareHtml({
    required Uint8List bytes,
    required String fileName,
    required Rect? sharePositionOrigin,
    required bool Function() authorize,
  }) async {
    check(authorize);
    html = utf8.decode(bytes);
    return status;
  }

  @override
  Future<PersonalLogHandoffDeliveryStatus> saveOrSharePdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  }) async {
    check(authorize);
    return status;
  }

  @override
  Future<PersonalLogHandoffDeliveryStatus> printPdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  }) async {
    check(authorize);
    return status;
  }
}

class _Renderer implements PersonalLogHandoffRenderer {
  const _Renderer();
  @override
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  }) async => Uint8List.fromList(ascii.encode('%PDF-'));
}

class _PausedRenderer implements PersonalLogHandoffRenderer {
  final started = Completer<void>();
  final _pending = Completer<Uint8List>();
  void complete() {
    if (!_pending.isCompleted) {
      _pending.complete(Uint8List.fromList(ascii.encode('%PDF-')));
    }
  }

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  }) {
    started.complete();
    return _pending.future;
  }
}
