import '../entities/algorithm_descriptor.dart';

/// Single auditable contract for every algorithm that may change a visible
/// result. The Algorithm Observatory renders every entry in [all].
class AlgorithmRegistry {
  static const List<AlgorithmDescriptor> all = [
    AlgorithmDescriptor(
      id: 'intake_dose_context',
      name: 'Intake dose context builder',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/intake_dose_context_builder.dart',
      userVisibleImpact:
          'Separates an entered intake dose from package strength.',
      inputs: 'Medication entry and package metadata',
      outputs: 'Dose context or explicit missing state',
      hasLiveTrace: false,
      limitation: 'Validates structure, not clinical appropriateness.',
    ),
    AlgorithmDescriptor(
      id: 'dosage_note_parser',
      name: 'Dosage note parser',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/dosage_note_parser.dart',
      userVisibleImpact: 'Accepts or rejects structured dose text.',
      inputs: 'Dose note text',
      outputs: 'Value, unit, or parse failure',
      hasLiveTrace: false,
      limitation: 'Syntax parsing only; it never recommends a dose.',
    ),
    AlgorithmDescriptor(
      id: 'medication_entry_validator',
      name: 'Medication entry validator',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath: 'lib/domain/usecases/medication_entry_validator.dart',
      userVisibleImpact:
          'Controls whether medication context reaches modeling.',
      inputs: 'Ingredient, strength, unit, form, route, release type',
      outputs: 'Validated context and issue codes',
      hasLiveTrace: false,
      limitation: 'Metadata completeness is not clinical validation.',
    ),
    AlgorithmDescriptor(
      id: 'runtime_model_applicability_abstention_gate',
      name: 'Runtime model applicability and abstention gate',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath:
          'lib/domain/entities/mechanistic_medication_applicability.dart',
      userVisibleImpact:
          'Prevents levodopa-specific model curves, scores, and ranking outside the supported medication domain.',
      inputs:
          'Exact active ingredients plus route, dosage form, and release type',
      outputs: 'Applicability state, modeled release profile, and reason codes',
      hasLiveTrace: false,
      limitation:
          'A passing metadata gate establishes model input scope, not clinical suitability or predictive validity.',
    ),
    AlgorithmDescriptor(
      id: 'package_dose_calculator',
      name: 'Medication package dose calculator',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/medication_package_dose_calculator.dart',
      userVisibleImpact:
          'Converts a confirmed package selection into ingredient amounts.',
      inputs: 'Confirmed product and unit count',
      outputs: 'Component dose quantities',
      hasLiveTrace: false,
      limitation:
          'Runs only after explicit confirmation; not a dosing calculator.',
    ),
    AlgorithmDescriptor(
      id: 'meal_composition_normalizer',
      name: 'Meal composition normalizer',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath: 'lib/domain/usecases/meal_composition_normalizer.dart',
      userVisibleImpact:
          'Determines nutrient bands, physical form, and missingness.',
      inputs: 'Food components and serving-level nutrients',
      outputs: 'Normalized meal composition',
      hasLiveTrace: true,
      traceProviderId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
      limitation:
          'Missing values remain missing and are never inferred as zero.',
    ),
    AlgorithmDescriptor(
      id: 'time_axis_builder',
      name: 'Time-axis builder',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.liveTimeline,
      sourcePath: 'lib/domain/usecases/time_axis_builder.dart',
      additionalSourcePaths: ['lib/domain/entities/time_axis_events.dart'],
      userVisibleImpact:
          'Places validated meals and medication on one UTC minute axis.',
      inputs: 'Timestamps and validated contexts',
      outputs: 'Ordered conflict timeline',
      hasLiveTrace: false,
      limitation:
          'Omitted timestamps widen uncertainty; time is never invented.',
    ),
    AlgorithmDescriptor(
      id: 'metadata_completeness_gate',
      name: 'Metadata completeness gate',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath: 'lib/domain/usecases/metadata_completeness_gate.dart',
      userVisibleImpact:
          'Downgrades confidence when provenance or formulation is incomplete.',
      inputs: 'Medication, food, and explanation metadata',
      outputs: 'Completeness grade and scoring weight',
      hasLiveTrace: false,
      limitation: 'Completeness is not accuracy.',
    ),
    AlgorithmDescriptor(
      id: 'input_quality_gate',
      name: 'Input quality gate',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath: 'lib/domain/usecases/input_quality_gate.dart',
      userVisibleImpact:
          'Allows or withholds an educational trace; never changes food order.',
      inputs: 'Eight context-quality dimensions',
      outputs: 'Eligibility, blockers, and fallback reasons',
      hasLiveTrace: false,
      limitation: 'Assesses input sufficiency, not medical correctness.',
    ),
    AlgorithmDescriptor(
      id: 'gastric_emptying',
      name: 'Gastric emptying model',
      stage: AlgorithmStage.model,
      visualization: AlgorithmVisualization.liveCurve,
      sourcePath: 'lib/domain/usecases/gastric_emptying_model.dart',
      additionalSourcePaths: [
        'lib/domain/entities/gastric_emptying_parameters.dart',
        'lib/domain/entities/gastric_emptying_profile.dart',
      ],
      userVisibleImpact:
          'Models component residence and intestinal arrival timing.',
      inputs: 'Meal form, energy, fat, fiber, and overlap',
      outputs: 'Remaining-fraction and arrival-rate curves',
      hasLiveTrace: true,
      traceProviderId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
      limitation:
          'Population-informed educational sensitivity model, not a gastric-emptying test.',
    ),
    AlgorithmDescriptor(
      id: 'levodopa_absorption_opportunity',
      name: 'Levodopa absorption opportunity',
      stage: AlgorithmStage.model,
      visualization: AlgorithmVisualization.liveCurve,
      sourcePath:
          'lib/domain/usecases/levodopa_absorption_opportunity_model.dart',
      additionalSourcePaths: [
        'lib/domain/entities/absorption_opportunity.dart',
      ],
      userVisibleImpact:
          'Models a possible small-intestinal opportunity window.',
      inputs: 'Dose time, release type, and modeled residual meal load',
      outputs: 'Openness curve, peak, delay likelihood, uncertainty',
      hasLiveTrace: true,
      traceProviderId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
      limitation:
          'Openness is not absorbed fraction, plasma concentration, or response.',
    ),
    AlgorithmDescriptor(
      id: 'amino_acid_competition',
      name: 'LNAA competition model',
      stage: AlgorithmStage.model,
      visualization: AlgorithmVisualization.liveCurve,
      sourcePath: 'lib/domain/usecases/amino_acid_competition_model.dart',
      additionalSourcePaths: [
        'lib/domain/entities/amino_acid_competition.dart',
        'lib/domain/entities/amino_acid_profile.dart',
        'lib/domain/entities/nutrient_derivation.dart',
        'lib/domain/entities/protein_source.dart',
      ],
      userVisibleImpact:
          'Models overlap between protein-derived LNAA pressure and absorption opportunity.',
      inputs: 'Protein, amino-acid fields or source proxy, emptying, dose',
      outputs: 'Pressure curve, overlap, band, and data mode',
      hasLiveTrace: true,
      traceProviderId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
      limitation:
          'A unitless proxy; normal-diet LNAA variation was not important in most participants in one small study.',
    ),
    AlgorithmDescriptor(
      id: 'protein_distribution',
      name: 'Protein distribution model',
      stage: AlgorithmStage.model,
      visualization: AlgorithmVisualization.scoreBreakdown,
      sourcePath: 'lib/domain/usecases/protein_distribution_model.dart',
      additionalSourcePaths: ['lib/domain/entities/protein_distribution.dart'],
      userVisibleImpact:
          'Balances modeled overlap against a protein-adequacy proxy.',
      inputs: 'Modeled overlap, candidate protein, and time-window hint',
      outputs: 'Window role, redistribution score, adequacy contribution',
      hasLiveTrace: false,
      limitation: 'Does not prescribe restriction or a daily protein target.',
    ),
    AlgorithmDescriptor(
      id: 'mechanistic_conflict',
      name: 'Mechanistic conflict engine',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.scoreBreakdown,
      sourcePath: 'lib/domain/usecases/mechanistic_conflict_engine.dart',
      userVisibleImpact:
          'Composes timing, emptying, absorption, and competition into one trace.',
      inputs: 'Time axis and normalized meal compositions',
      outputs: 'Score, severity, confidence, drivers, and per-dose trace',
      hasLiveTrace: true,
      traceProviderId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
      limitation:
          'Ordinal educational conflict score, not predicted symptom severity.',
    ),
    AlgorithmDescriptor(
      id: 'mechanistic_candidate_scorer',
      name: 'Mechanistic next-meal scorer',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.scoreBreakdown,
      sourcePath: 'lib/domain/usecases/mechanistic_next_meal_scorer.dart',
      additionalSourcePaths: [
        'lib/domain/usecases/next_meal_scoring_parameters.dart',
      ],
      userVisibleImpact:
          'Computes analysis-only candidate traces without changing recommendation order.',
      inputs: 'User window, candidates, conflict engine, provenance',
      outputs: 'Sample trace, component scores, diagnostic comparison order',
      hasLiveTrace: true,
      traceProviderId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
      limitation:
          'Never chooses a meal time or changes the production recommendation order.',
    ),
    AlgorithmDescriptor(
      id: 'recommendation_orchestrator',
      name: 'Recommendation orchestrator',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath:
          'lib/domain/usecases/next_meal_recommendation_orchestrator.dart',
      userVisibleImpact:
          'Selects deterministic, local-AI polish, or conservative fallback path.',
      inputs: 'Gate status, deterministic results, consent, local endpoint',
      outputs: 'Path, visible reasons, and bounded result',
      hasLiveTrace: false,
      limitation:
          'Local AI may reorder only a whitelist and cannot bypass safety gates.',
    ),
    AlgorithmDescriptor(
      id: 'runtime_rule_engine',
      name: 'Runtime rule engine',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/runtime_rule_engine.dart',
      additionalSourcePaths: [
        'lib/core/constants/baseline_cdss_rules.dart',
        'lib/core/constants/baseline_cdss_rule_translations.dart',
        'lib/domain/entities/rule_registry_models.dart',
      ],
      userVisibleImpact:
          'Evaluates registry rules and records fired and unfired outcomes.',
      inputs: 'Rule candidates and normalized facts',
      outputs: 'Rule explanations and escalation state',
      hasLiveTrace: false,
      limitation:
          'Rules are versioned educational logic, not autonomous diagnosis.',
    ),
    AlgorithmDescriptor(
      id: 'database_meal_check',
      name: 'Database-backed meal check',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/database_backed_meal_check_usecase.dart',
      userVisibleImpact:
          'Combines catalog facts, deterministic rules, and mechanistic trace.',
      inputs: 'Meal, medication, catalog snapshot, and rules',
      outputs: 'Rendered interaction result and audit evidence',
      hasLiveTrace: false,
      limitation: 'Falls back conservatively when evidence is incomplete.',
    ),
    AlgorithmDescriptor(
      id: 'clinical_decision_support',
      name: 'Clinical-decision-support artifact service',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/clinical_decision_support_service.dart',
      userVisibleImpact:
          'Builds and publishes the versioned fact/rule artifact read by result paths.',
      inputs: 'Staged sources, facts, rules, and release metadata',
      outputs: 'Published snapshot, audit rows, and rollback state',
      hasLiveTrace: false,
      limitation:
          'Artifact governance supports reviewability; it does not make the prototype clinical software.',
    ),
    AlgorithmDescriptor(
      id: 'imported_label_rules',
      name: 'Imported label rule provider',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/imported_label_rule_provider.dart',
      userVisibleImpact:
          'Turns eligible published label facts into runtime rule candidates.',
      inputs: 'Published label facts and provenance',
      outputs: 'Versioned rule candidates or explicit exclusion',
      hasLiveTrace: false,
      limitation:
          'A label statement is formulation-specific and does not become a universal rule.',
    ),
    AlgorithmDescriptor(
      id: 'rule_registry_compiler',
      name: 'Rule registry compiler',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/rule_registry_compiler.dart',
      additionalSourcePaths: ['lib/core/constants/cdss_rule_schema.dart'],
      userVisibleImpact:
          'Rejects invalid or internally inconsistent rule definitions before evaluation.',
      inputs: 'Rule registry entries and copy/source contracts',
      outputs: 'Compiled deterministic rules or validation failure',
      hasLiveTrace: false,
      limitation:
          'Compilation checks structure and safety contracts, not clinical truth.',
    ),
    AlgorithmDescriptor(
      id: 'runtime_rule_support',
      name: 'Runtime rule support and escalation',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/runtime_rule_support.dart',
      userVisibleImpact:
          'Combines same-band outcomes and controls deterministic escalation.',
      inputs: 'Rule outcomes, severity bands, and support metadata',
      outputs: 'Stable combined band and trace reasons',
      hasLiveTrace: false,
      limitation:
          'Band composition is an educational policy, not a risk calculator.',
    ),
    AlgorithmDescriptor(
      id: 'legacy_food_recommendations',
      name: 'Legacy food recommendation scorer',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.scoreBreakdown,
      sourcePath: 'lib/domain/usecases/get_food_recommendations_usecase.dart',
      userVisibleImpact:
          'Scores legacy food candidates by nutrition, timing, region, repetition, and provenance.',
      inputs: 'History, catalog foods, medications, and user profile',
      outputs: 'Ranked legacy candidate explanations',
      hasLiveTrace: false,
      limitation:
          'Compatibility scoring is heuristic and subordinate to safety and mechanistic gates.',
    ),
    AlgorithmDescriptor(
      id: 'local_ai_adapter',
      name: 'Local AI bounded adapter',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/local_ai_recommendation_adapter.dart',
      userVisibleImpact:
          'Optionally polishes copy or reorders only an approved candidate whitelist.',
      inputs: 'Consent, localhost endpoint, deterministic whitelist, schema',
      outputs: 'Validated polish/rerank or deterministic fallback',
      hasLiveTrace: false,
      limitation:
          'Cannot create candidates, facts, dose/timing advice, or bypass deterministic gates.',
    ),
    AlgorithmDescriptor(
      id: 'medication_metadata_adapter',
      name: 'Medication provenance adapter',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath:
          'lib/domain/usecases/medication_context_metadata_adapter.dart',
      additionalSourcePaths: [
        'lib/domain/entities/medication_source_metadata.dart',
      ],
      userVisibleImpact:
          'Bridges label section and formulation provenance into the mechanistic trace.',
      inputs: 'Catalog medication variant and label provenance',
      outputs: 'Engine-facing metadata without dose inference',
      hasLiveTrace: false,
      limitation: 'Product strength metadata never becomes an intake dose.',
    ),
    AlgorithmDescriptor(
      id: 'explanation_copy_compiler',
      name: 'Explanation copy compiler',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/explanation_copy_compiler.dart',
      userVisibleImpact:
          'Blocks unsafe, unsourced, or structurally invalid explanation templates.',
      inputs: 'Localized templates, claim flags, and source requirements',
      outputs: 'Validated copy registry or compile failure',
      hasLiveTrace: false,
      limitation: 'Template validation cannot create missing provenance.',
    ),
    AlgorithmDescriptor(
      id: 'timeline_projection',
      name: 'Timeline projection use case',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.liveTimeline,
      sourcePath: 'lib/domain/usecases/get_timeline_usecase.dart',
      additionalSourcePaths: ['lib/domain/entities/timeline_event.dart'],
      userVisibleImpact:
          'Orders meal and medication events for the visible history timeline.',
      inputs: 'Stored meals and medication records',
      outputs: 'Chronological timeline items',
      hasLiveTrace: false,
      limitation:
          'Presentation ordering only; it does not infer missing event times.',
    ),
    AlgorithmDescriptor(
      id: 'protein_trend',
      name: 'Protein trend aggregation',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.liveCurve,
      sourcePath: 'lib/domain/usecases/get_protein_trend_usecase.dart',
      userVisibleImpact:
          'Aggregates logged meal protein into the analytics trend.',
      inputs: 'Stored meals with nutrient totals',
      outputs: 'Time-ordered protein series',
      hasLiveTrace: false,
      limitation: 'Descriptive aggregation, not intake adequacy assessment.',
    ),
    AlgorithmDescriptor(
      id: 'catalog_query_normalizer',
      name: 'Catalog query normalizer',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/domain/usecases/catalog_query_normalizer.dart',
      userVisibleImpact:
          'Controls how names and identifiers enter catalog search.',
      inputs: 'Free-text query and optional domain hint',
      outputs: 'Normalized tokens and identifier candidates',
      hasLiveTrace: false,
      limitation: 'Normalization does not establish identity.',
    ),
    AlgorithmDescriptor(
      id: 'catalog_resolution',
      name: 'Catalog resolution engine',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/domain/usecases/catalog_resolution_engine.dart',
      additionalSourcePaths: ['lib/domain/entities/catalog_resolution.dart'],
      userVisibleImpact:
          'Ranks identity candidates and may refuse ambiguous matches.',
      inputs: 'Normalized query, catalog candidates, authority signals',
      outputs: 'Match status, confidence, candidates, and issues',
      hasLiveTrace: false,
      limitation:
          'A high catalog score does not validate clinical interchangeability.',
    ),
    AlgorithmDescriptor(
      id: 'variant_resolver',
      name: 'Product/food variant resolver',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/domain/usecases/variant_resolver.dart',
      userVisibleImpact: 'Keeps formulation and food variants distinct.',
      inputs: 'Candidate variants, jurisdiction, provenance',
      outputs: 'Selected variant or unresolved state',
      hasLiveTrace: false,
      limitation:
          'Never treats different release forms as equivalent by name alone.',
    ),
    AlgorithmDescriptor(
      id: 'source_authority',
      name: 'Source authority scorer',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.scoreBreakdown,
      sourcePath: 'lib/domain/usecases/source_authority_scorer.dart',
      userVisibleImpact:
          'Weights source authority without replacing missing evidence.',
      inputs: 'Source system and jurisdiction metadata',
      outputs: 'Authority tier and bounded score',
      hasLiveTrace: false,
      limitation: 'Authority is ordinal provenance, not measurement certainty.',
    ),
    AlgorithmDescriptor(
      id: 'fact_conflict',
      name: 'Fact conflict engine',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/domain/usecases/fact_conflict_engine.dart',
      userVisibleImpact:
          'Resolves, preserves, or escalates contradictory catalog facts.',
      inputs: 'Fact clusters, recency, authority, and equivalence',
      outputs: 'Resolved fact, alternatives, or unresolved conflict',
      hasLiveTrace: false,
      limitation:
          'Unresolved conflicts remain visible instead of being averaged away.',
    ),
    AlgorithmDescriptor(
      id: 'catalog_projection',
      name: 'CDSS catalog projection',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/cdss_catalog_projection_service.dart',
      userVisibleImpact:
          'Projects versioned evidence into user-facing catalog details.',
      inputs: 'Published snapshot facts and provenance',
      outputs: 'Drug, food, section, and nutrient projections',
      hasLiveTrace: false,
      limitation:
          'Projection cannot make an unpublished or stale fact current.',
    ),
    AlgorithmDescriptor(
      id: 'explanation_copy',
      name: 'Explanation copy compiler/service',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/explanation_copy_service.dart',
      userVisibleImpact: 'Chooses source-bounded localized explanation copy.',
      inputs: 'Rule outcome, locale, source refs, template contract',
      outputs: 'Rendered copy or safe fallback',
      hasLiveTrace: false,
      limitation: 'Copy cannot add a claim absent from the rule evidence.',
    ),
    AlgorithmDescriptor(
      id: 'catalog_candidate_projection',
      name: 'Catalog food candidate projection',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/catalog_food_to_candidate.dart',
      userVisibleImpact:
          'Controls which catalog nutrient, form, and provenance fields enter candidate scoring.',
      inputs: 'Catalog food row and nutrient missingness',
      outputs: 'Mechanistic candidate with preserved provenance',
      hasLiveTrace: false,
      limitation:
          'Projection preserves source data and does not infer missing nutrients.',
    ),
    AlgorithmDescriptor(
      id: 'evidence_trace_bundle',
      name: 'Evidence trace bundle builder',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/evidence_trace_bundle_builder.dart',
      userVisibleImpact:
          'Assembles the facts, rules, sources, and missingness shown for independent review.',
      inputs: 'Result trace, fact snapshot, rules, and sources',
      outputs: 'Versioned review bundle',
      hasLiveTrace: false,
      limitation:
          'A complete bundle improves auditability but does not validate clinical truth.',
    ),
    AlgorithmDescriptor(
      id: 'label_section_code_mapper',
      name: 'Label section code mapper',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/domain/usecases/label_section_code_mapper.dart',
      userVisibleImpact:
          'Determines which official label section semantics reach rule compilation.',
      inputs: 'Regulatory section codes and source metadata',
      outputs: 'Canonical label section or explicit unknown state',
      hasLiveTrace: false,
      limitation:
          'Section identity does not make a statement transferable across products.',
    ),
    AlgorithmDescriptor(
      id: 'knowledge_base_release',
      name: 'Knowledge-base release gate',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/knowledge_base_release_service.dart',
      userVisibleImpact:
          'Controls whether a versioned knowledge snapshot is eligible for release and rollback.',
      inputs: 'Snapshot facts, source contracts, conflicts, and review state',
      outputs: 'Release decision, blockers, and audit evidence',
      hasLiveTrace: false,
      limitation:
          'Release readiness is a governance state, not clinical validation.',
    ),
    AlgorithmDescriptor(
      id: 'rule_explanation_projection',
      name: 'Rule explanation projection',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/domain/usecases/rule_explanation_projection.dart',
      userVisibleImpact:
          'Projects matched and suppressed rule traces into visible explanations.',
      inputs: 'Compiled rule outcomes and evidence references',
      outputs: 'Ordered explanation nodes and safe fallback copy',
      hasLiveTrace: false,
      limitation:
          'Projection can expose a rule decision but cannot strengthen its evidence.',
    ),
    AlgorithmDescriptor(
      id: 'safe_copy_template_registry',
      name: 'Safe copy template registry',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/domain/usecases/safe_copy_template_registry.dart',
      additionalSourcePaths: ['lib/domain/entities/rule_explanation.dart'],
      userVisibleImpact:
          'Restricts explanation wording to versioned source-bounded templates.',
      inputs: 'Decision code, locale, evidence class, and safety boundary',
      outputs: 'Allowed template or conservative fallback',
      hasLiveTrace: false,
      limitation:
          'A safe template cannot compensate for absent or low-quality evidence.',
    ),
    AlgorithmDescriptor(
      id: 'legacy_interaction_engine',
      name: 'Legacy interaction engine',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/core/analysis/interaction_engine.dart',
      userVisibleImpact: 'Provides the legacy deterministic interaction path.',
      inputs: 'Meal, medication, and legacy rules',
      outputs: 'Legacy interaction classification',
      hasLiveTrace: false,
      limitation:
          'Kept for compatibility; mechanistic trace is preferred when eligible.',
    ),
    AlgorithmDescriptor(
      id: 'legacy_nutrition_classifier',
      name: 'Legacy nutrition classifier',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath: 'lib/core/analysis/nutrition_classifier.dart',
      additionalSourcePaths: ['lib/core/analysis/nutrition_rules.dart'],
      userVisibleImpact: 'Maps nutrient values into legacy display bands.',
      inputs: 'Nutrient totals',
      outputs: 'Nutrition categories',
      hasLiveTrace: false,
      limitation: 'Coarse categories are not nutrition assessment.',
    ),
    AlgorithmDescriptor(
      id: 'legacy_catalog_engine',
      name: 'Legacy catalog engine',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/core/analysis/catalog_engine.dart',
      userVisibleImpact: 'Supports compatibility catalog lookups.',
      inputs: 'Legacy catalog query',
      outputs: 'Legacy candidate list',
      hasLiveTrace: false,
      limitation: 'Does not supersede the provenance-aware resolver.',
    ),
    AlgorithmDescriptor(
      id: 'catalog_search_index',
      name: 'Catalog n-gram search index',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/core/analysis/catalog_search_index.dart',
      userVisibleImpact:
          'Produces stable multilingual type-ahead matches without rescanning the full catalog.',
      inputs: 'Normalized query and revision-bound catalog entries',
      outputs: 'Source-ordered exact substring matches',
      hasLiveTrace: false,
      limitation:
          'Text matching improves retrieval speed; it does not establish product identity.',
    ),
    AlgorithmDescriptor(
      id: 'medication_catalog_search',
      name: 'Medication product catalog search',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/core/services/medication_product_catalog.dart',
      additionalSourcePaths: ['lib/core/models/medication_product_pack.dart'],
      userVisibleImpact:
          'Filters product packs and deterministically prioritizes exact identifiers.',
      inputs: 'Search terms, normalized identifiers, and product packs',
      outputs: 'Exact-first, generic-name-stable product matches',
      hasLiveTrace: false,
      limitation:
          'Search rank supports selection and does not establish interchangeability.',
    ),
    AlgorithmDescriptor(
      id: 'timeline_context_index',
      name: 'Timeline nearest-context index',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.liveTimeline,
      sourcePath: 'lib/features/timeline/timeline_lookup_index.dart',
      userVisibleImpact:
          'Chooses the nearest meal or intake shown beside each timeline event.',
      inputs: 'Reverse-chronological events, meals, and medication intakes',
      outputs:
          'Deterministic nearest cross-type context with earlier-tie policy',
      hasLiveTrace: false,
      limitation:
          'Adjacency is display context only and is not a causal interaction claim.',
    ),
    AlgorithmDescriptor(
      id: 'product_response_copy_policy',
      name: 'Product response-copy policy',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/core/copy/response_copy_service.dart',
      userVisibleImpact:
          'Maps machine outcomes and missingness into bounded user-facing copy.',
      inputs: 'Engine result, issue codes, locale, and protected facts',
      outputs: 'Localized safe copy or unchanged deterministic fallback',
      hasLiveTrace: false,
      limitation:
          'Copy transformation cannot add facts or change the upstream decision.',
    ),
    AlgorithmDescriptor(
      id: 'reminder_schedule_manifest',
      name: 'Reminder schedule manifest preflight',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.decisionFlow,
      sourcePath: 'lib/core/services/reminder_schedule_manifest.dart',
      additionalSourcePaths: ['lib/domain/entities/user_logging_reminder.dart'],
      userVisibleImpact:
          'Deterministically validates and orders the notification requests to be scheduled.',
      inputs: 'Enabled reminders, weekdays, platform budget, and id hasher',
      outputs: 'Stable schedule manifest or explicit fail-closed reason',
      hasLiveTrace: false,
      limitation:
          'A valid manifest does not prove that an operating system will deliver a notification.',
    ),
    AlgorithmDescriptor(
      id: 'reminder_pending_identity_attestation',
      name: 'Reminder pending-request identity attestation',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath:
          'lib/core/services/reminder_pending_identity_attestation.dart',
      userVisibleImpact:
          'Classifies the installed reminder request set as matched, drifted, or uninspectable for the reminder status UI.',
      inputs:
          'Planned notification ids and payload digests, plus plugin-reported pending requests',
      outputs:
          'Privacy-bounded attestation status and missing, extra, or replaced counts',
      hasLiveTrace: false,
      limitation:
          'Plugin-registry identity matching does not prove operating-system delivery or visible notification presentation.',
    ),
    AlgorithmDescriptor(
      id: 'amino_acid_extraction',
      name: 'FDC amino-acid extraction',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath: 'lib/data/datasources/remote/amino_acid_extractor.dart',
      userVisibleImpact:
          'Controls which source amino-acid measurements reach LNAA competition.',
      inputs:
          'FDC nutrient identifiers, units, values, and derivation metadata',
      outputs: 'Gram-normalized amino-acid profile with explicit partial state',
      hasLiveTrace: false,
      limitation:
          'Extraction preserves source measurements and does not create missing amino acids.',
    ),
    AlgorithmDescriptor(
      id: 'catalog_crosswalk_builder',
      name: 'Catalog identity crosswalk builder',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/data/datasources/remote/crosswalk_builders.dart',
      userVisibleImpact:
          'Creates deterministic external-id links used by catalog resolution.',
      inputs:
          'Source identifiers, concepts, variants, jurisdiction, confidence',
      outputs: 'Stable crosswalk identity and audit payload',
      hasLiveTrace: false,
      limitation:
          'A crosswalk records asserted identity and does not prove clinical equivalence.',
    ),
    AlgorithmDescriptor(
      id: 'catalog_source_ingestion',
      name: 'Source-specific catalog ingestion pipeline',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/data/datasources/remote/etl_ingestion_pipeline.dart',
      additionalSourcePaths: [
        'lib/core/utils/qualified_value_parser.dart',
        'lib/data/datasources/remote/china_cdc_food_platform_importer.dart',
        'lib/data/datasources/remote/ciqual_p0_importer.dart',
        'lib/data/datasources/remote/dailymed_p0_importer.dart',
        'lib/data/datasources/remote/dmd_importer.dart',
        'lib/data/datasources/remote/ema_p1_importer.dart',
        'lib/data/datasources/remote/eu_national_register_importer.dart',
        'lib/data/datasources/remote/fao_fbdg_p1_importer.dart',
        'lib/data/datasources/remote/fdc_p0_importer.dart',
        'lib/data/datasources/remote/health_canada_din_product_importer.dart',
        'lib/data/datasources/remote/health_canada_dpd_p0_importer.dart',
        'lib/data/datasources/remote/importer_audit.dart',
        'lib/data/datasources/remote/locale_resource_seed_importer.dart',
        'lib/data/datasources/remote/nmpa_importer.dart',
        'lib/data/datasources/remote/openfda_ndc_product_importer.dart',
        'lib/data/datasources/remote/p0_import_support.dart',
        'lib/data/datasources/remote/p0_ingestion_orchestrator.dart',
        'lib/data/datasources/remote/pmda_p1_importer.dart',
        'lib/data/datasources/remote/regional_seed_catalog_importer.dart',
        'lib/data/datasources/remote/secondary_source_registry_importer.dart',
        'lib/data/datasources/remote/seed_catalog_importer.dart',
        'lib/data/datasources/remote/source_adapter.dart',
        'lib/data/datasources/remote/source_adapter_registry.dart',
      ],
      userVisibleImpact:
          'Normalizes heterogeneous public-source records before they can affect catalog results.',
      inputs:
          'Versioned regulator, food-composition, and regional source payloads',
      outputs:
          'Auditable facts, variants, crosswalk candidates, and exclusions',
      hasLiveTrace: false,
      limitation:
          'Adapter success means schema-valid ingestion, not truth or clinical equivalence.',
    ),
    AlgorithmDescriptor(
      id: 'algorithm_configuration_identity',
      name: 'Canonical algorithm configuration identity',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/algorithm_sdk/algorithm_configuration_identity.dart',
      additionalSourcePaths: [
        'lib/algorithm_sdk/algorithm_component_graph_identity.dart',
        'lib/algorithm_sdk/algorithm_parameter_provenance.dart',
        'lib/algorithm_sdk/parkinsum_algorithm_sdk.dart',
        'lib/domain/entities/algorithm_component_identity_witness.dart',
      ],
      userVisibleImpact:
          'Binds an exported result to typed parameter provenance and the checked default algorithm stack.',
      inputs:
          'Units, values/distributions, formulas, provenance, rules, and source fingerprints',
      outputs:
          'Schema-versioned parameter manifest, canonical configuration, and SHA-256 digest',
      hasLiveTrace: false,
      limitation:
          'Identity proves byte/configuration consistency, not scientific validity.',
    ),
    AlgorithmDescriptor(
      id: 'algorithm_visual_projection',
      name: 'Algorithm visual contract projection',
      stage: AlgorithmStage.explain,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath:
          'lib/features/algorithm_observatory/algorithm_observatory_page.dart',
      additionalSourcePaths: [
        'lib/features/shared/interaction_result_view.dart',
        'lib/features/shared/mechanistic_trace_view.dart',
      ],
      userVisibleImpact:
          'Maps registered algorithms and real traces into bounded UI visuals.',
      inputs:
          'Registry descriptors, provider bindings, and result trace values',
      outputs:
          'Algorithm-specific static contracts and provider-labelled live visuals',
      hasLiveTrace: false,
      limitation:
          'A visualization explains supplied values and is not independent validation.',
    ),
    AlgorithmDescriptor(
      id: 'firestore_collection_diff',
      name: 'Canonical Firestore collection diff',
      stage: AlgorithmStage.resolve,
      visualization: AlgorithmVisualization.resolutionTable,
      sourcePath: 'lib/core/db/firestore_collection_diff.dart',
      userVisibleImpact:
          'Selects the minimal upserts and removals used to synchronize user collections.',
      inputs: 'Existing and desired JSON-compatible document maps',
      outputs: 'Canonical-content upserts and exact-id removals',
      hasLiveTrace: false,
      limitation:
          'The plan compares client state; transaction success remains a backend concern.',
    ),
    AlgorithmDescriptor(
      id: 'account_password_policy',
      name: 'Account password guidance policy',
      stage: AlgorithmStage.decide,
      visualization: AlgorithmVisualization.qualityMatrix,
      sourcePath: 'lib/core/security/account_password_policy.dart',
      userVisibleImpact:
          'Determines which client-side password-change issues are displayed.',
      inputs: 'Current, replacement, and confirmation password strings',
      outputs: 'Ordered validation issue codes',
      hasLiveTrace: false,
      limitation:
          'Client guidance is not the identity provider’s authoritative policy.',
    ),
    AlgorithmDescriptor(
      id: 'cdss_identifier_factory',
      name: 'CDSS identifier and input-digest factory',
      stage: AlgorithmStage.normalize,
      visualization: AlgorithmVisualization.provenanceGraph,
      sourcePath: 'lib/core/security/cdss_identifier_factory.dart',
      userVisibleImpact:
          'Controls artifact identity, idempotency, and privacy-preserving input digests.',
      inputs: 'Safe prefix, canonical JSON payload, clock, and secure entropy',
      outputs: 'Opaque artifact id or domain-separated SHA-256 digest',
      hasLiveTrace: false,
      limitation:
          'Identifiers support auditability and do not validate the underlying result.',
    ),
  ];

  static AlgorithmDescriptor? byId(String id) {
    for (final descriptor in all) {
      if (descriptor.id == id) return descriptor;
    }
    return null;
  }

  /// Every algorithm-bearing source directory is inventory-checked in tests.
  /// A file may be absent from [all] only when it is listed here with a
  /// reviewable reason showing that it cannot alter a user-visible result.
  static const Map<String, String> excludedSourcePaths = {
    'lib/core/analysis/food_repository.dart':
        'Static legacy lookup storage; ranking is registered separately.',
    'lib/core/analysis/medication_repository.dart':
        'Static legacy lookup storage; interaction logic is registered separately.',
    'lib/domain/entities/mechanistic_event_ledger.dart':
        'Versioned read-only event audit contract; it does not feed production scoring or recommendations.',
    'lib/domain/usecases/algorithm_observatory_service.dart':
        'Read-only synthetic trace fixture; never participates in app results.',
    'lib/domain/usecases/algorithm_numerical_verification_oracle.dart':
        'Read-only independent calculation verifier around registered production algorithms; never participates in app results.',
    'lib/domain/usecases/algorithm_registry.dart':
        'Coverage metadata for algorithms, not an algorithm itself.',
    'lib/domain/usecases/catalog_inventory_diagnostics.dart':
        'Reports existing catalog state without changing resolution or ranking.',
    'lib/domain/usecases/cdss_artifact_store.dart':
        'Persistence interface only; release decisions are registered separately.',
    'lib/domain/usecases/cdss_artifact_store_io.dart':
        'Platform file persistence only; no result transformation.',
    'lib/domain/usecases/cdss_artifact_store_stub.dart':
        'Platform fallback persistence only; no result transformation.',
    'lib/domain/usecases/contribution_safety_router.dart':
        'Offline contribution-governance workflow; not part of app result paths.',
    'lib/domain/usecases/data_integrity_report.dart':
        'Read-only diagnostics over already-produced data.',
    'lib/domain/usecases/evidence_graph_builder.dart':
        'Read-only provenance diagnostic; the user-facing trace bundle is registered.',
    'lib/domain/usecases/evidence_graph_mermaid_renderer.dart':
        'Presentation renderer for an existing graph.',
    'lib/domain/usecases/explanation_copy_diagnostics.dart':
        'Reports copy-registry state; compiler and service are registered.',
    'lib/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart':
        'Interchange export mapper; does not feed a runtime decision.',
    'lib/domain/usecases/fhir_inspired_nutrition_intake_mapper.dart':
        'Interchange export mapper; does not feed a runtime decision.',
    'lib/domain/usecases/local_privacy_preflight.dart':
        'Offline release diagnostic; does not change an app result.',
    'lib/domain/usecases/localization_lint_diagnostics.dart':
        'Read-only localization diagnostics.',
    'lib/domain/usecases/localization_safety_lint.dart':
        'Offline release gate; runtime copy selection is registered separately.',
    'lib/domain/usecases/mechanistic_event_ledger_builder.dart':
        'Read-only projection of validated production context into an audit ledger; it cannot alter runtime results.',
    'lib/domain/usecases/mechanistic_replay_runner.dart':
        'Deterministic verification harness around registered production models.',
    'lib/domain/usecases/model_assumption_registry.dart':
        'Evidence metadata rendered by the parameter panel; contains no formula.',
    'lib/domain/usecases/public_demo_walkthrough_generator.dart':
        'Documentation generator over existing traces.',
    'lib/domain/usecases/recommendation_replay_runner.dart':
        'Verification harness around the registered recommendation engine.',
    'lib/domain/usecases/release_snapshot_generator.dart':
        'Release report generator; it does not alter an app result.',
    'lib/domain/usecases/source_access_contract_checker.dart':
        'Offline source-access governance check, not a runtime decision path.',
    'lib/domain/usecases/source_quality_perturbation_report.dart':
        'Offline sensitivity report around registered source scoring.',
    'lib/domain/usecases/source_version_drift_checker.dart':
        'Offline drift report; published snapshot selection is registered.',
    'lib/domain/usecases/synthetic_scenario_fuzzer.dart':
        'Test-case generator around registered algorithms.',
  };
}
