import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/catalog_version_change_diff.dart';
import 'package:parkinsum_companion/features/diagnostics/data_integrity_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('data integrity view renders without fabricating percentages', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const DataIntegrityPage());

    expect(find.byType(DataIntegrityPage), findsOneWidget);
    expect(find.textContaining('0/0 100%'), findsNothing);
    expectNoWidgetErrors(reason: 'data integrity view failed to build cleanly');
  });

  testWidgets(
    'catalog diff is a local preview and clears after input changes',
    (tester) async {
      final state = await pumpFeaturePage(
        tester,
        const DataIntegrityPage(),
        state: AppState(services: Services.createEphemeral()),
      );
      final originalMedicationCount = state.medRepo.allDrugs.length;
      final catalogPanel = find.byKey(const Key('catalog-version-diff-panel'));
      await _bringIntoView(tester, catalogPanel);
      await tester.tap(catalogPanel);
      await tester.pumpAndSettle();

      final previous = _snapshot('2026-01', 1, const [('OLD', 'Old display')]);
      final current = _snapshot('2026-02', 2, const [('NEW', 'New display')]);
      final mapping = CatalogMappingEvidence(
        evidenceId: 'fixture-replacement',
        sourceCode: 'OLD',
        targetCodes: const ['NEW'],
        relationship: CatalogTransitionRelationship.replacedBy,
        sourceReference: 'fixture:evidence',
        evidenceSha256: List<String>.filled(64, 'a').join(),
        previousRecordSetSha256: previous.recordSetSha256,
        currentRecordSetSha256: current.recordSetSha256,
        review: CatalogMappingEvidenceReview.reviewed,
        license: CatalogMappingEvidenceLicense.clearedForLocalReview,
      );
      final previousCapture = find.byKey(
        const Key('catalog-version-diff-previous-capture'),
      );
      await _bringIntoView(tester, previousCapture);
      await tester.enterText(previousCapture, jsonEncode(previous.toJson()));
      final currentCapture = find.byKey(
        const Key('catalog-version-diff-current-capture'),
      );
      await _bringIntoView(tester, currentCapture);
      await tester.enterText(currentCapture, jsonEncode(current.toJson()));
      final mappingCapture = find.byKey(
        const Key('catalog-version-diff-mapping-evidence'),
      );
      await _bringIntoView(tester, mappingCapture);
      await tester.enterText(mappingCapture, jsonEncode([mapping.toJson()]));
      final compareButton = find.byKey(
        const Key('catalog-version-diff-compare'),
      );
      await _bringIntoView(tester, compareButton);
      await tester.tap(compareButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('catalog-version-diff-result')),
        findsOneWidget,
      );
      expect(find.textContaining('OLD → NEW'), findsOneWidget);
      expect(state.medRepo.allDrugs, hasLength(originalMedicationCount));

      final medicationImpactAction = find.byKey(
        const Key('catalog-version-diff-impact-scan'),
      );
      await _bringIntoView(tester, medicationImpactAction);
      await tester.tap(medicationImpactAction);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('catalog-version-diff-impact-result')),
        findsOneWidget,
      );

      await state.setActiveDrugIds(<String>[state.medRepo.allDrugs.first.id]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('catalog-version-diff-impact-result')),
        findsNothing,
        reason: 'an active-medication change expires its aggregate preview',
      );

      await _bringIntoView(tester, medicationImpactAction);
      await tester.tap(medicationImpactAction);
      await tester.pumpAndSettle();

      await state.addIntake(
        Intake(
          id: 'synthetic-impact-state-change',
          drugId: state.medRepo.allDrugs.first.id,
          takenAt: DateTime.utc(2026),
          dosageNote: '',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('catalog-version-diff-impact-result')),
        findsNothing,
        reason: 'a medication log change expires its aggregate preview',
      );

      await _bringIntoView(tester, medicationImpactAction);
      await tester.tap(medicationImpactAction);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('catalog-version-diff-impact-result')),
        findsOneWidget,
      );

      final foodImpactAction = find.byKey(
        const Key('catalog-version-diff-food-impact-scan'),
      );
      await _bringIntoView(tester, foodImpactAction);
      await tester.tap(foodImpactAction);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('catalog-version-diff-food-impact-result')),
        findsOneWidget,
      );

      final foodsWithChangedIdentity = state.foodRepo.allFoods.toList();
      final selectedFood = foodsWithChangedIdentity.first;
      foodsWithChangedIdentity[0] = FoodItem.fromJson({
        ...selectedFood.toJson(),
        'sourceFoodCode': '${selectedFood.sourceFoodCode ?? 'synthetic'}-v2',
      });
      state.foodRepo.replaceAll(foodsWithChangedIdentity);
      state.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('catalog-version-diff-food-impact-result')),
        findsNothing,
        reason: 'a food catalog identity change expires its aggregate preview',
      );

      await _bringIntoView(tester, currentCapture);
      await tester.enterText(currentCapture, '{}');
      await tester.pump();
      expect(
        find.byKey(const Key('catalog-version-diff-result')),
        findsNothing,
      );
    },
  );
}

Future<void> _bringIntoView(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

CatalogReleaseSnapshot _snapshot(
  String releaseId,
  int releaseSequence,
  List<(String, String)> concepts,
) => CatalogReleaseSnapshot(
  catalogId: 'synthetic_catalog',
  sourceSystem: 'synthetic_source',
  jurisdiction: 'US',
  releaseId: releaseId,
  releaseSequence: releaseSequence,
  concepts: [
    for (final (code, display) in concepts)
      CatalogConceptIdentity(
        sourceSystem: 'synthetic_source',
        jurisdiction: 'US',
        releaseId: releaseId,
        code: code,
        display: display,
      ),
  ],
);
