import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_currency_candidate_comparison.dart';
import 'package:parkinsum_companion/features/diagnostics/evidence_currency_candidate_panel.dart';

void main() {
  final registry = EvidenceCurrencyRegistry.current;
  final instant = DateTime.utc(2026, 8, 19);
  final syntheticReceipt = const EvidenceCurrencyCandidateComparisonService()
      .compare(
        baseline: registry,
        candidate: EvidenceCurrencyRegistry(
          records: [
            registry.records.first.copyWith(
              status: EvidenceCurrencyStatus.retracted,
              updateNoticeId: 'synthetic_test',
            ),
            ...registry.records.skip(1),
          ],
        ),
        asOfUtc: instant,
      );

  Widget page(
    ValueNotifier<String?> owner, {
    EvidenceCurrencyComparisonReceiptStore Function(String)? storeFactory,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: EvidenceCurrencyCandidatePanel(
          localeTag: 'en-US',
          registry: registry,
          asOfUtc: instant,
          currentOwner: () => owner.value,
          ownerChanges: owner,
          sessionAuthorized: () => owner.value != null,
          storeFactory: storeFactory,
        ),
      ),
    ),
  );

  testWidgets(
    'offline candidate changes and historical snapshots survive new panel instances',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final owner = ValueNotifier<String?>('synthetic_owner_a');
      await tester.pumpWidget(page(owner));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('compare-synthetic-evidence-candidate')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('current → retracted'), findsOneWidget);
      expect(
        find.textContaining('affected calculation withheld'),
        findsWidgets,
      );
      await tester.ensureVisible(
        find.byKey(const Key('save-evidence-comparison-receipt')),
      );
      await tester.tap(
        find.byKey(const Key('save-evidence-comparison-receipt')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved historical receipts · 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page(owner));
      await tester.pumpAndSettle();
      expect(find.text('Saved historical receipts · 1'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Synthetic candidate · not activated'),
      );
      await tester.tap(find.text('Synthetic candidate · not activated'));
      await tester.pumpAndSettle();
      expect(find.text('Historical baseline snapshot'), findsOneWidget);
      expect(find.text('Historical candidate snapshot'), findsOneWidget);
      expect(registry.records.first.status, EvidenceCurrencyStatus.current);
      owner.dispose();
    },
  );

  testWidgets(
    'owner A to B to A cannot revive an old asynchronous history lease',
    (tester) async {
      final owner = ValueNotifier<String?>('synthetic_owner_a');
      final delayed = Completer<List<EvidenceCurrencyComparisonReceipt>>();
      var loadsA = 0;
      final a = _TestStore(
        load: () => ++loadsA == 1 ? delayed.future : Future.value([]),
      );
      final b = _TestStore(load: () async => []);
      await tester.pumpWidget(
        page(owner, storeFactory: (id) => id.endsWith('_a') ? a : b),
      );
      await tester.pump();
      owner.value = 'synthetic_owner_b';
      await tester.pump();
      owner.value = 'synthetic_owner_a';
      await tester.pump();
      delayed.complete([syntheticReceipt]);
      await tester.pumpAndSettle();
      expect(find.text('Saved historical receipts · 0'), findsOneWidget);
      expect(find.text('Synthetic candidate · not activated'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      owner.dispose();
    },
  );

  testWidgets(
    'account switch revokes a pending save and clears candidate/history state',
    (tester) async {
      final owner = ValueNotifier<String?>('synthetic_owner_a');
      final releaseSave = Completer<void>();
      var saved = false;
      final store = _TestStore(
        load: () async => [],
        retain: (_, authorize) async {
          await releaseSave.future;
          if (authorize?.call() != true) throw StateError('lease revoked');
          saved = true;
        },
      );
      await tester.pumpWidget(page(owner, storeFactory: (_) => store));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('compare-synthetic-evidence-candidate')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('save-evidence-comparison-receipt')),
      );
      await tester.tap(
        find.byKey(const Key('save-evidence-comparison-receipt')),
      );
      await tester.pump();
      owner.value = 'synthetic_owner_b';
      await tester.pump();
      releaseSave.complete();
      await tester.pumpAndSettle();
      expect(saved, isFalse);
      expect(
        find.byKey(const Key('save-evidence-comparison-receipt')),
        findsNothing,
      );
      expect(find.text('Saved historical receipts · 0'), findsOneWidget);
      expect(find.text('Local receipt saved.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      owner.dispose();
    },
  );
}

class _TestStore implements EvidenceCurrencyComparisonReceiptStore {
  _TestStore({
    required Future<List<EvidenceCurrencyComparisonReceipt>> Function() load,
    Future<void> Function(EvidenceCurrencyComparisonReceipt, bool Function()?)?
    retain,
  }) : _load = load,
       _retain = retain;
  final Future<List<EvidenceCurrencyComparisonReceipt>> Function() _load;
  final Future<void> Function(
    EvidenceCurrencyComparisonReceipt,
    bool Function()?,
  )?
  _retain;
  @override
  Future<List<EvidenceCurrencyComparisonReceipt>> load({
    bool Function()? authorize,
  }) => _load();
  @override
  Future<void> retain(
    EvidenceCurrencyComparisonReceipt receipt, {
    bool Function()? authorize,
  }) async {
    await _retain?.call(receipt, authorize);
  }
}
