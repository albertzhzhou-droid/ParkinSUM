import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../algorithm_sdk/algorithm_parameter_provenance.dart';
import '../../core/theme/paper_theme.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/models/administration_dose_confirmation.dart';
import '../../core/models/intake.dart';
import '../../domain/entities/algorithm_descriptor.dart';
import '../../domain/entities/algorithm_dependency_compatibility.dart';
import '../../domain/entities/algorithm_configuration_change_impact.dart';
import '../../domain/entities/algorithm_contract_independent_oracle_attestation.dart';
import '../../domain/entities/algorithm_relation_domain_sampling_attestation.dart';
import '../../domain/entities/algorithm_result_root_manifest.dart';
import '../../domain/entities/algorithm_trace_node.dart';
import '../../domain/entities/context_of_use_requalification.dart';
import '../../domain/entities/configuration_baseline_registry.dart';
import '../../domain/entities/credibility_adaptive_design_simulation.dart';
import '../../domain/entities/credibility_bayesian_borrowing_calibration.dart';
import '../../domain/entities/credibility_bayesian_multisource_model_criticism.dart';
import '../../domain/entities/credibility_blinded_replication.dart';
import '../../domain/entities/credibility_evidence_execution_attestation.dart';
import '../../domain/entities/credibility_protocol_transparency_ledger.dart';
import '../../domain/entities/credibility_randomization_interim_firewall.dart';
import '../../domain/entities/credibility_statistical_analysis.dart';
import '../../domain/entities/credibility_target_population_transportability.dart';
import '../../domain/entities/credibility_transportability_sensitivity.dart';
import '../../domain/entities/evidence_currency.dart';
import '../../domain/entities/evidence_synthesis.dart';
import '../../domain/entities/gastric_structural_uncertainty.dart';
import '../../domain/entities/mechanistic_candidate_score.dart';
import '../../domain/entities/mechanistic_conflict_result.dart';
import '../../domain/entities/mechanistic_event_ledger.dart';
import '../../domain/entities/mechanistic_replay_capsule.dart';
import '../../domain/entities/mechanistic_medication_applicability.dart';
import '../../domain/entities/prospective_model_credibility_plan.dart';
import '../../domain/usecases/algorithm_numerical_verification_oracle.dart';
import '../../domain/usecases/algorithm_executable_contract_gate.dart';
import '../../domain/usecases/algorithm_configuration_change_impact_service.dart';
import '../../domain/usecases/configuration_baseline_registry_service.dart';
import '../../domain/usecases/algorithm_observatory_service.dart';
import '../../domain/usecases/administration_dose_confirmation_coordinator.dart';
import '../../domain/usecases/algorithm_registry.dart';
import '../../domain/usecases/adaptive_design_operating_characteristics_simulator.dart';
import '../../domain/usecases/bayesian_borrowing_operating_characteristics_simulator.dart';
import '../../domain/usecases/bayesian_multisource_model_criticism_simulator.dart';
import '../../domain/usecases/mechanistic_model_verification_gate.dart';
import '../../domain/usecases/mechanistic_event_ledger_authorization.dart';
import '../../domain/usecases/target_population_transportability_simulator.dart';
import '../../domain/usecases/transportability_bias_function_sensitivity_simulator.dart';
import '../../domain/usecases/dosage_note_parser.dart';
import '../shared/dose_expression_status_card.dart';

extension _AlgorithmObservatoryI18n on BuildContext {
  AppI18n get appI18n =>
      AppI18n.fromLocaleTag(Localizations.localeOf(this).toLanguageTag());
}

String _availabilityLabel(MechanisticResultAvailability availability) =>
    switch (availability) {
      MechanisticResultAvailability.available => 'available',
      MechanisticResultAvailability.notApplicable => 'not applicable',
      MechanisticResultAvailability.insufficient => 'insufficient data',
      MechanisticResultAvailability.blockedIntegrity => 'integrity blocked',
    };

String _modeledScoreLabel(MechanisticConflictResult result) {
  final score = result.modeledInteractionScore;
  return score == null ? '—' : '${(score * 100).toStringAsFixed(1)}%';
}

String _modeledBandsLabel(MechanisticConflictResult result) {
  final severity = result.modeledSeverityBand;
  final confidence = result.modeledConfidenceBand;
  if (severity == null || confidence == null) {
    return _availabilityLabel(result.availability);
  }
  return '${severity.name} / ${confidence.name}';
}

/// Read-only, replayable explanation surface for the algorithms that can
/// change a user-visible result.
class AlgorithmObservatoryPage extends StatefulWidget {
  /// Complex two-dimensional figures that must retain an equivalent textual
  /// and tabular representation whenever this page changes.
  static const complexChartIds = <String>{
    'gastric-emptying',
    'gastric-structural-uncertainty',
    'absorption-competition',
  };

  final AlgorithmObservatoryService? service;
  final DateTime? evidenceAsOfUtc;
  final Future<AlgorithmExecutableContractReport>? executableContractReport;
  final Future<void> Function(MechanisticReplayCapsule)? onSaveReplayCapsule;
  final Future<List<MechanisticReplayCapsule>> Function()?
  loadSavedReplayCapsules;

  const AlgorithmObservatoryPage({
    super.key,
    this.service,
    this.evidenceAsOfUtc,
    this.executableContractReport,
    this.onSaveReplayCapsule,
    this.loadSavedReplayCapsules,
  });

  @override
  State<AlgorithmObservatoryPage> createState() =>
      _AlgorithmObservatoryPageState();
}

class _AlgorithmObservatoryPageState extends State<AlgorithmObservatoryPage> {
  late final AlgorithmObservatoryService _service;
  final TextEditingController _algorithmSearchController =
      TextEditingController();
  ObservatoryScenario _scenario = ObservatoryScenario.mixedReference;
  late final Map<ObservatoryScenario, AlgorithmObservatorySnapshot> _snapshots;
  late final AlgorithmTraceSurfaceManifest _traceSurfaceManifest;
  late final Future<AlgorithmResultRootManifest> _resultRootManifest;
  late final AlgorithmNumericalOracleReport _oracleReport;
  late final MechanisticModelVerificationReport _invariantReport;
  late final Future<AlgorithmExecutableContractReport>
  _executableContractReport;
  late final AlgorithmContractIndependentOracleAssessment
  _independentContractOracleAssessment;
  late final AlgorithmRelationDomainSamplingAssessment
  _relationDomainSamplingAssessment;
  late final EvidenceCurrencyAssessment _evidenceCurrencyAssessment;
  late final EvidenceSynthesisAssessment _evidenceSynthesisAssessment;
  late final ContextOfUseRequalificationLedger _requalificationLedger;
  late final AlgorithmConfigurationChangeImpactPackage
  _configurationChangeImpact;
  late final Future<ConfigurationBaselineTransitionResult>
  _configurationBaselineRegistry;
  late final ProspectiveModelCredibilityPlan _prospectiveCredibilityPlan;
  late final EvidenceIndependenceAssessment _evidenceExecutionAssessment;
  late final CredibilityProtocolTransparencyLedger _protocolTransparencyLedger;
  late final ProtocolTransparencyAssessment _protocolTransparencyAssessment;
  late final BlindedReplicationAssessment _blindedReplicationAssessment;
  late final StatisticalGovernanceAssessment _statisticalAssessment;
  late final RandomizationInterimGovernanceAssessment
  _randomizationInterimAssessment;
  late final AdaptiveSimulationGovernanceAssessment
  _adaptiveSimulationAssessment;
  late final BayesianGovernanceAssessment _bayesianBorrowingAssessment;
  late final MultisourceGovernanceAssessment _bayesianMultisourceAssessment;
  late final TargetTransportabilityAssessment _targetTransportabilityAssessment;
  late final TransportSensitivityAssessment _transportSensitivityAssessment;
  late AlgorithmObservatorySnapshot _snapshot;
  AlgorithmStage? _algorithmStage;
  bool _liveTraceOnly = false;
  List<MechanisticReplayCapsule> _savedReplayCapsules =
      const <MechanisticReplayCapsule>[];
  bool _savedReplayCapsulesLoaded = false;
  bool _savingReplayCapsule = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AlgorithmObservatoryService();
    _traceSurfaceManifest = AlgorithmTraceSurfaceManifest(
      algorithms: AlgorithmRegistry.all,
      providers: const [AlgorithmObservatoryService.traceProviderContract],
    );
    _resultRootManifest = _loadResultRootManifest();
    _snapshots = {
      for (final scenario in ObservatoryScenario.values)
        scenario: _service.build(scenario),
    };
    _oracleReport = const AlgorithmNumericalVerificationOracle().run(
      service: _service,
    );
    _invariantReport = const MechanisticModelVerificationGate().verify(
      snapshots: _snapshots,
      oracleReport: _oracleReport,
    );
    _executableContractReport =
        widget.executableContractReport ??
        const AlgorithmExecutableContractGate().run();
    _independentContractOracleAssessment =
        const AlgorithmContractIndependentOracleVerifier().verify(
          AlgorithmContractIndependentOracleAttestation.current(),
        );
    _relationDomainSamplingAssessment =
        const AlgorithmRelationDomainSamplingVerifier().verify(
          AlgorithmRelationDomainSamplingAttestation.current(),
        );
    _snapshot = _snapshots[_scenario]!;
    if (widget.loadSavedReplayCapsules != null) {
      unawaited(_loadSavedReplayCapsules());
    }
    final evidenceAsOfUtc =
        widget.evidenceAsOfUtc?.toUtc() ?? DateTime.now().toUtc();
    _evidenceCurrencyAssessment = EvidenceCurrencyRegistry.current.assess(
      asOfUtc: evidenceAsOfUtc,
    );
    _evidenceSynthesisAssessment = EvidenceSynthesisRegistry.current.assess(
      asOfUtc: evidenceAsOfUtc,
      currencyAssessment: _evidenceCurrencyAssessment,
    );
    _requalificationLedger = ContextOfUseRequalificationLedger.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256: _snapshot.configurationIdentity.sha256Digest,
      evidenceAsOfUtc: evidenceAsOfUtc,
    );
    _configurationChangeImpact =
        const AlgorithmConfigurationChangeImpactService().buildCurrentFixture();
    _configurationBaselineRegistry =
        const ConfigurationBaselineRegistryService().buildCurrentFixture(
          impact: _configurationChangeImpact,
          contextOfUseRecordSha256: _requalificationLedger.latest.recordSha256,
        );
    _prospectiveCredibilityPlan = ProspectiveModelCredibilityPlan.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256: _snapshot.configurationIdentity.sha256Digest,
    );
    _evidenceExecutionAssessment =
        const CredibilityEvidenceIndependenceVerifier().verify(
          CredibilityEvidenceExecutionAttestation.syntheticCurrent(
            prospectivePlanSha256: _prospectiveCredibilityPlan.planSha256,
            manifestSha256:
                MechanisticApplicabilityManifest.current.sha256Digest,
            configurationSha256: _snapshot.configurationIdentity.sha256Digest,
            algorithmSourceBundleSha256: AlgorithmConfigurationIdentity
                .registeredAlgorithmSourceBundleSha256,
          ),
        );
    _protocolTransparencyLedger =
        CredibilityProtocolTransparencyLedger.syntheticCurrent(
          prospectivePlanSha256: _prospectiveCredibilityPlan.planSha256,
          executionAttestationSha256:
              _evidenceExecutionAssessment.attestation.attestationSha256,
          manifestSha256: MechanisticApplicabilityManifest.current.sha256Digest,
          configurationSha256: _snapshot.configurationIdentity.sha256Digest,
          algorithmSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
        );
    _protocolTransparencyAssessment =
        const CredibilityProtocolTransparencyVerifier().verify(
          _protocolTransparencyLedger,
        );
    final replicationPackage =
        CredibilityBlindedReplicationPackage.syntheticCurrent(
          protocolLedger: _protocolTransparencyLedger,
          protocolAssessment: _protocolTransparencyAssessment,
          executionAttestationSha256:
              _evidenceExecutionAssessment.attestation.attestationSha256,
          configurationSha256: _snapshot.configurationIdentity.sha256Digest,
          algorithmSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
        );
    _blindedReplicationAssessment =
        const CredibilityBlindedReplicationVerifier().verify(
          replicationPackage,
        );
    final statisticalPackage =
        CredibilityStatisticalAnalysisPackage.syntheticCurrent(
          prospectivePlanSha256: _prospectiveCredibilityPlan.planSha256,
          protocolLedgerSha256: _protocolTransparencyLedger.ledgerSha256,
          replicationPackageSha256: replicationPackage.packageSha256,
          configurationSha256: _snapshot.configurationIdentity.sha256Digest,
          algorithmSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
        );
    _statisticalAssessment = const CredibilityStatisticalAnalysisVerifier()
        .verify(statisticalPackage);
    final randomizationPackage =
        CredibilityRandomizationInterimPackage.syntheticCurrent(
          statisticalPackage: statisticalPackage,
          configurationSha256: _snapshot.configurationIdentity.sha256Digest,
          algorithmSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
        );
    _randomizationInterimAssessment =
        const CredibilityRandomizationInterimVerifier().verify(
          randomizationPackage,
        );
    final adaptivePackage = AdaptiveDesignSyntheticFixture.build(
      randomizationPackage: randomizationPackage,
    );
    _adaptiveSimulationAssessment =
        const CredibilityAdaptiveDesignSimulationVerifier().verify(
          adaptivePackage,
        );
    final bayesianPackage = BayesianBorrowingSyntheticFixture.build(
      adaptivePackage: adaptivePackage,
    );
    _bayesianBorrowingAssessment =
        const CredibilityBayesianBorrowingCalibrationVerifier().verify(
          bayesianPackage,
        );
    final multisourcePackage = BayesianMultisourceModelCriticismFixture.build(
      bayesianPackage: bayesianPackage,
    );
    _bayesianMultisourceAssessment =
        const CredibilityBayesianMultisourceModelCriticismVerifier().verify(
          multisourcePackage,
        );
    final targetTransportabilityPackage =
        TargetPopulationTransportabilityFixture.build(
          multisourcePackage: multisourcePackage,
        );
    _targetTransportabilityAssessment =
        const CredibilityTargetPopulationTransportabilityVerifier().verify(
          targetTransportabilityPackage,
        );
    _transportSensitivityAssessment =
        const CredibilityTransportabilitySensitivityVerifier().verify(
          TransportabilityBiasFunctionSensitivityFixture.build(
            transportPackage: targetTransportabilityPackage,
          ),
        );
  }

  Future<void> _loadSavedReplayCapsules() async {
    final load = widget.loadSavedReplayCapsules;
    if (load == null) return;
    try {
      final capsules = await load();
      if (!mounted) return;
      setState(() {
        _savedReplayCapsules = capsules;
        _savedReplayCapsulesLoaded = true;
      });
    } catch (error) {
      debugPrint(
        'Algorithm Observatory could not load saved synthetic replay capsules: ${error.runtimeType}',
      );
    }
  }

  Future<void> _saveReplayCapsule() async {
    final save = widget.onSaveReplayCapsule;
    if (save == null || _savingReplayCapsule) return;
    setState(() => _savingReplayCapsule = true);
    try {
      final capsule = _snapshot.replayCapsule;
      await save(capsule);
      final load = widget.loadSavedReplayCapsules;
      final capsules = load == null
          ? <String, MechanisticReplayCapsule>{
              for (final saved in _savedReplayCapsules)
                saved.capsuleSha256: saved,
              capsule.capsuleSha256: capsule,
            }.values.toList(growable: false)
          : await load();
      if (!mounted) return;
      setState(() {
        _savedReplayCapsules = capsules;
        _savedReplayCapsulesLoaded = true;
      });
    } catch (error) {
      debugPrint(
        'Algorithm Observatory could not save synthetic replay capsule: ${error.runtimeType}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.appI18n.tr('observatory.replay_capsule.save_failure'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReplayCapsule = false);
    }
  }

  Future<AlgorithmResultRootManifest> _loadResultRootManifest() async {
    final source = await rootBundle.loadString(
      'config/algorithm_result_root_manifest.json',
    );
    final manifest = AlgorithmResultRootManifest.decode(source);
    manifest.validateAgainstRegistry({
      for (final descriptor in AlgorithmRegistry.all)
        descriptor.id: descriptor.sourcePath,
    });
    return manifest;
  }

  @override
  void dispose() {
    _algorithmSearchController.dispose();
    super.dispose();
  }

  void _selectScenario(ObservatoryScenario scenario) {
    if (scenario == _scenario) return;
    debugPrint('[AlgorithmObservatory] scenario:selected ${scenario.name}');
    setState(() {
      _scenario = scenario;
      _snapshot = _snapshots[scenario]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final algorithmQuery = _algorithmSearchController.text.trim().toLowerCase();
    final visibleAlgorithms = AlgorithmRegistry.all
        .where((descriptor) {
          if (_algorithmStage != null && descriptor.stage != _algorithmStage) {
            return false;
          }
          if (_liveTraceOnly && !descriptor.hasLiveTrace) return false;
          if (algorithmQuery.isEmpty) return true;
          return <String>[
            descriptor.id,
            descriptor.name,
            descriptor.userVisibleImpact,
            descriptor.inputs,
            descriptor.outputs,
            descriptor.sourcePath,
          ].join(' ').toLowerCase().contains(algorithmQuery);
        })
        .toList(growable: false);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PaperAppBar(title: Text(context.appI18n.tr('observatory.title'))),
      body: PaperBackground(
        child: SafeArea(
          child: ListView(
            key: const Key('observatory-scroll-list'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _BoundaryCard(count: AlgorithmRegistry.all.length),
              const SizedBox(height: 14),
              _TraceSurfaceManifestPanel(manifest: _traceSurfaceManifest),
              const SizedBox(height: 14),
              _DependencyClosureReadinessPanel(manifest: _resultRootManifest),
              const SizedBox(height: 14),
              _ScenarioSelector(
                selected: _scenario,
                onSelected: _selectScenario,
              ),
              const SizedBox(height: 14),
              _SensitivityComparisonPanel(snapshots: _snapshots),
              const SizedBox(height: 14),
              _GastricEmptyingPanel(snapshot: _snapshot),
              const SizedBox(height: 14),
              _GastricStructuralUncertaintyPanel(snapshot: _snapshot),
              const SizedBox(height: 14),
              _AbsorptionCompetitionPanel(snapshot: _snapshot),
              const SizedBox(height: 14),
              _ConflictPanel(snapshot: _snapshot),
              const SizedBox(height: 14),
              _ExplanationTreePanel(root: _snapshot.explanationTree),
              const SizedBox(height: 14),
              _CandidatePanel(scores: _snapshot.candidateScores),
              const SizedBox(height: 14),
              _ConfigurationCoveragePanel(
                configurationIdentity: _snapshot.configurationIdentity,
              ),
              const SizedBox(height: 14),
              _ConfigurationChangeImpactPanel(
                impact: _configurationChangeImpact,
              ),
              const SizedBox(height: 14),
              _ConfigurationBaselineRegistryPanel(
                result: _configurationBaselineRegistry,
              ),
              const SizedBox(height: 14),
              _ParameterEvidencePanel(
                configurationIdentity: _snapshot.configurationIdentity,
              ),
              const SizedBox(height: 14),
              _ApplicabilityManifestPanel(
                manifest: MechanisticApplicabilityManifest.current,
              ),
              const SizedBox(height: 14),
              _EvidenceCurrencyPanel(assessment: _evidenceCurrencyAssessment),
              const SizedBox(height: 14),
              EvidenceSynthesisPanel(assessment: _evidenceSynthesisAssessment),
              const SizedBox(height: 14),
              _RequalificationLedgerPanel(ledger: _requalificationLedger),
              const SizedBox(height: 14),
              _ProspectiveCredibilityPanel(plan: _prospectiveCredibilityPlan),
              const SizedBox(height: 14),
              _EvidenceExecutionPanel(assessment: _evidenceExecutionAssessment),
              const SizedBox(height: 14),
              _ProtocolTransparencyPanel(
                assessment: _protocolTransparencyAssessment,
              ),
              const SizedBox(height: 14),
              _BlindedReplicationPanel(
                assessment: _blindedReplicationAssessment,
              ),
              const SizedBox(height: 14),
              _StatisticalGovernancePanel(assessment: _statisticalAssessment),
              const SizedBox(height: 14),
              _RandomizationInterimPanel(
                assessment: _randomizationInterimAssessment,
              ),
              const SizedBox(height: 14),
              _AdaptiveDesignSimulationPanel(
                assessment: _adaptiveSimulationAssessment,
              ),
              const SizedBox(height: 14),
              _BayesianBorrowingCalibrationPanel(
                assessment: _bayesianBorrowingAssessment,
              ),
              const SizedBox(height: 14),
              _BayesianMultisourceModelCriticismPanel(
                assessment: _bayesianMultisourceAssessment,
              ),
              const SizedBox(height: 14),
              _TargetPopulationTransportabilityPanel(
                assessment: _targetTransportabilityAssessment,
              ),
              const SizedBox(height: 14),
              _TransportabilitySensitivityPanel(
                assessment: _transportSensitivityAssessment,
              ),
              const SizedBox(height: 14),
              const _DoseExpressionGrammarPanel(),
              const SizedBox(height: 14),
              const _DoseConfirmationReconciliationPanel(),
              const SizedBox(height: 14),
              _MechanisticInvariantGatePanel(
                report: _invariantReport,
                totalAlgorithms: AlgorithmRegistry.all.length,
              ),
              const SizedBox(height: 14),
              _ExecutableContractGatePanel(
                report: _executableContractReport,
                mathematicalCoverage: _invariantReport.coveredAlgorithmIds,
                totalAlgorithms: AlgorithmRegistry.all.length,
              ),
              const SizedBox(height: 14),
              _IndependentContractOraclePanel(
                assessment: _independentContractOracleAssessment,
              ),
              const SizedBox(height: 14),
              _RelationDomainSamplingPanel(
                assessment: _relationDomainSamplingAssessment,
              ),
              const SizedBox(height: 14),
              _NumericalOraclePanel(
                report: _oracleReport,
                totalAlgorithms: AlgorithmRegistry.all.length,
              ),
              const SizedBox(height: 14),
              _MechanisticEventLedgerPanel(
                ledger: _snapshot.eventLedger,
                authorization: _snapshot.ledgerAuthorization,
              ),
              const SizedBox(height: 14),
              _MechanisticReplayCapsulePanel(
                capsule: _snapshot.replayCapsule,
                onSave: widget.onSaveReplayCapsule == null
                    ? null
                    : _saveReplayCapsule,
                saving: _savingReplayCapsule,
                savedCount: _savedReplayCapsulesLoaded
                    ? _savedReplayCapsules.length
                    : null,
                alreadySaved: _savedReplayCapsules.any(
                  (saved) =>
                      saved.capsuleSha256 ==
                      _snapshot.replayCapsule.capsuleSha256,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                context.appI18n.tr('observatory.coverage.title'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                context.appI18n.tr('observatory.coverage.body'),
                style: TextStyle(color: Paper.inkMuted),
              ),
              const SizedBox(height: 12),
              _AlgorithmAtlasControls(
                controller: _algorithmSearchController,
                stage: _algorithmStage,
                liveTraceOnly: _liveTraceOnly,
                visibleCount: visibleAlgorithms.length,
                totalCount: AlgorithmRegistry.all.length,
                onSearchChanged: (_) => setState(() {}),
                onStageChanged: (stage) => setState(() {
                  _algorithmStage = _algorithmStage == stage ? null : stage;
                }),
                onLiveTraceChanged: (value) =>
                    setState(() => _liveTraceOnly = value),
                onClear: () => setState(() {
                  _algorithmSearchController.clear();
                  _algorithmStage = null;
                  _liveTraceOnly = false;
                }),
              ),
              const SizedBox(height: 14),
              for (final stage in AlgorithmStage.values) ...[
                if (visibleAlgorithms.any((entry) => entry.stage == stage)) ...[
                  _StageHeading(stage: stage),
                  const SizedBox(height: 8),
                  for (final descriptor in visibleAlgorithms.where(
                    (entry) => entry.stage == stage,
                  )) ...[
                    _AlgorithmCoverageCard(
                      descriptor: descriptor,
                      oracleStatus: _oracleReport.statusFor(descriptor.id),
                      invariantStatus: _invariantReport.statusFor(
                        descriptor.id,
                      ),
                      executableReport: _executableContractReport,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                ],
              ],
              if (visibleAlgorithms.isEmpty)
                PaperCard(
                  key: const Key('algorithm-atlas-empty'),
                  child: Text(
                    context.appI18n.tr('observatory.atlas.empty'),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlgorithmAtlasControls extends StatelessWidget {
  final TextEditingController controller;
  final AlgorithmStage? stage;
  final bool liveTraceOnly;
  final int visibleCount;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AlgorithmStage> onStageChanged;
  final ValueChanged<bool> onLiveTraceChanged;
  final VoidCallback onClear;

  const _AlgorithmAtlasControls({
    required this.controller,
    required this.stage,
    required this.liveTraceOnly,
    required this.visibleCount,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onStageChanged,
    required this.onLiveTraceChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final filtersActive =
        controller.text.isNotEmpty || stage != null || liveTraceOnly;
    return PaperCard(
      key: const Key('algorithm-atlas-controls'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.atlas.count', {
                    'visible': '$visibleCount',
                    'total': '$totalCount',
                  }),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (filtersActive)
                TextButton(
                  key: const Key('algorithm-atlas-clear'),
                  onPressed: onClear,
                  child: Text(context.appI18n.tr('observatory.atlas.clear')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('algorithm-atlas-search'),
            controller: controller,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: context.appI18n.tr('observatory.atlas.search'),
              hintText: context.appI18n.tr('observatory.atlas.search_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.appI18n.tr(
                        'observatory.atlas.clear_search',
                      ),
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in AlgorithmStage.values)
                FilterChip(
                  key: Key('algorithm-stage-filter-${value.name}'),
                  label: Text(_shortStageLabel(context, value)),
                  selected: stage == value,
                  onSelected: (_) => onStageChanged(value),
                ),
              FilterChip(
                key: const Key('algorithm-live-trace-filter'),
                avatar: const Icon(Icons.bolt_outlined, size: 18),
                label: Text(context.appI18n.tr('observatory.atlas.live_trace')),
                selected: liveTraceOnly,
                onSelected: onLiveTraceChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  final int count;
  const _BoundaryCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.boundary.title', {
                    'count': '$count',
                  }),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.appI18n.tr('observatory.boundary.body'),
            style: TextStyle(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _TraceSurfaceManifestPanel extends StatelessWidget {
  final AlgorithmTraceSurfaceManifest manifest;

  const _TraceSurfaceManifestPanel({required this.manifest});

  @override
  Widget build(BuildContext context) {
    final provider = manifest.providers.single;
    return PaperCard(
      key: const Key('observatory-trace-surface-manifest'),
      child: Semantics(
        container: true,
        label: context.appI18n.tr('observatory.trace_surface.semantics', {
          'live': '${manifest.liveCount}',
          'total': '${manifest.algorithms.length}',
          'static': '${manifest.staticOnlyCount}',
          'provider': provider.providerId,
          'schema': '${AlgorithmTraceSurfaceManifest.schemaVersion}',
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.appI18n.tr('observatory.trace_surface.title'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.appI18n.tr('observatory.trace_surface.summary', {
                'live': '${manifest.liveCount}',
                'total': '${manifest.algorithms.length}',
                'static': '${manifest.staticOnlyCount}',
              }),
              key: const Key('observatory-trace-surface-summary'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.appI18n.tr('observatory.trace_surface.body'),
              style: const TextStyle(color: Paper.inkMuted, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              context.appI18n.tr('observatory.trace_surface.identity', {
                'schema': '${AlgorithmTraceSurfaceManifest.schemaVersion}',
                'digest': manifest.sha256Digest.substring(0, 16),
              }),
              key: const Key('observatory-trace-surface-identity'),
              style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
            ),
            const SizedBox(height: 6),
            ExpansionTile(
              key: const Key('observatory-trace-surface-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Text(
                context.appI18n.tr('observatory.trace_surface.details'),
              ),
              children: [
                _traceContractLine(
                  context,
                  'observatory.trace_surface.provider',
                  provider.providerId,
                ),
                _traceContractLine(
                  context,
                  'observatory.trace_surface.fixture',
                  '${provider.fixtureSchema} · ${provider.fixtureRevision}',
                ),
                _traceContractLine(
                  context,
                  'observatory.trace_surface.lifecycle',
                  provider.lifecycle,
                ),
                _traceContractLine(
                  context,
                  'observatory.trace_surface.route',
                  provider.routeId,
                ),
                const SizedBox(height: 6),
                Text(
                  context.appI18n.tr(
                    'observatory.trace_surface.classification_boundary',
                  ),
                  key: const Key('observatory-trace-surface-boundary'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Paper.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _traceContractLine(
    BuildContext context,
    String labelKey,
    String value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            context.appI18n.tr(labelKey),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
          ),
        ),
      ],
    ),
  );
}

class _DependencyClosureReadinessPanel extends StatelessWidget {
  final Future<AlgorithmResultRootManifest> manifest;

  const _DependencyClosureReadinessPanel({required this.manifest});

  @override
  Widget build(BuildContext context) => PaperCard(
    key: const Key('observatory-dependency-closure-readiness'),
    child: FutureBuilder<AlgorithmResultRootManifest>(
      future: manifest,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null) {
          final failed = snapshot.hasError;
          return Semantics(
            container: true,
            label: failed
                ? context.appI18n.tr(
                    'observatory.dependency_closure.unavailable_semantics',
                  )
                : context.appI18n.tr(
                    'observatory.dependency_closure.loading_semantics',
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.appI18n.tr('observatory.dependency_closure.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  failed
                      ? context.appI18n.tr(
                          'observatory.dependency_closure.unavailable',
                        )
                      : context.appI18n.tr(
                          'observatory.dependency_closure.loading',
                        ),
                  key: const Key(
                    'observatory-dependency-closure-loading-or-error',
                  ),
                  style: const TextStyle(color: Paper.inkMuted),
                ),
              ],
            ),
          );
        }

        return Semantics(
          container: true,
          label: context.appI18n
              .tr('observatory.dependency_closure.semantics', {
                'count': '${resolved.entries.length}',
                'analyzer': algorithmDependencyAnalyzerVersion,
              }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.appI18n.tr(
                        'observatory.dependency_closure.title',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.appI18n.tr('observatory.dependency_closure.summary', {
                  'count': '${resolved.entries.length}',
                  'total': '${AlgorithmRegistry.all.length}',
                  'analyzer': algorithmDependencyAnalyzerVersion,
                }),
                key: const Key('observatory-dependency-closure-summary'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                context.appI18n.tr('observatory.dependency_closure.identity', {
                  'schema': algorithmResultRootManifestSchema,
                  'digest': resolved.sha256Digest.substring(0, 16),
                  'state': algorithmDependencyClosureHeld,
                }),
                key: const Key('observatory-dependency-root-identity'),
                style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ImpactStatusChip(
                    label: context.appI18n.tr(
                      'observatory.dependency_closure.registry_chip',
                    ),
                    positive: true,
                  ),
                  _ImpactStatusChip(
                    label: context.appI18n.tr(
                      'observatory.dependency_closure.edge_chip',
                    ),
                    positive: false,
                  ),
                  _ImpactStatusChip(
                    label: context.appI18n.tr(
                      'observatory.dependency_closure.closure_chip',
                    ),
                    positive: false,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ExpansionTile(
                key: const Key('observatory-dependency-root-details'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: Text(
                  context.appI18n.tr('observatory.dependency_closure.details'),
                ),
                subtitle: Text(
                  context.appI18n.tr(
                    'observatory.dependency_closure.details_subtitle',
                  ),
                  style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
                ),
                children: [
                  Semantics(
                    key: const Key(
                      'observatory-dependency-root-table-semantics',
                    ),
                    container: true,
                    label: context.appI18n.tr(
                      'observatory.dependency_closure.table_semantics',
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        key: const Key('observatory-dependency-root-table'),
                        columns: [
                          DataColumn(
                            label: Text(
                              context.appI18n.tr(
                                'observatory.dependency_closure.column_algorithm',
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              context.appI18n.tr(
                                'observatory.dependency_closure.column_root',
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              context.appI18n.tr(
                                'observatory.dependency_closure.column_sink',
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              context.appI18n.tr(
                                'observatory.dependency_closure.column_uri',
                              ),
                            ),
                          ),
                        ],
                        rows: [
                          for (final entry in resolved.entries)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    entry.algorithmId,
                                    key: Key(
                                      'dependency-root-${entry.algorithmId}',
                                    ),
                                  ),
                                ),
                                DataCell(SelectableText(entry.logicalRootId)),
                                DataCell(SelectableText(entry.resultSinkId)),
                                DataCell(
                                  SelectableText(entry.canonicalPackageUri),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.appI18n.tr(
                      'observatory.dependency_closure.boundary',
                    ),
                    key: const Key('observatory-dependency-closure-boundary'),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Paper.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ScenarioSelector extends StatelessWidget {
  final ObservatoryScenario selected;
  final ValueChanged<ObservatoryScenario> onSelected;

  const _ScenarioSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.appI18n.tr('observatory.scenario.title'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                ObservatoryScenario.mixedReference,
                context.appI18n.tr('observatory.scenario.mixed'),
              ),
              _chip(
                ObservatoryScenario.highFatProtein,
                context.appI18n.tr('observatory.scenario.high_fat_protein'),
              ),
              _chip(
                ObservatoryScenario.incompleteData,
                context.appI18n.tr('observatory.scenario.missing'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(ObservatoryScenario scenario, String label) {
    return ChoiceChip(
      key: Key('observatory-scenario-${scenario.name}'),
      label: Text(label),
      selected: selected == scenario,
      onSelected: (_) => onSelected(scenario),
    );
  }
}

class _SensitivityComparisonPanel extends StatelessWidget {
  static const double _compactBreakpoint = 700;

  final Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots;

  const _SensitivityComparisonPanel({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: const Key('observatory-sensitivity-comparison'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.appI18n.tr('observatory.comparison.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.appI18n.tr('observatory.comparison.body'),
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: context.appI18n.tr('observatory.comparison.semantics'),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < _compactBreakpoint) {
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < ObservatoryScenario.values.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: 8),
                        _SensitivityScenarioCard(
                          snapshot:
                              snapshots[ObservatoryScenario.values[index]]!,
                        ),
                      ],
                    ],
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    key: const Key('observatory-sensitivity-comparison-table'),
                    headingRowHeight: 44,
                    dataRowMinHeight: 42,
                    dataRowMaxHeight: 50,
                    horizontalMargin: 8,
                    columnSpacing: 20,
                    columns: [
                      DataColumn(
                        label: Text(
                          context.appI18n.tr('observatory.comparison.scenario'),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          context.appI18n.tr(
                            'observatory.comparison.completeness',
                          ),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          context.appI18n.tr('observatory.comparison.lag'),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          context.appI18n.tr('observatory.comparison.overlap'),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.appI18n.tr('observatory.comparison.bands'),
                        ),
                      ),
                    ],
                    rows: [
                      for (final scenario in ObservatoryScenario.values)
                        _row(context, snapshots[scenario]!),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, AlgorithmObservatorySnapshot snapshot) {
    final emptying = snapshot.conflict.primaryEmptyingProfile;
    final result = snapshot.conflict;
    return DataRow(
      cells: [
        DataCell(Text(_scenarioLabel(context, snapshot.scenario))),
        DataCell(
          Text(
            '${(snapshot.composition.compositionCompleteness * 100).round()}%',
          ),
        ),
        DataCell(
          Text(
            emptying == null
                ? '—'
                : '${emptying.aggregateLagMinutes.toStringAsFixed(0)} min',
          ),
        ),
        DataCell(Text(_modeledScoreLabel(result))),
        DataCell(Text(_modeledBandsLabel(result))),
      ],
    );
  }
}

class _SensitivityScenarioCard extends StatelessWidget {
  final AlgorithmObservatorySnapshot snapshot;

  const _SensitivityScenarioCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final result = snapshot.conflict;
    final emptying = result.primaryEmptyingProfile;
    final values = <({String field, String label, String value})>[
      (
        field: 'scenario',
        label: context.appI18n.tr('observatory.comparison.scenario'),
        value: _scenarioLabel(context, snapshot.scenario),
      ),
      (
        field: 'completeness',
        label: context.appI18n.tr('observatory.comparison.completeness'),
        value:
            '${(snapshot.composition.compositionCompleteness * 100).round()}%',
      ),
      (
        field: 'lag',
        label: context.appI18n.tr('observatory.comparison.lag'),
        value: emptying == null
            ? '—'
            : '${emptying.aggregateLagMinutes.toStringAsFixed(0)} min',
      ),
      (
        field: 'overlap',
        label: context.appI18n.tr('observatory.comparison.overlap'),
        value: _modeledScoreLabel(result),
      ),
      (
        field: 'bands',
        label: context.appI18n.tr('observatory.comparison.bands'),
        value: _modeledBandsLabel(result),
      ),
    ];
    return Container(
      key: Key('observatory-comparison-card-${snapshot.scenario.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Paper.surfaceSunken,
        borderRadius: BorderRadius.circular(Paper.radiusSm),
        border: Border.all(color: Paper.border, width: Paper.hairline),
      ),
      child: Column(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _SensitivityValueRow(
              key: Key(
                'observatory-comparison-${snapshot.scenario.name}-${values[index].field}',
              ),
              label: values[index].label,
              value: values[index].value,
              emphasized: index == 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _SensitivityValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _SensitivityValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  softWrap: true,
                  style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  softWrap: true,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: emphasized ? 14 : 13,
                    height: 1.25,
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableModelPanel extends StatelessWidget {
  final String id;
  final String title;
  final MechanisticConflictResult result;

  const _UnavailableModelPanel({
    required this.id,
    required this.title,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: Key('model-output-unavailable-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Modeled output: —'),
          const SizedBox(height: 4),
          Text('Status: ${_availabilityLabel(result.availability)}'),
          if (result.uncertaintyReasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${result.uncertaintyReasons.take(3).join(' · ')}',
              style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _GastricEmptyingPanel extends StatelessWidget {
  final AlgorithmObservatorySnapshot snapshot;
  const _GastricEmptyingPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final result = snapshot.conflict;
    if (!result.hasModeledOutput) {
      return _UnavailableModelPanel(
        id: 'gastric-emptying',
        title: context.appI18n.tr('observatory.gastric.title'),
        result: result,
      );
    }
    final profile = result.primaryEmptyingProfile;
    if (profile == null) return const SizedBox.shrink();
    final maxMinute = math.max(
      120,
      math.min(
        480,
        profile.mostlyEmptiedWindow.durationMinutes +
            profile.aggregateLagMinutes.round(),
      ),
    );
    final aggregate = <_ChartPoint>[];
    final arrival = <_ChartPoint>[];
    final rawArrival = <_ChartPoint>[];
    final fasterSensitivity = <_ChartPoint>[];
    final slowerSensitivity = <_ChartPoint>[];
    final sensitivityPercent = (profile.timeScaleSensitivityFraction * 100)
        .toStringAsFixed(0);
    for (var minute = 0; minute <= maxMinute; minute += 10) {
      aggregate.add(
        _ChartPoint(minute.toDouble(), profile.remainingFractionAt(minute)),
      );
      final arrivalRate = profile.intestinalArrivalRateAt(minute);
      rawArrival.add(_ChartPoint(minute.toDouble(), arrivalRate));
      // The shared chart canvas has a 0..1 vertical axis. Preserve raw
      // fraction/min values for the data table while using an explicit ×40
      // visual scale for the orange line.
      arrival.add(
        _ChartPoint(minute.toDouble(), (arrivalRate * 40).clamp(0, 1)),
      );
      final envelope = profile.sensitivityEnvelopeAt(minute);
      fasterSensitivity.add(
        _ChartPoint(minute.toDouble(), envelope.fasterRemaining),
      );
      slowerSensitivity.add(
        _ChartPoint(minute.toDouble(), envelope.slowerRemaining),
      );
    }
    final series = <_ChartSeries>[
      _ChartSeries(
        label: 'Meal remaining',
        color: const Color(0xff3559e0),
        points: aggregate,
      ),
      _ChartSeries(
        label: 'Arrival rate (line scaled ×40)',
        color: const Color(0xffe06b3c),
        points: arrival,
        tablePoints: rawArrival,
        tableValueFormat: _ChartValueFormat.fractionPerMinute,
      ),
      _ChartSeries(
        label: 'Faster sensitivity (−$sensitivityPercent% time scale)',
        color: const Color(0xff3559e0).withValues(alpha: 0.30),
        points: fasterSensitivity,
        strokeWidth: 1.1,
      ),
      _ChartSeries(
        label: 'Slower sensitivity (+$sensitivityPercent% time scale)',
        color: const Color(0xff3559e0).withValues(alpha: 0.30),
        points: slowerSensitivity,
        strokeWidth: 1.1,
      ),
      for (var i = 0; i < profile.componentProfiles.length; i++)
        _ChartSeries(
          label: profile.componentProfiles[i].componentId,
          color: Colors.teal.withValues(
            alpha: 0.35 + 0.45 * (i + 1) / profile.componentProfiles.length,
          ),
          points: [
            for (var minute = 0; minute <= maxMinute; minute += 10)
              _ChartPoint(
                minute.toDouble(),
                profile.componentProfiles[i].remainingFractionAt(minute),
              ),
          ],
          strokeWidth: 1.2,
        ),
    ];
    return _ChartPanel(
      id: 'gastric-emptying',
      title: context.appI18n.tr('observatory.gastric.title'),
      subtitle:
          'Lag + component residence curves → relative intestinal arrival. Uncertainty: ${profile.uncertaintyBand.name}.',
      semanticsLabel:
          'Gastric emptying chart. Meal remaining starts at 100 percent and declines over $maxMinute minutes. The orange arrival-rate line uses a disclosed times-40 display scale; its data table reports raw fraction per minute. Model uncertainty is ${profile.uncertaintyBand.name}.',
      series: series,
      xStart: 0,
      xEnd: maxMinute.toDouble(),
      xLabel: context.appI18n.tr('observatory.minutes_after_meal'),
      longDescription:
          'Peak modeled emptying window: ${_relativeWindow(profile.peakEmptyingWindow, snapshot.context.mealEvents.first.minute)} · central mostly-emptied window: ${_relativeWindow(profile.mostlyEmptiedWindow, snapshot.context.mealEvents.first.minute)}. The orange line is scaled ×40 only on the shared chart; the table reports raw fraction/min. The ±$sensitivityPercent% lines are illustrative one-way sensitivity—not a confidence interval. “Mostly emptied” is a model threshold, not a clinical measurement.',
    );
  }
}

class _GastricStructuralUncertaintyPanel extends StatelessWidget {
  final AlgorithmObservatorySnapshot snapshot;

  const _GastricStructuralUncertaintyPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final report = snapshot.gastricStructuralUncertainty;
    if (report == null) {
      return _UnavailableModelPanel(
        id: 'gastric-structural-uncertainty',
        title: 'Gastric structure sensitivity',
        result: snapshot.conflict,
      );
    }
    final available = report.trajectories
        .where(
          (trajectory) =>
              trajectory.availability ==
              GastricTrajectoryAvailability.available,
        )
        .toList(growable: false);
    final heldCount = report.trajectories.length - available.length;
    final maxMinute = available
        .expand((trajectory) => trajectory.points)
        .map((point) => point.minute)
        .fold<int>(1, math.max);
    final colors = <GastricStructureKind, Color>{
      GastricStructureKind.productionComponentLagExponential: const Color(
        0xff1f4ed8,
      ),
      GastricStructureKind.elashoffPowerExponential: const Color(0xffa344c4),
      GastricStructureKind.siegelModifiedPowerExponential: const Color(
        0xffd45b32,
      ),
      GastricStructureKind.explicitLagExponential: const Color(0xff27806e),
      GastricStructureKind.linearExponentialVolume: const Color(0xff7a6c54),
      GastricStructureKind.doubleWeibullPellet: const Color(0xff9a6a1f),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartPanel(
          id: 'gastric-structural-uncertainty',
          title: 'Gastric structure sensitivity',
          subtitle:
              'One unchanged production curve plus observable-matched, read-only shadow structures.',
          semanticsLabel:
              'Gastric model-form sensitivity chart with ${available.length} comparable normalized retention structures over $maxMinute minutes. Two incompatible observable structures remain held and are not plotted.',
          series: [
            for (final trajectory in available)
              _ChartSeries(
                label: trajectory.structure.name,
                color: colors[trajectory.structure.kind]!,
                points: [
                  for (final point in trajectory.points)
                    _ChartPoint(point.minute.toDouble(), point.value),
                ],
                strokeWidth:
                    trajectory.structure.kind ==
                        GastricStructureKind.productionComponentLagExponential
                    ? 2.8
                    : 1.5,
              ),
          ],
          xStart: 0,
          xEnd: maxMinute.toDouble(),
          xLabel: context.appI18n.tr('observatory.minutes_after_meal'),
          longDescription:
              '${available.length} normalized scintigraphic-retention structures share one time grid. '
              'The linear-exponential MRI volume and double-Weibull pellet structures are held because their measured observables do not match. '
              'Pairwise separation is model-form sensitivity only—not an ensemble, probability, confidence interval, accuracy gain, individual test, plasma concentration, symptom prediction, or clinical validation.',
        ),
        const SizedBox(height: 10),
        PaperCard(
          key: const Key('gastric-structural-uncertainty-contracts'),
          child: Semantics(
            container: true,
            label:
                'Six gastric structure contracts. ${available.length} observable matched and $heldCount held. Production output digest unchanged.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Structure contracts and fit gate',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Every structure declares its formula, observable, modality, units, parameter authority, sources, and supported domain. A better-looking fit cannot cross an observable boundary.',
                  style: TextStyle(color: Paper.inkMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill('${report.trajectories.length} structures'),
                    _pill('${available.length} comparable'),
                    _pill('$heldCount observable-held'),
                    _pill('${report.disagreements.length} pairwise checks'),
                    _pill('production digest unchanged'),
                  ],
                ),
                const SizedBox(height: 8),
                for (final trajectory in report.trajectories)
                  ExpansionTile(
                    key: Key(
                      'gastric-structure-card-${trajectory.structure.kind.name}',
                    ),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    title: Text(
                      trajectory.structure.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_gastricTrajectoryLabel(trajectory.availability)} · '
                      '${trajectory.fitAuthorization.disposition.name}',
                    ),
                    children: [
                      _ContractLine(
                        label: 'Exact formula',
                        value: trajectory.structure.formula,
                      ),
                      _ContractLine(
                        label: 'Observable',
                        value:
                            '${trajectory.structure.observable.name} · ${trajectory.structure.modality.name}',
                      ),
                      _ContractLine(
                        label: 'Units',
                        value:
                            '${trajectory.structure.originalUnit} → ${trajectory.structure.canonicalUnit}',
                      ),
                      _ContractLine(
                        label: 'Parameters',
                        value: trajectory.structure.parameters
                            .map(
                              (parameter) =>
                                  '${parameter.symbol}=${parameter.value.toStringAsPrecision(4)} ${parameter.unit} (${parameter.authority.name})',
                            )
                            .join(' · '),
                      ),
                      _ContractLine(
                        label: 'Fit gate',
                        value: trajectory.fitAuthorization.reasons.join(' · '),
                      ),
                      _ContractLine(
                        label: 'Evidence IDs',
                        value: trajectory.structure.evidenceSourceIds.join(
                          ' · ',
                        ),
                      ),
                      _ContractLine(
                        label: 'Supported domain',
                        value: trajectory.structure.supportedDomain,
                      ),
                      _ContractLine(
                        label: 'Limit',
                        value: trajectory.structure.limitation,
                      ),
                    ],
                  ),
                ExpansionTile(
                  key: const Key('gastric-structure-disagreement-table'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Pairwise model-form disagreement',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Absolute retention differences; no averaging or winner.',
                  ),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Structure pair')),
                          DataColumn(label: Text('Mean |Δ|')),
                          DataColumn(label: Text('Max |Δ|')),
                          DataColumn(label: Text('At minute')),
                        ],
                        rows: [
                          for (final disagreement in report.disagreements)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${_shortStructureId(disagreement.leftStructureId)} ↔ ${_shortStructureId(disagreement.rightStructureId)}',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    disagreement.meanAbsoluteDifference
                                        .toStringAsFixed(3),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    disagreement.maximumAbsoluteDifference
                                        .toStringAsFixed(3),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${disagreement.maximumDifferenceMinute}',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.boundary,
                  key: const Key('gastric-structural-boundary'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Paper.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _gastricTrajectoryLabel(GastricTrajectoryAvailability availability) =>
    switch (availability) {
      GastricTrajectoryAvailability.available => 'observable matched',
      GastricTrajectoryAvailability.observableMismatch => 'observable held',
      GastricTrajectoryAvailability.insufficientEvidence => 'evidence held',
      GastricTrajectoryAvailability.blockedIntegrity => 'integrity blocked',
    };

String _shortStructureId(String id) {
  final parts = id.split('.');
  return parts.length > 2 ? parts[2] : id;
}

class _ContractLine extends StatelessWidget {
  final String label;
  final String value;

  const _ContractLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Paper.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbsorptionCompetitionPanel extends StatelessWidget {
  final AlgorithmObservatorySnapshot snapshot;
  const _AbsorptionCompetitionPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final result = snapshot.conflict;
    if (!result.hasModeledOutput) {
      return _UnavailableModelPanel(
        id: 'absorption-competition',
        title: context.appI18n.tr('observatory.absorption.title'),
        result: result,
      );
    }
    final absorption = result.absorptionOpportunityWindow;
    final competition = result.competitionTimeline;
    if (absorption == null || competition == null) {
      return const SizedBox.shrink();
    }
    final mealMinute = snapshot.context.mealEvents.first.minute;
    final allMinutes = <int>[
      ...absorption.opennessProfile.map((sample) => sample.minute),
      ...competition.samples.map((sample) => sample.minute),
    ];
    final start = allMinutes.reduce(math.min);
    final end = allMinutes.reduce(math.max);
    return _ChartPanel(
      id: 'absorption-competition',
      title: context.appI18n.tr('observatory.absorption.title'),
      subtitle:
          'The overlap area—not either curve alone—feeds the conflict engine.',
      semanticsLabel:
          'Overlay chart of levodopa absorption opportunity and amino acid competition pressure. Modeled overlap is ${(competition.overlapWithAbsorptionWindow * 100).round()} percent and competition band is ${competition.competitionBand.name}.',
      series: [
        _ChartSeries(
          label: 'Absorption opportunity',
          color: const Color(0xff7b3fe4),
          points: absorption.opennessProfile
              .map(
                (sample) => _ChartPoint(
                  (sample.minute - start).toDouble(),
                  sample.openness,
                ),
              )
              .toList(growable: false),
        ),
        _ChartSeries(
          label: 'LNAA pressure',
          color: const Color(0xffd14b65),
          points: competition.samples
              .map(
                (sample) => _ChartPoint(
                  (sample.minute - start).toDouble(),
                  sample.pressure,
                ),
              )
              .toList(growable: false),
        ),
      ],
      xStart: 0,
      xEnd: math.max(1, end - start).toDouble(),
      xLabel: context.appI18n.tr('observatory.minutes_in_window'),
      markers: [
        _ChartMarker(
          x: (snapshot.context.medicationEvents.first.minute - start)
              .toDouble(),
          label: 'dose',
        ),
        _ChartMarker(x: (mealMinute - start).toDouble(), label: 'meal'),
      ],
      longDescription:
          'Overlap ${(competition.overlapWithAbsorptionWindow * 100).toStringAsFixed(1)}% · peak pressure ${(competition.peakPressure * 100).toStringAsFixed(0)}% · ${competition.lnaaSummary?.dataMode.name ?? 'unknown data mode'} · ${absorption.delayedArrivalLikelihood.name} delayed-arrival likelihood. Curves are unitless educational weights.',
    );
  }
}

class _ConflictPanel extends StatelessWidget {
  final AlgorithmObservatorySnapshot snapshot;
  const _ConflictPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final result = snapshot.conflict;
    return PaperCard(
      key: const Key('observatory-conflict-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.appI18n.tr('observatory.conflict.title'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.appI18n.tr('observatory.conflict.body'),
            style: TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 14),
          if (result.hasModeledOutput)
            _MetricBar(
              label: 'Interaction overlap',
              value: result.interactionScore,
              color: const Color(0xffd14b65),
            )
          else
            Text(
              'Interaction overlap: —',
              key: const Key('observatory-conflict-overlap-unavailable'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (result.hasModeledOutput) ...[
                _pill('severity ${result.severityBand.name}'),
                _pill('confidence ${result.confidenceBand.name}'),
                _pill('${result.perEventTraces.length} dose trace(s)'),
              ] else
                _pill('status ${_availabilityLabel(result.availability)}'),
              _pill('${result.sourceRefs.length} source refs'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            !result.hasModeledOutput
                ? 'No modeled drivers. ${result.uncertaintyReasons.take(3).join(' · ')}'
                : result.primaryDrivers.isEmpty
                ? 'No primary driver crossed a modeled band.'
                : 'Drivers: ${result.primaryDrivers.join(' · ')}',
          ),
          const SizedBox(height: 7),
          Text(
            result.limitationText,
            style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _CandidatePanel extends StatelessWidget {
  final List<MechanisticCandidateScore> scores;
  const _CandidatePanel({required this.scores});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: const Key('observatory-candidate-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.appI18n.tr('observatory.candidate.title'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.appI18n.tr('observatory.candidate.body'),
            style: TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 12),
          if (scores.isEmpty)
            const Text(
              'Modeled candidate scores: —',
              key: Key('observatory-candidate-scores-unavailable'),
            ),
          for (final score in scores) ...[
            Text(
              score.candidateName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (!score.hasModeledOutput)
              const Text('Modeled candidate score: —')
            else ...[
              _MetricBar(
                label: 'Final compatibility',
                value: score.modeledFinalCandidateScore!,
                color: const Color(0xff287d6b),
              ),
              _MetricBar(
                label: 'Worst conflict',
                value: score.modeledWorstCaseConflictOverlapScore!,
                color: const Color(0xffd14b65),
              ),
              _MetricBar(
                label: 'Protein redistribution',
                value: score.modeledProteinRedistributionScore!,
                color: const Color(0xffa36b12),
              ),
              _MetricBar(
                label: 'Nutrition adequacy proxy',
                value: score.modeledNutritionAdequacyContribution!,
                color: const Color(0xff3559e0),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              !score.hasModeledOutput
                  ? 'Status: ${_availabilityLabel(score.availability)}'
                  : '${score.modeledSampleCount} points in the user-provided window · best ${(score.modeledBestCaseConflictOverlapScore! * 100).round()}% · average ${(score.modeledAverageConflictOverlapScore! * 100).round()}% · worst ${(score.modeledWorstCaseConflictOverlapScore! * 100).round()}%',
              style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ExplanationTreePanel extends StatelessWidget {
  final AlgorithmTraceNode root;

  const _ExplanationTreePanel({required this.root});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: const Key('observatory-explanation-tree'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.appI18n.tr('observatory.tree.title'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${root.nodeCount} trace nodes show which inputs each model consumed, what it emitted, which evidence it cites, and where interpretation must stop.',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 8),
          _TraceNodeTile(node: root, depth: 0, initiallyExpanded: true),
        ],
      ),
    );
  }
}

class _TraceNodeTile extends StatelessWidget {
  final AlgorithmTraceNode node;
  final int depth;
  final bool initiallyExpanded;

  const _TraceNodeTile({
    required this.node,
    required this.depth,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('trace-node-${node.id}'),
      padding: EdgeInsets.only(top: 6, left: math.min(depth * 10, 30)),
      child: Material(
        color: Colors.white.withValues(alpha: depth == 0 ? 0.38 : 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xff3559e0).withValues(alpha: 0.12),
            child: Text(
              '${depth + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            node.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(node.output, style: const TextStyle(fontSize: 11)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Inputs\n• ${node.inputs.join('\n• ')}',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Evidence: ${node.sourceRefs.isEmpty ? 'no direct source reference' : node.sourceRefs.join(' · ')}',
                style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Boundary: ${node.limitation}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Paper.inkMuted,
                ),
              ),
            ),
            for (final child in node.children)
              _TraceNodeTile(node: child, depth: depth + 1),
          ],
        ),
      ),
    );
  }
}

class _ApplicabilityManifestPanel extends StatelessWidget {
  final MechanisticApplicabilityManifest manifest;

  const _ApplicabilityManifestPanel({required this.manifest});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: const Key('observatory-applicability-manifest'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Model applicability manifest',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${MechanisticApplicabilityManifest.schema} · '
            '${MechanisticApplicabilityManifest.manifestVersion} · '
            '${manifest.sha256Digest.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Semantics(
            label:
                'Trace only. Passing this applicability manifest is not clinical validation.',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfffff3d7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffd7a33b)),
              ),
              child: const Text(
                'TRACE ONLY · Passing every predicate permits an educational '
                'timing-overlap trace. It does not establish patient-specific '
                'accuracy, treatment suitability, or regulatory acceptance.',
                style: TextStyle(fontSize: 12, color: Color(0xff60460d)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Question: ${manifest.questionOfInterest}\n'
            'Context of use: ${manifest.contextOfUse}\n'
            'Observable: ${manifest.observableBoundary}\n'
            'Population: ${manifest.populationBoundary}\n'
            'Product identity: ${manifest.productIdentityBoundary}\n'
            'Fed-state boundary: ${manifest.fedStateBoundary}\n'
            'Terminology: ${manifest.terminologyIdentity}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (final provider in manifest.providers)
            ExpansionTile(
              key: Key('applicability-provider-${provider.providerId}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: Text(provider.providerId),
              subtitle: Text(
                '${provider.claimClass} · ${provider.decisionInfluence}',
                style: const TextStyle(fontSize: 11),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Observable: ${provider.observable}\n'
                    'Required predicates: ${provider.predicateIds.join(' · ')}\n'
                    'Evidence IDs: ${provider.evidenceSourceIds.join(' · ')}\n'
                    'Boundary: ${provider.limitation}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Paper.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          const Divider(height: 18),
          const Text(
            'Fail-closed predicate matrix',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final predicate in manifest.predicates)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${predicate.id}: ${predicate.supportedRule} · '
                'unknown→${predicate.unknownDisposition.name} · '
                'outside→${predicate.outsideDisposition.name} · '
                'integrity→${predicate.integrityDisposition.name}',
                style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _EvidenceCurrencyPanel extends StatelessWidget {
  final EvidenceCurrencyAssessment assessment;

  const _EvidenceCurrencyPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final blocked = assessment.requiresRequalification;
    final currentCount =
        assessment.records.length -
        assessment.heldRecords.length -
        assessment.blockedRecords.length;
    return PaperCard(
      key: const Key('observatory-evidence-currency'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evidence currency and sunset gate',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${EvidenceCurrencyRegistry.schema} · '
            '${EvidenceCurrencyRegistry.registryVersion} · '
            '${assessment.registrySha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: blocked
                ? 'Evidence requalification required.'
                : 'Evidence status reviews are current.',
            child: Container(
              key: const Key('observatory-evidence-currency-status'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: blocked
                    ? const Color(0xffffe6e3)
                    : const Color(0xffe4f4e8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: blocked
                      ? const Color(0xffb84c45)
                      : const Color(0xff3f8050),
                ),
              ),
              child: Text(
                blocked
                    ? 'REQUALIFICATION REQUIRED · '
                          '${assessment.heldRecords.length} held · '
                          '${assessment.blockedRecords.length} blocked'
                    : 'STATUS REVIEW CURRENT · $currentCount reviewed claims',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: blocked
                      ? const Color(0xff712922)
                      : const Color(0xff285b35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'As of: ${assessment.asOfUtc.toIso8601String()}\n'
            'Snapshot: ${assessment.snapshotSha256.substring(0, 12)}…\n'
            'Affected providers: '
            '${assessment.affectedProviderIds.isEmpty ? 'none' : assessment.affectedProviderIds.join(' · ')}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (final record in assessment.records)
            ExpansionTile(
              key: Key('evidence-currency-${record.claimId}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: Text(record.claimId),
              subtitle: Text(
                '${record.effectiveStatusAt(assessment.asOfUtc).name} · '
                '${record.dispositionAt(assessment.asOfUtc).name} · '
                'review by ${record.reviewByUtc}',
                style: const TextStyle(fontSize: 11),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${record.claim}\n'
                    'Source: ${record.sourceId}\n'
                    'Status authority: ${record.statusAuthoritySourceId} · '
                    '${record.statusMethod.name}\n'
                    'Providers: ${record.providerIds.join(' · ')}\n'
                    'Boundary: ${record.applicabilityBoundary}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Paper.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          const Divider(height: 18),
          const Text(
            'A current status review means only that no governed correction, '
            'retraction, withdrawal, expression of concern, supersession, or '
            'expiry was recorded at this snapshot. It does not establish '
            'validity, certainty, causality, clinical effectiveness, '
            'regulatory acceptance, or medical advice.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class EvidenceSynthesisPanel extends StatelessWidget {
  final EvidenceSynthesisAssessment assessment;

  const EvidenceSynthesisPanel({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    final blocked =
        assessment.blockedBodies.isNotEmpty ||
        assessment.integrityReasons.isNotEmpty;
    final held = assessment.heldBodies.isNotEmpty;
    final statusColor = blocked
        ? const Color(0xff712922)
        : held
        ? const Color(0xff76520e)
        : const Color(0xff285b35);
    final statusBackground = blocked
        ? const Color(0xffffe6e3)
        : held
        ? const Color(0xfffff3d7)
        : const Color(0xffe4f4e8);
    return PaperCard(
      key: const Key('observatory-evidence-synthesis'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Claim evidence contradiction and synthesis',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${EvidenceSynthesisRegistry.schema} · '
            '${EvidenceSynthesisRegistry.registryVersion} · '
            '${assessment.registrySha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: blocked
                ? 'Evidence synthesis blocked.'
                : held
                ? 'Evidence synthesis held for independent review.'
                : 'Evidence synthesis allows research trace only.',
            child: Container(
              key: const Key('observatory-evidence-synthesis-status'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.65)),
              ),
              child: Text(
                blocked
                    ? 'SYNTHESIS BLOCKED · '
                          '${assessment.blockedBodies.length} blocked'
                    : held
                    ? 'INDEPENDENT REVIEW HOLD · '
                          '${assessment.heldBodies.length} held'
                    : 'RESEARCH TRACE ONLY · reviewed bodies available',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'As of: ${assessment.asOfUtc.toIso8601String()}\n'
            'Snapshot: ${assessment.snapshotSha256.substring(0, 12)}…\n'
            'Affected providers: '
            '${assessment.affectedProviderIds.isEmpty ? 'none' : assessment.affectedProviderIds.join(' · ')}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (final adjudication in assessment.adjudications)
            ExpansionTile(
              key: Key('evidence-synthesis-${adjudication.body.claimId}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: Text(adjudication.body.claimId),
              subtitle: Text(
                '${adjudication.disposition.name} · '
                '${adjudication.body.reviewState.name} · '
                '${adjudication.body.declaredCertainty.name}',
                style: const TextStyle(fontSize: 11),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${adjudication.body.claim}\n'
                    'Outcome / measure: '
                    '${adjudication.body.expectedOutcomeId} / '
                    '${adjudication.body.expectedMeasureId}\n'
                    'Independent families: '
                    '${adjudication.independentFamilyCount} / '
                    '${adjudication.body.minimumIndependentFamilies}\n'
                    'Dependent finding components: '
                    '${adjudication.dependentFindingComponents.isEmpty ? 'none' : adjudication.dependentFindingComponents.map((members) => members.join(' + ')).join(' · ')}\n'
                    'Dependency links: '
                    '${adjudication.body.dependencies.isEmpty ? 'none' : adjudication.body.dependencies.map((dependency) => '${dependency.canonicalFindingIds.join(' ↔ ')} · ${dependency.relation.name} · ${dependency.reviewState.name} · ${dependency.sourceEvidenceIds.join(', ')}').join('\n')}\n'
                    'Directions: '
                    '${adjudication.directionCounts.entries.where((entry) => entry.value > 0).map((entry) => '${entry.key.name}:${entry.value}').join(' · ')}\n'
                    'Reasons: '
                    '${adjudication.reasons.isEmpty ? 'none' : adjudication.reasons.join(' · ')}\n'
                    'Boundary: ${adjudication.body.applicabilityBoundary}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Paper.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          const Divider(height: 18),
          const Text(
            'Support, null, opposing and adverse findings remain separate. '
            'Citation count never creates certainty, and declared certainty '
            'never establishes clinical validity, causality, treatment effect, '
            'regulatory acceptance, or medical advice.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequalificationLedgerPanel extends StatelessWidget {
  final ContextOfUseRequalificationLedger ledger;

  const _RequalificationLedgerPanel({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final record = ledger.latest;
    final blocked = !ledger.canPromoteResearchTraceOnly;
    final integrityReasons = ledger.integrityReasons;
    final integrityVerified = ledger.integrityVerified;
    final i18n = context.appI18n;
    return PaperCard(
      key: const Key('observatory-cou-requalification-ledger'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.cou.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${ContextOfUseRequalificationLedger.schema} · '
            '${ContextOfUseRequalificationLedger.ledgerVersion} · '
            '${record.recordSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: blocked
                ? i18n.tr('observatory.cou.blocked_semantics')
                : i18n.tr('observatory.cou.approved_semantics'),
            child: Container(
              key: const Key('observatory-cou-requalification-status'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: blocked
                    ? const Color(0xffffe6e3)
                    : const Color(0xffe4f4e8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: blocked
                      ? const Color(0xffb84c45)
                      : const Color(0xff3f8050),
                ),
              ),
              child: Text(
                blocked
                    ? i18n.tr('observatory.cou.blocked', {
                        'disposition': record.releaseDisposition.name,
                      })
                    : i18n.tr('observatory.cou.approved', {
                        'disposition': record.releaseDisposition.name,
                      }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: blocked
                      ? const Color(0xff712922)
                      : const Color(0xff285b35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-cou-integrity-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: integrityVerified
                  ? const Color(0xffe4f4e8)
                  : const Color(0xffffe6e3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: integrityVerified
                    ? const Color(0xff3f8050)
                    : const Color(0xffb84c45),
              ),
            ),
            child: Text(
              integrityVerified
                  ? i18n.tr('observatory.cou.integrity_verified')
                  : i18n.tr('observatory.cou.integrity_failed', {
                      'count': '${integrityReasons.length}',
                      'reasons': integrityReasons.join(' · '),
                    }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: integrityVerified
                    ? const Color(0xff285b35)
                    : const Color(0xff712922),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Manifest: ${record.currentManifestSha256.substring(0, 12)}…\n'
            'Configuration: '
            '${record.currentConfigurationSha256.substring(0, 12)}…\n'
            'Semantic diff: ${record.semanticDiffSha256.substring(0, 12)}…\n'
            'Risk: ${record.modelRisk.name} · '
            '${record.affectedProviderIds.length} providers · '
            '${record.affectedPredicateIds.length} predicates',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final decision in record.evidenceDecisions)
                _EvidenceStatusChip(decision: decision),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ledger.incompleteRequiredEvidence.isEmpty
                ? i18n.tr('observatory.cou.evidence_complete')
                : i18n.tr('observatory.cou.evidence_incomplete', {
                    'evidence': ledger.incompleteRequiredEvidence
                        .map((kind) => kind.name)
                        .join(' · '),
                  }),
            key: const Key('observatory-cou-incomplete-evidence'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xff712922),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            record.decisionBoundary,
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProspectiveCredibilityPanel extends StatelessWidget {
  final ProspectiveModelCredibilityPlan plan;

  const _ProspectiveCredibilityPanel({required this.plan});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final promotionBlocked = !plan.canPromoteResearchTraceOnly;
    return PaperCard(
      key: const Key('observatory-prospective-credibility-plan'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.credibility.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${ProspectiveModelCredibilityPlan.schema} · '
            '${ProspectiveModelCredibilityPlan.planVersion} · '
            '${plan.planSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-prospective-credibility-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xffffe6e3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffb84c45)),
            ),
            child: Text(
              i18n.tr('observatory.credibility.blocked', {
                'prospective': plan.prospectiveDecision.disposition.name,
                'postStudy': plan.postStudyDecision.disposition.name,
              }),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xff712922),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-prospective-credibility-integrity'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: plan.integrityVerified
                  ? const Color(0xffe4f4e8)
                  : const Color(0xffffe6e3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: plan.integrityVerified
                    ? const Color(0xff3f8050)
                    : const Color(0xffb84c45),
              ),
            ),
            child: Text(
              plan.integrityVerified
                  ? i18n.tr('observatory.credibility.integrity_verified')
                  : i18n.tr('observatory.credibility.integrity_failed', {
                      'count': '${plan.integrityReasons.length}',
                    }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: plan.integrityVerified
                    ? const Color(0xff285b35)
                    : const Color(0xff712922),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.credibility.risk', {
              'influence': plan.modelInfluence.name,
              'consequence': plan.decisionConsequence.name,
              'risk': plan.overallModelRisk,
              'incomplete': '${plan.incompleteGoals.length}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final goal in plan.goals) _CredibilityGoalChip(goal: goal),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.credibility.decision_separation', {
              'prospective': plan.prospectiveDecision.disposition.name,
              'postStudy': plan.postStudyDecision.disposition.name,
            }),
            key: const Key('observatory-credibility-decision-separation'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xff712922),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            promotionBlocked ? plan.safetyBoundary : '',
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CredibilityGoalChip extends StatelessWidget {
  final CredibilityGoal goal;

  const _CredibilityGoalChip({required this.goal});

  @override
  Widget build(BuildContext context) {
    final passed = goal.status == CredibilityActivityStatus.executedPassed;
    final color = passed ? const Color(0xff2f7541) : const Color(0xff9a3c35);
    return Semantics(
      label: '${goal.factor.name}: ${goal.status.name}',
      child: Container(
        key: Key('credibility-factor-${goal.factor.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          '${goal.factor.name}: ${goal.status.name}',
          style: TextStyle(fontSize: 10, color: color),
        ),
      ),
    );
  }
}

class _EvidenceExecutionPanel extends StatelessWidget {
  final EvidenceIndependenceAssessment assessment;

  const _EvidenceExecutionPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final attestation = assessment.attestation;
    final blocked = !assessment.canSupportScientificCredibility;
    return PaperCard(
      key: const Key('observatory-evidence-execution-attestation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.execution.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityEvidenceExecutionAttestation.schema} · '
            '${CredibilityEvidenceExecutionAttestation.attestationVersion} · '
            '${attestation.attestationSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-evidence-execution-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  assessment.status ==
                      EvidenceIndependenceStatus.mechanicallyObserved
                  ? const Color(0xfffff4d6)
                  : assessment.status ==
                        EvidenceIndependenceStatus.independentlyReviewed
                  ? const Color(0xffe4f4e8)
                  : const Color(0xffffe6e3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    assessment.status ==
                        EvidenceIndependenceStatus.mechanicallyObserved
                    ? const Color(0xff9b6a13)
                    : assessment.status ==
                          EvidenceIndependenceStatus.independentlyReviewed
                    ? const Color(0xff3f8050)
                    : const Color(0xffb84c45),
              ),
            ),
            child: Text(
              i18n.tr('observatory.execution.status', {
                'status': assessment.status.name,
                'scientific': blocked ? 'blocked' : 'eligible',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    assessment.status ==
                        EvidenceIndependenceStatus.mechanicallyObserved
                    ? const Color(0xff6c4709)
                    : assessment.status ==
                          EvidenceIndependenceStatus.independentlyReviewed
                    ? const Color(0xff285b35)
                    : const Color(0xff712922),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.execution.summary', {
              'records': '${attestation.records.length}',
              'splits': '${EvidenceSplitRole.values.length}',
              'steps': '${attestation.transformations.length}',
              'access': '${attestation.accessEvents.length}',
              'findings': '${assessment.findings.length}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final split in EvidenceSplitRole.values)
                _executionChip(
                  key: Key('evidence-split-${split.name}'),
                  label:
                      '${split.name}: ${attestation.records.where((record) => record.split == split).length}',
                  status: EvidenceIndependenceStatus.declared,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.execution.dimensions'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final dimension in EvidenceIndependenceDimension.values)
                _executionChip(
                  key: Key('evidence-independence-${dimension.name}'),
                  label:
                      '${dimension.name}: ${assessment.dimensionStatuses[dimension]!.name}',
                  status: assessment.dimensionStatuses[dimension]!,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.execution.access_order', {
              'freeze': attestation.planFrozenAtUtc,
              'holdout': attestation.accessEvents
                  .firstWhere(
                    (event) =>
                        event.action == EvidenceAccessAction.lockedHoldoutRead,
                  )
                  .occurredAtUtc,
              'result': attestation.accessEvents
                  .firstWhere(
                    (event) =>
                        event.action == EvidenceAccessAction.resultAccess,
                  )
                  .occurredAtUtc,
            }),
            key: const Key('observatory-evidence-access-order'),
            style: const TextStyle(fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 7),
          Text(
            attestation.boundary,
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _executionChip({
    required Key key,
    required String label,
    required EvidenceIndependenceStatus status,
  }) {
    final color = switch (status) {
      EvidenceIndependenceStatus.independentlyReviewed => const Color(
        0xff2f7541,
      ),
      EvidenceIndependenceStatus.mechanicallyObserved => const Color(
        0xff8b5d0d,
      ),
      EvidenceIndependenceStatus.declared => const Color(0xff3559e0),
      EvidenceIndependenceStatus.unknown => const Color(0xff666666),
      EvidenceIndependenceStatus.violated ||
      EvidenceIndependenceStatus.revoked => const Color(0xff9a3c35),
    };
    return Semantics(
      label: label,
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color)),
      ),
    );
  }
}

class _ProtocolTransparencyPanel extends StatelessWidget {
  final ProtocolTransparencyAssessment assessment;

  const _ProtocolTransparencyPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final ledger = assessment.ledger;
    final observed =
        assessment.status == ProtocolTransparencyStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff8b5d0d)
        : const Color(0xff9a3c35);
    return PaperCard(
      key: const Key('observatory-protocol-transparency-ledger'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.transparency.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityProtocolTransparencyLedger.schema} · '
            '${CredibilityProtocolTransparencyLedger.ledgerVersion} · '
            '${ledger.ledgerSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-protocol-transparency-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.transparency.status', {
                'status': assessment.status.name,
                'accepted': '${assessment.lastAcceptedSequence}',
                'gcp': assessment.canClaimGcpConformance
                    ? 'eligible'
                    : 'blocked',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.transparency.summary', {
              'events': '${ledger.events.length}',
              'outcomes': '${ledger.outcomes.length}',
              'findings': '${assessment.findings.length}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.transparency.timeline'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          for (final event in ledger.events) ...[
            Container(
              key: Key(
                'protocol-timeline-${event.sequence}-${event.type.name}',
              ),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Paper.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Paper.border),
              ),
              child: Text(
                '${event.sequence}. ${event.type.name} · '
                '${event.occurredAtUtc} · ${event.reviewDecision.name} · '
                '${event.assertedProspective ? 'prospective' : 'not prospective'} · '
                '${event.visibleResults.isEmpty ? 'no result visible' : event.visibleResults.map((item) => item.name).join(', ')}',
                style: const TextStyle(fontSize: 10.5, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 3),
          Text(
            i18n.tr('observatory.transparency.outcomes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in ProtocolOutcomeStatus.values)
                Container(
                  key: Key('protocol-outcome-status-${status.name}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff3559e0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xff3559e0).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${status.name}: ${assessment.outcomeStatusCounts[status]}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff2948ba),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ledger.boundary,
            key: const Key('observatory-protocol-transparency-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlindedReplicationPanel extends StatelessWidget {
  final BlindedReplicationAssessment assessment;

  const _BlindedReplicationPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status == BlindedReplicationStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    return PaperCard(
      key: const Key('observatory-blinded-replication'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.replication.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityBlindedReplicationPackage.schema} · '
            '${CredibilityBlindedReplicationPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-blinded-replication-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.replication.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
                'discrepancies': '${assessment.discrepancies.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.replication.summary', {
              'capsule': package.capsule.capsuleSha256.substring(0, 12),
              'responses': '${package.responses.length}',
              'outcomes': '${package.custody.expectedOutcomes.length}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.replication.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('replication-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff236b61).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff236b61).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr('observatory.replication.lane.${entry.key}'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff236b61),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.replication.outcomes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            key: const Key('observatory-replication-outcomes'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in ReplicationOutcomeStatus.values)
                Container(
                  key: Key('replication-outcome-${status.name}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff3559e0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xff3559e0).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${status.name}: ${package.custody.expectedOutcomes.where((item) => item.status == status).length}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff2948ba),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            package.boundary,
            key: const Key('observatory-replication-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticalGovernancePanel extends StatelessWidget {
  final StatisticalGovernanceAssessment assessment;

  const _StatisticalGovernancePanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status == StatisticalGovernanceStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    return PaperCard(
      key: const Key('observatory-statistical-governance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.statistics.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityStatisticalAnalysisPackage.schema} · '
            '${CredibilityStatisticalAnalysisPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-statistical-governance-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.statistics.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.statistics.summary', {
              'estimands': '${package.estimands.length}',
              'endpoints': '${package.endpoints.length}',
              'results': '${package.results.length}',
              'sensitivities': '${package.sensitivityResults.length}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.statistics.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('statistical-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff236b61).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff236b61).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr('observatory.statistics.lane.${entry.key}'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff236b61),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.statistics.outcomes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            key: const Key('observatory-statistical-outcomes'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in StatisticalResultStatus.values)
                Container(
                  key: Key('statistical-outcome-${status.name}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff3559e0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xff3559e0).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${status.name}: ${assessment.outcomeStatusCounts[status]}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff2948ba),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            package.boundary,
            key: const Key('observatory-statistical-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RandomizationInterimPanel extends StatelessWidget {
  final RandomizationInterimGovernanceAssessment assessment;

  const _RandomizationInterimPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status ==
        RandomizationInterimGovernanceStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    return PaperCard(
      key: const Key('observatory-randomization-interim'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.randomization.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityRandomizationInterimPackage.schema} · '
            '${CredibilityRandomizationInterimPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-randomization-interim-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.randomization.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.randomization.summary', {
              'assignments': '${assessment.counts['assignments']}',
              'access': '${assessment.counts['accessEvents']}',
              'planned': '${assessment.counts['plannedLooks']}',
              'completed': '${assessment.counts['completedLooks']}',
              'members': '${assessment.counts['committeeMembers']}',
              'emergency': '${assessment.counts['emergencyUnblinding']}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.randomization.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('randomization-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff236b61).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff236b61).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr(
                            'observatory.randomization.lane.${entry.key}',
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff236b61),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-randomization-concealment-boundary'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff3559e0).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff3559e0).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              i18n.tr('observatory.randomization.concealment', {
                'schedule': package.contract.scheduleCommitmentSha256.substring(
                  0,
                  12,
                ),
                'plan': package.boundaryPlan.planSha256.substring(0, 12),
              }),
              style: const TextStyle(fontSize: 11, color: Color(0xff2948ba)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            package.boundary,
            key: const Key('observatory-randomization-interim-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveDesignSimulationPanel extends StatelessWidget {
  final AdaptiveSimulationGovernanceAssessment assessment;

  const _AdaptiveDesignSimulationPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status ==
        AdaptiveSimulationGovernanceStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    final resultByScenario = {
      for (final result in package.results) result.scenarioId: result,
    };
    final nullUpperBounds = package.scenarios
        .where((scenario) => scenario.nullCompatible)
        .map((scenario) {
          final result = resultByScenario[scenario.scenarioId]!;
          return result.successProbability +
              1.96 * result.monteCarloStandardError;
        });
    final alternativeLowerBounds = package.scenarios
        .where((scenario) => !scenario.nullCompatible)
        .map((scenario) {
          final result = resultByScenario[scenario.scenarioId]!;
          return result.successProbability -
              1.96 * result.monteCarloStandardError;
        });
    final maximumNullUpper = nullUpperBounds.reduce(math.max);
    final minimumAlternativeLower = alternativeLowerBounds.reduce(math.min);
    return PaperCard(
      key: const Key('observatory-adaptive-simulation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.adaptive.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityAdaptiveDesignSimulationPackage.schema} · '
            '${CredibilityAdaptiveDesignSimulationPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-adaptive-simulation-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.adaptive.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.adaptive.summary', {
              'scenarios': '${assessment.counts['scenarios']}',
              'nulls': '${assessment.counts['nullScenarios']}',
              'alternatives': '${assessment.counts['alternativeScenarios']}',
              'repetitions': '${assessment.counts['totalRepetitions']}',
              'oracles': '${assessment.counts['oracleVectors']}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.adaptive.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('adaptive-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff4f46a5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff4f46a5).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr('observatory.adaptive.lane.${entry.key}'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff4f46a5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-adaptive-simulation-precision'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff3559e0).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff3559e0).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              i18n.tr('observatory.adaptive.precision', {
                'mcse': assessment.maximumMonteCarloStandardError
                    .toStringAsFixed(6),
                'nullUpper': maximumNullUpper.toStringAsFixed(5),
                'alternativeLower': minimumAlternativeLower.toStringAsFixed(5),
              }),
              style: const TextStyle(fontSize: 11, color: Color(0xff2948ba)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.adaptive.boundary', {
              'looks': package.contract.informationFractions
                  .map((item) => '${(item * 100).toStringAsFixed(0)}%')
                  .join(' / '),
              'efficacy': package.contract.efficacyZBoundaries
                  .map((item) => item.toStringAsFixed(2))
                  .join(' / '),
              'futility': package.contract.futilityZBoundaries
                  .map((item) => item.toStringAsFixed(2))
                  .join(' / '),
              'boundary': package.boundary,
            }),
            key: const Key('observatory-adaptive-simulation-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceStatusChip extends StatelessWidget {
  final CouEvidenceDecision decision;

  const _EvidenceStatusChip({required this.decision});

  @override
  Widget build(BuildContext context) {
    final complete = decision.status == CouEvidenceStatus.complete;
    final notRequired = decision.status == CouEvidenceStatus.notRequired;
    final color = complete
        ? const Color(0xff2f7541)
        : notRequired
        ? const Color(0xff666666)
        : const Color(0xff9a3c35);
    return Semantics(
      label: '${decision.kind.name}: ${decision.status.name}',
      child: Container(
        key: Key('cou-evidence-${decision.kind.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          '${decision.kind.name}: ${decision.status.name}',
          style: TextStyle(fontSize: 10, color: color),
        ),
      ),
    );
  }
}

class _ConfigurationChangeImpactPanel extends StatelessWidget {
  const _ConfigurationChangeImpactPanel({required this.impact});

  final AlgorithmConfigurationChangeImpactPackage impact;

  @override
  Widget build(BuildContext context) {
    final changedReplayCount = impact.replayDeltas
        .where((delta) => delta.comparison == ImpactReplayComparison.changed)
        .length;
    final affectedAlgorithms =
        impact.changes
            .expand((change) => change.affectedAlgorithmIds)
            .toSet()
            .toList()
          ..sort();
    return PaperCard(
      key: const Key('observatory-configuration-change-impact'),
      child: Semantics(
        container: true,
        label:
            'Configuration change impact matrix. ${impact.changes.length} '
            'semantic changes affect ${affectedAlgorithms.length} algorithms. '
            '${impact.replayDeltas.length} before and after outputs include '
            '$changedReplayCount changed outputs. Promotion remains blocked.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration difference and requalification matrix',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${AlgorithmConfigurationChangeImpactPackage.schema} · '
              '${impact.changes.length} semantic changes · '
              '${affectedAlgorithms.length} affected algorithms · '
              '$changedReplayCount/${impact.replayDeltas.length} replay outputs changed',
              key: const Key('configuration-change-impact-summary'),
              style: const TextStyle(color: Paper.inkMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ImpactStatusChip(
                  key: const Key('configuration-impact-pin-status'),
                  label: 'TWO EXTERNAL DIGEST PINS VERIFIED',
                  positive: true,
                ),
                _ImpactStatusChip(
                  key: const Key('configuration-impact-graph-status'),
                  label: impact.graphComplete
                      ? 'IMPACT GRAPH STRUCTURALLY COMPLETE'
                      : '${impact.integrityReasons.length} GRAPH HOLDS',
                  positive: impact.graphComplete,
                ),
                _ImpactStatusChip(
                  key: const Key('configuration-impact-promotion-status'),
                  label: impact.canCloseImpact
                      ? 'IMPACT MAY CLOSE'
                      : 'PROMOTION BLOCKED',
                  positive: impact.canCloseImpact,
                ),
              ],
            ),
            const SizedBox(height: 9),
            SelectableText(
              'Previous: ${impact.previousConfigurationSha256}\n'
              'Current: ${impact.currentConfigurationSha256}\n'
              'Rollback identity: ${impact.rollbackConfigurationSha256}\n'
              'Semantic diff: ${impact.semanticDiffSha256}\n'
              'Impact package: ${impact.packageSha256}',
              key: const Key('configuration-impact-identities'),
              style: const TextStyle(
                fontSize: 10,
                height: 1.35,
                fontFamily: 'monospace',
                color: Paper.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const Key('configuration-impact-changes'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Field → algorithm semantic differences',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Added, removed and changed values retain their exact before and after state.',
                style: TextStyle(fontSize: 11, color: Paper.inkMuted),
              ),
              children: [
                for (final change in impact.changes)
                  Align(
                    key: Key('configuration-change-${change.path}'),
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${change.kind.name.toUpperCase()} · ${change.aspect.name} · ${change.path}\n'
                        '${change.previousValue} → ${change.currentValue}\n'
                        'Consumers: ${change.affectedAlgorithmIds.isEmpty ? 'UNKNOWN' : change.affectedAlgorithmIds.join(', ')}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Paper.inkMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            ExpansionTile(
              key: const Key('configuration-impact-relationships'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Algorithm → output → replay → UI graph',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${impact.relationships.length} registered algorithms; missing replay consumers remain visible.',
                style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
              ),
              children: [
                for (final relationship in impact.relationships)
                  Align(
                    key: Key(
                      'configuration-impact-relationship-${relationship.algorithmId}',
                    ),
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${relationship.algorithmId} → ${relationship.outputId}\n'
                        '${relationship.replayFixtureIds.isEmpty ? 'Replay: MISSING' : 'Replay: ${relationship.replayFixtureIds.join(', ')}'} → '
                        'UI: ${relationship.uiDescriptorId}\n'
                        '${relationship.sourceBundleOnly ? 'Source-bundle-only fallback' : 'Explicit field + source coverage'}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Paper.inkMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            ExpansionTile(
              key: const Key('configuration-impact-replay-deltas'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Deterministic before / after replay outputs',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Changed, unchanged, adverse, abstained and null states are typed; green is not approval.',
                style: TextStyle(fontSize: 11, color: Paper.inkMuted),
              ),
              children: [
                for (final delta in impact.replayDeltas)
                  Align(
                    key: Key(
                      'configuration-impact-replay-${delta.fixtureId}-${delta.outputId}',
                    ),
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${delta.fixtureId} · ${delta.outputId}\n'
                        '${delta.comparison.name.toUpperCase()} · ${delta.runtimeState.name} · ${delta.toleranceContract}\n'
                        '${delta.previousValue} → ${delta.currentValue}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Paper.inkMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Independent verification obligations',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final obligation in impact.obligations)
                  _ImpactStatusChip(
                    key: Key(
                      'configuration-obligation-${obligation.kind.name}',
                    ),
                    label:
                        '${obligation.kind.name}: ${obligation.disposition.name}',
                    positive: obligation.closesObligation,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              impact.comparisonBoundary,
              key: const Key('configuration-impact-boundary'),
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Paper.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationBaselineRegistryPanel extends StatelessWidget {
  const _ConfigurationBaselineRegistryPanel({required this.result});

  final Future<ConfigurationBaselineTransitionResult> result;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<ConfigurationBaselineTransitionResult>(
    future: result,
    builder: (context, snapshot) {
      final transition = snapshot.data;
      return PaperCard(
        key: const Key('observatory-configuration-baseline-registry'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reviewed configuration baseline registry',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (transition == null)
              const Text(
                'Verifying append-only baseline lineage…',
                key: Key('configuration-baseline-loading'),
                style: TextStyle(color: Paper.inkMuted),
              )
            else ...[
              Text(
                '${ConfigurationBaselineRegistryState.schema} · '
                'revision ${transition.state.revision} · '
                '${transition.state.events.length} retained events · '
                '${transition.accepted ? 'transition accepted' : 'candidate held'}',
                key: const Key('configuration-baseline-summary'),
                style: const TextStyle(color: Paper.inkMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ImpactStatusChip(
                    key: const Key('configuration-baseline-chain-status'),
                    label: transition.state.integrityReasons.isEmpty
                        ? 'APPEND-ONLY CHAIN VERIFIED'
                        : 'CHAIN INVALID',
                    positive: transition.state.integrityReasons.isEmpty,
                  ),
                  _ImpactStatusChip(
                    key: const Key('configuration-baseline-transition-status'),
                    label: transition.accepted
                        ? 'ACTIVE POINTER UPDATED'
                        : 'ACTIVATION BLOCKED',
                    positive: transition.accepted,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SelectableText(
                'Active configuration: ${transition.state.activeConfigurationSha256}\n'
                'Candidate: ${transition.receipt.candidateConfigurationSha256}\n'
                'Expected active: ${transition.receipt.expectedActiveConfigurationSha256}\n'
                'Receipt: ${transition.receipt.receiptSha256}\n'
                'Registry: ${transition.state.registrySha256}',
                key: const Key('configuration-baseline-identities'),
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  fontFamily: 'monospace',
                  color: Paper.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Decision: ${transition.reason}. '
                '${transition.receipt.signatures.length} independent signatures '
                'attached; ${transition.receipt.obligations.length} obligation '
                'lanes retained for ${transition.receipt.environment} / '
                '${transition.receipt.targetPopulationScope}.',
                key: const Key('configuration-baseline-decision'),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Paper.inkMuted,
                ),
              ),
              ExpansionTile(
                key: const Key('configuration-baseline-event-timeline'),
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Candidate → decision → active / rollback lineage',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                children: [
                  for (final event in transition.state.events)
                    Align(
                      key: Key(
                        'configuration-baseline-event-${event.sequence}',
                      ),
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${event.sequence}. ${event.kind.name} · ${event.reason}\n'
                          '${event.activeConfigurationBeforeSha256} → '
                          '${event.activeConfigurationAfterSha256}\n'
                          'Event: ${event.eventSha256}',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Paper.inkMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in transition.receipt.obligations.entries)
                    _ImpactStatusChip(
                      key: Key(
                        'configuration-baseline-obligation-${entry.key}',
                      ),
                      label: '${entry.key}: ${entry.value.name}',
                      positive:
                          entry.value ==
                              ConfigurationBaselineObligationStatus.satisfied ||
                          entry.value ==
                              ConfigurationBaselineObligationStatus
                                  .notApplicable,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'The current prior baseline is a manufactured local fixture. '
                'The candidate remains inactive because evidence obligations '
                'and independent signatures are unresolved. Event-chain '
                'integrity is change-control evidence only—not scientific '
                'validation, regulatory approval, clinical performance, or '
                'medical advice.',
                key: Key('configuration-baseline-boundary'),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Paper.inkMuted,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ImpactStatusChip extends StatelessWidget {
  const _ImpactStatusChip({
    super.key,
    required this.label,
    required this.positive,
  });

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xff2f7541) : const Color(0xff9a3c35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

class _ConfigurationCoveragePanel extends StatelessWidget {
  final AlgorithmConfigurationIdentity configurationIdentity;

  const _ConfigurationCoveragePanel({required this.configurationIdentity});

  @override
  Widget build(BuildContext context) {
    final manifest = configurationIdentity.configurationCoverageManifest;
    final witnessLabel = manifest.completePerFieldCoverageCount == 1
        ? 'witness'
        : 'witnesses';
    final witnessVerb = manifest.completePerFieldCoverageCount == 1
        ? 'carries'
        : 'carry';
    return PaperCard(
      key: const Key('observatory-configuration-coverage'),
      child: Semantics(
        container: true,
        label:
            '${manifest.entries.length} registered algorithms. '
            '${manifest.fieldAndSourceBoundCount} have explicit field records '
            'and ${manifest.sourceBundleOnlyCount} use source-bundle-only fallback. '
            '${manifest.completePerFieldCoverageCount} $witnessVerb a digest-bound, '
            'reviewed witness for a declared configuration scope. This status '
            'does not establish transitive dependency closure or scientific '
            'validation.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Algorithm configuration coverage ledger',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${AlgorithmConfigurationCoverageManifest.schema} · '
              '${manifest.entries.length} registered · '
              '${manifest.fieldAndSourceBoundCount} field + source bound · '
              '${manifest.sourceBundleOnlyCount} source-bundle only · '
              '${manifest.completePerFieldCoverageCount} reviewed declared-scope $witnessLabel · '
              'not scientific validation.',
              key: const Key('observatory-configuration-coverage-summary'),
              style: const TextStyle(color: Paper.inkMuted),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const Key('observatory-configuration-coverage-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: const Text(
                'Registry-to-field ownership',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Source-only fallback is visible and never counted as parameter-level coverage.',
                style: TextStyle(fontSize: 11, color: Paper.inkMuted),
              ),
              children: [
                for (final entry in manifest.entries)
                  Padding(
                    key: Key('configuration-coverage-${entry.algorithmId}'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _entryText(entry),
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Paper.inkMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              AlgorithmConfigurationCoverageManifest.boundary,
              key: const Key('observatory-configuration-coverage-boundary'),
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Paper.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _entryText(AlgorithmConfigurationCoverageEntry entry) {
    final witness = entry.completenessWitness;
    final buffer = StringBuffer()
      ..write('${entry.algorithmName} · ${entry.mode.name} · ')
      ..writeln(
        witness == null
            ? 'NO REVIEWED PER-FIELD WITNESS'
            : 'REVIEWED WITNESS FOR DECLARED CONFIGURATION SCOPE',
      )
      ..writeln(
        '${entry.fieldRecordIds.isEmpty ? 'No explicit field records' : '${entry.fieldRecordIds.length} explicit field records'} · '
        '${entry.sourcePaths.join(' · ')}',
      );
    if (witness != null) {
      buffer
        ..writeln(
          'Witness ${witness.witnessId} · ${witness.sha256Digest} · '
          'reviewed ${witness.reviewedAt}',
        )
        ..writeln('Declared scope · ${witness.completionBoundary}')
        ..writeln('Review evidence · ${witness.reviewEvidenceIds.join(' · ')}')
        ..writeln(
          'Configuration section · ${witness.configurationSectionSha256}',
        )
        ..writeln(
          'Registered source bundle · ${witness.registeredSourceBundleSha256}',
        )
        ..writeln(
          'Owned sources · ${_digestBindings(witness.ownedSourceSha256)}',
        )
        ..writeln('Field records · ${witness.fieldRecordIds.join(' · ')}')
        ..writeln(
          'Affected result sinks · '
          '${_sinkBindings(witness.affectedResultSinksByFieldId)}',
        )
        ..writeln(
          'Required result sinks · ${witness.requiredResultSinks.join(' · ')}',
        )
        ..writeln(
          'Dependency contracts · '
          '${_digestBindings(witness.dependencyContractSha256)}',
        )
        ..writeln('Witness limitation · ${witness.limitation}');
    }
    buffer.write('Coverage limitation · ${entry.limitation}');
    return buffer.toString();
  }

  String _digestBindings(Map<String, String> values) =>
      values.entries.map((entry) => '${entry.key}=${entry.value}').join(' · ');

  String _sinkBindings(Map<String, List<String>> values) => values.entries
      .map((entry) => '${entry.key}=[${entry.value.join(',')}]')
      .join(' · ');
}

class _ParameterEvidencePanel extends StatelessWidget {
  final AlgorithmConfigurationIdentity configurationIdentity;

  const _ParameterEvidencePanel({required this.configurationIdentity});

  @override
  Widget build(BuildContext context) {
    final records = configurationIdentity.parameterProvenanceManifest.records;
    final heuristicCount = records
        .where(
          (record) =>
              record.provenanceStatus ==
              AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        )
        .length;
    final fittedCount = records
        .where(
          (record) =>
              record.provenanceStatus ==
              AlgorithmParameterProvenanceStatus.fitted,
        )
        .length;
    return PaperCard(
      key: const Key('observatory-parameter-evidence'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.appI18n.tr('observatory.parameters.title'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${AlgorithmParameterProvenanceManifest.schema} · '
            '${records.length} result-affecting parameter/structure records · '
            '$heuristicCount prototype-heuristic · $fittedCount fitted. '
            'Configuration ${configurationIdentity.sha256Digest.substring(0, 12)}… proves replay identity only, not biological or clinical validity.',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 8),
          for (final record in records) _ParameterEvidenceRow(record: record),
        ],
      ),
    );
  }
}

class _ParameterEvidenceRow extends StatelessWidget {
  final AlgorithmParameterProvenanceRecord record;

  const _ParameterEvidenceRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final isHeuristic =
        record.provenanceStatus ==
        AlgorithmParameterProvenanceStatus.prototypeHeuristic;
    final valueLabel = _parameterValueLabel(record);
    final provenanceLabel = switch (record.provenanceStatus) {
      AlgorithmParameterProvenanceStatus.prototypeHeuristic =>
        'prototype-heuristic',
      AlgorithmParameterProvenanceStatus.literatureDerived =>
        'literature-derived',
      AlgorithmParameterProvenanceStatus.measured => 'measured',
      AlgorithmParameterProvenanceStatus.fitted => 'fitted',
    };
    return Semantics(
      container: true,
      label:
          '${record.displayName}. $valueLabel. $provenanceLabel. '
          'Not clinical. Formula ${record.formulaId}.',
      child: ExpansionTile(
        key: Key('parameter-${record.parameterId}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: Text(record.displayName, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '$valueLabel · $provenanceLabel · not clinical · '
          '${record.formulaId}',
          style: TextStyle(
            fontSize: 11,
            color: isHeuristic ? const Color(0xff704500) : Paper.inkMuted,
          ),
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'Semantic ID: ${record.semanticId}\n'
              'Consumed by: ${record.algorithmIds.join(' · ')}\n'
              'Units: ${record.originalUnit} → ${record.canonicalUnit} via ${record.transformId}\n'
              'Supported engineering domain: ${_parameterSupportLabel(record.supportedDomain)}\n'
              'Sources: ${record.sourceIds.join(' · ')}\n'
              'Reviewed: ${record.reviewDate}\n'
              'Boundary: ${record.limitation}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Paper.inkMuted,
              ),
            ),
          ),
          if (record.canonicalValue is Map || record.canonicalValue is List)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'Canonical structure (read-only):\n'
                  '${const JsonEncoder.withIndent('  ').convert(record.canonicalValue)}',
                  key: Key('parameter-structure-${record.parameterId}'),
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Paper.inkMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BayesianBorrowingCalibrationPanel extends StatelessWidget {
  final BayesianGovernanceAssessment assessment;

  const _BayesianBorrowingCalibrationPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status == BayesianGovernanceStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    final resultByScenario = {
      for (final result in package.results) result.scenarioId: result,
    };
    BayesianOperatingCharacteristicsResult familyResult(
      BayesianBorrowingScenarioFamily family,
    ) {
      final scenario = package.scenarios.firstWhere(
        (item) => item.family == family,
      );
      return resultByScenario[scenario.scenarioId]!;
    }

    final noConflict = familyResult(BayesianBorrowingScenarioFamily.noConflict);
    final mildConflict = familyResult(
      BayesianBorrowingScenarioFamily.mildConflict,
    );
    final severeConflict = familyResult(
      BayesianBorrowingScenarioFamily.severeConflict,
    );
    final nullMaximum = package.scenarios
        .where((scenario) => scenario.nullCompatible)
        .map((scenario) => resultByScenario[scenario.scenarioId]!)
        .map((result) => result.decisionProbability)
        .reduce(math.max);
    final alternativeMinimum = package.scenarios
        .where((scenario) => !scenario.nullCompatible)
        .map((scenario) => resultByScenario[scenario.scenarioId]!)
        .map((result) => result.decisionProbability)
        .reduce(math.min);
    return PaperCard(
      key: const Key('observatory-bayesian-borrowing'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.bayesian.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityBayesianBorrowingCalibrationPackage.schema} · '
            '${CredibilityBayesianBorrowingCalibrationPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-bayesian-borrowing-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.bayesian.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.bayesian.summary', {
              'external': '${assessment.counts['externalEvidence']}',
              'scenarios': '${assessment.counts['scenarios']}',
              'nulls': '${assessment.counts['nullScenarios']}',
              'repetitions': '${assessment.counts['totalRepetitions']}',
              'oracles': '${assessment.counts['oracleVectors']}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.bayesian.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('bayesian-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff7b3fa1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff7b3fa1).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr('observatory.bayesian.lane.${entry.key}'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff7b3fa1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-bayesian-borrowing-conflict'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff7b3fa1).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff7b3fa1).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              i18n.tr('observatory.bayesian.conflict', {
                'none': noConflict.meanBorrowingWeight.toStringAsFixed(3),
                'mild': mildConflict.meanBorrowingWeight.toStringAsFixed(3),
                'severe': severeConflict.meanBorrowingWeight.toStringAsFixed(3),
                'ess': assessment.maximumBorrowedEffectiveSampleSize
                    .toStringAsFixed(2),
              }),
              style: const TextStyle(fontSize: 11, color: Color(0xff5e2b7e)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('observatory-bayesian-borrowing-calibration'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff3559e0).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff3559e0).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              i18n.tr('observatory.bayesian.calibration', {
                'nullMax': nullMaximum.toStringAsFixed(4),
                'alternativeMin': alternativeMinimum.toStringAsFixed(4),
                'mcse': assessment.maximumMonteCarloStandardError
                    .toStringAsFixed(6),
                'posterior': package.contract.posteriorSuccessProbability
                    .toStringAsFixed(3),
              }),
              style: const TextStyle(fontSize: 11, color: Color(0xff2948ba)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            i18n.tr('observatory.bayesian.draft'),
            key: const Key('observatory-bayesian-draft-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xff9a3c35),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            package.boundary,
            key: const Key('observatory-bayesian-borrowing-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BayesianMultisourceModelCriticismPanel extends StatelessWidget {
  final MultisourceGovernanceAssessment assessment;

  const _BayesianMultisourceModelCriticismPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status == MultisourceGovernanceStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    final resultByScenario = {
      for (final result in package.operatingResults) result.scenarioId: result,
    };
    final maximumNullDecision = package.scenarios
        .where((scenario) => scenario.nullCompatible)
        .map((scenario) => resultByScenario[scenario.scenarioId]!)
        .map((result) => result.decisionProbability)
        .reduce(math.max);
    final minimumAlternativeDecision = package.scenarios
        .where((scenario) => !scenario.nullCompatible)
        .map((scenario) => resultByScenario[scenario.scenarioId]!)
        .map((result) => result.decisionProbability)
        .reduce(math.min);
    final criticismByKind =
        <MultisourceCriticismKind, List<MultisourceCriticismResult>>{};
    for (final result in package.criticismResults) {
      criticismByKind.putIfAbsent(result.kind, () => []).add(result);
    }
    double valueFor(MultisourceCriticismKind kind) =>
        criticismByKind[kind]!.first.observedValue;

    return PaperCard(
      key: const Key('observatory-bayesian-multisource'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.multisource.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityBayesianMultisourceModelCriticismPackage.schema} · '
            '${CredibilityBayesianMultisourceModelCriticismPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-bayesian-multisource-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.multisource.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.multisource.summary', {
              'sources': '${assessment.counts['sources']}',
              'included': '${assessment.counts['includedSources']}',
              'groups': '${assessment.counts['dependencyGroups']}',
              'checks': '${assessment.counts['criticismChecks']}',
              'scenarios': '${assessment.counts['scenarios']}',
              'repetitions': '${assessment.counts['totalRepetitions']}',
              'independent': '${assessment.counts['independentCases']}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.multisource.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('multisource-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff0f766e).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff0f766e).withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr('observatory.multisource.lane.${entry.key}'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff0f766e),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-bayesian-multisource-ledger'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff6842a5).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff6842a5).withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.tr('observatory.multisource.ledger'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final source in package.sourceLedger)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${source.sourceId} · ${source.disposition.name} · '
                      '${source.exchangeability.name} · '
                      'overlap ${source.overlapScore.toStringAsFixed(2)} · '
                      'bias ${source.biasRiskScore.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: source.included
                            ? const Color(0xff4f2f82)
                            : Paper.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('observatory-bayesian-multisource-criticism'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff3559e0).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff3559e0).withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              i18n.tr('observatory.multisource.criticism', {
                'prior': valueFor(
                  MultisourceCriticismKind.priorPredictive,
                ).toStringAsFixed(4),
                'sbc': valueFor(
                  MultisourceCriticismKind.simulationBasedCalibration,
                ).toStringAsFixed(4),
                'posterior': valueFor(
                  MultisourceCriticismKind.posteriorPredictive,
                ).toStringAsFixed(4),
                'negative': valueFor(
                  MultisourceCriticismKind.negativeControl,
                ).toStringAsFixed(4),
                'ess': assessment.totalBorrowedEffectiveSampleSize
                    .toStringAsFixed(2),
              }),
              style: const TextStyle(fontSize: 11, color: Color(0xff2948ba)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('observatory-bayesian-multisource-operating'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff9a6a1f).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff9a6a1f).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              i18n.tr('observatory.multisource.operating', {
                'nullMax': maximumNullDecision.toStringAsFixed(4),
                'alternativeMin': minimumAlternativeDecision.toStringAsFixed(4),
                'mcse': assessment.maximumMonteCarloStandardError
                    .toStringAsFixed(6),
                'posterior': package.posteriorControlMean.toStringAsFixed(4),
              }),
              style: const TextStyle(fontSize: 11, color: Color(0xff7b5317)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            i18n.tr('observatory.multisource.independent', {
              'language': package.independentReplication.language,
              'cases': '${assessment.counts['independentCases']}',
              'digest': package.independentReplication.scriptSha256.substring(
                0,
                12,
              ),
            }),
            key: const Key('observatory-bayesian-multisource-independent'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xff236b61),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            package.boundary,
            key: const Key('observatory-bayesian-multisource-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetPopulationTransportabilityPanel extends StatelessWidget {
  final TargetTransportabilityAssessment assessment;

  const _TargetPopulationTransportabilityPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status == TargetTransportabilityStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    final referenceEstimates = package.estimatorEstimates.where(
      (estimate) => estimate.caseId == 'both_models_correct',
    );
    final augmentedOperating = package.operatingResults.where(
      (result) =>
          result.estimator == TransportEstimatorKind.augmentedInverseOdds,
    );

    return PaperCard(
      key: const Key('observatory-target-transportability'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.transport.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityTargetPopulationTransportabilityPackage.schema} · '
            '${CredibilityTargetPopulationTransportabilityPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-target-transportability-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.transport.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.transport.summary', {
              'trial': '${assessment.counts['trialRecords']}',
              'target': '${assessment.counts['targetRecords']}',
              'assumptions': '${assessment.counts['assumptions']}',
              'cases': '${assessment.counts['manufacturedCases']}',
              'scenarios': '${assessment.counts['scenarios']}',
              'repetitions': '${assessment.counts['totalRepetitions']}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.transport.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('transport-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff0f766e).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff0f766e).withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr('observatory.transport.lane.${entry.key}'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff0f766e),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key(
              'observatory-target-transportability-identification',
            ),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff6842a5).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff6842a5).withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.tr('observatory.transport.identification', {
                    'contrast': package.contract.causalContrast,
                    'target': package.contract.targetPopulationId,
                  }),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff4f2f82),
                  ),
                ),
                const SizedBox(height: 5),
                for (final edge in package.contract.graphEdges)
                  Text(
                    '${edge.from} → ${edge.to} · ${edge.rationale}',
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('observatory-target-transportability-overlap'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff3559e0).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff3559e0).withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              i18n.tr('observatory.transport.overlap', {
                'minScore': package.overlapDiagnostic.minimumSamplingScore
                    .toStringAsFixed(3),
                'maxScore': package.overlapDiagnostic.maximumSamplingScore
                    .toStringAsFixed(3),
                'maxWeight': package.overlapDiagnostic.maximumInverseOddsWeight
                    .toStringAsFixed(2),
                'ess': package.overlapDiagnostic.effectiveTargetSampleSize
                    .toStringAsFixed(1),
                'before': package.overlapDiagnostic.maximumSmdBeforeWeighting
                    .toStringAsFixed(3),
                'after': package.overlapDiagnostic.maximumSmdAfterWeighting
                    .toStringAsExponential(1),
                'violations':
                    '${package.overlapDiagnostic.supportViolationStrata.length}',
              }),
              style: const TextStyle(fontSize: 11, color: Color(0xff2948ba)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('observatory-target-transportability-estimators'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff236b61).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff236b61).withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.tr('observatory.transport.estimators'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff236b61),
                  ),
                ),
                const SizedBox(height: 5),
                for (final estimate in referenceEstimates)
                  Text(
                    '${estimate.estimator.name} · '
                    '${estimate.estimate.toStringAsFixed(3)} · '
                    '95% ${estimate.lower95.toStringAsFixed(3)}–'
                    '${estimate.upper95.toStringAsFixed(3)}',
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('observatory-target-transportability-sensitivity'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff9a6a1f).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff9a6a1f).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              i18n.tr('observatory.transport.sensitivity', {
                'values': package.truncationSensitivity
                    .map(
                      (item) =>
                          '${item.truncationCap?.toStringAsFixed(1) ?? 'none'}:'
                          '${item.estimate.toStringAsFixed(3)}/'
                          '${item.effectiveSampleSize.toStringAsFixed(0)}',
                    )
                    .join(' · '),
              }),
              style: const TextStyle(fontSize: 10, color: Color(0xff7b5317)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('observatory-target-transportability-operating'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff8b3a62).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff8b3a62).withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.tr('observatory.transport.operating'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff8b3a62),
                  ),
                ),
                const SizedBox(height: 5),
                for (final result in augmentedOperating)
                  Text(
                    result.status ==
                            TransportOperatingStatus.heldNonidentifiable
                        ? '${result.scenarioId} · HELD · ${result.disposition}'
                        : '${result.scenarioId} · '
                              'bias ${result.bias!.toStringAsFixed(3)} · '
                              'coverage ${result.coverage95!.toStringAsFixed(3)} · '
                              'MCSE ${result.monteCarloStandardError!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            i18n.tr('observatory.transport.independent', {
              'language': package.independentReplication.language,
              'cases': '${assessment.counts['independentCases']}',
              'digest': package.independentReplication.scriptSha256.substring(
                0,
                12,
              ),
            }),
            key: const Key('observatory-target-transportability-independent'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xff236b61),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            package.boundary,
            key: const Key('observatory-target-transportability-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportabilitySensitivityPanel extends StatelessWidget {
  final TransportSensitivityAssessment assessment;

  const _TransportabilitySensitivityPanel({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final package = assessment.package;
    final observed =
        assessment.status == TransportSensitivityStatus.mechanicallyObserved;
    final statusColor = observed
        ? const Color(0xff236b61)
        : const Color(0xff9a3c35);
    final region = package.partialIdentification;
    return PaperCard(
      key: const Key('observatory-transport-sensitivity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('observatory.transportSensitivity.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${CredibilityTransportabilitySensitivityPackage.schema} · '
            '${CredibilityTransportabilitySensitivityPackage.packageVersion} · '
            '${package.packageSha256.substring(0, 12)}…',
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-transport-sensitivity-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.65)),
            ),
            child: Text(
              i18n.tr('observatory.transportSensitivity.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.transportSensitivity.summary', {
              'axes': '${assessment.counts['axes']}',
              'grid': '${assessment.counts['gridPoints']}',
              'admissible': '${assessment.counts['admissiblePoints']}',
              'excluded': '${assessment.counts['excludedPoints']}',
              'scenarios': '${assessment.counts['scenarios']}',
              'repetitions': '${assessment.counts['totalRepetitions']}',
            }),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('observatory.transportSensitivity.lanes'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in assessment.lanes.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value}',
                  child: Container(
                    key: Key('sensitivity-lane-${entry.key}'),
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff8b3a62).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff8b3a62).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.tr(
                            'observatory.transportSensitivity.lane.${entry.key}',
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff8b3a62),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-assumptions'),
            title: i18n.tr('observatory.transportSensitivity.assumptions'),
            color: const Color(0xff6842a5),
            children: [
              Text(package.contract.targetEstimand),
              Text(package.contract.biasFunctionDefinition),
              Text(package.contract.deltaDefinition),
              Text(package.contract.adjustmentFormula),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-elicitation'),
            title: i18n.tr('observatory.transportSensitivity.elicitation'),
            color: const Color(0xff3559e0),
            children: [
              for (final record in package.contract.elicitationRecords)
                Text(
                  '${record.role} · ${record.axisIds.join(', ')} · '
                  '${record.observedAtUtc} · ${record.disposition}',
                ),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-parameter-space'),
            title: i18n.tr('observatory.transportSensitivity.parameterSpace'),
            color: const Color(0xff9a6a1f),
            children: [
              for (final axis in package.contract.axes)
                Text(
                  '${axis.label} · ${axis.minimum.toStringAsFixed(3)}–'
                  '${axis.maximum.toStringAsFixed(3)} · '
                  '${axis.values.length} values · ${axis.units}',
                ),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-local'),
            title: i18n.tr('observatory.transportSensitivity.local'),
            color: const Color(0xff236b61),
            children: [
              for (final item in package.localCases)
                _SensitivityMetricBar(
                  label: item.caseId,
                  valueLabel: item.adjustedEffect.toStringAsFixed(5),
                  fraction: (item.adjustedEffect.abs() / 0.40).clamp(0, 1),
                  color: item.adjustedEffect <= package.contract.nullThreshold
                      ? const Color(0xffb3261e)
                      : item.adjustedEffect <=
                            package.contract.decisionThreshold
                      ? const Color(0xff9a6a1f)
                      : const Color(0xff236b61),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-global'),
            title: i18n.tr('observatory.transportSensitivity.global'),
            color: const Color(0xff0f766e),
            children: [
              for (final item in package.globalIndices) ...[
                _SensitivityMetricBar(
                  label: '${item.axisId} · first order',
                  valueLabel: item.firstOrderIndex.toStringAsFixed(4),
                  fraction: item.firstOrderIndex,
                  color: const Color(0xff0f766e),
                ),
                _SensitivityMetricBar(
                  label: '${item.axisId} · total effect',
                  valueLabel: item.totalEffectIndex.toStringAsFixed(4),
                  fraction: item.totalEffectIndex,
                  color: const Color(0xff3559e0),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-bounds'),
            title: i18n.tr('observatory.transportSensitivity.bounds'),
            color: const Color(0xff8b3a62),
            children: [
              _EffectRangeBar(
                lower: region.lowerEffect,
                upper: region.upperEffect,
                decisionThreshold: package.contract.decisionThreshold,
                nullThreshold: package.contract.nullThreshold,
              ),
              Text(
                '${region.lowerEffect.toStringAsFixed(4)} – '
                '${region.upperEffect.toStringAsFixed(4)} · 95% envelope '
                '${region.lowerConfidenceEnvelope.toStringAsFixed(4)} – '
                '${region.upperConfidenceEnvelope.toStringAsFixed(4)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-tipping'),
            title: i18n.tr('observatory.transportSensitivity.tipping'),
            color: const Color(0xff9a3c35),
            children: [
              _SensitivityMetricBar(
                label: 'decision tipping',
                valueLabel:
                    '${region.decisionTippingPoints}/${region.admissiblePoints}',
                fraction: region.decisionTippingFraction,
                color: const Color(0xff9a6a1f),
              ),
              _SensitivityMetricBar(
                label: 'null crossing',
                valueLabel:
                    '${region.nullCrossingPoints}/${region.admissiblePoints}',
                fraction: region.nullCrossingFraction,
                color: const Color(0xffb3261e),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-operating'),
            title: i18n.tr('observatory.transportSensitivity.operating'),
            color: const Color(0xff4f2f82),
            children: [
              for (final result in package.operatingResults)
                Text(
                  result.status == SensitivityOperatingStatus.estimated
                      ? '${result.scenarioId} · bias '
                            '${result.bias!.toStringAsFixed(4)} · coverage '
                            '${result.coverage95!.toStringAsFixed(3)} · MCSE '
                            '${result.monteCarloStandardError!.toStringAsFixed(5)}'
                      : '${result.scenarioId} · ${result.status.name} · '
                            '${result.disposition}',
                ),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySection(
            key: const Key('observatory-transport-sensitivity-independent'),
            title: i18n.tr('observatory.transportSensitivity.independent'),
            color: const Color(0xff236b61),
            children: [
              Text(
                '${package.independentReplication.language} · '
                '${assessment.counts['independentCases']} cases · '
                '${package.independentReplication.scriptSha256.substring(0, 12)}… · '
                '${package.independentReplication.dependencyLock}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            package.boundary,
            key: const Key('observatory-transport-sensitivity-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensitivitySection extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;

  const _SensitivitySection({
    super.key,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(fontSize: 10, color: Paper.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    ),
  );
}

class _SensitivityMetricBar extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double fraction;
  final Color color;

  const _SensitivityMetricBar({
    required this.label,
    required this.valueLabel,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $valueLabel',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(valueLabel, style: const TextStyle(fontFeatures: [])),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: fraction.clamp(0, 1),
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    ),
  );
}

class _EffectRangeBar extends StatelessWidget {
  final double lower;
  final double upper;
  final double decisionThreshold;
  final double nullThreshold;

  const _EffectRangeBar({
    required this.lower,
    required this.upper,
    required this.decisionThreshold,
    required this.nullThreshold,
  });

  @override
  Widget build(BuildContext context) {
    const scaleLower = -0.05;
    const scaleUpper = 0.40;
    const span = scaleUpper - scaleLower;
    double position(double value) => ((value - scaleLower) / span).clamp(0, 1);
    return Semantics(
      label:
          'Partial identification range $lower to $upper, null $nullThreshold, decision $decisionThreshold',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final left = width * position(lower);
          final right = width * position(upper);
          return SizedBox(
            height: 28,
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xff8b3a62).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: left,
                  width: math.max(2, right - left),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xff8b3a62),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                for (final marker in [nullThreshold, decisionThreshold])
                  Positioned(
                    top: 4,
                    left: math.max(0, width * position(marker) - 1),
                    child: Container(
                      width: 2,
                      height: 20,
                      color: marker == nullThreshold
                          ? const Color(0xffb3261e)
                          : const Color(0xff9a6a1f),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DoseExpressionGrammarPanel extends StatelessWidget {
  const _DoseExpressionGrammarPanel();

  static const _examples = <String>[
    '100 mg',
    '25 mg / 100 mg',
    '100 mg then 50',
    '1,5 mg',
  ];

  @override
  Widget build(BuildContext context) {
    final parser = DosageNoteParser();
    return PaperCard(
      key: const Key('observatory-dose-expression-grammar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_snippet_outlined, color: Color(0xff287d6b)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Input contract · Versioned dose-expression grammar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'The same production parser used by medication logging is replayed '
            'below. Exactly one positive decimal and one reviewed local unit can '
            'become a typed administration quantity; ambiguous text is preserved '
            'but held from result algorithms.',
          ),
          const SizedBox(height: 8),
          SelectableText(
            '${DosageNoteParser.grammarId}/v${DosageNoteParser.grammarVersion}\n'
            'SHA-256 ${DosageNoteParser.grammarDigest}\n'
            '${DosageNoteParser.localUnitSystem}/v${DosageNoteParser.localUnitVersion}',
            key: const Key('observatory-dose-expression-identity'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < _examples.length; index++) ...[
            Text(
              'Synthetic replay: ${_examples[index]}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            DoseExpressionStatusCard(
              key: Key('observatory-dose-expression-example-$index'),
              rawText: _examples[index],
              parser: parser,
            ),
            if (index != _examples.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          const Text(
            'Boundary: this visual verifies parser behavior on synthetic text. '
            'It does not validate a prescription, medication identity, dose '
            'appropriateness, administration, or clinical outcome.',
            key: Key('observatory-dose-expression-boundary'),
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DoseConfirmationReconciliationPanel extends StatelessWidget {
  const _DoseConfirmationReconciliationPanel();

  @override
  Widget build(BuildContext context) {
    final coordinator = AdministrationDoseConfirmationCoordinator();
    final base = Intake(
      id: 'observatory_dose_receipt',
      drugId: 'synthetic_levodopa',
      takenAt: DateTime.utc(2026, 8, 27, 12),
      dosageNote: '100 mg',
    );
    final confirmed = coordinator
        .prepare(
          draft: base,
          current: null,
          expectedRecordRevisionDigest:
              administrationDoseConfirmationAbsentRevisionDigest,
          ownerScope: 'synthetic_observatory_account',
          operationId: 'event_op_observatory_dose_receipt',
          confirmationRequested: true,
          assertionSource: AdministrationDoseAssertionSource.typed,
          confirmationAction: 'observatory.synthetic_confirmation',
          uiContractVersion: 'observatory-dose-confirmation:1',
          confirmedAt: DateTime.utc(2026, 8, 27, 12, 1),
        )
        .intake!;
    final scenarios = <({String label, AdministrationDoseEvaluation result})>[
      (
        label: 'Exact receipt and record',
        result: coordinator.evaluate(
          confirmed,
          ownerScope: 'synthetic_observatory_account',
        ),
      ),
      (
        label: 'Raw expression changed',
        result: coordinator.evaluate(
          confirmed.copyWith(dosageNote: '50 mg'),
          ownerScope: 'synthetic_observatory_account',
        ),
      ),
      (
        label: 'Account scope changed',
        result: coordinator.evaluate(
          confirmed,
          ownerScope: 'different_synthetic_account',
        ),
      ),
      (
        label: 'Structured amount changed',
        result: coordinator.evaluate(
          Intake(
            id: confirmed.id,
            drugId: confirmed.drugId,
            takenAt: confirmed.takenAt,
            dosageNote: confirmed.dosageNote,
            doseAmount: 50,
            doseUnit: 'mg',
            doseConfirmation: confirmed.doseConfirmation,
          ),
          ownerScope: 'synthetic_observatory_account',
        ),
      ),
    ];
    final receipt = confirmed.doseConfirmation!;
    return PaperCard(
      key: const Key('observatory-dose-confirmation-reconciliation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xff287d6b)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Input provenance · Dose confirmation reconciliation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'A synthetic user action binds the exact intake revision, account '
            'scope digest, medication, product snapshot, accepted AST, grammar, '
            'structured pair, administration time, and UI contract. Each row is '
            're-evaluated by the production reconciliation coordinator.',
          ),
          const SizedBox(height: 8),
          SelectableText(
            '${receipt.receiptId}\n'
            'expected revision ${receipt.expectedRecordRevisionDigest}\n'
            'record binding ${receipt.recordBindingDigest}',
            key: const Key('observatory-dose-confirmation-identity'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < scenarios.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                key: Key('observatory-dose-confirmation-case-$index'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    scenarios[index].result.confirmed
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    size: 18,
                    color: scenarios[index].result.confirmed
                        ? const Color(0xff287d6b)
                        : const Color(0xff9a6700),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${scenarios[index].label} · '
                      '${scenarios[index].result.status.name} · '
                      '${scenarios[index].result.reasonCode}',
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'Boundary: confirmation proves only a local user assertion and '
            'record-binding check. It is not a prescription, clinician review, '
            'digital signature, proof of ingestion, or clinical validation.',
            key: Key('observatory-dose-confirmation-boundary'),
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MechanisticInvariantGatePanel extends StatelessWidget {
  final MechanisticModelVerificationReport report;
  final int totalAlgorithms;

  const _MechanisticInvariantGatePanel({
    required this.report,
    required this.totalAlgorithms,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = !report.passed;
    final accent = blocked ? const Color(0xffb3261e) : const Color(0xff287d6b);
    final covered = report.coveredAlgorithmIds.length;
    return PaperCard(
      key: const Key('observatory-invariant-gate'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                blocked ? Icons.gpp_bad_outlined : Icons.rule_folder_outlined,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.invariant.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.invariant.body'),
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                context.appI18n.tr('observatory.invariant.summary', {
                  'passed': '${report.passedCheckCount}',
                  'total': '${report.checks.length}',
                }),
              ),
              _pill(
                context.appI18n.tr('observatory.invariant.algorithms_summary', {
                  'covered': '$covered',
                  'total': '$totalAlgorithms',
                }),
              ),
              _pill(
                context.appI18n.tr('observatory.invariant.scenarios', {
                  'count': '${report.scenarioIds.length}',
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.appI18n.tr('observatory.invariant.manifest', {
              'digest': '${report.specificationDigest.substring(0, 12)}…',
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            context.appI18n.tr('observatory.invariant.configuration', {
              'digest': report.configurationDigest.length == 64
                  ? '${report.configurationDigest.substring(0, 12)}…'
                  : report.configurationDigest,
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 7),
          for (final check in report.checks)
            ExpansionTile(
              key: Key('observatory-invariant-check-${check.spec.id}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              leading: Icon(
                check.passed ? Icons.check_circle_outline : Icons.error_outline,
                size: 20,
                color: check.passed ? const Color(0xff287d6b) : accent,
              ),
              title: Text(
                check.spec.observable,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${check.spec.canonicalUnit} · ${check.spec.method}',
                style: const TextStyle(fontSize: 11),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${check.observation}\n'
                    '${context.appI18n.tr('observatory.invariant.tolerance')}: '
                    '${check.spec.tolerance}\n'
                    '${context.appI18n.tr('observatory.invariant.sources')}: '
                    '${check.spec.sourceRefs.join(' · ')}'
                    '${check.failureCodes.isEmpty ? '' : '\n${context.appI18n.tr('observatory.invariant.failures')}: ${check.failureCodes.join(' · ')}'}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Paper.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.invariant.boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutableContractGatePanel extends StatelessWidget {
  final Future<AlgorithmExecutableContractReport> report;
  final Set<String> mathematicalCoverage;
  final int totalAlgorithms;

  const _ExecutableContractGatePanel({
    required this.report,
    required this.mathematicalCoverage,
    required this.totalAlgorithms,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AlgorithmExecutableContractReport>(
      future: report,
      builder: (context, snapshot) {
        final current = snapshot.data;
        final pending = snapshot.connectionState != ConnectionState.done;
        final blocked =
            snapshot.hasError || (current != null && !current.passed);
        final accent = blocked
            ? const Color(0xffb3261e)
            : pending
            ? const Color(0xffa36b12)
            : const Color(0xff287d6b);
        final combined = current == null
            ? mathematicalCoverage
            : <String>{...mathematicalCoverage, ...current.coveredAlgorithmIds};
        return PaperCard(
          key: const Key('observatory-executable-contract-gate'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    blocked
                        ? Icons.gpp_bad_outlined
                        : pending
                        ? Icons.hourglass_top_outlined
                        : Icons.account_tree_outlined,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.appI18n.tr('observatory.executable.title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                context.appI18n.tr('observatory.executable.body'),
                style: const TextStyle(color: Paper.inkMuted),
              ),
              const SizedBox(height: 10),
              if (pending)
                Row(
                  key: const Key('observatory-executable-contract-pending'),
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.appI18n.tr('observatory.executable.pending'),
                      ),
                    ),
                  ],
                )
              else if (snapshot.hasError || current == null)
                Text(
                  context.appI18n.tr('observatory.executable.blocked'),
                  key: const Key('observatory-executable-contract-blocked'),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      context.appI18n.tr('observatory.executable.summary', {
                        'passed': '${current.passedCheckCount}',
                        'total': '${current.checks.length}',
                      }),
                    ),
                    _pill(
                      context.appI18n
                          .tr('observatory.executable.algorithms_summary', {
                            'covered': '${combined.length}',
                            'total': '$totalAlgorithms',
                          }),
                    ),
                    _pill(
                      context.appI18n.tr(
                        'observatory.executable.not_covered_count',
                        {'count': '${totalAlgorithms - combined.length}'},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.appI18n.tr('observatory.executable.manifest', {
                    'digest':
                        '${current.specificationSha256.substring(0, 12)}…',
                  }),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  context.appI18n.tr('observatory.executable.configuration', {
                    'digest':
                        '${current.configurationSha256.substring(0, 12)}…',
                  }),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  context.appI18n.tr('observatory.executable.source_bundle', {
                    'digest': '${current.sourceBundleSha256.substring(0, 12)}…',
                  }),
                  style: const TextStyle(fontSize: 12),
                ),
                if (current.integrityFailureCodes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    current.integrityFailureCodes.join(' · '),
                    key: const Key(
                      'observatory-executable-contract-integrity-failures',
                    ),
                    style: TextStyle(color: accent, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 7),
                for (final check in current.checks)
                  ExpansionTile(
                    key: Key('observatory-executable-check-${check.spec.id}'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 10),
                    leading: Icon(
                      _executableStatusIcon(check.status),
                      size: 20,
                      color: _executableStatusColor(check.status),
                    ),
                    title: Text(
                      check.spec.relation,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${check.spec.algorithmId} · ${check.spec.kind.name} · ${check.status.name}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${context.appI18n.tr('observatory.executable.observation')}: '
                          '${check.observationSha256.length == 64 ? '${check.observationSha256.substring(0, 12)}…' : check.observationSha256}\n'
                          '${context.appI18n.tr('observatory.invariant.sources')}: '
                          '${check.spec.sourceRefs.join(' · ')}'
                          '${check.failureCodes.isEmpty ? '' : '\n${context.appI18n.tr('observatory.executable.failures')}: ${check.failureCodes.join(' · ')}'}',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Paper.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 5),
              Text(
                context.appI18n.tr('observatory.executable.boundary'),
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Paper.inkMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IndependentContractOraclePanel extends StatelessWidget {
  const _IndependentContractOraclePanel({required this.assessment});

  final AlgorithmContractIndependentOracleAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final attestation = assessment.attestation;
    final passed = assessment.passed;
    final accent = passed ? const Color(0xff236b61) : const Color(0xffb3261e);
    return PaperCard(
      key: const Key('observatory-independent-contract-oracle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.hub_outlined : Icons.sync_problem_outlined,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.independent_contract.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.independent_contract.body'),
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-independent-contract-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.65)),
            ),
            child: Text(
              context.appI18n.tr('observatory.independent_contract.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                context.appI18n
                    .tr('observatory.independent_contract.relations', {
                      'passed': '${attestation.relationPassedCount}',
                      'total': '${attestation.relationCount}',
                    }),
              ),
              _pill(
                context.appI18n
                    .tr('observatory.independent_contract.mutations', {
                      'killed': '${attestation.mutationKilledCount}',
                      'total': '${attestation.mutationCount}',
                    }),
              ),
              _pill(
                context.appI18n.tr(
                  'observatory.independent_contract.survivors',
                  {'count': '${attestation.mutationSurvivorCount}'},
                ),
              ),
              _pill(
                context.appI18n
                    .tr('observatory.independent_contract.scheduler', {
                      'passed': '${attestation.schedulerPassedCount}',
                      'total': '${attestation.schedulerCaseCount}',
                    }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.appI18n
                .tr('observatory.independent_contract.invalid_relations', {
                  'rejected': '${attestation.invalidRelationRejectedCount}',
                  'total': '${attestation.invalidRelationFixtureCount}',
                }),
            key: const Key('observatory-independent-contract-false-relations'),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.independent_contract.identities', {
              'registry':
                  '${attestation.relationRegistrySha256.substring(0, 12)}…',
              'oracle':
                  '${attestation.independentOracleSha256.substring(0, 12)}…',
              'report': '${attestation.reportSha256.substring(0, 12)}…',
            }),
            key: const Key('observatory-independent-contract-identities'),
            style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
          ),
          if (assessment.findings.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              assessment.findings.join(' · '),
              key: const Key('observatory-independent-contract-findings'),
              style: TextStyle(color: accent, fontSize: 11),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            AlgorithmContractIndependentOracleAttestation.boundary,
            key: const Key('observatory-independent-contract-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationDomainSamplingPanel extends StatelessWidget {
  const _RelationDomainSamplingPanel({required this.assessment});

  final AlgorithmRelationDomainSamplingAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final attestation = assessment.attestation;
    final passed = assessment.passed;
    final accent = passed ? const Color(0xff9a6700) : const Color(0xffb3261e);
    final falseAlarmPercent = (attestation.falseAlarmRate * 100)
        .toStringAsFixed(1);
    return PaperCard(
      key: const Key('observatory-relation-domain-sampling'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.science_outlined : Icons.sync_problem_outlined,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.relation_sampling.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.relation_sampling.body'),
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-relation-domain-sampling-status'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.65)),
            ),
            child: Text(
              context.appI18n.tr('observatory.relation_sampling.status', {
                'status': assessment.status.name,
                'findings': '${assessment.findings.length}',
              }),
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                context.appI18n.tr('observatory.relation_sampling.cases', {
                  'count': '${attestation.caseCount}',
                  'relations': '${attestation.relationPassedCount}',
                }),
              ),
              _pill(
                context.appI18n.tr('observatory.relation_sampling.holds', {
                  'count': '${attestation.preconditionHoldCount}',
                }),
              ),
              _pill(
                context.appI18n
                    .tr('observatory.relation_sampling.production_cases', {
                      'passed': '${attestation.productionRelationPassedCount}',
                      'count': '${attestation.productionApiCaseCount}',
                    }),
              ),
              _pill(
                context.appI18n.tr(
                  'observatory.relation_sampling.production_invocations',
                  {'count': '${attestation.productionApiInvocationCount}'},
                ),
              ),
              _pill(
                context.appI18n.tr(
                  'observatory.relation_sampling.production_holds',
                  {'count': '${attestation.productionPreconditionHoldCount}'},
                ),
              ),
              _pill(
                context.appI18n.tr('observatory.relation_sampling.mutations', {
                  'killed': '${attestation.mutationKilledCount}',
                  'total': '${attestation.mutationCaseCount}',
                }),
              ),
              _pill(
                context.appI18n.tr('observatory.relation_sampling.survivors', {
                  'count': '${attestation.mutationSurvivorCount}',
                }),
              ),
              _pill(
                context.appI18n
                    .tr('observatory.relation_sampling.false_relations', {
                      'rejected': '${attestation.falseRelationRejectedCount}',
                      'total': '${attestation.falseRelationFixtureCount}',
                    }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.appI18n.tr('observatory.relation_sampling.false_alarms', {
              'count': '${attestation.falseAlarmCount}',
              'total': '${attestation.falseAlarmDenominator}',
              'rate': falseAlarmPercent,
            }),
            key: const Key('observatory-relation-domain-false-alarms'),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            context.appI18n
                .tr('observatory.relation_sampling.production_boundary', {
                  'cases': '${attestation.productionApiCaseCount}',
                  'evaluations':
                      '${attestation.productionIndependentEvaluationCount}',
                  'anchors': '${attestation.productionAnchorRelationCount}',
                }),
            key: const Key('observatory-relation-domain-production-boundary'),
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.appI18n.tr('observatory.relation_sampling.generator', {
              'id': AlgorithmRelationDomainSamplingAttestation.generatorId,
              'version':
                  AlgorithmRelationDomainSamplingAttestation.generatorVersion,
            }),
            key: const Key('observatory-relation-domain-generator'),
            style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
          ),
          const SizedBox(height: 4),
          Text(
            context.appI18n.tr('observatory.relation_sampling.identities', {
              'plan': '${attestation.planSha256.substring(0, 12)}…',
              'sampler': '${attestation.samplerSha256.substring(0, 12)}…',
              'report': '${attestation.reportSha256.substring(0, 12)}…',
              'production':
                  '${attestation.productionExecutionReportSha256.substring(0, 12)}…',
              'executor':
                  '${attestation.productionExecutorSha256.substring(0, 12)}…',
            }),
            key: const Key('observatory-relation-domain-identities'),
            style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
          ),
          if (assessment.findings.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              assessment.findings.join(' · '),
              key: const Key('observatory-relation-domain-findings'),
              style: TextStyle(color: accent, fontSize: 11),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            AlgorithmRelationDomainSamplingAttestation.boundary,
            key: const Key('observatory-relation-domain-boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _executableStatusIcon(AlgorithmExecutableContractStatus status) =>
    switch (status) {
      AlgorithmExecutableContractStatus.passed => Icons.check_circle_outline,
      AlgorithmExecutableContractStatus.failed => Icons.error_outline,
      AlgorithmExecutableContractStatus.blocked => Icons.block_outlined,
      AlgorithmExecutableContractStatus.pending => Icons.hourglass_top_outlined,
      AlgorithmExecutableContractStatus.notCovered =>
        Icons.pending_actions_outlined,
    };

Color _executableStatusColor(AlgorithmExecutableContractStatus status) =>
    switch (status) {
      AlgorithmExecutableContractStatus.passed => const Color(0xff287d6b),
      AlgorithmExecutableContractStatus.failed ||
      AlgorithmExecutableContractStatus.blocked => const Color(0xffb3261e),
      AlgorithmExecutableContractStatus.pending => const Color(0xffa36b12),
      AlgorithmExecutableContractStatus.notCovered => Paper.inkMuted,
    };

class _NumericalOraclePanel extends StatelessWidget {
  final AlgorithmNumericalOracleReport report;
  final int totalAlgorithms;

  const _NumericalOraclePanel({
    required this.report,
    required this.totalAlgorithms,
  });

  @override
  Widget build(BuildContext context) {
    final verified = report.coveredAlgorithmIds
        .where(
          (id) =>
              report.statusFor(id) == AlgorithmNumericalOracleStatus.verified,
        )
        .length;
    final blocked =
        report.blockReasonCode != null || report.failedCaseCount > 0;
    final accent = blocked ? const Color(0xffb3261e) : const Color(0xff287d6b);
    return PaperCard(
      key: const Key('observatory-numerical-oracle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                blocked ? Icons.gpp_bad_outlined : Icons.fact_check_outlined,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.oracle.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.oracle.body'),
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                context.appI18n.tr('observatory.oracle.summary', {
                  'passed': '${report.passedCaseCount}',
                  'total': '${report.cases.length}',
                }),
              ),
              _pill(
                context.appI18n.tr('observatory.oracle.algorithms_summary', {
                  'verified': '$verified',
                  'total': '$totalAlgorithms',
                }),
              ),
              _pill(
                context.appI18n.tr('observatory.oracle.not_covered_count', {
                  'count': '${totalAlgorithms - verified}',
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.appI18n.tr('observatory.oracle.manifest', {
              'digest': '${report.manifestDigest.substring(0, 12)}…',
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            context.appI18n.tr('observatory.oracle.configuration', {
              'digest': report.configurationDigest == 'unavailable'
                  ? report.configurationDigest
                  : '${report.configurationDigest.substring(0, 12)}…',
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 7),
          Text(
            context.appI18n.tr('observatory.oracle.boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
          if (report.blockReasonCode case final reason?) ...[
            const SizedBox(height: 7),
            Text(
              reason,
              key: const Key('observatory-numerical-oracle-block-reason'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MechanisticEventLedgerPanel extends StatelessWidget {
  final MechanisticEventLedger ledger;
  final MechanisticLedgerAuthorizationAssessment authorization;

  const _MechanisticEventLedgerPanel({
    required this.ledger,
    required this.authorization,
  });

  @override
  Widget build(BuildContext context) {
    final syntheticCount = ledger.events
        .where((event) => event.synthetic)
        .length;
    final authorizationAccent = authorization.authorized
        ? const Color(0xFF16784A)
        : const Color(0xFFB3261E);
    return PaperCard(
      key: const Key('observatory-mechanistic-event-ledger'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.ledger.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.ledger.body'),
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-mechanistic-ledger-authorization'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: authorizationAccent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: authorizationAccent.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.appI18n.tr(
                    authorization.authorized
                        ? 'observatory.ledger.authorization_verified'
                        : 'observatory.ledger.authorization_blocked',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  context.appI18n
                      .tr('observatory.ledger.authorization_detail', {
                        'binding':
                            '${ledger.inputBindingSha256.substring(0, 12)}…',
                        'report':
                            '${authorization.reportSha256.substring(0, 12)}…',
                      }),
                  style: const TextStyle(fontSize: 12),
                ),
                if (authorization.findings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    authorization.findings.join(' · '),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  context.appI18n.tr(
                    'observatory.ledger.authorization_boundary',
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                context.appI18n.tr('observatory.ledger.event_count', {
                  'count': '${ledger.events.length}',
                }),
              ),
              _pill(
                context.appI18n.tr('observatory.ledger.synthetic_count', {
                  'count': '$syntheticCount',
                }),
              ),
              _pill(mechanisticEventLedgerSchema),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            context.appI18n.tr('observatory.ledger.digest', {
              'digest': '${ledger.sha256Digest.substring(0, 12)}…',
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            context.appI18n.tr('observatory.ledger.replay_digest', {
              'digest': '${ledger.canonicalReplayDigest.substring(0, 12)}…',
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            context.appI18n.tr('observatory.ledger.configuration', {
              'digest': '${ledger.configurationDigest.substring(0, 12)}…',
            }),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 7),
          for (final event in ledger.events)
            _MechanisticLedgerEventTile(event: event),
          const SizedBox(height: 6),
          Text(
            ledger.boundary,
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MechanisticReplayCapsulePanel extends StatelessWidget {
  const _MechanisticReplayCapsulePanel({
    required this.capsule,
    required this.onSave,
    required this.saving,
    required this.savedCount,
    required this.alreadySaved,
  });

  final MechanisticReplayCapsule capsule;
  final VoidCallback? onSave;
  final bool saving;
  final int? savedCount;
  final bool alreadySaved;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF126E75);
    return PaperCard(
      key: const Key('observatory-mechanistic-lossless-replay-capsule'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.appI18n.tr('observatory.replay_capsule.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.replay_capsule.body'),
            style: const TextStyle(color: Paper.inkMuted),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('observatory-lossless-replay-verified'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.appI18n.tr('observatory.replay_capsule.verified'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  context.appI18n.tr('observatory.replay_capsule.digest', {
                    'digest': '${capsule.capsuleSha256.substring(0, 12)}…',
                  }),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(mechanisticReplayCapsuleSchema),
              _pill(mechanisticReplayCanonicalizationProfile),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            context.appI18n.tr('observatory.replay_capsule.coverage'),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            context.appI18n.tr('observatory.replay_capsule.scalar_profile'),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 7),
          Text(
            context.appI18n.tr('observatory.replay_capsule.timezone_boundary'),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.appI18n.tr(
              'observatory.replay_capsule.credibility_boundary',
            ),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Paper.inkMuted,
            ),
          ),
          MechanisticReplayCapsuleSaveControl(
            onSave: onSave,
            saving: saving,
            savedCount: savedCount,
            alreadySaved: alreadySaved,
          ),
        ],
      ),
    );
  }
}

class MechanisticReplayCapsuleSaveControl extends StatelessWidget {
  const MechanisticReplayCapsuleSaveControl({
    required this.onSave,
    required this.saving,
    required this.savedCount,
    required this.alreadySaved,
    super.key,
  });

  final VoidCallback? onSave;
  final bool saving;
  final int? savedCount;
  final bool alreadySaved;

  @override
  Widget build(BuildContext context) {
    if (onSave == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.appI18n.tr('observatory.replay_capsule.save_disclosure'),
            style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
          ),
          if (savedCount != null) ...[
            const SizedBox(height: 5),
            Text(
              context.appI18n.tr('observatory.replay_capsule.saved_count', {
                'count': '$savedCount',
              }),
              key: const Key('observatory-replay-capsule-saved-count'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('observatory-save-synthetic-replay-capsule'),
            onPressed: saving || alreadySaved ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    alreadySaved
                        ? Icons.check_circle_outline
                        : Icons.save_alt_outlined,
                  ),
            label: Text(
              context.appI18n.tr(
                saving
                    ? 'observatory.replay_capsule.save_saving'
                    : alreadySaved
                    ? 'observatory.replay_capsule.save_already_saved'
                    : 'observatory.replay_capsule.save_action',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MechanisticLedgerEventTile extends StatelessWidget {
  final MechanisticLedgerEvent event;

  const _MechanisticLedgerEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: Key('mechanistic-ledger-event-${event.id}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      leading: Icon(switch (event.kind) {
        MechanisticLedgerEventKind.dose => Icons.medication_outlined,
        MechanisticLedgerEventKind.meal => Icons.restaurant_outlined,
        MechanisticLedgerEventKind.observation => Icons.monitor_heart_outlined,
        MechanisticLedgerEventKind.context => Icons.tune_outlined,
      }, size: 20),
      title: Text(
        '${event.kind.name} · ${event.id}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${event.originalTimestamp} · order ${event.orderAtTimestamp} · '
        '${event.synthetic ? 'synthetic' : 'observed'}',
        style: const TextStyle(fontSize: 11),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'UTC: ${event.occurredAtUtc.toIso8601String()}\n'
            'Offset: ${event.timezoneOffsetMinutes} min · '
            'source ${event.sourceId} · revision ${event.revisionId}'
            '${event.formulation == null ? '' : '\nForm: ${event.formulation}'}'
            '${event.route == null ? '' : ' · route ${event.route}'}'
            '${event.compartment == null ? '' : ' · compartment ${event.compartment}'}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Paper.inkMuted,
            ),
          ),
        ),
        for (final measurement in event.measurements)
          _MechanisticLedgerMeasurementRow(measurement: measurement),
      ],
    );
  }
}

class _MechanisticLedgerMeasurementRow extends StatelessWidget {
  final MechanisticLedgerMeasurement measurement;

  const _MechanisticLedgerMeasurementRow({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final value = measurement.state == MechanisticLedgerValueState.known
        ? '${measurement.originalValue} ${measurement.originalUnit} → '
              '${measurement.canonicalValue} ${measurement.canonicalUnit}'
        : measurement.state.name;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(measurement.id, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$value · ${measurement.origin.name}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

String _parameterSupportLabel(AlgorithmParameterSupport support) {
  return switch (support.kind) {
    AlgorithmParameterSupportKind.numericRange =>
      '${support.minimum}..${support.maximum} (not a clinical reference range)',
    AlgorithmParameterSupportKind.allowedValues => support.allowedValues.join(
      ' · ',
    ),
    AlgorithmParameterSupportKind.schema => support.schemaId!,
  };
}

String _parameterValueLabel(AlgorithmParameterProvenanceRecord record) {
  final distribution = record.distribution;
  if (distribution != null) {
    return '${distribution.familyId} distribution';
  }
  final value = record.canonicalValue;
  if (value is Map || value is List) {
    final digest = AlgorithmConfigurationIdentity.digestConfiguration(value);
    final size = value is Map ? value.length : (value as List).length;
    final sizeUnit = value is Map ? 'field' : 'item';
    return '$size-$sizeUnit canonical structure · ${digest.substring(0, 10)}…';
  }
  return '$value ${record.canonicalUnit}';
}

class _ChartPanel extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final String semanticsLabel;
  final List<_ChartSeries> series;
  final double xStart;
  final double xEnd;
  final String xLabel;
  final List<_ChartMarker> markers;
  final String longDescription;

  const _ChartPanel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.series,
    required this.xStart,
    required this.xEnd,
    required this.xLabel,
    required this.longDescription,
    this.markers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: Key('chart-panel-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Paper.inkMuted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [for (final item in series) _LegendItem(series: item)],
          ),
          const SizedBox(height: 8),
          Semantics(
            key: Key('chart-image-$id'),
            label: semanticsLabel,
            image: true,
            child: SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(
                painter: _AlgorithmChartPainter(
                  series: series,
                  xStart: xStart,
                  xEnd: xEnd,
                  markers: markers,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              xLabel,
              style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            key: Key('chart-long-description-$id'),
            container: true,
            label: context.appI18n.tr(
              'observatory.chart.long_description_semantics',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.appI18n.tr('observatory.chart.long_description'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  longDescription,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Paper.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ExpansionTile(
            key: Key('chart-data-table-$id'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              context.appI18n.tr('observatory.chart.data_table'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              context.appI18n.tr('observatory.chart.data_table_help'),
              style: const TextStyle(fontSize: 11),
            ),
            children: [
              _ChartDataTable(
                id: id,
                xLabel: xLabel,
                series: series,
                markers: markers,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartDataTable extends StatefulWidget {
  final String id;
  final String xLabel;
  final List<_ChartSeries> series;
  final List<_ChartMarker> markers;

  const _ChartDataTable({
    required this.id,
    required this.xLabel,
    required this.series,
    required this.markers,
  });

  @override
  State<_ChartDataTable> createState() => _ChartDataTableState();
}

class _ChartDataTableState extends State<_ChartDataTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xValues = <double>{
      for (final item in widget.series)
        for (final point in item.points) point.x,
    }.toList()..sort();
    final valuesBySeries = <Map<double, double>>[
      for (final item in widget.series)
        {for (final point in item.tablePoints ?? item.points) point.x: point.y},
    ];
    final markersByX = <double, List<String>>{};
    for (final marker in widget.markers) {
      markersByX.putIfAbsent(marker.x, () => <String>[]).add(marker.label);
    }

    return Semantics(
      key: Key('chart-data-semantics-${widget.id}'),
      container: true,
      label: context.appI18n.tr('observatory.chart.data_table_semantics'),
      child: Scrollbar(
        key: Key('chart-data-scrollbar-${widget.id}'),
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          key: Key('chart-data-scroll-view-${widget.id}'),
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 44,
            horizontalMargin: 8,
            columnSpacing: 18,
            columns: [
              DataColumn(label: Text(widget.xLabel)),
              for (final item in widget.series)
                DataColumn(label: Text(item.label)),
              if (widget.markers.isNotEmpty)
                DataColumn(
                  label: Text(context.appI18n.tr('observatory.chart.events')),
                ),
            ],
            rows: [
              for (final x in xValues)
                DataRow(
                  cells: [
                    DataCell(Text(_formatChartX(x))),
                    for (var index = 0; index < widget.series.length; index++)
                      DataCell(
                        Text(
                          widget.series[index].formatTableValue(
                            valuesBySeries[index][x],
                          ),
                        ),
                      ),
                    if (widget.markers.isNotEmpty)
                      DataCell(Text(markersByX[x]?.join(', ') ?? '—')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bounded = value.clamp(0.0, 1.0);
    return Semantics(
      label: '$label ${(bounded * 100).round()} percent',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: bounded,
                  minHeight: 8,
                  backgroundColor: Colors.black.withValues(alpha: 0.07),
                  color: color,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${(bounded * 100).round()}%',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageHeading extends StatelessWidget {
  final AlgorithmStage stage;
  const _StageHeading({required this.stage});

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      AlgorithmStage.normalize => context.appI18n.tr(
        'observatory.stage.normalize',
      ),
      AlgorithmStage.model => context.appI18n.tr('observatory.stage.model'),
      AlgorithmStage.decide => context.appI18n.tr('observatory.stage.decide'),
      AlgorithmStage.resolve => context.appI18n.tr('observatory.stage.resolve'),
      AlgorithmStage.explain => context.appI18n.tr('observatory.stage.explain'),
    };
    return Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _AlgorithmCoverageCard extends StatelessWidget {
  final AlgorithmDescriptor descriptor;
  final AlgorithmNumericalOracleStatus oracleStatus;
  final AlgorithmInvariantCoverageStatus invariantStatus;
  final Future<AlgorithmExecutableContractReport> executableReport;

  const _AlgorithmCoverageCard({
    required this.descriptor,
    required this.oracleStatus,
    required this.invariantStatus,
    required this.executableReport,
  });

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: Key('algorithm-card-${descriptor.id}'),
      padding: const EdgeInsets.all(12),
      child: Semantics(
        container: true,
        label:
            '${descriptor.name}. ${_visualizationContractLabel(descriptor.visualization)}. '
            '${descriptor.hasLiveTrace ? 'Production-engine-derived fixed-scenario trace available.' : 'Static audit contract only; no production scenario trace.'} '
            'Mathematical invariant gate: ${invariantStatus.name}. '
            'Independent numerical oracle: ${oracleStatus.name}. '
            '${descriptor.userVisibleImpact} Inputs: ${descriptor.inputs}. '
            'Outputs: ${descriptor.outputs}. Boundary: ${descriptor.limitation}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xff3559e0).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconFor(descriptor.visualization),
                    color: const Color(0xff3559e0),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              descriptor.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _pill(
                            _visualizationContractLabel(
                              descriptor.visualization,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        descriptor.userVisibleImpact,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AlgorithmVisualizationContract(descriptor: descriptor),
            const SizedBox(height: 8),
            Text(
              '${descriptor.inputs} → ${descriptor.outputs}',
              style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Boundary: ${descriptor.limitation}',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Paper.inkMuted,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              key: Key('algorithm-trace-status-${descriptor.id}'),
              children: [
                Icon(
                  descriptor.hasLiveTrace
                      ? Icons.bolt_outlined
                      : Icons.schema_outlined,
                  size: 15,
                  color: Paper.inkMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    descriptor.hasLiveTrace
                        ? 'Production-engine-derived fixed-scenario trace available'
                        : 'Static algorithm contract; no production scenario trace',
                    style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              key: Key('algorithm-invariant-status-${descriptor.id}'),
              children: [
                Icon(
                  switch (invariantStatus) {
                    AlgorithmInvariantCoverageStatus.passed =>
                      Icons.rule_outlined,
                    AlgorithmInvariantCoverageStatus.failed =>
                      Icons.error_outline,
                    AlgorithmInvariantCoverageStatus.notCovered =>
                      Icons.pending_actions_outlined,
                  },
                  size: 15,
                  color: switch (invariantStatus) {
                    AlgorithmInvariantCoverageStatus.passed => const Color(
                      0xff287d6b,
                    ),
                    AlgorithmInvariantCoverageStatus.failed => const Color(
                      0xffb3261e,
                    ),
                    AlgorithmInvariantCoverageStatus.notCovered =>
                      Paper.inkMuted,
                  },
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    context.appI18n.tr(
                      'observatory.invariant.${switch (invariantStatus) {
                        AlgorithmInvariantCoverageStatus.passed => 'passed',
                        AlgorithmInvariantCoverageStatus.failed => 'failed',
                        AlgorithmInvariantCoverageStatus.notCovered => 'not_covered',
                      }}',
                    ),
                    style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            FutureBuilder<AlgorithmExecutableContractReport>(
              future: executableReport,
              builder: (context, snapshot) {
                final status = snapshot.connectionState != ConnectionState.done
                    ? AlgorithmExecutableContractStatus.pending
                    : snapshot.hasError || snapshot.data == null
                    ? AlgorithmExecutableContractStatus.blocked
                    : snapshot.data!.statusFor(descriptor.id);
                return Row(
                  key: Key('algorithm-executable-status-${descriptor.id}'),
                  children: [
                    Icon(
                      _executableStatusIcon(status),
                      size: 15,
                      color: _executableStatusColor(status),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        context.appI18n.tr(
                          'observatory.executable.${switch (status) {
                            AlgorithmExecutableContractStatus.passed => 'passed',
                            AlgorithmExecutableContractStatus.failed => 'failed',
                            AlgorithmExecutableContractStatus.blocked => 'blocked_status',
                            AlgorithmExecutableContractStatus.pending => 'pending_status',
                            AlgorithmExecutableContractStatus.notCovered => 'not_covered',
                          }}',
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Paper.inkMuted,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 7),
            Row(
              key: Key('algorithm-oracle-status-${descriptor.id}'),
              children: [
                Icon(
                  switch (oracleStatus) {
                    AlgorithmNumericalOracleStatus.verified =>
                      Icons.verified_outlined,
                    AlgorithmNumericalOracleStatus.mismatch =>
                      Icons.error_outline,
                    AlgorithmNumericalOracleStatus.notCovered =>
                      Icons.pending_actions_outlined,
                    AlgorithmNumericalOracleStatus.blocked =>
                      Icons.block_outlined,
                  },
                  size: 15,
                  color: switch (oracleStatus) {
                    AlgorithmNumericalOracleStatus.verified => const Color(
                      0xff287d6b,
                    ),
                    AlgorithmNumericalOracleStatus.mismatch ||
                    AlgorithmNumericalOracleStatus.blocked => const Color(
                      0xffb3261e,
                    ),
                    AlgorithmNumericalOracleStatus.notCovered => Paper.inkMuted,
                  },
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    context.appI18n.tr(
                      'observatory.oracle.${switch (oracleStatus) {
                        AlgorithmNumericalOracleStatus.verified => 'verified',
                        AlgorithmNumericalOracleStatus.mismatch => 'mismatch',
                        AlgorithmNumericalOracleStatus.notCovered => 'not_covered',
                        AlgorithmNumericalOracleStatus.blocked => 'blocked',
                      }}',
                    ),
                    style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlgorithmVisualizationContract extends StatelessWidget {
  final AlgorithmDescriptor descriptor;

  const _AlgorithmVisualizationContract({required this.descriptor});

  @override
  Widget build(BuildContext context) {
    final visual = descriptor.staticVisual;
    return ExcludeSemantics(
      child: Container(
        key: Key('algorithm-visual-${descriptor.id}'),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        ),
        child: Column(
          key: Key(visual.contractId),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              visual.transformLabel,
              key: Key('algorithm-static-visual-title-${descriptor.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _StaticVisualNode(
                    label: 'INPUT',
                    value: visual.inputLabel,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.arrow_forward_rounded, size: 15),
                ),
                Expanded(
                  child: _StaticVisualNode(
                    label: 'LOGIC',
                    value: descriptor.id,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.arrow_forward_rounded, size: 15),
                ),
                Expanded(
                  child: _StaticVisualNode(
                    label: 'OUTPUT',
                    value: visual.outputLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticVisualNode extends StatelessWidget {
  final String label;
  final String value;

  const _StaticVisualNode({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Paper.inkMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, height: 1.15),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final _ChartSeries series;
  const _LegendItem({required this.series});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: series.color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              series.label,
              style: const TextStyle(fontSize: 11),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPoint {
  final double x;
  final double y;
  const _ChartPoint(this.x, this.y);
}

enum _ChartValueFormat { percentage, fractionPerMinute }

class _ChartSeries {
  final String label;
  final Color color;
  final List<_ChartPoint> points;
  final List<_ChartPoint>? tablePoints;
  final _ChartValueFormat tableValueFormat;
  final double strokeWidth;

  const _ChartSeries({
    required this.label,
    required this.color,
    required this.points,
    this.tablePoints,
    this.tableValueFormat = _ChartValueFormat.percentage,
    this.strokeWidth = 2.4,
  });

  String formatTableValue(double? value) {
    if (value == null) return '—';
    return switch (tableValueFormat) {
      _ChartValueFormat.percentage => '${(value * 100).toStringAsFixed(1)}%',
      _ChartValueFormat.fractionPerMinute =>
        '${value.toStringAsFixed(4)} fraction/min',
    };
  }
}

class _ChartMarker {
  final double x;
  final String label;
  const _ChartMarker({required this.x, required this.label});
}

class _AlgorithmChartPainter extends CustomPainter {
  final List<_ChartSeries> series;
  final double xStart;
  final double xEnd;
  final List<_ChartMarker> markers;

  const _AlgorithmChartPainter({
    required this.series,
    required this.xStart,
    required this.xEnd,
    required this.markers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 10.0;
    const right = 8.0;
    const bottom = 24.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final grid = Paint()
      ..color = Colors.black.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final painter = TextPainter(
        text: TextSpan(
          text: '${i * 25}%',
          style: TextStyle(
            fontSize: 9,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(1, y - painter.height / 2));
    }
    final range = math.max(1e-9, xEnd - xStart);
    double mapX(double value) =>
        plot.left + ((value - xStart) / range).clamp(0.0, 1.0) * plot.width;
    double mapY(double value) =>
        plot.bottom - value.clamp(0.0, 1.0) * plot.height;

    for (final marker in markers) {
      if (marker.x < xStart || marker.x > xEnd) continue;
      final x = mapX(marker.x);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..strokeWidth = 1,
      );
      final label = TextPainter(
        text: TextSpan(
          text: marker.label,
          style: const TextStyle(fontSize: 9, color: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x + 3, plot.top));
    }

    for (final item in series) {
      if (item.points.length < 2) continue;
      final path = Path();
      for (var i = 0; i < item.points.length; i++) {
        final point = item.points[i];
        final offset = Offset(mapX(point.x), mapY(point.y));
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..strokeWidth = item.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AlgorithmChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.xStart != xStart ||
        oldDelegate.xEnd != xEnd ||
        oldDelegate.markers != markers;
  }
}

Widget _pill(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.black12),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}

String _relativeWindow(dynamic window, int anchor) {
  final start = (window.startMinute as int) - anchor;
  final end = (window.endMinute as int) - anchor;
  return '$start–$end min';
}

IconData _iconFor(AlgorithmVisualization visualization) {
  return switch (visualization) {
    AlgorithmVisualization.liveCurve => Icons.multiline_chart_rounded,
    AlgorithmVisualization.liveTimeline => Icons.timeline_rounded,
    AlgorithmVisualization.scoreBreakdown => Icons.bar_chart_rounded,
    AlgorithmVisualization.decisionFlow => Icons.account_tree_outlined,
    AlgorithmVisualization.qualityMatrix => Icons.grid_view_rounded,
    AlgorithmVisualization.resolutionTable => Icons.table_rows_outlined,
    AlgorithmVisualization.provenanceGraph => Icons.hub_outlined,
  };
}

String _visualizationContractLabel(AlgorithmVisualization visualization) {
  return switch (visualization) {
    AlgorithmVisualization.liveCurve => 'curve contract',
    AlgorithmVisualization.liveTimeline => 'timeline contract',
    AlgorithmVisualization.scoreBreakdown => 'score contract',
    AlgorithmVisualization.decisionFlow => 'decision-flow contract',
    AlgorithmVisualization.qualityMatrix => 'quality-matrix contract',
    AlgorithmVisualization.resolutionTable => 'resolution-table contract',
    AlgorithmVisualization.provenanceGraph => 'evidence-graph contract',
  };
}

String _shortStageLabel(BuildContext context, AlgorithmStage stage) {
  return switch (stage) {
    AlgorithmStage.normalize => context.appI18n.tr(
      'observatory.atlas.stage.normalize',
    ),
    AlgorithmStage.model => context.appI18n.tr('observatory.atlas.stage.model'),
    AlgorithmStage.decide => context.appI18n.tr(
      'observatory.atlas.stage.decide',
    ),
    AlgorithmStage.resolve => context.appI18n.tr(
      'observatory.atlas.stage.resolve',
    ),
    AlgorithmStage.explain => context.appI18n.tr(
      'observatory.atlas.stage.explain',
    ),
  };
}

String _formatChartX(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String _scenarioLabel(BuildContext context, ObservatoryScenario scenario) {
  return switch (scenario) {
    ObservatoryScenario.mixedReference => context.appI18n.tr(
      'observatory.scenario.mixed',
    ),
    ObservatoryScenario.highFatProtein => context.appI18n.tr(
      'observatory.scenario.high_fat_protein',
    ),
    ObservatoryScenario.incompleteData => context.appI18n.tr(
      'observatory.scenario.missing',
    ),
  };
}
