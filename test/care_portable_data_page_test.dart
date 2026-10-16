import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/care_workspace/care_portable_data_page.dart';
import 'package:parkinsum_companion/features/settings/portable_data_package_page.dart';
import 'package:provider/provider.dart';

final class _Clipboard implements PortableDataClipboard {
  String? text;
  int writes = 0;
  @override
  Future<String?> readText() async => text;
  @override
  Future<void> writeText(
    String text, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('expired');
    this.text = text;
    writes += 1;
  }
}

Future<AppState> _fixture(WidgetTester tester) async {
  final state = await tester.runAsync(() async {
    final services = Services.createEphemeral();
    await services.ready;
    await services.userDataService.saveOnboarded(true);
    final state = AppState(services: services);
    await state.bootstrap();
    await state.addDiscussionNote('Synthetic explicit question');
    return state;
  });
  addTearDown(state!.dispose);
  return state;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      350,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester,
  AppState state,
  _Clipboard clipboard, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: CarePortableDataPage(clipboard: clipboard),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'explicit generation/copy, no-write preview, cancellation and confirmed Care-only restoration',
    (tester) async {
      final state = await _fixture(tester);
      final clipboard = _Clipboard();
      final sourceNote = state.discussionNotes.single;
      final originalProfile = jsonEncode(state.userProfile.toJson());
      final originalMeals = state.meals.map((m) => m.toJson()).toList();
      await _open(tester, state, clipboard);
      await _tap(tester, 'care-backup-generate');
      await _tap(tester, 'care-backup-copy');
      expect(clipboard.writes, 1);
      expect(clipboard.text, contains('Synthetic explicit question'));
      expect(clipboard.text, isNot(contains(state.currentUserId!)));
      expect(
        await tester.runAsync(() => state.deleteDiscussionNote(sourceNote.id)),
        isTrue,
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'care-restore-paste');
      await _tap(tester, 'care-restore-preview');
      expect(state.discussionNotes, isEmpty);
      await _tap(tester, 'care-restore-confirm');
      await _tap(tester, 'care-restore-dialog-cancel');
      expect(state.discussionNotes, isEmpty);
      await _tap(tester, 'care-restore-confirm');
      await _tap(tester, 'care-restore-dialog-confirm');
      expect(state.discussionNotes.single.toJson(), sourceNote.toJson());
      expect(jsonEncode(state.userProfile.toJson()), originalProfile);
      expect(state.meals.map((m) => m.toJson()).toList(), originalMeals);
      expect(find.text('Care records saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('record changes expire generated backup and restore preview', (
    tester,
  ) async {
    final state = await _fixture(tester);
    final clipboard = _Clipboard();
    await _open(tester, state, clipboard);
    await _tap(tester, 'care-backup-generate');
    await _tap(tester, 'care-backup-copy');
    await _tap(tester, 'care-restore-paste');
    await _tap(tester, 'care-restore-preview');
    expect(
      await tester.runAsync(
        () => state.addDiscussionNote('Later new question'),
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('care-backup-stale')), findsOneWidget);
    expect(find.byKey(const ValueKey('care-backup-copy')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('care-restore-stale')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('care-restore-confirm')), findsNothing);
    expect(state.discussionNotes, hasLength(2));
  });

  testWidgets(
    'signout hides prior package/input and same-account reentry requires reopening',
    (tester) async {
      final state = await _fixture(tester);
      final clipboard = _Clipboard();
      await _open(tester, state, clipboard);
      await _tap(tester, 'care-backup-generate');
      await tester.runAsync(() => state.signOut());
      await tester.pumpAndSettle();
      expect(find.text('Session changed. Please reopen.'), findsOneWidget);
      expect(find.byKey(const ValueKey('care-restore-input')), findsNothing);
      await tester.runAsync(() => state.bootstrap());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('care-backup-copy')), findsNothing);
      expect(find.byKey(const ValueKey('care-restore-input')), findsNothing);
    },
  );

  for (final locale in ['en-US', 'zh-CN']) {
    testWidgets('$locale Care backup remains operable at 390px and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await _fixture(tester);
      final clipboard = _Clipboard();
      final saved = await tester.runAsync(
        () => state.saveUserProfile(
          state.userProfile.copyWith(displayLocale: locale),
        ),
      );
      expect(saved?.wasCommitted, isTrue);
      expect(saved?.appliesToCurrentSession, isTrue);
      await _open(tester, state, clipboard, scale: 2);
      await _tap(tester, 'care-backup-generate');
      await _tap(tester, 'care-backup-copy');
      await _tap(tester, 'care-restore-paste');
      await _tap(tester, 'care-restore-preview');
      expect(state.discussionNotes, hasLength(1));
      expect(clipboard.writes, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
