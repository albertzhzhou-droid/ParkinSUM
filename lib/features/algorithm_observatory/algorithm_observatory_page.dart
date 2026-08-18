import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../algorithm_sdk/algorithm_parameter_provenance.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../core/i18n/app_i18n.dart';
import '../../domain/entities/algorithm_descriptor.dart';
import '../../domain/entities/algorithm_trace_node.dart';
import '../../domain/entities/mechanistic_candidate_score.dart';
import '../../domain/entities/mechanistic_conflict_result.dart';
import '../../domain/entities/mechanistic_event_ledger.dart';
import '../../domain/usecases/algorithm_numerical_verification_oracle.dart';
import '../../domain/usecases/algorithm_observatory_service.dart';
import '../../domain/usecases/algorithm_registry.dart';

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
  final AlgorithmObservatoryService? service;

  const AlgorithmObservatoryPage({super.key, this.service});

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
  late final AlgorithmNumericalOracleReport _oracleReport;
  late AlgorithmObservatorySnapshot _snapshot;
  AlgorithmStage? _algorithmStage;
  bool _liveTraceOnly = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AlgorithmObservatoryService();
    _snapshots = {
      for (final scenario in ObservatoryScenario.values)
        scenario: _service.build(scenario),
    };
    _oracleReport = const AlgorithmNumericalVerificationOracle().run(
      service: _service,
    );
    _snapshot = _snapshots[_scenario]!;
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
      appBar: GlassAppBar(title: Text(context.appI18n.tr('observatory.title'))),
      body: LiquidGlassBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _BoundaryCard(count: AlgorithmRegistry.all.length),
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
              _AbsorptionCompetitionPanel(snapshot: _snapshot),
              const SizedBox(height: 14),
              _ConflictPanel(snapshot: _snapshot),
              const SizedBox(height: 14),
              _ExplanationTreePanel(root: _snapshot.explanationTree),
              const SizedBox(height: 14),
              _CandidatePanel(scores: _snapshot.candidateScores),
              const SizedBox(height: 14),
              _ParameterEvidencePanel(
                configurationIdentity: _snapshot.configurationIdentity,
              ),
              const SizedBox(height: 14),
              _NumericalOraclePanel(
                report: _oracleReport,
                totalAlgorithms: AlgorithmRegistry.all.length,
              ),
              const SizedBox(height: 14),
              _MechanisticEventLedgerPanel(ledger: _snapshot.eventLedger),
              const SizedBox(height: 22),
              Text(
                context.appI18n.tr('observatory.coverage.title'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                context.appI18n.tr('observatory.coverage.body'),
                style: TextStyle(color: LiquidGlass.onSurfaceMuted),
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
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                ],
              ],
              if (visibleAlgorithms.isEmpty)
                GlassCard(
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
    return GlassCard(
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
    return GlassCard(
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

class _ScenarioSelector extends StatelessWidget {
  final ObservatoryScenario selected;
  final ValueChanged<ObservatoryScenario> onSelected;

  const _ScenarioSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
    return GlassCard(
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
            style: const TextStyle(color: LiquidGlass.onSurfaceMuted),
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
        color: LiquidGlass.glassFillSoft,
        borderRadius: BorderRadius.circular(LiquidGlass.radiusSm),
        border: Border.all(
          color: LiquidGlass.stroke,
          width: LiquidGlass.hairline,
        ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: LiquidGlass.onSurfaceMuted,
                  ),
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
    return GlassCard(
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
              style: const TextStyle(
                fontSize: 12,
                color: LiquidGlass.onSurfaceMuted,
              ),
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
      footer:
          'Peak modeled emptying window: ${_relativeWindow(profile.peakEmptyingWindow, snapshot.context.mealEvents.first.minute)} · central mostly-emptied window: ${_relativeWindow(profile.mostlyEmptiedWindow, snapshot.context.mealEvents.first.minute)}. The orange line is scaled ×40 only on the shared chart; the table reports raw fraction/min. The ±$sensitivityPercent% lines are illustrative one-way sensitivity—not a confidence interval. “Mostly emptied” is a model threshold, not a clinical measurement.',
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
      footer:
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
    return GlassCard(
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
            style: TextStyle(color: LiquidGlass.onSurfaceMuted),
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
            style: const TextStyle(
              fontSize: 12,
              color: LiquidGlass.onSurfaceMuted,
            ),
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
    return GlassCard(
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
            style: TextStyle(color: LiquidGlass.onSurfaceMuted),
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
              style: const TextStyle(
                fontSize: 12,
                color: LiquidGlass.onSurfaceMuted,
              ),
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
    return GlassCard(
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
            style: const TextStyle(color: LiquidGlass.onSurfaceMuted),
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
                style: const TextStyle(
                  fontSize: 11,
                  color: LiquidGlass.onSurfaceMuted,
                ),
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
                  color: LiquidGlass.onSurfaceMuted,
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
    return GlassCard(
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
            style: const TextStyle(color: LiquidGlass.onSurfaceMuted),
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
    return ExpansionTile(
      key: Key('parameter-${record.parameterId}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      title: Text(record.displayName, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '$valueLabel · ${record.provenanceStatus.name} · ${record.formulaId}',
        style: TextStyle(
          fontSize: 11,
          color: isHeuristic
              ? const Color(0xffa36b12)
              : LiquidGlass.onSurfaceMuted,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Semantic ID: ${record.semanticId}\n'
            'Units: ${record.originalUnit} → ${record.canonicalUnit} via ${record.transformId}\n'
            'Supported engineering domain: ${_parameterSupportLabel(record.supportedDomain)}\n'
            'Sources: ${record.sourceIds.join(' · ')}\n'
            'Reviewed: ${record.reviewDate}\n'
            'Boundary: ${record.limitation}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
        ),
      ],
    );
  }
}

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
    return GlassCard(
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
            style: const TextStyle(color: LiquidGlass.onSurfaceMuted),
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
              color: LiquidGlass.onSurfaceMuted,
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

  const _MechanisticEventLedgerPanel({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final syntheticCount = ledger.events
        .where((event) => event.synthetic)
        .length;
    return GlassCard(
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
            style: const TextStyle(color: LiquidGlass.onSurfaceMuted),
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
              color: LiquidGlass.onSurfaceMuted,
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
              color: LiquidGlass.onSurfaceMuted,
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
              style: const TextStyle(
                fontSize: 11,
                color: LiquidGlass.onSurfaceMuted,
              ),
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
  final String footer;

  const _ChartPanel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.series,
    required this.xStart,
    required this.xEnd,
    required this.xLabel,
    required this.footer,
    this.markers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: Key('chart-panel-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: LiquidGlass.onSurfaceMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [for (final item in series) _LegendItem(series: item)],
          ),
          const SizedBox(height: 8),
          Semantics(
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
              style: const TextStyle(
                fontSize: 11,
                color: LiquidGlass.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            footer,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: LiquidGlass.onSurfaceMuted,
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

  const _AlgorithmCoverageCard({
    required this.descriptor,
    required this.oracleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: Key('algorithm-card-${descriptor.id}'),
      padding: const EdgeInsets.all(12),
      child: Semantics(
        container: true,
        label:
            '${descriptor.name}. ${_visualizationContractLabel(descriptor.visualization)}. '
            '${descriptor.hasLiveTrace ? 'Production-engine-derived fixed-scenario trace available.' : 'Static audit contract only; no production scenario trace.'} '
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
              style: const TextStyle(
                fontSize: 12,
                color: LiquidGlass.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Boundary: ${descriptor.limitation}',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: LiquidGlass.onSurfaceMuted,
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
                  color: LiquidGlass.onSurfaceMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    descriptor.hasLiveTrace
                        ? 'Production-engine-derived fixed-scenario trace available'
                        : 'Static algorithm contract; no production scenario trace',
                    style: const TextStyle(
                      fontSize: 11,
                      color: LiquidGlass.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
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
                    AlgorithmNumericalOracleStatus.notCovered =>
                      LiquidGlass.onSurfaceMuted,
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: LiquidGlass.onSurfaceMuted,
                    ),
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
            color: LiquidGlass.onSurfaceMuted,
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
