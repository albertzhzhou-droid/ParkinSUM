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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/interaction_result.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/amino_acid_competition.dart';
import '../../domain/entities/gastric_emptying_profile.dart';
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
    final persistedTrace = result?.mechanisticTraceJson;
    final usesTypedTrace = persistedTrace == null && typedResult != null;
    final trace = persistedTrace ?? typedResult?.toJson();
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
          view.hasModeledOutput
              ? 'Interaction score ${view.scoreText} · severity ${view.severityLabel} · confidence ${view.confidenceLabel}'
              : '${view.abstentionHeading} · ${view.applicabilityLabel}',
          style: const TextStyle(
            color: LiquidGlass.onSurfaceMuted,
            fontSize: 12,
          ),
        ),
        children: [
          if (usesTypedTrace && view.hasModeledOutput)
            _TraceMiniCharts(result: typedResult!, validatedView: view),
          _TraceBody(view: view),
        ],
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
              _BandChip(
                label: view.hasModeledOutput
                    ? 'conf ${view.confidenceLabel}'
                    : 'status ${view.statusLabel}',
              ),
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
          children: view.hasModeledOutput
              ? [
                  _BandChip(label: 'score ${view.scoreText}'),
                  _BandChip(label: 'severity ${view.severityLabel}'),
                  _BandChip(label: 'confidence ${view.confidenceLabel}'),
                ]
              : [_BandChip(label: 'status ${view.statusLabel}')],
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
          Text(
            view.hasModeledOutput
                ? 'Missing or uncertain inputs'
                : 'Why no modeled output',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

/// Compact live charts on the ordinary result surface. They consume the typed
/// production trace and never recompute a second score.
class _TraceMiniCharts extends StatelessWidget {
  final MechanisticConflictResult result;
  final MechanisticTraceViewModel validatedView;
  const _TraceMiniCharts({required this.result, required this.validatedView});

  @override
  Widget build(BuildContext context) {
    // Never consult the unsanitized typed result as the rendering verdict.
    // The same strict wire parser that drives the status copy also gates every
    // modeled curve and numeric annotation.
    if (!validatedView.hasModeledOutput) return const SizedBox.shrink();
    final rawEmptying = result.primaryEmptyingProfile;
    final rawAbsorption = result.absorptionOpportunityWindow;
    final rawCompetition = result.competitionTimeline;
    final emptying = rawEmptying?.hasModeledOutput == true ? rawEmptying : null;
    final absorption = rawAbsorption?.hasModeledOutput == true
        ? rawAbsorption
        : null;
    final competition = rawCompetition?.hasModeledOutput == true
        ? rawCompetition
        : null;
    if (emptying == null && absorption == null && competition == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (emptying != null) ...[
            const Text(
              'Gastric residence sensitivity',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Semantics(
              image: true,
              label:
                  'Gastric residence sensitivity curve with ${emptying.uncertaintyBand.name} uncertainty.',
              child: SizedBox(
                height: 92,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TraceSparkPainter.gastric(emptying),
                ),
              ),
            ),
            const Text(
              'Meal remaining (blue). Sensitivity curve—not a gastric-emptying test.',
              style: TextStyle(fontSize: 10, color: LiquidGlass.onSurfaceMuted),
            ),
            const SizedBox(height: 10),
          ],
          if (absorption != null && competition != null) ...[
            const Text(
              'Absorption opportunity × LNAA pressure',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Semantics(
              image: true,
              label:
                  'Absorption opportunity and amino acid pressure overlay. Modeled overlap ${(competition.overlapWithAbsorptionWindow * 100).round()} percent.',
              child: SizedBox(
                height: 92,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TraceSparkPainter.overlap(
                    absorption.opennessProfile
                        .map((sample) => (sample.minute, sample.openness))
                        .toList(growable: false),
                    competition.samples
                        .map((sample) => (sample.minute, sample.pressure))
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
            Text(
              'Opportunity (purple) · LNAA pressure (red) · overlap ${(competition.overlapWithAbsorptionWindow * 100).toStringAsFixed(1)}%. Unitless educational weights.',
              style: const TextStyle(
                fontSize: 10,
                color: LiquidGlass.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TraceSparkPainter extends CustomPainter {
  final List<(double, double)> first;
  final List<(double, double)> second;
  final Color firstColor;
  final Color secondColor;

  const _TraceSparkPainter._({
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
  });

  factory _TraceSparkPainter.gastric(GastricEmptyingProfile profile) {
    final maxMinute = math.max(
      120,
      math.min(480, profile.mostlyEmptiedWindow.durationMinutes),
    );
    return _TraceSparkPainter._(
      first: [
        for (var minute = 0; minute <= maxMinute; minute += 10)
          (minute.toDouble(), profile.remainingFractionAt(minute)),
      ],
      second: const [],
      firstColor: const Color(0xff3559e0),
      secondColor: Colors.transparent,
    );
  }

  factory _TraceSparkPainter.overlap(
    List<(int, double)> opportunity,
    List<(int, double)> pressure,
  ) {
    return _TraceSparkPainter._(
      first: opportunity
          .map((point) => (point.$1.toDouble(), point.$2))
          .toList(growable: false),
      second: pressure
          .map((point) => (point.$1.toDouble(), point.$2))
          .toList(growable: false),
      firstColor: const Color(0xff7b3fe4),
      secondColor: const Color(0xffd14b65),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...first, ...second];
    if (all.length < 2) return;
    final minX = all.map((point) => point.$1).reduce(math.min);
    final maxX = all.map((point) => point.$1).reduce(math.max);
    final range = math.max(1e-9, maxX - minX);
    final rect = Rect.fromLTRB(2, 4, size.width - 2, size.height - 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
    for (var i = 1; i < 4; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.06)
          ..strokeWidth = 1,
      );
    }
    void draw(List<(double, double)> points, Color color) {
      if (points.length < 2) return;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final x = rect.left + (point.$1 - minX) / range * rect.width;
        final y = rect.bottom - point.$2.clamp(0.0, 1.0) * rect.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    draw(first, firstColor);
    draw(second, secondColor);
  }

  @override
  bool shouldRepaint(covariant _TraceSparkPainter oldDelegate) =>
      oldDelegate.first != first || oldDelegate.second != second;
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
  final MechanisticResultAvailability availability;
  final String applicabilityLabel;
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
    required this.availability,
    required this.applicabilityLabel,
    required this.primaryDrivers,
    required this.modeledWindowsLabel,
    required this.missingInputs,
    required this.limitationText,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.sourceRefsLabel,
    this.resolvedSources = const <ResolvedSourceRef>[],
  });

  bool get hasModeledOutput =>
      availability == MechanisticResultAvailability.available;

  /// Backwards-compatible UI alias. New code should inspect [availability].
  bool get insufficientContext => !hasModeledOutput;

  String get statusLabel => switch (availability) {
    MechanisticResultAvailability.available => 'available',
    MechanisticResultAvailability.notApplicable => 'not applicable',
    MechanisticResultAvailability.insufficient => 'insufficient data',
    MechanisticResultAvailability.blockedIntegrity => 'integrity blocked',
  };

  String get abstentionHeading => switch (availability) {
    MechanisticResultAvailability.available => 'Modeled output available',
    MechanisticResultAvailability.notApplicable => 'Model not applicable',
    MechanisticResultAvailability.insufficient => 'Model abstained',
    MechanisticResultAvailability.blockedIntegrity => 'Model blocked',
  };

  factory MechanisticTraceViewModel.fromJson(Map<String, dynamic> json) {
    final rawScoreValue = json['interaction_score'];
    final rawSeverityValue = json['severity_band'];
    final rawConfidenceValue = json['confidence_band'];
    final rawInteractionTypeValue = json['interaction_type'];
    final rawAvailabilityValue = json['result_availability'];
    final rawHasModeledOutputValue = json['has_modeled_output'];
    final rawDriversValue = json['primary_drivers'];
    final rawWindowsValue = json['modeled_timeline_windows'];
    final rawAbstentionReasonsValue = json['abstention_reasons'];
    final rawUncertaintyReasonsValue = json['uncertainty_reasons'];
    final rawSourceRefsValue = json['source_refs'];

    bool isStringList(Object? value) =>
        value == null ||
        (value is List && value.every((element) => element is String));
    bool isWindowList(Object? value) =>
        value == null ||
        (value is List &&
            value.every((element) {
              if (element is! Map) return false;
              final start = element['start_minute'];
              final end = element['end_minute'];
              return start is int && end is int && end >= start;
            }));
    bool isNonEmptyModeledWindowList(Object? value) =>
        value is List &&
        value.isNotEmpty &&
        value.every((element) {
          if (element is! Map) return false;
          final start = element['start_minute'];
          final end = element['end_minute'];
          return start is int && end is int && end > start;
        });

    final malformedWireTypes =
        !json.containsKey('result_availability') ||
        !json.containsKey('has_modeled_output') ||
        (rawScoreValue != null && rawScoreValue is! num) ||
        (rawSeverityValue != null && rawSeverityValue is! String) ||
        (rawConfidenceValue != null && rawConfidenceValue is! String) ||
        rawInteractionTypeValue is! String ||
        (json.containsKey('result_availability') &&
            rawAvailabilityValue is! String) ||
        (json.containsKey('has_modeled_output') &&
            rawHasModeledOutputValue is! bool) ||
        !isStringList(rawDriversValue) ||
        !isWindowList(rawWindowsValue) ||
        !isStringList(rawAbstentionReasonsValue) ||
        !isStringList(rawUncertaintyReasonsValue) ||
        !isStringList(rawSourceRefsValue) ||
        !_isFiniteJsonWireValue(json) ||
        (json['limitation_text'] != null &&
            json['limitation_text'] is! String) ||
        (json['safety_boundary'] != null &&
            json['safety_boundary'] is! String) ||
        (json['not_advice_text'] != null && json['not_advice_text'] is! String);

    final rawScore = rawScoreValue is num ? rawScoreValue.toDouble() : null;
    final rawSeverity = rawSeverityValue is String ? rawSeverityValue : null;
    final rawConfidence = rawConfidenceValue is String
        ? rawConfidenceValue
        : null;
    final interactionType = rawInteractionTypeValue is String
        ? rawInteractionTypeValue
        : '';
    final declaredAvailability = _parseAvailability(rawAvailabilityValue);
    final validInteractionType = MechanisticInteractionType.values.any(
      (value) => value.name == interactionType,
    );
    final validSeverity = SeverityBand.values.any(
      (value) => value.name == rawSeverity,
    );
    final validConfidence = ConfidenceBand.values.any(
      (value) => value.name == rawConfidence,
    );
    final explicitHasModeledOutput = rawHasModeledOutputValue;
    final availabilityMarkerMismatch =
        explicitHasModeledOutput is bool &&
        explicitHasModeledOutput !=
            (declaredAvailability == MechanisticResultAvailability.available);
    SeverityBand? expectedSeverity(double? score) {
      if (score == null || !score.isFinite || score < 0 || score > 1) {
        return null;
      }
      if (score >= 0.35) return SeverityBand.high;
      if (score >= 0.15) return SeverityBand.moderate;
      if (score > 0) return SeverityBand.low;
      return SeverityBand.none;
    }

    final availablePayloadContradiction =
        declaredAvailability == MechanisticResultAvailability.available &&
        (rawScore == null ||
            !rawScore.isFinite ||
            rawScore < 0 ||
            rawScore > 1 ||
            !validSeverity ||
            rawSeverity != expectedSeverity(rawScore)?.name ||
            !validConfidence ||
            rawConfidence == ConfidenceBand.insufficient.name ||
            rawDriversValue is! List ||
            !isNonEmptyModeledWindowList(rawWindowsValue) ||
            rawUncertaintyReasonsValue is! List ||
            rawSourceRefsValue is! List ||
            !_validAvailablePerEventWire(json, rawScore) ||
            !_validAvailableResultIdentityWire(json) ||
            !_validRequiredAvailableProviderWire(
              json['primary_emptying_profile'],
              _validAvailableGastricWire,
            ) ||
            !_validRequiredAvailableProviderWire(
              json['absorption_opportunity_window'],
              _validAvailableAbsorptionWire,
            ) ||
            !_validRequiredAvailableProviderWire(
              json['competition_timeline'],
              _validAvailableCompetitionWire,
            ) ||
            interactionType ==
                MechanisticInteractionType.insufficientMedicationContext.name ||
            interactionType ==
                MechanisticInteractionType.insufficientMealContext.name);
    final availability =
        malformedWireTypes ||
            availabilityMarkerMismatch ||
            !validInteractionType ||
            availablePayloadContradiction
        ? MechanisticResultAvailability.blockedIntegrity
        : declaredAvailability;
    final hasModeledOutput =
        availability == MechanisticResultAvailability.available;
    final applicabilityLabel = switch (availability) {
      MechanisticResultAvailability.available => 'modeled output available',
      MechanisticResultAvailability.notApplicable => switch (interactionType) {
        'insufficientMedicationContext' => 'unsupported medication context',
        'insufficientMealContext' => 'unsupported meal context',
        _ => 'outside the supported model domain',
      },
      MechanisticResultAvailability.insufficient => switch (interactionType) {
        'insufficientMedicationContext' => 'insufficient medication context',
        'insufficientMealContext' => 'insufficient meal context',
        _ => 'insufficient model inputs',
      },
      MechanisticResultAvailability.blockedIntegrity =>
        'integrity check failed',
    };
    final Iterable<String> driverValues = hasModeledOutput
        ? rawDriversValue is List
              ? rawDriversValue.whereType<String>()
              : const <String>[]
        : const <String>[];
    final drivers = driverValues
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList(growable: false);
    var windowIndex = 0;
    final Iterable<Map<dynamic, dynamic>> windowValues = hasModeledOutput
        ? rawWindowsValue is List
              ? rawWindowsValue.whereType<Map<dynamic, dynamic>>()
              : const <Map<dynamic, dynamic>>[]
        : const <Map<dynamic, dynamic>>[];
    final windows = windowValues
        .map((w) {
          final startValue = w['start_minute'];
          final endValue = w['end_minute'];
          if (startValue is! num || endValue is! num) return '';
          final start = startValue.toInt();
          final end = endValue.toInt();
          windowIndex += 1;
          return 'window $windowIndex: ${math.max(0, end - start)} min duration';
        })
        .where((s) => s.isNotEmpty)
        .take(2)
        .toList(growable: false);
    final abstentionReasons = rawAbstentionReasonsValue is List
        ? rawAbstentionReasonsValue.whereType<String>().toList(growable: false)
        : null;
    final Iterable<String> reasonValues =
        abstentionReasons ??
        (rawUncertaintyReasonsValue is List
            ? rawUncertaintyReasonsValue.whereType<String>()
            : null) ??
        const <String>[];
    final parsedReasons = reasonValues
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final missing =
        availability == MechanisticResultAvailability.blockedIntegrity &&
            parsedReasons.isEmpty
        ? const ['mechanistic_result.integrity_contract_invalid']
        : parsedReasons;
    final limitation = json['limitation_text'] is String
        ? json['limitation_text'] as String
        : '';
    // Boundary copy: prefer the model's emitted text; otherwise source the
    // default boundary/not-advice copy through the compiler-validated
    // SafeCopyTemplate registry (ExplanationCopyService), which itself falls
    // back to the canonical `RuleExplanation` defaults if a template is absent.
    const copy = ExplanationCopyService();
    final safety = json['safety_boundary'] is String
        ? json['safety_boundary'] as String
        : copy.safetyBoundary();
    final notAdvice = json['not_advice_text'] is String
        ? json['not_advice_text'] as String
        : copy.notAdvice();
    final refs =
        (rawSourceRefsValue is List
                ? rawSourceRefsValue.whereType<String>()
                : const <String>[])
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
      scoreText: hasModeledOutput ? rawScore!.toStringAsFixed(2) : '—',
      severityLabel: hasModeledOutput ? rawSeverity! : '—',
      confidenceLabel: hasModeledOutput ? rawConfidence! : '—',
      availability: availability,
      applicabilityLabel: applicabilityLabel,
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

bool _isFiniteJsonWireValue(Object? value) {
  if (value == null || value is String || value is bool) return true;
  if (value is num) return value.isFinite;
  if (value is List) return value.every(_isFiniteJsonWireValue);
  if (value is Map) {
    return value.keys.every((key) => key is String) &&
        value.values.every(_isFiniteJsonWireValue);
  }
  return false;
}

bool _isStringWireList(Object? value) =>
    value is List && value.every((element) => element is String);

bool _isBoundedWireNumber(Object? value) =>
    value is num && value.isFinite && value >= 0 && value <= 1;

bool _isPositiveWireWindow(Object? value) {
  if (value is! Map) return false;
  final start = value['start_minute'];
  final end = value['end_minute'];
  return start is int && end is int && end > start;
}

bool _closeWireNumber(num left, num right) =>
    left.isFinite && right.isFinite && (left - right).abs() <= 1e-9;

bool _validAvailablePerEventWire(Map<String, dynamic> json, double? topScore) {
  final rawCount = json['per_event_count'];
  final rawTraces = json['per_event_traces'];
  if (topScore == null ||
      rawCount is! int ||
      rawCount <= 0 ||
      rawTraces is! List ||
      rawTraces.length != rawCount) {
    return false;
  }
  const validCompetitionBands = {'none', 'low', 'moderate', 'high'};
  const validArrivalBands = {'low', 'moderate', 'high'};
  final ids = <String>{};
  final scores = <double>[];
  double? primaryScore;
  var primaryCount = 0;
  for (final rawTrace in rawTraces) {
    if (rawTrace is! Map) return false;
    final id = rawTrace['medication_event_id'];
    final score = rawTrace['interaction_score'];
    final competitionBand = rawTrace['competition_band'];
    final arrivalBand = rawTrace['delayed_arrival_likelihood'];
    final isPrimary = rawTrace['is_primary'];
    final medicationMinute = rawTrace['medication_minute'];
    final componentCount = rawTrace['combination_component_count'];
    final labelRefCount = rawTrace['label_section_ref_count'];
    if (id is! String ||
        id.trim().isEmpty ||
        id != id.trim() ||
        !ids.add(id) ||
        medicationMinute is! int ||
        !_isBoundedWireNumber(score) ||
        rawTrace['is_levodopa'] != true ||
        rawTrace['release_type'] is! String ||
        !const {
          'immediate',
          'immediate_release',
        }.contains(rawTrace['release_type']) ||
        competitionBand is! String ||
        !validCompetitionBands.contains(competitionBand) ||
        arrivalBand is! String ||
        !validArrivalBands.contains(arrivalBand) ||
        isPrimary is! bool ||
        componentCount is! int ||
        componentCount < 0 ||
        labelRefCount is! int ||
        labelRefCount < 0 ||
        !_isStringWireList(rawTrace['source_refs']) ||
        !_isStringWireList(rawTrace['uncertainty_reasons']) ||
        !_isOptionalStringWire(rawTrace['release_type_source']) ||
        !_isOptionalStringWire(rawTrace['dose_form']) ||
        !_isOptionalStringWire(rawTrace['route']) ||
        (rawTrace.containsKey('levodopa_component_present') &&
            rawTrace['levodopa_component_present'] is! bool) ||
        !_isOptionalStringWire(rawTrace['medication_source_system']) ||
        !_isOptionalStringWire(rawTrace['medication_source_doc_id']) ||
        !_isOptionalStringWire(rawTrace['medication_metadata_completeness'])) {
      return false;
    }
    final parsedScore = (score as num).toDouble();
    scores.add(parsedScore);
    if (isPrimary) {
      primaryCount += 1;
      primaryScore = parsedScore;
    }
  }
  if (primaryCount != 1 || primaryScore == null) return false;
  final maximum = scores.reduce((a, b) => a > b ? a : b);
  return _closeWireNumber(primaryScore, maximum) &&
      _closeWireNumber(topScore, primaryScore);
}

bool _validRequiredAvailableProviderWire(
  Object? raw,
  bool Function(Map<dynamic, dynamic>) validate,
) => raw is Map && validate(raw);

bool _validAvailableResultIdentityWire(Map<String, dynamic> wire) {
  final id = wire['id'];
  final explanation = wire['explanation'];
  final absorption = wire['absorption_opportunity_window'];
  final traces = wire['per_event_traces'];
  if (id is! String ||
      id.trim().isEmpty ||
      id != id.trim() ||
      explanation is! Map ||
      explanation['result_id'] != id ||
      absorption is! Map ||
      traces is! List) {
    return false;
  }
  final primaryTraces = traces.whereType<Map>().where(
    (trace) => trace['is_primary'] == true,
  );
  if (primaryTraces.length != 1) return false;
  return absorption['medication_event_id'] ==
      primaryTraces.single['medication_event_id'];
}

bool _hasAvailableProviderMarkers(Map<dynamic, dynamic> wire) =>
    wire['result_availability'] == 'available' &&
    wire['has_modeled_output'] == true &&
    wire['model_applicable'] == true &&
    _isStringWireList(wire['applicability_reasons']);

bool _validAvailableGastricWire(Map<dynamic, dynamic> wire) {
  if (!_hasAvailableProviderMarkers(wire)) return false;
  final components = wire['component_profiles'];
  final aggregateLag = wire['aggregate_lag_minutes'];
  final sensitivity = wire['time_scale_sensitivity_fraction'];
  final peak = wire['peak_emptying_window'];
  final mostly = wire['mostly_emptied_window'];
  final mealId = wire['meal_id'];
  if (mealId is! String ||
      mealId.trim().isEmpty ||
      components is! List ||
      components.isEmpty ||
      !const {
        'narrow',
        'moderate',
        'wide',
        'veryWide',
      }.contains(wire['uncertainty_band']) ||
      !_isStringWireList(wire['assumptions']) ||
      !_isStringWireList(wire['missing_inputs']) ||
      !_isStringWireList(wire['source_refs']) ||
      aggregateLag is! num ||
      !aggregateLag.isFinite ||
      aggregateLag < 0 ||
      sensitivity is! num ||
      !sensitivity.isFinite ||
      sensitivity < 0 ||
      sensitivity >= 1 ||
      !_isPositiveWireWindow(peak) ||
      !_isPositiveWireWindow(mostly)) {
    return false;
  }
  final componentIds = <String>{};
  final kinetics = <GastricComponentKinetics>[];
  var fractionSum = 0.0;
  for (final rawComponent in components) {
    if (rawComponent is! Map) return false;
    final id = rawComponent['component_id'];
    final lag = rawComponent['lag_minutes'];
    final half = rawComponent['half_emptying_minutes'];
    final fraction = rawComponent['fraction_of_meal'];
    if (id is! String ||
        id.trim().isEmpty ||
        !componentIds.add(id.trim()) ||
        lag is! num ||
        !lag.isFinite ||
        lag < 0 ||
        half is! num ||
        !half.isFinite ||
        half <= 0 ||
        fraction is! num ||
        !fraction.isFinite ||
        fraction <= 0 ||
        fraction > 1 ||
        !const {
          'solid',
          'liquid',
          'mixed',
          'unknown',
        }.contains(rawComponent['physical_form']) ||
        !_isStringWireList(rawComponent['applied_modifiers'])) {
      return false;
    }
    fractionSum += fraction.toDouble();
    kinetics.add((
      fractionOfMeal: fraction.toDouble(),
      lagMinutes: lag.toDouble(),
      halfEmptyingMinutes: half.toDouble(),
    ));
  }
  final peakMap = peak as Map;
  final mostlyMap = mostly as Map;
  final derived = deriveGastricProfileShape(kinetics);
  return (fractionSum - 1).abs() <= 1e-9 &&
      (aggregateLag.toDouble() - derived.aggregateLagMinutes).abs() <=
          gastricDerivedCoherenceTolerance &&
      peakMap['start_minute'] == mostlyMap['start_minute'] &&
      (peakMap['end_minute'] as int) - (peakMap['start_minute'] as int) ==
          derived.peakWindowDurationMinutes &&
      (mostlyMap['end_minute'] as int) - (mostlyMap['start_minute'] as int) ==
          derived.mostlyEmptiedWindowDurationMinutes;
}

bool _validAvailableAbsorptionWire(Map<dynamic, dynamic> wire) {
  if (!_hasAvailableProviderMarkers(wire)) return false;
  final window = wire['window'];
  final peakMinute = wire['peak_minute'];
  final samples = wire['openness_profile'];
  final medicationEventId = wire['medication_event_id'];
  final delayedArrival = wire['delayed_arrival_likelihood'];
  if (medicationEventId is! String ||
      medicationEventId.trim().isEmpty ||
      delayedArrival is! String ||
      !const {'low', 'moderate', 'high'}.contains(delayedArrival) ||
      !const {
        'narrow',
        'moderate',
        'wide',
        'veryWide',
      }.contains(wire['uncertainty_band']) ||
      !_isStringWireList(wire['assumptions']) ||
      !_isStringWireList(wire['missing_inputs']) ||
      !_isStringWireList(wire['source_refs']) ||
      !_isPositiveWireWindow(window) ||
      peakMinute is! int ||
      samples is! List ||
      samples.isEmpty ||
      !_isBoundedWireNumber(wire['peak_openness'])) {
    return false;
  }
  final windowMap = window as Map;
  final windowStart = (windowMap['start_minute'] as num).toInt();
  final windowEnd = (windowMap['end_minute'] as num).toInt();
  if (peakMinute < windowStart || peakMinute > windowEnd) {
    return false;
  }
  int? previousMinute;
  var maximumOpenness = double.negativeInfinity;
  var peakMatches = false;
  for (final rawSample in samples) {
    if (rawSample is! Map) return false;
    final minute = rawSample['minute'];
    final openness = rawSample['openness'];
    if (minute is! int ||
        (previousMinute != null && minute <= previousMinute) ||
        !_isBoundedWireNumber(openness) ||
        minute < windowStart ||
        minute > windowEnd) {
      return false;
    }
    final parsedOpenness = (openness as num).toDouble();
    if (parsedOpenness > maximumOpenness) maximumOpenness = parsedOpenness;
    previousMinute = minute;
  }
  for (final rawSample in samples.whereType<Map>()) {
    final minute = rawSample['minute'];
    final openness = rawSample['openness'];
    if (minute == peakMinute &&
        openness is num &&
        _closeWireNumber(openness, maximumOpenness)) {
      peakMatches = true;
    }
  }
  return (samples.first as Map)['minute'] == windowStart &&
      (samples.last as Map)['minute'] == windowEnd &&
      maximumOpenness > 0 &&
      peakMatches &&
      _closeWireNumber(wire['peak_openness'] as num, maximumOpenness);
}

bool _validAvailableCompetitionWire(Map<dynamic, dynamic> wire) {
  if (!_hasAvailableProviderMarkers(wire)) return false;
  final samples = wire['samples'];
  final competitionBand = wire['competition_band'];
  if (samples is! List ||
      samples.isEmpty ||
      wire['peak_minute'] is! int ||
      !_isBoundedWireNumber(wire['peak_pressure']) ||
      !_isBoundedWireNumber(wire['overlap_with_absorption_window']) ||
      competitionBand is! String ||
      !const {'none', 'low', 'moderate', 'high'}.contains(competitionBand) ||
      competitionBandForOverlap(
            (wire['overlap_with_absorption_window'] as num).toDouble(),
          ).name !=
          competitionBand ||
      !const {
        'narrow',
        'moderate',
        'wide',
        'veryWide',
      }.contains(wire['uncertainty_band']) ||
      !_isStringWireList(wire['assumptions']) ||
      !_isStringWireList(wire['source_refs'])) {
    return false;
  }
  int? previousMinute;
  var maximumPressure = double.negativeInfinity;
  var peakMatches = false;
  for (final rawSample in samples) {
    if (rawSample is! Map) return false;
    final minute = rawSample['minute'];
    final pressure = rawSample['pressure'];
    if (minute is! int ||
        (previousMinute != null && minute <= previousMinute) ||
        !_isBoundedWireNumber(pressure)) {
      return false;
    }
    final parsedPressure = (pressure as num).toDouble();
    if (parsedPressure > maximumPressure) maximumPressure = parsedPressure;
    if (minute == wire['peak_minute'] &&
        _closeWireNumber(parsedPressure, wire['peak_pressure'] as num)) {
      peakMatches = true;
    }
    previousMinute = minute;
  }
  final summary = wire['lnaa_summary'];
  if (summary is! Map ||
      !_isNonnegativeRequiredWireNumber(summary['effective_load_factor']) ||
      (summary['effective_load_factor'] as num) < 0.5 ||
      (summary['effective_load_factor'] as num) > 1.5 ||
      !_isStringWireList(summary['sources_present']) ||
      !(summary['sources_present'] as List).every(
        const {
          'dairy',
          'meat',
          'fish',
          'egg',
          'soy',
          'legume',
          'grain',
          'mixed',
          'unknown',
        }.contains,
      ) ||
      summary['is_prototype_heuristic'] is! bool ||
      summary['uncertainty_widened'] is! bool ||
      !_isStringWireList(summary['source_refs']) ||
      !_isStringWireList(summary['amino_acid_nutrient_ids']) ||
      summary['partial_amino_acid_data'] is! bool ||
      (summary['amino_acid_confidence_tier'] != null &&
          summary['amino_acid_confidence_tier'] is! String) ||
      !_isNonnegativeOptionalWireNumber(summary['competing_lnaa_grams']) ||
      !_isNonnegativeOptionalWireNumber(
        summary['competing_lnaa_grams_per_serving'],
      ) ||
      !_isNonnegativeOptionalWireNumber(summary['dose_relative_lnaa_ratio']) ||
      !_isOptionalBoundedWireNumber(
        summary['actual_amino_acid_protein_coverage_fraction'],
      ) ||
      summary['dose_relative_available'] is! bool ||
      (summary['dose_relative_available'] == true) !=
          (summary['dose_relative_lnaa_ratio'] != null)) {
    return false;
  }
  final dataMode = summary['data_mode'];
  final coverage = summary['actual_amino_acid_protein_coverage_fraction'];
  if (dataMode is! String) return false;
  final hasAbsoluteValues =
      summary['competing_lnaa_grams'] != null ||
      summary['competing_lnaa_grams_per_serving'] != null ||
      summary['dose_relative_lnaa_ratio'] != null ||
      summary['dose_relative_available'] == true;
  final sources = summary['sources_present'] as List;
  final aminoAcidIds = summary['amino_acid_nutrient_ids'] as List;
  final uncertaintyWidened = summary['uncertainty_widened'] as bool;
  final partialAminoAcidData = summary['partial_amino_acid_data'] as bool;
  final dataModeCoherent = switch (dataMode) {
    'actualAminoAcidFields' =>
      coverage is num &&
          _closeWireNumber(coverage, 1) &&
          !partialAminoAcidData &&
          summary['competing_lnaa_grams'] is num &&
          sources.isEmpty,
    'hybridActualAndProteinSourceProxy' =>
      coverage is num &&
          coverage.isFinite &&
          coverage > 0 &&
          coverage < 1 &&
          partialAminoAcidData &&
          uncertaintyWidened &&
          !hasAbsoluteValues &&
          summary['amino_acid_confidence_tier'] == null &&
          sources.isNotEmpty,
    'proteinSourceProxy' =>
      coverage is num &&
          _closeWireNumber(coverage, 0) &&
          !hasAbsoluteValues &&
          aminoAcidIds.isEmpty &&
          summary['amino_acid_confidence_tier'] == null,
    'unknown' =>
      _closeWireNumber(summary['effective_load_factor'] as num, 1) &&
          uncertaintyWidened &&
          !partialAminoAcidData &&
          coverage == null &&
          !hasAbsoluteValues &&
          aminoAcidIds.isEmpty &&
          summary['amino_acid_confidence_tier'] == null &&
          sources.length == 1 &&
          sources.single == 'unknown' &&
          (wire['peak_pressure'] as num).abs() <= 1e-12 &&
          (wire['overlap_with_absorption_window'] as num).abs() <= 1e-12 &&
          samples.whereType<Map>().every(
            (sample) =>
                (sample['pressure'] as num).isFinite &&
                (sample['pressure'] as num).abs() <= 1e-12,
          ),
    _ => false,
  };
  if (!dataModeCoherent) return false;
  return peakMatches &&
      _closeWireNumber(wire['peak_pressure'] as num, maximumPressure);
}

bool _isNonnegativeOptionalWireNumber(Object? value) =>
    value == null || (value is num && value.isFinite && value >= 0);

bool _isOptionalStringWire(Object? value) => value == null || value is String;

bool _isNonnegativeRequiredWireNumber(Object? value) =>
    value is num && value.isFinite && value >= 0;

bool _isOptionalBoundedWireNumber(Object? value) =>
    value == null || _isBoundedWireNumber(value);

MechanisticResultAvailability _parseAvailability(Object? raw) {
  if (raw is String) {
    for (final value in MechanisticResultAvailability.values) {
      if (value.name == raw) return value;
    }
    // An unknown status is itself an integrity failure; never infer a score.
    return MechanisticResultAvailability.blockedIntegrity;
  }
  // Untyped legacy payloads do not carry enough evidence to distinguish a
  // real modeled zero from an abstention sentinel. They must pass through an
  // explicit migration boundary before this UI may render model output.
  return MechanisticResultAvailability.blockedIntegrity;
}

class MechanisticCandidateScoreViewModel {
  final MechanisticResultAvailability availability;
  final String confidenceLabel;
  final String worstPctText;
  final String bestPctText;
  final String avgPctText;
  final int? sampleCount;
  final String proteinWindowRole;
  final String redistributionPctText;
  final String aminoAcidDataMode;
  final String sourceSystem;
  final String firstExplanationLine;

  const MechanisticCandidateScoreViewModel({
    required this.availability,
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
  });

  bool get hasModeledOutput =>
      availability == MechanisticResultAvailability.available;

  /// Backwards-compatible presentation alias.
  bool get insufficientContext => !hasModeledOutput;

  String get statusLabel => switch (availability) {
    MechanisticResultAvailability.available => 'available',
    MechanisticResultAvailability.notApplicable => 'not applicable',
    MechanisticResultAvailability.insufficient => 'insufficient data',
    MechanisticResultAvailability.blockedIntegrity => 'integrity blocked',
  };

  factory MechanisticCandidateScoreViewModel.fromScore(
    MechanisticCandidateScore score,
  ) {
    String pct(double? v) =>
        v == null ? '—' : '${(v * 100).toStringAsFixed(0)}%';
    final firstLine = score.explanation.isEmpty ? '' : score.explanation.first;
    return MechanisticCandidateScoreViewModel(
      availability: score.availability,
      confidenceLabel: score.modeledConfidenceBand?.name ?? '—',
      worstPctText: pct(score.modeledWorstCaseConflictOverlapScore),
      bestPctText: pct(score.modeledBestCaseConflictOverlapScore),
      avgPctText: pct(score.modeledAverageConflictOverlapScore),
      sampleCount: score.modeledSampleCount,
      proteinWindowRole:
          score.modeledProteinDistribution?.windowRole.name ?? '—',
      redistributionPctText: pct(score.modeledProteinRedistributionScore),
      aminoAcidDataMode:
          score
              .upstreamResult
              ?.competitionTimeline
              ?.lnaaSummary
              ?.dataMode
              .name ??
          '—',
      sourceSystem: score.sourceSystem,
      firstExplanationLine: firstLine,
    );
  }
}
