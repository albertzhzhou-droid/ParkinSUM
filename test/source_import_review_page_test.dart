import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/features/import/source_import_review_page.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'reviewed_import_activation_test.dart' show prepareOn, activationBundle;
import 'held_import_review_evidence_test.dart' show serviceFor;

// Web Locks invoke real JavaScript callbacks. Yield real time and pump the
// widget microtask zone until the visible operation finishes; do not mock locks.
Future<void> settleReview(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 250; attempt++) {
      await tester.pump();
      if (find.byKey(const ValueKey('source-review-busy')).evaluate().isEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError(
      'Source review did not finish its asynchronous operation.',
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  // Browser lock promises use the real event loop, including page initialization.
  if (kIsWeb) {
    LiveTestWidgetsFlutterBinding().framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> reveal(WidgetTester tester, Finder target) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settleReview(tester);
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('source-review-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await settleReview(tester);
    expect(target.hitTestable(), findsOneWidget);
  }

  Future<void> choose(WidgetTester tester) async {
    await reveal(tester, find.byKey(const ValueKey('source-review-reference')));
    await tester.enterText(
      find.byKey(const ValueKey('source-review-reference')),
      'Synthetic local review',
    );
    await reveal(tester, find.byKey(const ValueKey('source-review-reason')));
    await tester.enterText(
      find.byKey(const ValueKey('source-review-reason')),
      'Original source b reviewed for this software fixture.',
    );
    final dropdown = find.byWidgetPredicate(
      (w) => w is DropdownButtonFormField<String>,
    );
    await reveal(tester, dropdown);
    await tester.tap(dropdown);
    await settleReview(tester);
    await tester.tap(find.text('10 g · source').last);
    await settleReview(tester);
    final button = find.byKey(const ValueKey('source-review-preview'));
    await reveal(tester, button);
    await tester.tap(button);
    await settleReview(tester);
  }

  testWidgets(
    'real local UI choice previews without promotion, then explicit confirmation consumes original 10',
    (tester) async {
      final db = WebCdssDatabase();
      final service = serviceFor(db);
      final held = (await tester.runAsync(() => prepareOn(db, service)))!;
      int refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SourceImportReviewPage(
            snapshotId: held.snapshotId,
            releaseService: held.release,
            isSessionCurrent: () => true,
            onActivated: () async {
              refreshed++;
            },
          ),
        ),
      );
      await settleReview(tester);
      await choose(tester);
      expect(
        (await db.queryTable(
          'engine_snapshot',
        )).where((r) => r['promoted_at'] != null),
        isEmpty,
      );
      final confirm = find.byKey(const ValueKey('source-review-confirm'));
      await reveal(tester, confirm);
      await tester.tap(confirm);
      await settleReview(tester);
      final activate = find.byKey(const ValueKey('source-review-activate'));
      await reveal(tester, activate);
      await tester.tap(activate);
      await settleReview(tester);
      expect(refreshed, 1);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('source-review-notice')),
        -200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('source-review-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await settleReview(tester);
      expect(
        find.byKey(const ValueKey('source-review-notice')),
        findsOneWidget,
      );
      expect(
        (await CdssCatalogProjectionService(
          database: WebCdssDatabase(),
          requireConsistentCatalog: true,
        ).projectFoods()).single.proteinG,
        10,
      );
      expect(
        (await db.queryTable(
          'engine_snapshot',
        )).where((r) => r['promoted_at'] != null),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'source change after preview keeps the import held and displays the actual refusal',
    (tester) async {
      final db = WebCdssDatabase();
      final service = serviceFor(db);
      final held = (await tester.runAsync(() => prepareOn(db, service)))!;
      await tester.pumpWidget(
        MaterialApp(
          home: SourceImportReviewPage(
            snapshotId: held.snapshotId,
            releaseService: held.release,
            isSessionCurrent: () => true,
            onActivated: () async {
              fail('Not committed');
            },
          ),
        ),
      );
      await settleReview(tester);
      await choose(tester);
      await tester.runAsync(
        () => db.insertSourceDocument(
          activationBundle(status: 'retired').sourceDocuments.single,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(WebCdssDatabase.stateKey);
      final confirm = find.byKey(const ValueKey('source-review-confirm'));
      await reveal(tester, confirm);
      await tester.tap(confirm);
      await settleReview(tester);
      final activate = find.byKey(const ValueKey('source-review-activate'));
      await reveal(tester, activate);
      await tester.tap(activate);
      await settleReview(tester);
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), before);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('source-review-error')),
        -200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('source-review-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(const ValueKey('source-review-error')), findsOneWidget);
    },
  );
  testWidgets(
    'session transition clears typed explanations and original preview',
    (tester) async {
      final db = WebCdssDatabase();
      final held = (await tester.runAsync(
        () => prepareOn(db, serviceFor(db)),
      ))!;
      final current = ValueNotifier(true);
      addTearDown(current.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SourceImportReviewPage(
            snapshotId: held.snapshotId,
            releaseService: held.release,
            isSessionCurrent: () => current.value,
            sessionChanges: current,
            onActivated: () async {},
            localeTag: 'zh-CN',
          ),
        ),
      );
      await settleReview(tester);
      await tester.enterText(
        find.byKey(const ValueKey('source-review-reference')),
        'Private typed explanation',
      );
      current.value = false;
      await settleReview(tester);
      expect(find.text('Private typed explanation'), findsNothing);
      expect(find.byKey(const ValueKey('source-review-confirm')), findsNothing);
      expect(
        (await db.queryTable(
          'engine_snapshot',
        )).where((r) => r['promoted_at'] != null),
        isEmpty,
      );
    },
  );

  for (final locale in ['en-US', 'zh-CN']) {
    testWidgets('source review works at 390px and 200 percent in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = WebCdssDatabase();
      final held = (await tester.runAsync(
        () => prepareOn(db, serviceFor(db)),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: SourceImportReviewPage(
            snapshotId: held.snapshotId,
            releaseService: held.release,
            isSessionCurrent: () => true,
            onActivated: () async {},
            localeTag: locale,
          ),
        ),
      );
      await settleReview(tester);
      await choose(tester);
      await reveal(tester, find.byKey(const ValueKey('source-review-confirm')));
      expect(tester.takeException(), isNull);
      expect(
        (await db.queryTable(
          'engine_snapshot',
        )).where((r) => r['promoted_at'] != null),
        isEmpty,
      );
    });
  }
  test(
    'session revocation after last receipt write rolls back the entire activation',
    () async {
      final db = WebCdssDatabase();
      final service = serviceFor(db);
      final held = await prepareOn(db, service);
      final preview = await held.release.previewReviewedImport(
        heldSnapshotId: held.snapshotId,
        decisionIds: [held.decisionId],
      );
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(WebCdssDatabase.stateKey);
      int checks = 0;
      await expectLater(
        held.release.activateReviewedImportForSession(
          preview: preview,
          confirmationReference: 'synthetic',
          confirmationReason: 'test session rollback',
          isSessionCurrent: () => ++checks == 1,
        ),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), before);
    },
  );
}
