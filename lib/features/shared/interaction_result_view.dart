import 'package:flutter/material.dart';

import '../../core/copy/response_copy_service.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/interaction_result.dart';
import 'mechanistic_trace_view.dart';

/// Neutral accent for results that cannot be assessed yet. Never green: a
/// missing input is not an all-clear.
const Color interactionAwaitingInputsColor = Colors.blueGrey;

/// Accent for a stored result. A result that only awaits missing inputs is
/// shown neutrally; its stored severity and score are unchanged.
Color interactionResultColor(
  InteractionResult result,
  ResponseCopyService copy,
) {
  return copy.awaitingMissingInputs(result)
      ? interactionAwaitingInputsColor
      : interactionSeverityColor(result.overallSeverity);
}

Color interactionSeverityColor(InteractionSeverity? severity) {
  switch (severity) {
    case null:
      return Colors.blueGrey;
    case InteractionSeverity.low:
      return Colors.green;
    case InteractionSeverity.moderate:
      return Colors.orange;
    case InteractionSeverity.high:
      return Colors.red;
  }
}

String interactionSeverityLabel(
  BuildContext context,
  InteractionSeverity? severity,
) {
  final i18n = context.appI18n;
  switch (severity) {
    case null:
      return i18n.tr('interaction.unassessed');
    case InteractionSeverity.low:
      return i18n.tr('interaction.low');
    case InteractionSeverity.moderate:
      return i18n.tr('interaction.moderate');
    case InteractionSeverity.high:
      return i18n.tr('interaction.high');
  }
}

class InteractionSummaryCard extends StatelessWidget {
  final InteractionResult result;

  final bool showEvidenceEntry;
  const InteractionSummaryCard({
    super.key,
    required this.result,
    this.showEvidenceEntry = true,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final copy = ResponseCopyService(i18n: i18n);
    // Missing dose or time is shown as "can't assess yet", not as a risk
    // level. The stored score and rule decisions stay under "How was this
    // computed?".
    final awaiting = copy.awaitingMissingInputs(result);
    final accent = interactionResultColor(result, copy);
    final hasComputationDetail =
        result.score != null ||
        result.scoreFactors.isNotEmpty ||
        result.keyFindings.isNotEmpty ||
        result.dataNotes.isNotEmpty ||
        result.mechanisticTraceJson != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Icon(
                result.hasAssessment && !awaiting
                    ? Icons.shield_outlined
                    : Icons.info_outline,
                color: accent,
              ),
              Text(
                awaiting
                    ? copy.awaitingInputsHeadline(result)
                    : interactionSeverityLabel(context, result.overallSeverity),
                key: const Key('interaction-status-label'),
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
              if (result.score != null && !awaiting)
                Text(
                  i18n.tr('interaction.score', {'value': '${result.score}'}),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(copy.interactionSummary(result)),
          if (showEvidenceEntry)
            TextButton.icon(
              key: const Key('interaction-evidence-and-missing'),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                i18n.languageFamily == 'zh'
                    ? '依据与缺失信息'
                    : 'Evidence and missing information',
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(
                    i18n.languageFamily == 'zh'
                        ? '依据与缺失信息'
                        : 'Evidence and missing information',
                  ),
                  content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                      child: InteractionSummaryCard(
                        result: result,
                        showEvidenceEntry: false,
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(i18n.tr('common.close')),
                    ),
                  ],
                ),
              ),
            ),
          if (result.analysisText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              i18n.tr('interaction.analysis_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(copy.interactionAnalysis(result)),
          ],
          if (result.nextActions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              i18n.tr('interaction.next_actions'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final action in result.nextActions.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${copy.nextAction(action)}'),
              ),
          ],
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final issue in result.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _IssueTile(
                  issue: issue,
                  awaitingInputs:
                      awaiting && copy.issueAwaitsMissingInputs(issue),
                ),
              ),
          ],
          if (hasComputationDetail)
            _ComputationDetails(
              result: result,
              awaiting: awaiting,
              initiallyExpanded: !showEvidenceEntry,
            ),
        ],
      ),
    );
  }
}

/// Engine detail behind "How was this computed?": the stored rule score, its
/// weighted factors, raw findings, data notes and the educational trace.
class _ComputationDetails extends StatelessWidget {
  final InteractionResult result;
  final bool awaiting;
  final bool initiallyExpanded;

  const _ComputationDetails({
    required this.result,
    required this.awaiting,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final copy = ResponseCopyService(i18n: i18n);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('interaction-how-computed'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          i18n.tr('interaction.how_computed'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          if (result.score != null)
            Text(
              i18n.tr('interaction.how_computed_score', {
                'score': '${result.score}',
              }),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          if (awaiting) ...[
            const SizedBox(height: 4),
            Text(i18n.tr('interaction.how_computed_awaiting_note')),
          ] else if (result.score != null) ...[
            const SizedBox(height: 4),
            Text(i18n.tr('interaction.how_computed_points_note')),
          ],
          if (result.scoreFactors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final factor in result.scoreFactors)
                  _ScoreFactorChip(factor: factor),
              ],
            ),
          ],
          if (result.keyFindings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              i18n.tr('interaction.key_findings'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final finding in result.keyFindings.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${copy.keyFinding(finding)}'),
              ),
          ],
          if (result.dataNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              i18n.tr('interaction.data_notes'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final note in result.dataNotes.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${copy.dataNote(note)}'),
              ),
          ],
          if (result.mechanisticTraceJson != null) ...[
            const SizedBox(height: 12),
            MechanisticConflictTraceCard(result: result),
          ],
        ],
      ),
    );
  }
}

class _ScoreFactorChip extends StatelessWidget {
  final InteractionScoreFactor factor;

  const _ScoreFactorChip({required this.factor});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '${factor.label} +${factor.points}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final InteractionIssue issue;

  /// The issue only reflects missing inputs and the whole result is shown as
  /// "can't assess yet".
  final bool awaitingInputs;

  const _IssueTile({required this.issue, this.awaitingInputs = false});

  @override
  Widget build(BuildContext context) {
    final accent = awaitingInputs
        ? interactionAwaitingInputsColor
        : interactionSeverityColor(issue.severity);
    final i18n = context.appI18n;
    final copy = ResponseCopyService(i18n: i18n);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${awaitingInputs ? i18n.tr('interaction.awaiting_inputs_short') : interactionSeverityLabel(context, issue.severity)} · ${copy.issueTitle(issue.title)}',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(copy.issueDetail(issue)),
          if (issue.evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              i18n.tr('interaction.evidence_count', {
                'count': '${issue.evidence.length}',
              }),
              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final evidence in issue.evidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EvidenceCard(evidence: evidence),
              ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final InteractionEvidence evidence;

  const _EvidenceCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evidence.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (evidence.pmid != null && evidence.pmid!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              '${i18n.tr('interaction.evidence_pmid')}: ${evidence.pmid}',
            ),
          ],
          if (evidence.publication != null &&
              evidence.publication!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            SelectableText(
              '${i18n.tr('interaction.evidence_publication')}: ${evidence.publication}',
            ),
          ],
          if (evidence.evidenceKind != null &&
              evidence.evidenceKind!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            SelectableText(
              '${i18n.tr('interaction.evidence_kind')}: ${evidence.evidenceKind}',
            ),
          ],
          if (evidence.sourceFamily != null &&
              evidence.sourceFamily!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            SelectableText(
              '${i18n.tr('interaction.evidence_source_family')}: ${evidence.sourceFamily}',
            ),
          ],
          if (evidence.doi != null && evidence.doi!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            SelectableText(
              '${i18n.tr('interaction.evidence_doi')}: ${evidence.doi}',
            ),
          ],
          if (evidence.sourceUrl != null &&
              evidence.sourceUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              i18n.tr('interaction.evidence_link'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            SelectableText(evidence.sourceUrl!),
          ],
        ],
      ),
    );
  }
}
