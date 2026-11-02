import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/services/medication_product_catalog.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/onboarding/onboarding_flow.dart';
import 'package:parkinsum_companion/features/onboarding/onboarding_page.dart';
import 'package:parkinsum_companion/features/shared/package_dose_selector.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';

const _catalogPath = 'assets/data/common_medication_products_openfda.json';
const _levodopaId = 'drug_levodopa_carbidopa';
const _strength25100 = 'carbidopa/levodopa 25/100 mg · tablet';

void main() {
  final catalogJson = File(_catalogPath).readAsStringSync();

  test(
    'levodopa strengths come from the bundled catalog, one per strength',
    () {
      final catalog = MedicationProductCatalog.fromOpenFdaSnapshot(catalogJson);
      final services = Services.createEphemeral();
      final drug = services.medicationRepository.getById(_levodopaId)!;
      final labels = packageStrengthOptions(
        catalog,
        drug,
      ).map(packageStrengthLabel).toList();

      expect(
        labels.take(3),
        orderedEquals(<String>[
          'carbidopa/levodopa 10/100 mg · tablet',
          _strength25100,
          'carbidopa/levodopa 25/250 mg · tablet',
        ]),
      );
      expect(labels.toSet(), hasLength(labels.length));
      // Three-ingredient entacapone combinations are a different medication.
      expect(labels.where((label) => label.contains('entacapone')), isEmpty);
    },
  );

  test('without a pick the draft records no dose and no derivation', () {
    final intake = OnboardingDraft(
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      swallowingTextureMode: 'unrestricted',
      localAiConsentEnabled: false,
      contentJurisdictionOverrideText: '',
      activeDrugIds: const [_levodopaId],
      initialIntakeDrugId: _levodopaId,
      initialIntakeAt: DateTime.utc(2026, 10, 22, 8),
      initialIntakeDoseNote: '',
    ).buildInitialIntake(intakeId: 'intake_no_pick');

    expect(intake!.dosageNote, isEmpty);
    expect(intake.doseAmount, isNull);
    expect(intake.productSelection, isNull);
  });

  testWidgets('the timeline intake editor uses the same picker', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    await state.bootstrap();
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: DefaultAssetBundle(
          bundle: _CatalogAssetBundle(catalogJson),
          child: const MaterialApp(home: IntakeEditorPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text(_strength25100));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('package-quantity-1.5')),
    );
    expect(find.text('= 150 mg levodopa'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('intake-dose-note')),
          )
          .controller!
          .text,
      '150 mg',
    );

    // Another strength replaces the calculated dose instead of keeping it.
    await _tapVisible(
      tester,
      find.text('carbidopa/levodopa 25/250 mg · tablet'),
    );
    expect(find.byKey(const ValueKey('package-dose-result')), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('intake-dose-note')),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  group('onboarding intake step', () {
    Future<AppState> pumpOnboarding(WidgetTester tester) async {
      final services = Services.createEphemeral();
      await services.ready;
      final state = AppState(services: services);
      await state.bootstrap();
      addTearDown(state.dispose);
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: DefaultAssetBundle(
            bundle: _CatalogAssetBundle(catalogJson),
            child: const MaterialApp(home: OnboardingPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Initial medications'));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('onboarding-medication-$_levodopaId')),
      );
      await _tapVisible(tester, find.text('Record most recent intake'));
      return state;
    }

    Future<void> finish(WidgetTester tester) async {
      await _tapVisible(tester, find.text('Review and start'));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('onboarding-finish')),
      );
    }

    CheckboxListTile checkbox(WidgetTester tester) =>
        tester.widget<CheckboxListTile>(
          find.byKey(const Key('dose-confirmation-checkbox')),
        );

    String doseField(WidgetTester tester) => tester
        .widget<TextField>(
          find.byKey(const ValueKey('onboarding-initial-intake-dose')),
        )
        .controller!
        .text;

    testWidgets('25/100 × 1½ shows and records 150 mg levodopa', (
      tester,
    ) async {
      final state = await pumpOnboarding(tester);

      await _tapVisible(tester, find.text(_strength25100));
      // A strength alone is not a dose.
      expect(doseField(tester), isEmpty);
      expect(find.byKey(const ValueKey('package-dose-result')), findsNothing);
      expect(checkbox(tester).onChanged, isNull);

      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('package-quantity-1.5')),
      );
      expect(find.text('= 150 mg levodopa'), findsOneWidget);
      expect(doseField(tester), '150 mg');
      // Calculated, but only recorded as confirmed after the explicit tick.
      expect(checkbox(tester).value, isFalse);

      await _tapVisible(
        tester,
        find.byKey(const Key('dose-confirmation-checkbox')),
      );
      await finish(tester);

      final intake = state.intakes.single;
      expect(intake.drugId, _levodopaId);
      expect(intake.doseAmount, 150);
      expect(intake.doseUnit, 'mg');
      expect(intake.productSelection!.doseDerivation!.resultValue, 150);
      expect(intake.productSelection!.doseDerivation!.packageUnitQuantity, 1.5);
      expect(
        intake.doseConfirmation!.assertionSource,
        AdministrationDoseAssertionSource.packageDerived,
      );
      expect(state.evaluateDoseConfirmation(intake).confirmed, isTrue);
    });

    testWidgets('no strength or count selected records no dose', (
      tester,
    ) async {
      final state = await pumpOnboarding(tester);

      expect(find.text(_strength25100), findsOneWidget);
      expect(checkbox(tester).onChanged, isNull);
      await finish(tester);

      final intake = state.intakes.single;
      expect(intake.dosageNote, isEmpty);
      expect(intake.doseAmount, isNull);
      expect(intake.productSelection, isNull);
      expect(intake.doseConfirmation, isNull);
    });

    testWidgets('free text still validates as before', (tester) async {
      final state = await pumpOnboarding(tester);
      final field = find.byKey(
        const ValueKey('onboarding-initial-intake-dose'),
      );

      await tester.enterText(field, '25/100');
      await tester.pump();
      expect(checkbox(tester).onChanged, isNull);

      await tester.enterText(field, '100 mg');
      await tester.pump();
      expect(checkbox(tester).onChanged, isNotNull);
      await _tapVisible(
        tester,
        find.byKey(const Key('dose-confirmation-checkbox')),
      );
      await finish(tester);

      final intake = state.intakes.single;
      expect(intake.doseAmount, 100);
      expect(intake.productSelection, isNull);
      expect(
        intake.doseConfirmation!.assertionSource,
        AdministrationDoseAssertionSource.typed,
      );
    });

    testWidgets('typing over a calculated dose drops the derivation', (
      tester,
    ) async {
      final state = await pumpOnboarding(tester);
      await _tapVisible(tester, find.text(_strength25100));
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('package-quantity-1')),
      );
      expect(find.text('= 100 mg levodopa'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-initial-intake-dose')),
        '120 mg',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('package-dose-result')), findsNothing);
      await finish(tester);

      final intake = state.intakes.single;
      expect(intake.doseAmount, isNull);
      expect(intake.productSelection!.doseDerivation, isNull);
    });
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  // The catalog loads asynchronously; give it a few frames to appear.
  for (var frame = 0; frame < 20 && finder.evaluate().isEmpty; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _CatalogAssetBundle extends CachingAssetBundle {
  _CatalogAssetBundle(this.catalogJson);

  final String catalogJson;

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      key == _catalogPath ? catalogJson : rootBundle.loadString(key);
}
