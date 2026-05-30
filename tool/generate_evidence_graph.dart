// Generates a local ParkinSUM evidence graph under build/evidence_graph/ by
// composing existing synthetic artifacts.
//
// Usage:
//   dart run tool/generate_evidence_graph.dart
//
// Reads (when present): build/mechanistic_replay/latest.json,
// build/source_quality_perturbation/latest.json, build/release_snapshot/latest.json,
// build/public_demo_walkthrough/latest.json. For the EvidenceTraceBundle it
// builds a deterministic SYNTHETIC/DEMO sample (clearly marked) since there is no
// standalone bundle artifact. Missing inputs become missing_artifact nodes —
// never fabricated. No network; no slow verification commands.
//
// Local evidence graph only. Not a FHIR Provenance resource, not W3C PROV, not a
// patient record, not clinical validation, not medical advice.

import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_graph_builder.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_graph_mermaid_renderer.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_trace_bundle_builder.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_nutrition_intake_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

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

/// Deterministic, synthetic/demo EvidenceTraceBundle sample (no real data).
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

  return const EvidenceTraceBundleBuilder()
      .build(
        bundleId: 'demo-bundle',
        createdAt: 'synthetic-demo',
        nutritionView: nutritionView,
        medicationKnowledgeView: medView,
      )
      .toJson();
}

Future<void> main(List<String> args) async {
  final inputs = EvidenceGraphInputs(
    replayReport: _readJson('build/mechanistic_replay/latest.json'),
    sourceQualityReport:
        _readJson('build/source_quality_perturbation/latest.json'),
    releaseSnapshot: _readJson('build/release_snapshot/latest.json'),
    publicDemoWalkthrough:
        _readJson('build/public_demo_walkthrough/latest.json'),
    evidenceBundle: _sampleEvidenceBundle(),
  );

  final graph = const EvidenceGraphBuilder().build(inputs);
  final mermaid = const EvidenceGraphMermaidRenderer().render(graph);

  final outDir = Directory('build/evidence_graph');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeEvidenceGraph(graph));
  File('${outDir.path}/latest.mmd').writeAsStringSync(mermaid);
  File('${outDir.path}/latest.md').writeAsStringSync(
    '# ParkinSUM Local Evidence Graph\n\n'
    'Educational/research prototype. Synthetic/demo artifacts only. Local '
    'evidence graph — not a FHIR Provenance resource, not W3C PROV, not a '
    'patient record, not clinical validation, not medical advice.\n\n'
    '```mermaid\n$mermaid```\n',
  );

  final missing =
      graph.nodes.where((n) => n.isMissing).map((n) => n.id).toList();
  stdout
    ..writeln('Evidence graph written '
        '(${graph.nodes.length} nodes, ${graph.edges.length} edges'
        '${missing.isEmpty ? '' : '; missing_artifact: ${missing.join(', ')}'}).')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.mmd')
    ..writeln('Report: ${outDir.path}/latest.md');
  exit(0);
}
