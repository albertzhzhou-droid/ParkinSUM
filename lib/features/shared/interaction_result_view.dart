import 'package:flutter/material.dart';

import '../../core/copy/response_copy_service.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/models/interaction_result.dart';
import 'mechanistic_trace_view.dart';

Color interactionSeverityColor(InteractionSeverity severity) {
  switch (severity) {
    case InteractionSeverity.low:
      return Colors.green;
    case InteractionSeverity.moderate:
      return Colors.orange;
    case InteractionSeverity.high:
      return Colors.red;
  }
}

String interactionSeverityLabel(
    BuildContext context, InteractionSeverity severity) {
  final i18n = context.appI18n;
  switch (severity) {
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

  const InteractionSummaryCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final accent = interactionSeverityColor(result.overallSeverity);
    final i18n = context.appI18n;
    final copy = ResponseCopyService(i18n: i18n);

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
          Row(
            children: [
              Icon(Icons.shield_outlined, color: accent),
              const SizedBox(width: 8),
              Text(
                interactionSeverityLabel(context, result.overallSeverity),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                i18n.tr('interaction.score', {'value': '${result.score}'}),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(copy.interactionSummary(result)),
          if (result.scoreFactors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final factor in result.scoreFactors.take(4))
                  _ScoreFactorChip(factor: factor),
              ],
            ),
          ],
          if (result.analysisText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              i18n.tr('interaction.analysis_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(copy.interactionAnalysis(result)),
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
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final issue in result.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _IssueTile(issue: issue),
              ),
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

  const _IssueTile({required this.issue});

  @override
  Widget build(BuildContext context) {
    final accent = interactionSeverityColor(issue.severity);
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
            '${interactionSeverityLabel(context, issue.severity)} · ${copy.issueTitle(issue.title)}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(copy.issueDetail(issue)),
          if (issue.evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              i18n.tr(
                'interaction.evidence_count',
                {'count': '${issue.evidence.length}'},
              ),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
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
