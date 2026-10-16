import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/app_database_memory.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_replay_capsule.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_event_ledger_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const configurationSha =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test(
    'web archive rejects duplicate JSON members before last-value-wins and preserves raw history',
    () async {
      final capsule = _capsule(_fixture(), configurationSha);
      final raw = capsule.canonicalJson;
      for (final duplicate in [
        raw.replaceFirst('{', '{"capsule_id":"${capsule.capsuleId}",'),
        raw.replaceFirst('{', '{"capsule_\\u0069d":"${capsule.capsuleId}",'),
      ]) {
        // The old decoder would retain the same final payload and valid hash.
        expect(
          MechanisticReplayCapsule.fromJson(
            Map<String, Object?>.from(jsonDecode(duplicate) as Map),
          ).capsuleSha256,
          capsule.capsuleSha256,
        );
        final archive = '[$duplicate]';
        SharedPreferences.setMockInitialValues({
          'db.mechanistic_replay_capsules.v1': archive,
        });
        final database = WebAppDatabase();
        await expectLater(
          database.loadMechanisticReplayCapsules(),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'duplicate',
              'replay_json_duplicate_member',
            ),
          ),
        );
        await expectLater(
          database.saveMechanisticReplayCapsule(capsule),
          throwsFormatException,
        );
        expect(
          (await SharedPreferences.getInstance()).getString(
            'db.mechanistic_replay_capsules.v1',
          ),
          archive,
        );
      }
    },
  );

  test(
    'rich engine input survives an exact self-contained replay round trip',
    () {
      final fixture = _fixture();
      final ledger = const MechanisticEventLedgerBuilder().build(
        ledgerId: 'lossless_replay_rich_fixture',
        context: fixture.context,
        mealCompositionsById: fixture.compositions,
        configurationDigest: configurationSha,
        createdAtUtc: DateTime.utc(2026, 8, 31, 12),
        sourceId: 'synthetic:test',
        revisionId: 'lossless_replay_v1',
        synthetic: true,
      );
      final capsule = MechanisticReplayCapsule.capture(
        capsuleId: 'lossless_replay_rich_fixture',
        generatedAtUtc: DateTime.utc(2026, 8, 31, 12),
        ledger: ledger,
        context: fixture.context,
        mealCompositionsById: fixture.compositions,
      );

      final parsed = MechanisticReplayCapsule.fromJsonString(
        capsule.canonicalJson,
      );
      final restored = parsed.restore(
        expectedConfigurationSha256: configurationSha,
      );

      expect(parsed.capsuleSha256, capsule.capsuleSha256);
      expect(parsed.canonicalJson, capsule.canonicalJson);
      expect(restored.ledger.toJson(), ledger.toJson());
      expect(restored.context.toJson(), fixture.context.toJson());
      expect(
        restored.mealCompositionsById['composition-rich']!.toJson(),
        fixture.compositions['composition-rich']!.toJson(),
      );
      expect(restored.context.foodComponentEvents, hasLength(1));
      expect(
        restored.context.medicationEvents.single.context.metadata,
        isNotNull,
      );
      expect(
        restored
            .mealCompositionsById['composition-rich']!
            .foodComponents
            .single
            .aminoAcidProfile,
        isNotNull,
      );
    },
  );

  test('map order changes do not change canonical bytes or digest', () {
    final capsule = _capsule(_fixture(), configurationSha);
    final decoded = jsonDecode(capsule.canonicalJson) as Map<String, dynamic>;
    final reversed = <String, Object?>{
      for (final key in decoded.keys.toList().reversed) key: decoded[key],
    };
    final reparsed = MechanisticReplayCapsule.fromJson(reversed);

    expect(reparsed.canonicalJson, capsule.canonicalJson);
    expect(reparsed.capsuleSha256, capsule.capsuleSha256);
  });

  test('raw replay rejects duplicate root and escaped nested member names', () {
    final capsule = _capsule(_fixture(), configurationSha);
    final raw = capsule.canonicalJson;
    final cases = [
      raw.replaceFirst('{', '{"capsule_id":"${capsule.capsuleId}",'),
      raw.replaceFirst(
        '"context":{',
        '"context":{"discarded":true,"discar\\u0064ed":false,',
      ),
      '{"array":[{"a":1,"\\u0061":1}]}',
    ];
    for (final duplicate in cases) {
      expect(
        () => MechanisticReplayCapsule.fromJsonString(duplicate),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'reason',
            'replay_json_duplicate_member',
          ),
        ),
      );
    }
  });

  test(
    'raw replay transport applies container depth and UTF-8 byte limits before decoding',
    () {
      final depth = mechanisticReplayMaxJsonContainerDepth + 1;
      final deep = '${'[' * depth}0${']' * depth}';
      expect(
        () => MechanisticReplayCapsule.fromJsonString(deep),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'reason',
            'replay_json_depth_limit',
          ),
        ),
      );
      final oversized = '"${'餐' * (mechanisticReplayMaxJsonBytes ~/ 3 + 1)}"';
      expect(oversized.length, lessThan(mechanisticReplayMaxJsonBytes));
      expect(
        () => MechanisticReplayCapsule.fromJsonString(oversized),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'reason',
            'replay_json_byte_limit',
          ),
        ),
      );
      // Exactly at each ceiling the transport scan succeeds, then the capsule
      // root schema independently rejects the intentionally non-capsule input.
      final atByteLimit = '${' ' * (mechanisticReplayMaxJsonBytes - 2)}{}';
      expect(
        () => MechanisticReplayCapsule.fromJsonString(atByteLimit),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'schema rejection',
            contains('keys mismatch'),
          ),
        ),
      );
      final atDepthLimit =
          '${'[' * mechanisticReplayMaxJsonContainerDepth}0${']' * mechanisticReplayMaxJsonContainerDepth}';
      expect(
        () => MechanisticReplayCapsule.fromJsonString(atDepthLimit),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'schema rejection',
            contains('must be an object'),
          ),
        ),
      );
    },
  );

  test('future replay schema remains rejected without implicit migration', () {
    final capsule = _capsule(_fixture(), configurationSha);
    final future = Map<String, Object?>.from(capsule.toJson())
      ..['schema_version'] = 2;
    expect(
      () => MechanisticReplayCapsule.fromJsonString(jsonEncode(future)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'reason',
          'Unsupported replay capsule schema.',
        ),
      ),
    );
    expect(
      () => MechanisticReplayCapsule.fromJsonString(
        capsule.canonicalJson.substring(0, capsule.canonicalJson.length - 1),
      ),
      throwsFormatException,
    );
  });

  test('digest, unknown-field, and configuration drift fail closed', () {
    final capsule = _capsule(_fixture(), configurationSha);
    final digestMutation = Map<String, Object?>.from(capsule.toJson())
      ..['capsule_sha256'] =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    expect(
      () => MechanisticReplayCapsule.fromJson(digestMutation),
      throwsFormatException,
    );

    final unknownField = Map<String, Object?>.from(capsule.toJson())
      ..['future_field'] = true;
    expect(
      () => MechanisticReplayCapsule.fromJson(unknownField),
      throwsFormatException,
    );

    expect(
      () => capsule.restore(
        expectedConfigurationSha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      throwsStateError,
    );
  });

  test('Unicode code points and original units remain distinguishable', () {
    final composed = _fixture(
      componentName: 'Café',
      strength: 1000,
      unit: 'mg',
    );
    final decomposed = _fixture(
      componentName: 'Cafe\u0301',
      strength: 1,
      unit: 'g',
    );
    final composedCapsule = _capsule(composed, configurationSha);
    final decomposedCapsule = _capsule(decomposed, configurationSha);

    expect(
      composedCapsule.capsuleSha256,
      isNot(decomposedCapsule.capsuleSha256),
    );
    expect(
      composedCapsule
          .restore(expectedConfigurationSha256: configurationSha)
          .context
          .medicationEvents
          .single
          .context
          .unit,
      'mg',
    );
    expect(
      decomposedCapsule
          .restore(expectedConfigurationSha256: configurationSha)
          .mealCompositionsById['composition-rich']!
          .foodComponents
          .single
          .name,
      'Cafe\u0301',
    );
  });

  test(
    'memory persistence is append-only, idempotent, and digest ordered',
    () async {
      final database = InMemoryAppDatabase();
      final older = _capsule(
        _fixture(),
        configurationSha,
        capsuleId: 'older_replay',
        generatedAtUtc: DateTime.utc(2026, 8, 31, 12),
      );
      final newer = _capsule(
        _fixture(),
        configurationSha,
        capsuleId: 'newer_replay',
        generatedAtUtc: DateTime.utc(2026, 8, 31, 13),
      );
      final expectedNewerJson = newer.canonicalJson;

      await database.saveMechanisticReplayCapsule(older);
      await database.saveMechanisticReplayCapsule(newer);
      await database.saveMechanisticReplayCapsule(newer);
      newer.encodedLedger['caller_mutation'] = true;

      final restored = await database.loadMechanisticReplayCapsules();
      expect(restored, hasLength(2));
      expect(restored.map((capsule) => capsule.capsuleSha256), <String>[
        newer.capsuleSha256,
        older.capsuleSha256,
      ]);
      expect(restored.first.canonicalJson, expectedNewerJson);
    },
  );

  test(
    'web persistence survives a new adapter and deduplicates by digest',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final firstAdapter = WebAppDatabase();
      final secondAdapter = WebAppDatabase();
      final older = _capsule(
        _fixture(),
        configurationSha,
        capsuleId: 'web_older_replay',
        generatedAtUtc: DateTime.utc(2026, 8, 31, 12),
      );
      final newer = _capsule(
        _fixture(),
        configurationSha,
        capsuleId: 'web_newer_replay',
        generatedAtUtc: DateTime.utc(2026, 8, 31, 13),
      );
      final expectedNewerJson = newer.canonicalJson;

      await Future.wait(<Future<void>>[
        firstAdapter.saveMechanisticReplayCapsule(older),
        secondAdapter.saveMechanisticReplayCapsule(newer),
      ]);
      await firstAdapter.saveMechanisticReplayCapsule(newer);
      newer.encodedLedger['caller_mutation'] = true;

      final restored = await WebAppDatabase().loadMechanisticReplayCapsules();
      expect(restored, hasLength(2));
      expect(restored.map((capsule) => capsule.capsuleSha256), <String>[
        newer.capsuleSha256,
        older.capsuleSha256,
      ]);
      expect(restored.first.canonicalJson, expectedNewerJson);
    },
  );
}

MechanisticReplayCapsule _capsule(
  _ReplayFixture fixture,
  String configuration, {
  String capsuleId = 'lossless_replay_fixture',
  DateTime? generatedAtUtc,
}) {
  final generatedAt = generatedAtUtc ?? DateTime.utc(2026, 8, 31, 12);
  final ledger = const MechanisticEventLedgerBuilder().build(
    ledgerId: capsuleId,
    context: fixture.context,
    mealCompositionsById: fixture.compositions,
    configurationDigest: configuration,
    createdAtUtc: generatedAt,
    sourceId: 'synthetic:test',
    revisionId: 'lossless_replay_v1',
    synthetic: true,
  );
  return MechanisticReplayCapsule.capture(
    capsuleId: capsuleId,
    generatedAtUtc: generatedAt,
    ledger: ledger,
    context: fixture.context,
    mealCompositionsById: fixture.compositions,
  );
}

_ReplayFixture _fixture({
  String componentName = 'Café au lait',
  double strength = 100.5,
  String unit = 'mg',
}) {
  final medication = NormalizedMedicationContext(
    drugProductVariant: 'synthetic:carbidopa-levodopa-ir',
    activeIngredients: const ['carbidopa', 'levodopa'],
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    strength: strength,
    unit: unit,
    jurisdiction: 'CA',
    sourceDocId: 'synthetic:label',
    labelSection: 'composition',
    extractionConfidence: 0.875,
    limitationText: 'Synthetic fixture; not a medication instruction.',
    metadata: const MechanisticMedicationMetadata(
      sourceSystem: 'synthetic_label_registry',
      sourceDocId: 'synthetic:label',
      sourceDocVersion: 'v1',
      effectiveDate: '2026-01-01',
      jurisdiction: 'CA',
      language: 'en-CA',
      drugProductVariantId: 'synthetic:carbidopa-levodopa-ir',
      doseForm: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      releaseTypeSource: 'structured_variant_metadata',
      components: [
        MedicationComponent(
          ingredientName: 'carbidopa',
          role: 'decarboxylase_inhibitor',
          strengthValue: 25,
          strengthUnit: 'mg',
          sourceRefs: ['synthetic:label#composition'],
          extractionConfidence: 0.875,
        ),
        MedicationComponent(
          ingredientName: 'levodopa',
          role: 'active',
          strengthValue: 100,
          strengthUnit: 'mg',
          sourceRefs: ['synthetic:label#composition'],
          extractionConfidence: 0.875,
        ),
      ],
      labelSectionRefs: [
        LabelSectionRef(
          sourceSystem: 'synthetic_label_registry',
          sourceDocId: 'synthetic:label',
          sourceDocVersion: 'v1',
          jurisdiction: 'CA',
          language: 'en-CA',
          sectionId: 'composition',
          sectionKey: 'composition',
          sectionTitle: '成分 / Composition',
          sectionPath: '/composition',
          effectiveDate: '2026-01-01',
          extractedField: 'active_ingredients',
          extractedValue: 'carbidopa;levodopa',
          extractionConfidence: 0.875,
          parserName: 'synthetic_fixture',
          sourceRefs: ['synthetic:label#composition'],
          limitationText: 'Synthetic provenance only.',
        ),
      ],
      sourceRefs: ['synthetic:label'],
      limitationText: 'Synthetic metadata only.',
      metadataCompleteness: 'complete',
    ),
  );
  final component = FoodComponent(
    id: 'component-rich',
    name: componentName,
    physicalForm: MealPhysicalForm.mixed,
    proteinGrams: 7.25,
    fatGrams: 3.5,
    fiberGrams: 1.125,
    carbohydrateGrams: 12.75,
    calories: 111.5,
    portionGrams: 240,
    sourceDocId: 'synthetic:food',
    proteinSource: ProteinSourceType.dairy,
    aminoAcidProfile: const AminoAcidProfile(
      leucine: 0.625,
      isoleucine: 0.375,
      valine: 0.45,
      phenylalanine: 0.31,
      tyrosine: 0.275,
      tryptophan: 0.09,
      unit: 'g',
      basis: 'per_serving',
      nutrientIds: ['505', '503'],
      sourceRefs: ['synthetic:food'],
      derivations: {
        'leucine': NutrientDerivation(
          derivationCode: 'A',
          derivationDescription: 'analytical',
          sourceCode: 'synthetic',
          dataPoints: 4,
          min: 0.6,
          max: 0.65,
          median: 0.625,
        ),
      },
      fdcDataType: 'Synthetic',
    ),
  );
  final composition = MealComposition(
    id: 'composition-rich',
    totalCalories: 111.5,
    proteinGrams: 7.25,
    fatGrams: 3.5,
    fiberGrams: 1.125,
    carbohydrateGrams: 12.75,
    liquidFraction: 0.75,
    mealPhysicalForm: MealPhysicalForm.mixed,
    portionSizeBand: PortionSizeBand.small,
    proteinAmountBand: AmountBand.low,
    fatAmountBand: AmountBand.low,
    fiberAmountBand: AmountBand.low,
    calorieBand: AmountBand.low,
    compositionCompleteness: 1,
    missingFields: const [],
    foodComponents: [component],
  );
  final context = TimeAxisConflictContext(
    referenceMinute: 29454480,
    medicationEvents: [
      MedicationTimelineEvent(
        id: 'dose-rich',
        minute: 29454480,
        context: medication,
      ),
    ],
    mealEvents: const [
      MealTimelineEvent(
        id: 'meal-rich',
        minute: 29454420,
        compositionId: 'composition-rich',
        durationMinutes: 20,
        physicalForm: MealPhysicalForm.mixed,
      ),
    ],
    foodComponentEvents: const [
      FoodComponentTimelineEvent(
        id: 'food-rich',
        minute: 29454425,
        parentMealId: 'meal-rich',
        foodComponentId: 'component-rich',
        physicalForm: MealPhysicalForm.mixed,
      ),
    ],
    userDefinedWindow: const UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 29454540, endMinute: 29454660),
      source: 'synthetic:test',
    ),
    missingFields: const {'observation.series'},
  );
  return _ReplayFixture(
    context: context,
    compositions: {'composition-rich': composition},
  );
}

final class _ReplayFixture {
  const _ReplayFixture({required this.context, required this.compositions});

  final TimeAxisConflictContext context;
  final Map<String, MealComposition> compositions;
}
