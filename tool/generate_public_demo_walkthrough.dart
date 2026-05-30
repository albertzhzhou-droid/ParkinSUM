// Generates a reviewer-facing public demo walkthrough under
// build/public_demo_walkthrough/ by composing existing synthetic artifacts.
//
// Usage:
//   dart run tool/generate_public_demo_walkthrough.dart
//
// Consumes (when present): mechanistic replay latest JSON, source-quality
// perturbation latest JSON, release snapshot latest JSON, a deterministic
// synthetic EvidenceTraceBundle sample, and a capability-matrix summary. Missing
// artifacts are reported as `missing_artifact` — never fabricated.
//
// Educational/research prototype. Synthetic data only. Not medical advice.

import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_trace_bundle_builder.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_nutrition_intake_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/public_demo_walkthrough_generator.dart';

Map<String, dynamic>? _readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    final decoded = jsonDecode(f.readAsStringSync());
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// A deterministic, synthetic, PHI-free EvidenceTraceBundle sample (no real
/// data), used so the walkthrough has an evidence-bundle summary to show.
Map<String, dynamic> _sampleEvidenceBundle() {
  const medMeta = MechanisticMedicationMetadata(
    sourceSystem: 'DailyMed',
    sourceDocId: 'spl:demo',
    jurisdiction: 'US',
    language: 'en',
    doseForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    releaseTypeSource: 'structured_variant_metadata',
    components: [
      MedicationComponent(ingredientName: 'levodopa', role: 'active'),
    ],
    labelSectionRefs: [],
    sourceRefs: ['src.spl.identity'],
    limitationText: 'Provenance only.',
    metadataCompleteness: 'partial',
  );
  final medView = const FhirInspiredMedicationKnowledgeMapper()
      .fromMechanisticMetadata(medMeta, demoDrugProductId: 'demo-prod');

  final comp = MealCompositionNormalizer().normalize(
    mealId: 'comp_demo',
    declaredPhysicalForm: MealPhysicalForm.solid,
    components: const [
      FoodComponent(
        id: 'food.demo.synth',
        name: 'demo food (synthetic)',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: 10,
        fatGrams: 5,
        fiberGrams: 2,
        carbohydrateGrams: 20,
        calories: 180,
        portionGrams: 150,
        sourceDocId: 'synthetic:demo_food',
      ),
    ],
  );
  final nutritionView = const FhirInspiredNutritionIntakeMapper()
      .fromMealComposition(comp, demoMealId: 'demo-meal');

  final bundle = const EvidenceTraceBundleBuilder().build(
    bundleId: 'demo-bundle',
    createdAt: 'synthetic-demo',
    nutritionView: nutritionView,
    medicationKnowledgeView: medView,
  );
  return bundle.toJson();
}

Future<void> main(List<String> args) async {
  final inputs = PublicDemoWalkthroughInputs(
    replayReport: _readJson('build/mechanistic_replay/latest.json'),
    sourceQualityReport:
        _readJson('build/source_quality_perturbation/latest.json'),
    releaseSnapshot: _readJson('build/release_snapshot/latest.json'),
    evidenceBundle: _sampleEvidenceBundle(),
    capabilityMatrixSummary: File('docs/CAPABILITY_MATRIX.md').existsSync()
        ? 'see docs/CAPABILITY_MATRIX.md'
        : null,
  );

  final doc = const PublicDemoWalkthroughGenerator().build(inputs);

  final outDir = Directory('build/public_demo_walkthrough');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.md').writeAsStringSync(doc.toMarkdown());
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodePublicDemoWalkthrough(doc));

  stdout
    ..writeln('Public demo walkthrough written.')
    ..writeln('Report: ${outDir.path}/latest.md')
    ..writeln('Report: ${outDir.path}/latest.json');
  exit(0);
}
