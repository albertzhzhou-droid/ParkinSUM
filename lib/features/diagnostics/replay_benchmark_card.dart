import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';

/// Developer tool: re-runs the fixed recommendation replay scenarios through
/// deterministic ranking and the optional AI rerank, and shows the raw report.
///
/// Lives in Engineering diagnostics (it used to sit on the user-facing
/// Analytics page, where a raw benchmark read as an unfinished app).
class ReplayBenchmarkCard extends StatelessWidget {
  const ReplayBenchmarkCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final report = state.latestReplayBenchmarkReport;
    final error = state.latestReplayBenchmarkError;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperSectionHeader(
            title: i18n.tr('analytics.replay_benchmark'),
            subtitle: i18n.tr('analytics.replay_benchmark_help'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.isRunningReplayBenchmark
                ? null
                : () => context
                      .read<AppState>()
                      .runRecommendationReplayBenchmark(),
            icon: const Icon(Icons.play_circle_outline),
            label: Text(
              state.isRunningReplayBenchmark
                  ? i18n.tr('analytics.replay_running')
                  : i18n.tr('analytics.replay_run'),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            PaperNote(
              tone: PaperTone.danger,
              icon: Icons.error_outline_rounded,
              child: Text(
                i18n.tr('analytics.replay_report_error', {'error': error}),
              ),
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 14),
            Text(
              i18n.tr('analytics.replay_last_report'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${report.datasetVersion} · ${report.generatedAtIso} · '
              '${i18n.tr('analytics.replay_cases', {'count': '${report.cases.length}'})}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Paper.surfaceSunken,
                borderRadius: BorderRadius.circular(Paper.radiusMd),
                border: Border.all(color: Paper.border),
              ),
              child: SelectableText(
                report.toMarkdown(),
                style: const TextStyle(
                  fontFamily: Paper.mono,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
