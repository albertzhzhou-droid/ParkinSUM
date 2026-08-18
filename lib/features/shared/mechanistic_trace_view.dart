/// Compact, presentational widgets for rendering deterministic mechanistic
/// engine output in the UI. These widgets never construct prescriptive
/// copy — every string field comes directly from the model or from the
/// compiler-validated boundary copy resolved by `ExplanationCopyService`
/// (which falls back to the banned-phrase-safe `RuleExplanation` defaults).
///
/// Layout philosophy:
/// - Use one `GlassCard` per trace section.
/// - Show typed band chips, not raw JSON.
/// - Hide everything behind an `ExpansionTile` so the section stays
///   collapsed by default and doesn't clutter the existing UI.
library;

import 'package:flutter/material.dart';

import '../../core/models/interaction_result.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/mechanistic_candidate_score.dart';
import '../../domain/entities/mechanistic_conflict_result.dart';
import '../../domain/usecases/explanation_copy_service.dart';
import '../../domain/usecases/model_assumption_registry.dart';

/// Renders a single `InteractionResult`'s mechanistic trace as a compact
/// card. Pass the result; the card no-ops when `mechanisticTraceJson` is
/// null.
class MechanisticConflictTraceCard extends StatelessWidget {
  final InteractionResult? result;
  final MechanisticConflictResult? typedResult;
  final String sectionTitle;

  const MechanisticConflictTraceCard({
    super.key,
    this.result,
    this.typedResult,
    this.sectionTitle = 'Model trace (educational)',
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? trace;
    if (result != null) trace = result!.mechanisticTraceJson;
    trace ??= typedResult?.toJson();
    if (trace == null) return const SizedBox.shrink();
    final view = MechanisticTraceViewModel.fromJson(trace);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          sectionTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Interaction score ${view.scoreText} · severity ${view.severityLabel} · confidence ${view.confidenceLabel}',
          style: const TextStyle(
            color: LiquidGlass.onSurfaceMuted,
            fontSize: 12,
          ),
        ),
        children: [_TraceBody(view: view)],
      ),
    );
  }
}

/// Renders one `MechanisticCandidateScore` as a single compact tile. Use
/// inside a `Column` / `ListView` next to the existing candidate cards.
class MechanisticCandidateScoreLine extends StatelessWidget {
  final MechanisticCandidateScore score;

  const MechanisticCandidateScoreLine({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final view = MechanisticCandidateScoreViewModel.fromScore(score);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  score.candidateName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _BandChip(label: 'conf ${view.confidenceLabel}'),
            ],
          ),
          const SizedBox(height: 6),
          if (view.insufficientContext)
            Text(
              view.firstExplanationLine,
              style: const TextStyle(color: LiquidGlass.onSurfaceMuted),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _BandChip(label: 'worst ${view.worstPctText}'),
                _BandChip(label: 'best ${view.bestPctText}'),
                _BandChip(label: 'avg ${view.avgPctText}'),
                _BandChip(label: 'samples ${view.sampleCount}'),
                _BandChip(label: 'protein-window ${view.proteinWindowRole}'),
                _BandChip(
                  label: 'redistribution ${view.redistributionPctText}',
                ),
                _BandChip(label: 'aa-mode ${view.aminoAcidDataMode}'),
                _BandChip(label: 'src ${view.sourceSystem}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              view.firstExplanationLine,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            score.notAdviceText,
            style: const TextStyle(
              fontSize: 11,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceBody extends StatelessWidget {
  final MechanisticTraceViewModel view;
  const _TraceBody({required this.view});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _BandChip(label: 'score ${view.scoreText}'),
            _BandChip(label: 'severity ${view.severityLabel}'),
            _BandChip(label: 'confidence ${view.confidenceLabel}'),
          ],
        ),
        const SizedBox(height: 10),
        if (view.primaryDrivers.isNotEmpty) ...[
          const Text(
            'Primary modeled drivers',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            view.primaryDrivers.join(', '),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],
        if (view.modeledWindowsLabel.isNotEmpty) ...[
          const Text(
            'Modeled timeline windows',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(view.modeledWindowsLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
        ],
        if (view.missingInputs.isNotEmpty) ...[
          const Text(
            'Missing or uncertain inputs',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            view.missingInputs.take(3).join(', '),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          view.limitationText,
          style: const TextStyle(
            fontSize: 11,
            color: LiquidGlass.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          view.safetyBoundary,
          style: const TextStyle(
            fontSize: 11,
            color: LiquidGlass.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          view.notAdviceText,
          style: const TextStyle(
            fontSize: 11,
            color: LiquidGlass.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          view.sourceRefsLabel,
          style: const TextStyle(
            fontSize: 11,
            color: LiquidGlass.onSurfaceMuted,
          ),
        ),
        // Each source's title and — crucially — what it does *not* establish.
        // The registry has always carried this copy; nothing displayed it.
        for (final source in view.resolvedSources)
          _SourceRefLine(source: source),
      ],
    );
  }
}

class _SourceRefLine extends StatelessWidget {
  final ResolvedSourceRef source;
  const _SourceRefLine({required this.source});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ${source.title}'
            '${source.resolved ? ' (${source.evidenceLevel})' : ' (unresolved reference)'}',
            style: const TextStyle(
              fontSize: 11,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
          if (source.limitation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 2),
              child: Text(
                'Limitation: ${source.limitation}',
                style: const TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: LiquidGlass.onSurfaceMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  final String label;
  const _BandChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

// -----------------------------------------------------------------------------
// View models. Pure Dart — no Flutter imports — so they're easy to test.
// -----------------------------------------------------------------------------

/// A `sourceRef` id resolved against [ModelAssumptionRegistry].
///
/// The trace used to render bare ids and a count ("Sources (3) available in
/// model trace"), which told the reader provenance existed without showing any
/// of it — while the registry already carried a title, a citation, and a
/// plain-language limitation for each id.
///
/// An id that does not resolve is surfaced as itself with [resolved] false,
/// never hidden: an unresolvable reference is information about the trace, not
/// noise to suppress.
class ResolvedSourceRef {
  final String sourceRef;
  final String title;

  /// Plain-language statement of what this source does *not* establish.
  /// Empty when the id did not resolve.
  final String limitation;

  final String evidenceLevel;
  final bool resolved;

  const ResolvedSourceRef({
    required this.sourceRef,
    required this.title,
    required this.limitation,
    required this.evidenceLevel,
    required this.resolved,
  });

  /// Resolves [sourceRef] through the registry, preserving unknown ids.
  factory ResolvedSourceRef.resolve(String sourceRef) {
    final assumption = ModelAssumptionRegistry.byId(sourceRef);
    if (assumption == null) {
      return ResolvedSourceRef(
        sourceRef: sourceRef,
        title: sourceRef,
        limitation: '',
        evidenceLevel: 'unresolved',
        resolved: false,
      );
    }
    return ResolvedSourceRef(
      sourceRef: sourceRef,
      title: assumption.title,
      limitation: assumption.limitation,
      evidenceLevel: assumption.evidenceLevel.name,
      resolved: true,
    );
  }
}

class MechanisticTraceViewModel {
  final String scoreText;
  final String severityLabel;
  final String confidenceLabel;
  final List<String> primaryDrivers;
  final String modeledWindowsLabel;
  final List<String> missingInputs;
  final String limitationText;
  final String safetyBoundary;
  final String notAdviceText;
  final String sourceRefsLabel;

  /// The trace's source refs resolved to titles + limitations. Order follows
  /// the emitted `source_refs`, so the display is deterministic.
  final List<ResolvedSourceRef> resolvedSources;

  const MechanisticTraceViewModel({
    required this.scoreText,
    required this.severityLabel,
    required this.confidenceLabel,
    required this.primaryDrivers,
    required this.modeledWindowsLabel,
    required this.missingInputs,
    required this.limitationText,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.sourceRefsLabel,
    this.resolvedSources = const <ResolvedSourceRef>[],
  });

  factory MechanisticTraceViewModel.fromJson(Map<String, dynamic> json) {
    final score = (json['interaction_score'] as num?)?.toDouble() ?? 0;
    final severity = (json['severity_band'] as String?) ?? 'unknown';
    final confidence = (json['confidence_band'] as String?) ?? 'insufficient';
    final drivers = (json['primary_drivers'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList(growable: false);
    final windows =
        (json['modeled_timeline_windows'] as List<dynamic>? ?? const [])
            .map((w) {
              if (w is! Map) return '';
              final start = (w['start_minute'] as num?)?.toInt() ?? 0;
              final end = (w['end_minute'] as num?)?.toInt() ?? 0;
              final relStart = end - start; // duration
              return '${end - relStart - start}–${end - start} min';
            })
            .where((s) => s.isNotEmpty)
            .take(2)
            .toList(growable: false);
    final missing = (json['uncertainty_reasons'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final limitation = (json['limitation_text'] as String?) ?? '';
    // Boundary copy: prefer the model's emitted text; otherwise source the
    // default boundary/not-advice copy through the compiler-validated
    // SafeCopyTemplate registry (ExplanationCopyService), which itself falls
    // back to the canonical `RuleExplanation` defaults if a template is absent.
    const copy = ExplanationCopyService();
    final safety =
        (json['safety_boundary'] as String?) ?? copy.safetyBoundary();
    final notAdvice = (json['not_advice_text'] as String?) ?? copy.notAdvice();
    final refs = (json['source_refs'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final resolvedSources = refs
        .map(ResolvedSourceRef.resolve)
        .toList(growable: false);
    final unresolvedCount = resolvedSources.where((s) => !s.resolved).length;
    // The count is still useful, but it is no longer the only thing shown —
    // the resolved titles and limitations render below it.
    final refsLabel = refs.isEmpty
        ? 'Sources: none recorded.'
        : 'Sources (${refs.length})'
              '${unresolvedCount > 0 ? ', $unresolvedCount unresolved' : ''}:';
    return MechanisticTraceViewModel(
      resolvedSources: resolvedSources,
      scoreText: score.toStringAsFixed(2),
      severityLabel: severity,
      confidenceLabel: confidence,
      primaryDrivers: drivers,
      modeledWindowsLabel: windows.join(', '),
      missingInputs: missing,
      limitationText: limitation,
      safetyBoundary: safety,
      notAdviceText: notAdvice,
      sourceRefsLabel: refsLabel,
    );
  }
}

class MechanisticCandidateScoreViewModel {
  final String confidenceLabel;
  final String worstPctText;
  final String bestPctText;
  final String avgPctText;
  final int sampleCount;
  final String proteinWindowRole;
  final String redistributionPctText;
  final String aminoAcidDataMode;
  final String sourceSystem;
  final String firstExplanationLine;
  final bool insufficientContext;

  const MechanisticCandidateScoreViewModel({
    required this.confidenceLabel,
    required this.worstPctText,
    required this.bestPctText,
    required this.avgPctText,
    required this.sampleCount,
    required this.proteinWindowRole,
    required this.redistributionPctText,
    required this.aminoAcidDataMode,
    required this.sourceSystem,
    required this.firstExplanationLine,
    required this.insufficientContext,
  });

  factory MechanisticCandidateScoreViewModel.fromScore(
    MechanisticCandidateScore score,
  ) {
    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
    final firstLine = score.explanation.isEmpty ? '' : score.explanation.first;
    return MechanisticCandidateScoreViewModel(
      confidenceLabel: _bandToString(score.confidenceBand),
      worstPctText: pct(score.worstCaseConflictOverlapScore),
      bestPctText: pct(score.bestCaseConflictOverlapScore),
      avgPctText: pct(score.averageConflictOverlapScore),
      sampleCount: score.sampleCount,
      proteinWindowRole:
          score.proteinDistribution?.windowRole.name ?? 'unknown',
      redistributionPctText: pct(score.proteinRedistributionScore),
      aminoAcidDataMode:
          score
              .upstreamResult
              ?.competitionTimeline
              ?.lnaaSummary
              ?.dataMode
              .name ??
          'unknown',
      sourceSystem: score.sourceSystem,
      firstExplanationLine: firstLine,
      insufficientContext: score.insufficientContext,
    );
  }
}

String _bandToString(ConfidenceBand b) => b.name;
