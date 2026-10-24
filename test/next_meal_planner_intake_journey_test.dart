import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/core/services/medication_product_catalog.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/usecases/intake_dose_context_builder.dart';
import 'package:parkinsum_companion/features/next_meal/next_meal_page.dart';
import 'package:parkinsum_companion/features/shared/package_dose_selector.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';

/// End to end with the bundled openFDA snapshot and synthetic times only:
/// a dose logged through the strength picker carries the picked product's
/// own form, route and release type, so the planner can model it.
const _catalogPath = 'assets/data/common_medication_products_openfda.json';
const _levodopaId = 'drug_levodopa_carbidopa';
const _strength25100 = 'carbidopa/levodopa 25/100 mg · tablet';

MedicationProductPack _pack(String dosageForm, List<String> routes) =>
    MedicationProductPack(
      id: 'synthetic_pack',
      genericName: 'carbidopa and levodopa',
      brandName: null,
      labelerName: null,
      jurisdiction: 'US',
      identifiers: const [
        MedicationProductIdentifier(
          system: MedicationIdentifierSystem.ndcPackage,
          level: MedicationIdentifierLevel.package,
          value: '00000-0000-00',
        ),
      ],
      ingredients: const [],
      dosageForm: dosageForm,
      routes: routes,
      packageDescription: '',
      marketingStartDate: null,
      marketingEndDate: null,
      sourceSystem: 'SYNTHETIC',
      sourceUrl: 'https://example.test',
      retrievedAt: null,
    );

void main() {
  final catalogJson = File(_catalogPath).readAsStringSync();

  test('a product record states release type only through its SPL form', () {
    expect(productFormulationFromPack(_pack('TABLET', ['ORAL'])), (
      dosageForm: 'spl:TABLET',
      route: 'oral',
      releaseType: 'immediate',
    ));
    for (final (form, release) in [
      ('TABLET, ORALLY DISINTEGRATING', 'immediate'),
      ('TABLET, EXTENDED RELEASE', 'extended_release'),
      ('CAPSULE, EXTENDED RELEASE', 'extended_release'),
      ('TABLET, DELAYED RELEASE', 'delayed_release'),
      ('SOLUTION', 'unspecified'),
      ('CAPSULE, COATED PELLETS', 'unspecified'),
      ('unspecified', 'unspecified'),
    ]) {
      expect(releaseTypeForSplDosageForm(form), release, reason: form);
    }
    expect(
      productFormulationFromPack(_pack('TABLET', ['ORAL', 'SUBLINGUAL'])).route,
      'unspecified',
    );
    expect(
      productFormulationFromPack(_pack('unspecified', const [])).dosageForm,
      'unspecified',
    );
  });

  test('a selected product needs its own formulation to be resolved', () {
    final services = Services.createEphemeral();
    final drug = services.medicationRepository.getById(_levodopaId)!;
    final selected = Intake(
      id: 'synthetic',
      drugId: _levodopaId,
      takenAt: DateTime.utc(2026, 10, 20, 8),
      dosageNote: '100 mg',
      // Catalog-level fields, as saved before the product formulation was
      // carried: not evidence for the picked package.
      dosageForm: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      productSelection: MedicationProductSelection.fromPack(
        _pack('TABLET', ['ORAL']),
      ),
    );
    expect(
      resolveIntakeMechanisticFormulation(
        intake: selected,
        drug: drug,
      ).releaseType,
      'unspecified',
    );
    final carried = withProductFormulation(
      selected,
      _pack('TABLET, EXTENDED RELEASE', ['ORAL']),
    );
    expect(resolveIntakeMechanisticFormulation(intake: carried, drug: drug), (
      dosageForm: 'tablet',
      route: 'oral',
      releaseType: 'extended_release',
    ));
  });

  Future<AppState> logThroughPicker(
    WidgetTester tester,
    String strengthLabel,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    await state.bootstrap();
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 2400);
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
    await _tapVisible(tester, find.text(strengthLabel));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('package-quantity-1')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('dose-confirmation-checkbox')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('intake-save')),
    );
    expect(state.intakes, hasLength(1));
    return state;
  }

  Future<void> openPlanner(WidgetTester tester, AppState state) async {
    final dose = state.intakes.single.takenAt;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: NextMealPage(
            clock: () => dose.add(const Duration(minutes: 30)),
            initialPlannedAt: dose.subtract(const Duration(minutes: 2)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('strength chip → saved dose → the planner shows a modeled chip', (
    tester,
  ) async {
    final state = await logThroughPicker(tester, _strength25100);
    final intake = state.intakes.single;
    expect(intake.productSelection, isNotNull);
    expect(intake.dosageForm, 'spl:TABLET');
    expect(intake.route, 'oral');
    expect(intake.releaseType, 'immediate');
    expect(intake.doseConfirmation, isNotNull);

    await openPlanner(tester, state);
    expect(find.textContaining('meal 2 min before the dose'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'Modeled brain entry ≈ [\d–]+% of no meal')),
      findsWidgets,
    );
    expect(find.textContaining('release type'), findsNothing);
  });

  testWidgets('an extended-release strength is recorded and not modeled', (
    tester,
  ) async {
    final catalog = MedicationProductCatalog.fromOpenFdaSnapshot(catalogJson);
    final drug = Services.createEphemeral().medicationRepository.getById(
      _levodopaId,
    )!;
    final extended = packageStrengthOptions(catalog, drug).firstWhere(
      (pack) => pack.dosageForm.toUpperCase() == 'TABLET, EXTENDED RELEASE',
    );
    final state = await logThroughPicker(
      tester,
      packageStrengthLabel(extended),
    );
    expect(state.intakes.single.releaseType, 'extended_release');

    await openPlanner(tester, state);
    expect(
      find.textContaining('covers oral immediate-release levodopa only'),
      findsWidgets,
    );
    expect(find.textContaining('Modeled brain entry ≈'), findsNothing);
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
