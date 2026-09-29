import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/intake.dart';
import '../../core/state/app_state.dart';
import '../../domain/entities/medication_assertion_reconciliation.dart';
import '../../domain/usecases/dosage_note_parser.dart';
import '../../domain/usecases/medication_assertion_reconciliation_service.dart';

class MedicationAssertionReconciliationPage extends StatelessWidget {
  const MedicationAssertionReconciliationPage({
    super.key,
    required this.intakeId,
  });

  final String intakeId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final intake = state.intakes
        .where((item) => item.id == intakeId)
        .firstOrNull;
    final copy = _ReconciliationCopy.forFamily(
      AppI18n.fromLocaleTag(
        Localizations.localeOf(context).toLanguageTag(),
      ).languageFamily,
    );
    if (intake == null) {
      return Scaffold(
        appBar: AppBar(title: Text(copy.title)),
        body: Center(child: Text(copy.missing)),
      );
    }
    final resultUse = state.evaluateDoseForResultUse(intake);
    final graph = resultUse.assertionGraph;
    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: ListView(
        key: const ValueKey<String>('medication-reconciliation-list'),
        padding: const EdgeInsets.all(16),
        children: [
          _DoseResultGateStatusCard(
            graph: graph,
            resultEligible: resultUse.eligible,
            resultReasons: resultUse.reasonCodes,
            copy: copy,
          ),
          const SizedBox(height: 12),
          Text(copy.sources, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final node in graph.nodes)
                    SizedBox(
                      width: cardWidth,
                      child: _AssertionCard(node: node, copy: copy),
                    ),
                ],
              );
            },
          ),
          if (graph.nodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(copy.noSources),
            ),
          const SizedBox(height: 16),
          Text(
            copy.relationships,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (graph.edges.isEmpty)
            Text(copy.noRelationships)
          else
            for (final edge in graph.edges)
              _EdgeTile(edge: edge, nodes: graph.nodes, copy: copy),
          const SizedBox(height: 16),
          _BitemporalProjectionPanel(
            key: ValueKey<String>('bitemporal-projection-${intake.id}'),
            state: state,
            intake: intake,
            graphDigest: graph.graphDigest,
            copy: copy,
          ),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            label: copy.boundary,
            child: Card(
              color: const Color(0xfffff7e6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(copy.boundary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey<String>('add-medication-assertion'),
                icon: const Icon(Icons.add_link_outlined),
                label: Text(copy.addSource),
                onPressed: () => _showAddAssertion(
                  context,
                  state: state,
                  intakeId: intake.id,
                  graphDigest: graph.graphDigest,
                  defaultEventTime: intake.takenAt,
                  copy: copy,
                ),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('acknowledge-assertion-graph'),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  graph.hasUnresolvedConflict
                      ? copy.acknowledgeConflict
                      : copy.confirmReviewed,
                ),
                onPressed: () => _appendDecision(
                  context,
                  state: state,
                  intakeId: intake.id,
                  graph: graph,
                  resolution: graph.hasUnresolvedConflict
                      ? MedicationReconciliationResolution
                            .acknowledgedUnresolved
                      : MedicationReconciliationResolution.confirmedNoConflict,
                  copy: copy,
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('hold-assertion-graph'),
                icon: const Icon(Icons.pause_circle_outline),
                label: Text(copy.hold),
                onPressed: () => _appendDecision(
                  context,
                  state: state,
                  intakeId: intake.id,
                  graph: graph,
                  resolution: MedicationReconciliationResolution.heldForReview,
                  copy: copy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showAddAssertion(
    BuildContext context, {
    required AppState state,
    required String intakeId,
    required String graphDigest,
    required DateTime defaultEventTime,
    required _ReconciliationCopy copy,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddAssertionDialog(
        intakeId: intakeId,
        expectedGraphDigest: graphDigest,
        defaultEventTime: defaultEventTime,
        copy: copy,
      ),
    );
  }

  Future<void> _appendDecision(
    BuildContext context, {
    required AppState state,
    required String intakeId,
    required MedicationAssertionGraph graph,
    required MedicationReconciliationResolution resolution,
    required _ReconciliationCopy copy,
  }) async {
    final result = await state.appendMedicationReconciliationDecision(
      intakeId: intakeId,
      expectedGraphDigest: graph.graphDigest,
      resolution: resolution,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result == null ? copy.stale : copy.saved)),
    );
  }
}

class _BitemporalProjectionPanel extends StatefulWidget {
  const _BitemporalProjectionPanel({
    super.key,
    required this.state,
    required this.intake,
    required this.graphDigest,
    required this.copy,
  });

  final AppState state;
  final Intake intake;
  final String graphDigest;
  final _ReconciliationCopy copy;

  @override
  State<_BitemporalProjectionPanel> createState() =>
      _BitemporalProjectionPanelState();
}

class _BitemporalProjectionPanelState
    extends State<_BitemporalProjectionPanel> {
  late DateTime _validAtUtc;
  late DateTime _knownAtUtc;
  MedicationAssertionBitemporalProjection? _projection;
  String? _projectionGraphDigest;

  @override
  void initState() {
    super.initState();
    _validAtUtc = widget.intake.takenAt.toUtc();
    _knownAtUtc = DateTime.now().toUtc();
  }

  @override
  void didUpdateWidget(covariant _BitemporalProjectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intake.id != widget.intake.id) {
      _validAtUtc = widget.intake.takenAt.toUtc();
      _knownAtUtc = DateTime.now().toUtc();
      _projection = null;
      _projectionGraphDigest = null;
    }
  }

  Future<void> _selectCutoff(
    BuildContext context, {
    required bool selectValidAt,
  }) async {
    final copy = widget.copy;
    final initial = selectValidAt ? _validAtUtc : _knownAtUtc;
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100, 12, 31);
    var initialDate = DateTime(initial.year, initial.month, initial.day);
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: selectValidAt ? copy.validAt : copy.knownAt,
    );
    if (selectedDate == null || !context.mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: copy.utcTime,
    );
    if (selectedTime == null || !context.mounted) return;
    final selectedUtc = DateTime.utc(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    setState(() {
      if (selectValidAt) {
        _validAtUtc = selectedUtc;
      } else {
        _knownAtUtc = selectedUtc;
      }
      _projection = null;
      _projectionGraphDigest = null;
    });
  }

  void _project() {
    final projection = widget.state.projectMedicationAssertionsBitemporal(
      widget.intake,
      validAt: _validAtUtc,
      knownAt: _knownAtUtc,
    );
    setState(() {
      _projection = projection;
      _projectionGraphDigest = widget.graphDigest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final projection = _projection;
    final isCurrent =
        projection != null && _projectionGraphDigest == widget.graphDigest;
    return Card(
      key: const ValueKey<String>('bitemporal-projection-panel'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.bitemporalTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(copy.bitemporalHelp),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey<String>('select-valid-at-cutoff'),
                  onPressed: () => _selectCutoff(context, selectValidAt: true),
                  child: Text('${copy.validAt}: ${_formatUtc(_validAtUtc)}'),
                ),
                OutlinedButton(
                  key: const ValueKey<String>('select-known-at-cutoff'),
                  onPressed: () => _selectCutoff(context, selectValidAt: false),
                  child: Text('${copy.knownAt}: ${_formatUtc(_knownAtUtc)}'),
                ),
                TextButton(
                  key: const ValueKey<String>('known-at-event-time'),
                  onPressed: () => setState(() {
                    _knownAtUtc = _validAtUtc;
                    _projection = null;
                    _projectionGraphDigest = null;
                  }),
                  child: Text(copy.knownAtEvent),
                ),
                TextButton(
                  key: const ValueKey<String>('known-at-current-time'),
                  onPressed: () => setState(() {
                    _knownAtUtc = DateTime.now().toUtc();
                    _projection = null;
                    _projectionGraphDigest = null;
                  }),
                  child: Text(copy.knownAtNow),
                ),
                FilledButton.tonal(
                  key: const ValueKey<String>('run-bitemporal-projection'),
                  onPressed: _project,
                  child: Text(copy.projectHistory),
                ),
              ],
            ),
            if (projection != null && !isCurrent) ...[
              const SizedBox(height: 8),
              Text(copy.historyChanged),
            ],
            if (isCurrent) ...[
              const Divider(height: 24),
              _BitemporalProjectionResult(projection: projection, copy: copy),
            ],
          ],
        ),
      ),
    );
  }
}

class _BitemporalProjectionResult extends StatelessWidget {
  const _BitemporalProjectionResult({
    required this.projection,
    required this.copy,
  });

  final MedicationAssertionBitemporalProjection projection;
  final _ReconciliationCopy copy;

  @override
  Widget build(BuildContext context) {
    final available = projection.assertions
        .where(
          (entry) =>
              entry.knowledgeStatus ==
              MedicationAssertionKnowledgeStatus.availableAtCutoff,
        )
        .length;
    final withheld = projection.assertions.length - available;
    final withinInterval = projection.assertions
        .where(
          (entry) =>
              entry.knowledgeStatus ==
                  MedicationAssertionKnowledgeStatus.availableAtCutoff &&
              entry.validTimeStatus ==
                  MedicationAssertionValidTimeStatus.inEffectiveInterval,
        )
        .length;
    final uncertainTime = projection.assertions
        .where(
          (entry) =>
              entry.knowledgeStatus ==
                  MedicationAssertionKnowledgeStatus.availableAtCutoff &&
              entry.validTimeStatus ==
                  MedicationAssertionValidTimeStatus.uncertainEffectiveTime,
        )
        .length;
    final visibleDecisions = projection.decisions
        .where(
          (entry) =>
              entry.knowledgeStatus ==
              MedicationAssertionKnowledgeStatus.availableAtCutoff,
        )
        .length;
    final aggregateIntegrityTimeUnknown =
        projection.aggregateIntegrityTemporalStatus ==
        MedicationAggregateIntegrityTemporalStatus.knowledgeTimeUnresolved;
    final otherIntegrityFindingCount =
        projection.integrityFindings.length -
        (aggregateIntegrityTimeUnknown ? 1 : 0);
    final historicalGraph = projection.historicalConflictGraph;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.projectionSummary(
            available,
            withheld,
            withinInterval,
            uncertainTime,
            visibleDecisions,
          ),
          key: const ValueKey<String>('bitemporal-projection-summary'),
        ),
        if (aggregateIntegrityTimeUnknown) ...[
          const SizedBox(height: 6),
          Text(
            copy.aggregateIntegrityTimeUnknown,
            key: const ValueKey<String>(
              'bitemporal-aggregate-integrity-time-unknown',
            ),
          ),
        ],
        if (projection.assertions.isEmpty) ...[
          const SizedBox(height: 6),
          Text(copy.noHistoricalAssertions),
        ],
        const SizedBox(height: 8),
        Text(
          copy.historicalGraphSummary(
            historicalGraph.nodes.length,
            historicalGraph.edges.length,
            historicalGraph.blockingEdges.length,
            historicalGraph.integrityFindings.length,
            historicalGraph.staleDecisionCount,
          ),
          key: const ValueKey<String>('bitemporal-historical-graph-summary'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (historicalGraph.edges.isEmpty &&
            historicalGraph.integrityFindings.isEmpty) ...[
          const SizedBox(height: 4),
          Text(copy.noHistoricalRelationships),
        ],
        for (final edge in historicalGraph.edges)
          _EdgeTile(edge: edge, nodes: historicalGraph.nodes, copy: copy),
        if (historicalGraph.currentDecision != null)
          Text(
            '${copy.reviewDecision}: ${copy.resolutionLabel(historicalGraph.currentDecision!.resolution)}',
          ),
        for (var index = 0; index < projection.assertions.length; index++)
          _BitemporalAssertionTile(
            index: index + 1,
            entry: projection.assertions[index],
            copy: copy,
          ),
        for (final entry in projection.decisions)
          ListTile(
            key: ValueKey<String>('bitemporal-decision-${entry.decisionId}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(copy.reviewDecision),
            subtitle: Text(
              entry.decision == null
                  ? copy.hiddenAtCutoff
                  : copy.resolutionLabel(entry.decision!.resolution),
            ),
          ),
        if (otherIntegrityFindingCount > 0) ...[
          const SizedBox(height: 6),
          Text(copy.integrityFindingCount(otherIntegrityFindingCount)),
        ],
        const SizedBox(height: 6),
        Text(copy.bitemporalBoundary),
      ],
    );
  }
}

class _BitemporalAssertionTile extends StatelessWidget {
  const _BitemporalAssertionTile({
    required this.index,
    required this.entry,
    required this.copy,
  });

  final int index;
  final MedicationAssertionBitemporalEntry entry;
  final _ReconciliationCopy copy;

  @override
  Widget build(BuildContext context) {
    final assertion = entry.assertion;
    return Card(
      key: ValueKey<String>('bitemporal-assertion-$index'),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.knowledgeStatusLabel(entry.knowledgeStatus),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (assertion == null)
              Text(copy.hiddenAtCutoff)
            else ...[
              Text(
                '${copy.evidenceLabel(assertion.evidenceClass)} · '
                '${copy.statusLabel(assertion.status)}',
              ),
              Text(
                '${copy.validTimeStatusLabel(entry.validTimeStatus)} · '
                '${copy.eventTime}: ${assertion.effectiveStartUtc == null ? copy.unknown : _formatUtc(assertion.effectiveStartUtc!)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatUtc(DateTime value) =>
    '${value.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 16)} UTC';

class _DoseResultGateStatusCard extends StatelessWidget {
  const _DoseResultGateStatusCard({
    required this.graph,
    required this.resultEligible,
    required this.resultReasons,
    required this.copy,
  });

  final MedicationAssertionGraph graph;
  final bool resultEligible;
  final List<String> resultReasons;
  final _ReconciliationCopy copy;

  @override
  Widget build(BuildContext context) {
    final blocked = !resultEligible;
    final color = blocked ? const Color(0xff9a6700) : const Color(0xff287d6b);
    final assertionBlocked = !graph.resultAffectingDoseEligible;
    return Semantics(
      container: true,
      label: blocked ? copy.modelHeld : copy.modelEligible,
      child: Card(
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    blocked
                        ? Icons.pause_circle_outline
                        : Icons.verified_outlined,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      blocked ? copy.modelHeld : copy.modelEligible,
                      key: const ValueKey<String>(
                        'dose-combined-result-gate-status',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                copy.summary(
                  graph.nodes.length,
                  graph.blockingEdges.length,
                  graph.staleDecisionCount,
                ),
              ),
              if (resultReasons.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  copy.resultReasons(resultReasons),
                  key: const ValueKey<String>('dose-result-gate-reasons'),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                key: const ValueKey<String>('assertion-subgate-status'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: assertionBlocked
                        ? const Color(0xff9a6700)
                        : const Color(0xff287d6b),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assertionBlocked
                          ? copy.assertionSubgateHeld
                          : copy.assertionSubgateEligible,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (graph.resultGateReasons.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(copy.assertionReasons(graph.resultGateReasons)),
                    ],
                  ],
                ),
              ),
              if (graph.currentDecision != null) ...[
                const SizedBox(height: 6),
                Text(copy.decisionRecorded),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssertionCard extends StatelessWidget {
  const _AssertionCard({required this.node, required this.copy});

  final MedicationAssertionNode node;
  final _ReconciliationCopy copy;

  @override
  Widget build(BuildContext context) {
    final effective = node.effectiveStartUtc == null
        ? copy.unknown
        : _format(node.effectiveStartUtc!);
    final dose = node.doseValue == null
        ? copy.unknown
        : '${node.doseValue} ${node.doseUnit}';
    final sourceLabelPrefix = node.sourceDisplayLabel == null
        ? ''
        : '${node.sourceDisplayLabel}. ';
    return Semantics(
      container: true,
      label:
          '$sourceLabelPrefix${copy.evidenceLabel(node.evidenceClass)}. ${copy.statusLabel(node.status)}. $effective.',
      child: Card(
        key: ValueKey<String>('assertion-${node.assertionId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.evidenceLabel(node.evidenceClass),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (node.sourceDisplayLabel != null)
                _row(copy.sourceLabel, node.sourceDisplayLabel!),
              _row(copy.eventTime, effective),
              _row(copy.assertedTime, _format(node.assertedAtUtc)),
              _row(
                copy.importedTime,
                node.importedAtUtc == null
                    ? copy.notApplicable
                    : _format(node.importedAtUtc!),
              ),
              _row(copy.recordedTime, _format(node.recordedAtUtc)),
              _row(copy.precision, node.timePrecision.name),
              _row(copy.dose, dose),
              _row(copy.status, copy.statusLabel(node.status)),
              _row(copy.actor, copy.roleLabel(node.actorRole)),
              _row(copy.revision, node.sourceRevisionDigest.substring(0, 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text('$label: $value'),
  );

  String _format(DateTime value) => value.toLocal().toString().split('.').first;
}

class _EdgeTile extends StatelessWidget {
  const _EdgeTile({
    required this.edge,
    required this.nodes,
    required this.copy,
  });

  final MedicationAssertionEdge edge;
  final List<MedicationAssertionNode> nodes;
  final _ReconciliationCopy copy;

  @override
  Widget build(BuildContext context) {
    String sourceLabel(String assertionId) {
      final node = nodes
          .where((candidate) => candidate.assertionId == assertionId)
          .firstOrNull;
      if (node == null) return copy.unknown;
      final evidence = copy.evidenceLabel(node.evidenceClass);
      return node.sourceDisplayLabel == null
          ? evidence
          : '${node.sourceDisplayLabel} · $evidence';
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        edge.blocking ? Icons.warning_amber_rounded : Icons.link_outlined,
        color: edge.blocking
            ? const Color(0xff9a6700)
            : const Color(0xff287d6b),
      ),
      title: Text(copy.relationshipLabel(edge.relationship)),
      subtitle: Text(
        '${sourceLabel(edge.fromAssertionId)} → '
        '${sourceLabel(edge.toAssertionId)}',
      ),
    );
  }
}

class _AddAssertionDialog extends StatefulWidget {
  const _AddAssertionDialog({
    required this.intakeId,
    required this.expectedGraphDigest,
    required this.defaultEventTime,
    required this.copy,
  });

  final String intakeId;
  final String expectedGraphDigest;
  final DateTime defaultEventTime;
  final _ReconciliationCopy copy;

  @override
  State<_AddAssertionDialog> createState() => _AddAssertionDialogState();
}

class _AddAssertionDialogState extends State<_AddAssertionDialog> {
  final _sourceController = TextEditingController();
  final _revisionController = TextEditingController(text: '1');
  final _doseController = TextEditingController();
  MedicationAssertionEvidenceClass _evidenceClass =
      MedicationAssertionEvidenceClass.userStatement;
  MedicationAssertionStatus _status = MedicationAssertionStatus.unknown;
  late DateTime _eventTime;
  bool _eventTimeKnown = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _eventTime = widget.defaultEventTime;
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _revisionController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  Future<void> _pickEventTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventTime),
    );
    if (time == null) return;
    setState(() {
      _eventTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving || _sourceController.text.trim().isEmpty) return;
    final parsed = DosageNoteParser().inspect(_doseController.text.trim());
    if (_doseController.text.trim().isNotEmpty && !parsed.accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.copy.invalidDose)));
      return;
    }
    setState(() => _saving = true);
    final expression = parsed.expression;
    final state = context.read<AppState>();
    final result = await state.appendMedicationAssertion(
      intakeId: widget.intakeId,
      expectedGraphDigest: widget.expectedGraphDigest,
      evidenceClass: _evidenceClass,
      status: _status,
      actorRole: _roleFor(_evidenceClass),
      sourceLabel: _sourceController.text,
      sourceRevision: _revisionController.text,
      doseValue: expression?.value,
      doseUnit: expression?.unit.code,
      effectiveStart: _eventTimeKnown ? _eventTime : null,
      effectiveEnd: _eventTimeKnown ? _eventTime : null,
      timePrecision: _eventTimeKnown
          ? MedicationAssertionTimePrecision.minute
          : MedicationAssertionTimePrecision.unknown,
      timeUncertaintyMinutes: _eventTimeKnown ? 1 : 0,
      timezoneOffsetMinutes: _eventTimeKnown
          ? _eventTime.timeZoneOffset.inMinutes
          : null,
      timezoneSource: _eventTimeKnown
          ? MedicationAssertionTimezoneSource.deviceLocal
          : MedicationAssertionTimezoneSource.unknown,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.copy.stale)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.copy.addSource),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MedicationAssertionEvidenceClass>(
              key: const ValueKey<String>('assertion-evidence-class'),
              isExpanded: true,
              initialValue: _evidenceClass,
              decoration: InputDecoration(labelText: widget.copy.sourceType),
              items: MedicationAssertionEvidenceClass.values
                  .where(
                    (value) =>
                        value !=
                        MedicationAssertionEvidenceClass.localUserConfirmation,
                  )
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        widget.copy.evidenceLabel(value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _evidenceClass = value!),
            ),
            TextField(
              key: const ValueKey<String>('assertion-source-label'),
              controller: _sourceController,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: widget.copy.sourceLabel,
                helperText: widget.copy.sourceLabelHint,
              ),
            ),
            TextField(
              controller: _revisionController,
              decoration: InputDecoration(labelText: widget.copy.revision),
            ),
            TextField(
              key: const ValueKey<String>('assertion-dose'),
              controller: _doseController,
              decoration: InputDecoration(labelText: widget.copy.optionalDose),
            ),
            DropdownButtonFormField<MedicationAssertionStatus>(
              isExpanded: true,
              initialValue: _status,
              decoration: InputDecoration(labelText: widget.copy.status),
              items: MedicationAssertionStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        widget.copy.statusLabel(value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _status = value!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _eventTimeKnown,
              title: Text(widget.copy.eventTimeKnown),
              onChanged: (value) => setState(() => _eventTimeKnown = value),
            ),
            if (_eventTimeKnown)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(widget.copy.eventTime),
                subtitle: Text(_eventTime.toString().split('.').first),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickEventTime,
              ),
            Text(widget.copy.boundary),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: Text(widget.copy.cancel),
      ),
      FilledButton(
        key: const ValueKey<String>('save-medication-assertion'),
        onPressed: _saving ? null : _save,
        child: Text(widget.copy.save),
      ),
    ],
  );

  MedicationAssertionActorRole _roleFor(
    MedicationAssertionEvidenceClass value,
  ) => switch (value) {
    MedicationAssertionEvidenceClass.userStatement ||
    MedicationAssertionEvidenceClass.packageDerived =>
      MedicationAssertionActorRole.user,
    MedicationAssertionEvidenceClass.caregiverStatement =>
      MedicationAssertionActorRole.caregiver,
    MedicationAssertionEvidenceClass.prescriptionRequest ||
    MedicationAssertionEvidenceClass.formalAdministration =>
      MedicationAssertionActorRole.clinician,
    MedicationAssertionEvidenceClass.dispenseRecord =>
      MedicationAssertionActorRole.pharmacist,
    MedicationAssertionEvidenceClass.deviceObservation =>
      MedicationAssertionActorRole.device,
    MedicationAssertionEvidenceClass.importedStatement =>
      MedicationAssertionActorRole.importer,
    MedicationAssertionEvidenceClass.localUserConfirmation =>
      MedicationAssertionActorRole.user,
  };
}

final class _ReconciliationCopy {
  const _ReconciliationCopy({required this.zh});

  final bool zh;

  factory _ReconciliationCopy.forFamily(String family) =>
      _ReconciliationCopy(zh: family == 'zh');

  String get title => zh ? '药物来源与时间核对' : 'Medication source and time review';
  String get missing => zh ? '该记录已不存在。' : 'This record no longer exists.';
  String get sources => zh ? '来源陈述' : 'Source assertions';
  String get relationships =>
      zh ? '来源关系与冲突' : 'Source relationships and conflicts';
  String get noSources => zh ? '尚无来源陈述。' : 'No source assertions yet.';
  String get noRelationships => zh ? '尚无来源关系。' : 'No source relationships yet.';
  String get modelHeld => zh ? '剂量已暂停进入算法' : 'Dose is held from algorithms';
  String get modelEligible =>
      zh ? '剂量可用于算法结果' : 'Dose is eligible for algorithm result use';
  String get assertionSubgateHeld =>
      zh ? '断言子门：存在未决阻断' : 'Assertion subgate: unresolved blocker';
  String get assertionSubgateEligible =>
      zh ? '断言子门：无未决冲突' : 'Assertion subgate: no unresolved conflict';
  String get addSource => zh ? '添加另一来源' : 'Add another source';
  String get acknowledgeConflict =>
      zh ? '确认已查看冲突' : 'Acknowledge reviewed conflicts';
  String get confirmReviewed => zh ? '确认已核对' : 'Confirm review';
  String get hold => zh ? '保留待核对' : 'Hold for review';
  String get stale =>
      zh ? '记录已变化，请重新查看。' : 'The record changed. Review it again.';
  String get saved => zh ? '核对决定已追加保存。' : 'Review decision appended.';
  String get decisionRecorded =>
      zh ? '当前图版本已有核对决定。' : 'This graph revision has a review decision.';
  String get boundary => zh
      ? '这些是不同来源的陈述，不代表处方正确、实际服药或临床核对。查看冲突不会删除任何陈述，也不会自动解除算法暂停。'
      : 'These are source assertions, not proof of a valid prescription, actual administration, adherence, or clinical reconciliation. Reviewing a conflict never deletes a claim or automatically releases a held algorithm input.';
  String get eventTime => zh ? '事件时间' : 'Event time';
  String get assertedTime => zh ? '断言时间' : 'Assertion time';
  String get importedTime => zh ? '导入时间' : 'Import time';
  String get recordedTime => zh ? '记录时间' : 'Recorded time';
  String get precision => zh ? '时间精度' : 'Time precision';
  String get dose => zh ? '来源剂量' : 'Source dose';
  String get status => zh ? '来源状态' : 'Source status';
  String get actor => zh ? '来源角色' : 'Source role';
  String get revision => zh ? '来源修订' : 'Source revision';
  String get unknown => zh ? '未知' : 'Unknown';
  String get notApplicable => zh ? '不适用' : 'Not applicable';
  String get sourceType => zh ? '来源类别' : 'Source type';
  String get sourceLabel => zh ? '来源名称' : 'Source name';
  String get sourceLabelHint => zh
      ? '用简短通用名称，例如“患者门户记录”；不要填写姓名等个人信息。'
      : 'Use a short generic label, such as “patient portal record”; do not enter personal identifiers.';
  String get optionalDose =>
      zh ? '可选剂量，例如 100 mg' : 'Optional dose, for example 100 mg';
  String get eventTimeKnown =>
      zh ? '来源给出了事件时间' : 'Source includes an event time';
  String get invalidDose =>
      zh ? '剂量表达式无法明确识别。' : 'The dose expression is ambiguous or unsupported.';
  String get cancel => zh ? '取消' : 'Cancel';
  String get save => zh ? '追加来源' : 'Append source';
  String get bitemporalTitle => zh ? '历史证据视图' : 'Historical evidence view';
  String get bitemporalHelp => zh
      ? '分别选择要查看的用药事件时间和当时已知信息的截止时间。时间均按 UTC 解释。'
      : 'Choose the medication event time and the separate cutoff for what was known then. Both timestamps use UTC.';
  String get validAt => zh ? '事件时间' : 'Event time';
  String get knownAt => zh ? '已知时间截止' : 'Known-by cutoff';
  String get utcTime => zh ? 'UTC 时间' : 'UTC time';
  String get knownAtEvent => zh ? '按事件时间查看已知证据' : 'Set cutoff to event time';
  String get knownAtNow => zh ? '按当前时间查看' : 'Set cutoff to now';
  String get projectHistory => zh ? '查看历史证据' : 'View historical evidence';
  String get historyChanged => zh
      ? '来源记录已变化；请重新生成历史视图。'
      : 'Source records changed. Run the historical view again.';
  String get hiddenAtCutoff =>
      zh ? '此截止时间下不显示来源详情。' : 'Source details are hidden at this cutoff.';
  String get noHistoricalAssertions => zh
      ? '所选时间下没有可列出的来源陈述。'
      : 'No source assertions are listed for these cutoffs.';
  String get reviewDecision => zh ? '核对决定' : 'Review decision';
  String get bitemporalBoundary => zh
      ? '这是只读来源证据视图，不证明实际服药或临床核对结果，也不会改变当前剂量是否可进入算法。'
      : 'This is a read-only evidence view. It does not prove medication use or clinical reconciliation and does not change current dose eligibility.';
  String get noHistoricalRelationships => zh
      ? '该时间视图中没有可展示的来源关系。'
      : 'No source relationships are present in this view.';
  String get aggregateIntegrityTimeUnknown => zh
      ? '当前来源快照存在一项无可信知晓时间的聚合级用药证据完整性标记。无法判断它在所选截止时是否已存在；该标记未纳入历史关系图，因此本次投影不完整。'
      : 'The current source snapshot contains an aggregate medication-evidence integrity marker without a trustworthy knowledge time. Whether it existed by this cutoff is unknown; it is excluded from the historical graph, so this projection is incomplete.';

  String historicalGraphSummary(
    int nodes,
    int edges,
    int blocking,
    int integrity,
    int stale,
  ) => zh
      ? '当时的关系图：$nodes 条已知来源 · $edges 条关系 · $blocking 条阻断关系 · $integrity 项完整性问题 · $stale 条旧版核对决定。'
      : 'Historical graph: $nodes known sources · $edges relationships · $blocking blocking relationships · $integrity integrity findings · $stale stale review decisions.';

  String projectionSummary(
    int available,
    int withheld,
    int withinInterval,
    int uncertainTime,
    int decisions,
  ) => zh
      ? '截止时已知 $available 条来源陈述；隐藏 $withheld 条；$withinInterval 条记录区间覆盖所选事件时间；$uncertainTime 条时间关系不确定；当时可见 $decisions 条核对决定。'
      : '$available source assertions were available by the cutoff; $withheld hidden; $withinInterval recorded intervals cover the selected event time; $uncertainTime have uncertain event time; $decisions review decisions were available.';

  String integrityFindingCount(int count) => zh
      ? '有 $count 项来源完整性问题；相关详情已保留为受限状态。'
      : '$count source-integrity findings remain; affected details stay restricted.';

  String knowledgeStatusLabel(MedicationAssertionKnowledgeStatus status) =>
      switch (status) {
        MedicationAssertionKnowledgeStatus.availableAtCutoff =>
          zh ? '截止时已知' : 'Available by cutoff',
        MedicationAssertionKnowledgeStatus.afterKnowledgeCutoff =>
          zh ? '晚于已知时间截止' : 'After knowledge cutoff',
        MedicationAssertionKnowledgeStatus.unresolvedKnowledgeTime =>
          zh ? '导入时间不明' : 'Import time unresolved',
        MedicationAssertionKnowledgeStatus.invalidEvidence =>
          zh ? '来源完整性未通过' : 'Source integrity not established',
      };

  String validTimeStatusLabel(MedicationAssertionValidTimeStatus status) =>
      switch (status) {
        MedicationAssertionValidTimeStatus.inEffectiveInterval =>
          zh ? '记录区间覆盖所选事件时间' : 'Recorded interval covers event time',
        MedicationAssertionValidTimeStatus.outsideEffectiveInterval =>
          zh ? '记录区间不覆盖所选事件时间' : 'Recorded interval excludes event time',
        MedicationAssertionValidTimeStatus.uncertainEffectiveTime =>
          zh ? '事件时间关系不确定' : 'Event-time relation is uncertain',
        MedicationAssertionValidTimeStatus.notEvaluated =>
          zh ? '未评估事件时间' : 'Event time not evaluated',
      };

  String resolutionLabel(MedicationReconciliationResolution resolution) =>
      switch (resolution) {
        MedicationReconciliationResolution.confirmedNoConflict =>
          zh ? '用户记录：当时未见冲突' : 'Owner recorded no conflict at review',
        MedicationReconciliationResolution.acknowledgedUnresolved =>
          zh ? '用户记录：已查看未决冲突' : 'Owner acknowledged unresolved conflict',
        MedicationReconciliationResolution.heldForReview =>
          zh ? '用户记录：保留待核对' : 'Owner held the graph for review',
      };

  String summary(int nodes, int conflicts, int stale) => zh
      ? '$nodes 条来源陈述 · $conflicts 条未决关系 · $stale 条旧版核对决定'
      : '$nodes source assertions · $conflicts unresolved relationships · $stale stale review decisions';

  String resultReasons(List<String> reasons) => zh
      ? '组合结果门原因：${reasons.join('，')}'
      : 'Combined result-gate reasons: ${reasons.join(', ')}';

  String assertionReasons(List<String> reasons) => zh
      ? '断言子门原因：${reasons.join('，')}'
      : 'Assertion subgate reasons: ${reasons.join(', ')}';

  String evidenceLabel(MedicationAssertionEvidenceClass value) =>
      switch (value) {
        MedicationAssertionEvidenceClass.localUserConfirmation =>
          zh ? '本地用户确认' : 'Local user confirmation',
        MedicationAssertionEvidenceClass.userStatement =>
          zh ? '用户陈述' : 'User statement',
        MedicationAssertionEvidenceClass.caregiverStatement =>
          zh ? '照护者陈述' : 'Caregiver statement',
        MedicationAssertionEvidenceClass.packageDerived =>
          zh ? '包装推导陈述' : 'Package-derived statement',
        MedicationAssertionEvidenceClass.importedStatement =>
          zh ? '导入的用药陈述' : 'Imported medication statement',
        MedicationAssertionEvidenceClass.prescriptionRequest =>
          zh ? '处方或医嘱记录' : 'Prescription or request record',
        MedicationAssertionEvidenceClass.dispenseRecord =>
          zh ? '发药记录' : 'Dispense record',
        MedicationAssertionEvidenceClass.deviceObservation =>
          zh ? '设备观察' : 'Device observation',
        MedicationAssertionEvidenceClass.formalAdministration =>
          zh ? '正式给药记录标签' : 'Formal administration record label',
      };

  String statusLabel(MedicationAssertionStatus value) => switch (value) {
    MedicationAssertionStatus.taken => zh ? '来源称已服用' : 'Source says taken',
    MedicationAssertionStatus.notTaken =>
      zh ? '来源称未服用' : 'Source says not taken',
    MedicationAssertionStatus.unknown => zh ? '来源未知' : 'Source is unknown',
    MedicationAssertionStatus.enteredInError =>
      zh ? '来源标记录入错误' : 'Source marks entered in error',
  };

  String roleLabel(MedicationAssertionActorRole value) => switch (value) {
    MedicationAssertionActorRole.user => zh ? '用户' : 'User',
    MedicationAssertionActorRole.caregiver => zh ? '照护者' : 'Caregiver',
    MedicationAssertionActorRole.clinician =>
      zh ? '临床人员标签' : 'Clinician role label',
    MedicationAssertionActorRole.pharmacist =>
      zh ? '药师标签' : 'Pharmacist role label',
    MedicationAssertionActorRole.device => zh ? '设备' : 'Device',
    MedicationAssertionActorRole.importer => zh ? '导入器' : 'Importer',
    MedicationAssertionActorRole.organization =>
      zh ? '机构标签' : 'Organization role label',
    MedicationAssertionActorRole.unknown => zh ? '未知角色' : 'Unknown role',
  };

  String relationshipLabel(
    MedicationAssertionRelationship value,
  ) => switch (value) {
    MedicationAssertionRelationship.duplicate =>
      zh ? '重复陈述' : 'Duplicate assertion',
    MedicationAssertionRelationship.corroborates =>
      zh ? '相互印证但不证明' : 'Corroborates without proving',
    MedicationAssertionRelationship.doseConflict =>
      zh ? '剂量冲突' : 'Dose conflict',
    MedicationAssertionRelationship.timeConflict =>
      zh ? '时间冲突' : 'Time conflict',
    MedicationAssertionRelationship.productConflict =>
      zh ? '产品冲突' : 'Product conflict',
    MedicationAssertionRelationship.statusConflict =>
      zh ? '服用状态冲突' : 'Status conflict',
    MedicationAssertionRelationship.partialOverlap =>
      zh ? '时间区间部分重叠' : 'Partially overlapping times',
    MedicationAssertionRelationship.sourceRevisionConflict =>
      zh ? '来源修订冲突' : 'Source revision conflict',
    MedicationAssertionRelationship.supersedes => zh ? '后续陈述取代' : 'Supersedes',
    MedicationAssertionRelationship.retracts => zh ? '撤回' : 'Retracts',
    MedicationAssertionRelationship.derivedFrom => zh ? '来源派生' : 'Derived from',
    MedicationAssertionRelationship.futureDated => zh ? '未来时间' : 'Future-dated',
    MedicationAssertionRelationship.clockSkew =>
      zh ? '时钟顺序异常' : 'Clock-order conflict',
    MedicationAssertionRelationship.timezoneAmbiguous =>
      zh ? '时区不明确' : 'Timezone ambiguous',
    MedicationAssertionRelationship.unresolvedCandidateMatch =>
      zh ? '候选事件无法确定匹配' : 'Unresolved event match',
  };
}
