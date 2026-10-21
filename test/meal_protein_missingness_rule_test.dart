import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/database_backed_meal_check_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/variant_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only explicit oral levodopa receives protein timing fat and iron score modifiers',
    () async {
      final time = DateTime.utc(2026, 9, 29, 12);
      const modifierIds = [
        'levodopa_interference_weight',
        'protein_timing_penalty',
        'high_fat_meal_modifier',
        'iron_levodopa_modifier',
      ];
      for (final route in [
        'oral',
        'inhaled',
        'subcutaneous',
        'unspecified',
        '',
      ]) {
        final db = _OralLevodopaDatabase(route: route);
        final useCase = DatabaseBackedMealCheckUseCase(
          variantResolver: VariantResolver(database: db),
          clinicalDecisionSupportService: ClinicalDecisionSupportService(
            database: db,
            factConflictEngine: FactConflictEngine(),
            runtimeRuleEngine: RuntimeRuleEngine(),
          ),
          compiledRules: RuleRegistryCompiler().compileJsonList(
            baselineCdssRules,
            rulesVersion: 'baseline_cdss_rules_v1',
          ),
        );
        final result = await useCase(
          meal: Meal(
            id: 'synthetic_route_meal',
            eatenAt: time,
            title: 'Synthetic',
            coeventSubstanceTags: ['iron_salt'],
            items: [
              MealItem(
                foodId: 'synthetic_unknown_food',
                foodName: 'Synthetic',
                foodCategory: FoodCategory.other,
                quantityFactor: 1,
                foodTags: [],
                proteinPer100g: 20,
                carbsPer100g: 40,
                fatPer100g: 25,
                fiberPer100g: 0,
                sodiumPer100g: 0,
              ),
            ],
          ),
          activeDrugs: [
            DrugDefinition(
              id: 'synthetic_oral_levodopa',
              genericName: 'Levodopa',
              brandNames: [],
              tags: [DrugTag.levodopaLike],
              notes: '',
            ),
          ],
          intakes: [
            Intake(
              id: 'synthetic_route_intake',
              drugId: 'synthetic_oral_levodopa',
              takenAt: time,
              dosageNote: '',
            ),
          ],
          userProfile: UserProfile.defaults().copyWith(displayLocale: 'en-US'),
          now: time,
        );
        final factors = result.scoreFactors
            .map((factor) => factor.code)
            .toList();
        if (route == 'oral') {
          expect(factors, containsAll(modifierIds));
        } else {
          for (final id in modifierIds) {
            expect(factors, isNot(contains(id)), reason: route);
          }
          expect(
            result.keyFindings.any(
              (finding) => finding.startsWith('Require review'),
            ),
            isTrue,
            reason: route,
          );
          expect(
            result.keyFindings.any(
              (finding) => finding.startsWith(
                AppI18n.fromLocaleTag('en-US').decisionLabel('ALLOW'),
              ),
            ),
            isFalse,
            reason: route,
          );
          expect(
            factors,
            contains('rule_decision_weight'),
            reason: 'The categorical review requirement is preserved.',
          );
        }
      }
    },
  );
  test(
    'stored unknown numerics and duplicate observations cannot create protein score or display totals',
    () async {
      final time = DateTime.utc(2026, 9, 29, 12);
      Map<String, Object?> observation(
        double value, {
        String qualifier = 'exact',
        String source = 'synthetic_current',
      }) => {
        'entity_key': 'SYNTHETIC_FOOD_VARIANT',
        'attribute_code': 'protein_g',
        'qualifier_kind': qualifier,
        'value_num': value,
        'source_doc_id': source,
        'unit': 'g',
        'basis_type': 'per_100g_edible_part',
        'basis_amount': 100,
      };
      final cases = [
        (rows: <Map<String, Object?>>[], marker: true),
        (rows: [observation(50), observation(75)], marker: false),
        (rows: [observation(75), observation(50)], marker: false),
        (
          rows: [
            observation(50),
            observation(75, source: 'synthetic_old'),
          ],
          marker: false,
        ),
        (rows: [observation(50, qualifier: 'lt')], marker: false),
        (
          rows: [
            observation(50),
            observation(20, qualifier: 'lt'),
          ],
          marker: false,
        ),
        (rows: [observation(double.infinity)], marker: false),
        (
          rows: [
            {...observation(50), 'unit': 'mg'},
          ],
          marker: false,
        ),
        (
          rows: [
            {...observation(50), 'basis_type': 'per_serving'},
          ],
          marker: false,
        ),
        (
          rows: [
            {...observation(50), 'basis_amount': 30},
          ],
          marker: false,
        ),
      ];
      for (final sample in cases) {
        final db = _OralLevodopaDatabase(observations: sample.rows);
        final useCase = DatabaseBackedMealCheckUseCase(
          variantResolver: VariantResolver(database: db),
          clinicalDecisionSupportService: ClinicalDecisionSupportService(
            database: db,
            factConflictEngine: FactConflictEngine(),
            runtimeRuleEngine: RuntimeRuleEngine(),
          ),
          compiledRules: RuleRegistryCompiler().compileJsonList(
            baselineCdssRules,
            rulesVersion: 'baseline_cdss_rules_v1',
          ),
        );
        final result = await useCase(
          meal: Meal(
            id: 'synthetic_unknown_meal',
            eatenAt: time,
            title: 'Synthetic',
            items: [
              MealItem(
                foodId: 'synthetic_unknown_food',
                foodName: 'Synthetic',
                foodCategory: FoodCategory.other,
                quantityFactor: 1,
                foodTags: [],
                proteinPer100g: 80,
                carbsPer100g: 70,
                fatPer100g: 25,
                fiberPer100g: 0,
                sodiumPer100g: 0,
                missingNutrientFields: sample.marker ? {'proteinG'} : {},
              ),
            ],
          ),
          activeDrugs: [
            DrugDefinition(
              id: 'synthetic_oral_levodopa',
              genericName: 'Levodopa',
              brandNames: [],
              tags: [DrugTag.levodopaLike],
              notes: '',
            ),
          ],
          intakes: [
            Intake(
              id: 'synthetic_intake',
              drugId: 'synthetic_oral_levodopa',
              takenAt: time,
              dosageNote: '',
            ),
          ],
          userProfile: UserProfile.defaults().copyWith(displayLocale: 'en-US'),
          now: time,
        );
        expect(
          result.issues.any(
            (issue) => issue.detail.contains('Protein evidence is missing'),
          ),
          isTrue,
        );
        expect(result.analysisText, contains('Meal protein is unknown'));
        expect(result.analysisText, isNot(contains('about 80.0 g')));
        final factors = result.scoreFactors
            .map((factor) => factor.code)
            .toList();
        expect(factors, isNot(contains('levodopa_interference_weight')));
        expect(factors, isNot(contains('protein_timing_penalty')));
        expect(factors, isNot(contains('high_fat_meal_modifier')));
      }
    },
  );
  test(
    'meal adapter carries explicit unknown protein through the production rule path',
    () async {
      final db = _OralLevodopaDatabase();
      final useCase = DatabaseBackedMealCheckUseCase(
        variantResolver: VariantResolver(database: db),
        clinicalDecisionSupportService: ClinicalDecisionSupportService(
          database: db,
          factConflictEngine: FactConflictEngine(),
          runtimeRuleEngine: RuntimeRuleEngine(),
        ),
        compiledRules: RuleRegistryCompiler().compileJsonList(
          baselineCdssRules,
          rulesVersion: 'baseline_cdss_rules_v1',
        ),
      );
      final time = DateTime.utc(2026, 9, 29, 12);
      final drug = DrugDefinition(
        id: 'synthetic_oral_levodopa',
        genericName: 'Levodopa',
        brandNames: [],
        tags: [DrugTag.levodopaLike],
        notes: '',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
      );
      for (final missing in [true, false]) {
        final result = await useCase(
          meal: Meal(
            id: 'synthetic_protein_meal',
            eatenAt: time,
            title: 'Synthetic',
            items: [
              MealItem(
                foodId: 'synthetic_unknown_food',
                foodName: 'Synthetic',
                foodCategory: FoodCategory.other,
                quantityFactor: 1,
                foodTags: [],
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0,
                fiberPer100g: 0,
                sodiumPer100g: 0,
                missingNutrientFields: missing ? {'proteinG'} : {},
              ),
            ],
          ),
          activeDrugs: [drug],
          intakes: [
            Intake(
              id: 'synthetic_intake',
              drugId: drug.id,
              takenAt: time,
              dosageNote: '100 mg',
            ),
          ],
          userProfile: UserProfile.defaults(),
          now: time,
        );
        expect(
          result.issues.any(
            (issue) =>
                issue.detail.contains('蛋白信息缺失') ||
                issue.detail.contains('Protein evidence is missing'),
          ),
          missing,
          reason:
              'A measured zero and a missing numeric placeholder have different meanings.',
        );
        if (missing) expect(result.issues, isNotEmpty);
      }
    },
  );
  test(
    'oral levodopa without an intake is shown as awaiting inputs, not risk',
    () async {
      final time = DateTime.utc(2026, 9, 29, 12);
      final db = _OralLevodopaDatabase(route: 'oral');
      final useCase = DatabaseBackedMealCheckUseCase(
        variantResolver: VariantResolver(database: db),
        clinicalDecisionSupportService: ClinicalDecisionSupportService(
          database: db,
          factConflictEngine: FactConflictEngine(),
          runtimeRuleEngine: RuntimeRuleEngine(),
        ),
        compiledRules: RuleRegistryCompiler().compileJsonList(
          baselineCdssRules,
          rulesVersion: 'baseline_cdss_rules_v1',
        ),
      );
      final result = await useCase(
        meal: Meal(
          id: 'synthetic_missing_intake_meal',
          eatenAt: time,
          title: 'Synthetic',
          items: [
            MealItem(
              foodId: 'synthetic_protein_food',
              foodName: 'Synthetic',
              foodCategory: FoodCategory.other,
              quantityFactor: 1,
              foodTags: [],
              proteinPer100g: 31,
              carbsPer100g: 0,
              fatPer100g: 3.6,
              fiberPer100g: 0,
              sodiumPer100g: 0,
            ),
          ],
        ),
        activeDrugs: [
          DrugDefinition(
            id: 'synthetic_oral_levodopa',
            genericName: 'Levodopa',
            brandNames: [],
            tags: [DrugTag.levodopaLike],
            notes: '',
          ),
        ],
        intakes: const [],
        userProfile: UserProfile.defaults().copyWith(displayLocale: 'en-US'),
        now: time,
      );
      // The stored rule outcome is unchanged: a review-level, high score.
      expect(result.overallSeverity, InteractionSeverity.high);
      expect(
        result.scoreFactors.map((factor) => factor.code),
        contains('rule_decision_weight'),
      );
      // Only the presentation is neutral, and it names the missing inputs.
      final copy = ResponseCopyService(i18n: AppI18n.fromLocaleTag('en-US'));
      expect(copy.awaitingMissingInputs(result), isTrue);
      expect(
        copy.awaitingInputsHeadline(result),
        startsWith("Can't assess yet"),
      );
      expect(copy.awaitingInputsHeadline(result), contains('medication time'));
    },
  );
}

class _OralLevodopaDatabase extends InMemoryCdssDatabase {
  _OralLevodopaDatabase({this.observations = const [], this.route = 'oral'});
  final List<Map<String, Object?>> observations;
  final String route;
  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      table == 'drug_product_variant'
      ? [
          {
            'drug_product_variant_id': 'SYNTHETIC_ORAL_LEVODOPA',
            'drug_concept_id': 'DRUG_LEVODOPA',
            'external_product_code': 'synthetic_oral_levodopa',
            'jurisdiction': 'GLOBAL',
            'regulator': 'SYNTHETIC',
            'route': route,
            'dosage_form': 'tablet',
            'release_type': 'immediate_release',
          },
        ]
      : table == 'food_variant'
      ? [
          {
            'food_variant_id': 'SYNTHETIC_FOOD_VARIANT',
            'food_concept_id': 'SYNTHETIC_FOOD',
            'source_food_code': 'synthetic_unknown_food',
            'jurisdiction': 'GLOBAL',
            'source_family': 'SYNTHETIC',
          },
        ]
      : table == 'observation'
      ? observations
      : await super.queryTable(table);
}
