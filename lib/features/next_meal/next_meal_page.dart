import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/response_copy_service.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/next_meal_recommendation_models.dart';
import '../shared/mechanistic_trace_view.dart';

/// 下餐推荐：以冲突引擎为主、本地 AI 为可选润色。
///
/// 用户先选下一餐的预计时间 → 引擎按那个时间窗 + 当前药历 + 最近上下文重算，
/// 然后输出 5 条候选 + 一段"为什么这样推"的解释段落（多语言）。
class NextMealPage extends StatefulWidget {
  const NextMealPage({super.key});

  @override
  State<NextMealPage> createState() => _NextMealPageState();
}

class _NextMealPageState extends State<NextMealPage> {
  /// User-selected target meal time. Defaults to "now + 2h" rounded down to
  /// the nearest 5 minutes so the picker shows a clean value.
  late DateTime _targetTime;
  bool _useLocalAi = false;
  bool _generating = false;
  NextMealRecommendationResult? _result;
  String? _error;

  /// User-defined window length (minutes) starting at the target time.
  /// Required for mechanistic-primary ranking — the engine never picks the
  /// window; the user does. 0 = no window (mechanistic-primary inactive).
  int _windowMinutes = 60;
  static const List<int> _windowChoices = [0, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    final base = DateTime.now().add(const Duration(hours: 2));
    _targetTime = DateTime(
      base.year,
      base.month,
      base.day,
      base.hour,
      base.minute - (base.minute % 5),
    );
    // Default the AI toggle to whatever the user already consented to during
    // onboarding. They can still flip it per-generation.
    final state = context.read<AppState>();
    _useLocalAi = state.userProfile.localAiConsentEnabled;
  }

  Future<void> _pickTargetTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _targetTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_targetTime),
    );
    if (pickedTime == null) return;
    setState(() {
      _targetTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result =
          await context.read<AppState>().requestNextMealRecommendation(
                nextMealAt: _targetTime,
                useLocalAi: _useLocalAi,
                windowDuration: _windowMinutes > 0
                    ? Duration(minutes: _windowMinutes)
                    : null,
              );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(i18n.tr('next_meal.title'))),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SubtitleBlock(i18n: i18n),
            const SizedBox(height: 16),
            _ControlsCard(
              i18n: i18n,
              targetTime: _targetTime,
              useLocalAi: _useLocalAi,
              generating: _generating,
              onPickTime: _pickTargetTime,
              onToggleAi: (value) => setState(() => _useLocalAi = value),
              onGenerate: _generate,
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meal time window you provide (minutes)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LiquidGlass.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You set the window. The prototype only ranks food '
                    'candidates inside it and does not choose your meal time. '
                    'A window is required for mechanistic-primary ranking.',
                    style: TextStyle(
                        fontSize: 11, color: LiquidGlass.onSurfaceMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in _windowChoices)
                        ChoiceChip(
                          label: Text(m == 0 ? 'none' : '$m min'),
                          selected: _windowMinutes == m,
                          onSelected: (_) => setState(() => _windowMinutes = m),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) _ErrorCard(i18n: i18n, error: _error!),
            if (_result != null)
              _ResultBlock(
                i18n: i18n,
                result: _result!,
                windowProvided: _windowMinutes > 0,
              ),
            if (_result == null && !_generating && _error == null)
              _EmptyCard(i18n: i18n),
          ],
        ),
      ),
    );
  }
}

class _SubtitleBlock extends StatelessWidget {
  final AppI18n i18n;
  const _SubtitleBlock({required this.i18n});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined,
              size: 22, color: LiquidGlass.onSurfaceMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n.tr('next_meal.subtitle'),
              style: const TextStyle(
                color: LiquidGlass.onSurfaceMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  final AppI18n i18n;
  final DateTime targetTime;
  final bool useLocalAi;
  final bool generating;
  final VoidCallback onPickTime;
  final ValueChanged<bool> onToggleAi;
  final VoidCallback onGenerate;

  const _ControlsCard({
    required this.i18n,
    required this.targetTime,
    required this.useLocalAi,
    required this.generating,
    required this.onPickTime,
    required this.onToggleAi,
    required this.onGenerate,
  });

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.tr('next_meal.input_time'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: LiquidGlass.onSurfaceMuted,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(LiquidGlass.radiusMd),
              onTap: onPickTime,
              child: GlassSurface(
                borderRadius: LiquidGlass.radiusMd,
                blurSigma: LiquidGlass.blurSm,
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatTime(targetTime),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: LiquidGlass.onSurface,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const Icon(Icons.event_outlined,
                        size: 20, color: LiquidGlass.onSurfaceMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              i18n.tr('next_meal.use_local_ai'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: LiquidGlass.onSurface,
              ),
            ),
            subtitle: Text(
              i18n.tr('next_meal.use_local_ai_help'),
              style: const TextStyle(
                fontSize: 12,
                color: LiquidGlass.onSurfaceMuted,
                height: 1.35,
              ),
            ),
            value: useLocalAi,
            onChanged: generating ? null : onToggleAi,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GlassButton(
              onPressed: generating ? null : onGenerate,
              leadingIcon: generating ? null : Icons.auto_fix_high_rounded,
              label: Text(
                generating
                    ? i18n.tr('next_meal.generating')
                    : i18n.tr('next_meal.generate'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final AppI18n i18n;
  const _EmptyCard({required this.i18n});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu_outlined,
              size: 40, color: LiquidGlass.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(
            i18n.tr('next_meal.empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: LiquidGlass.onSurfaceMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final AppI18n i18n;
  final String error;
  const _ErrorCard({required this.i18n, required this.error});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 22, color: Colors.red.withValues(alpha: 0.85)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.tr('next_meal.error'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: const TextStyle(
                    fontSize: 12,
                    color: LiquidGlass.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  final AppI18n i18n;
  final NextMealRecommendationResult result;
  final bool windowProvided;
  const _ResultBlock(
      {required this.i18n, required this.result, required this.windowProvided});

  @override
  Widget build(BuildContext context) {
    final copy = ResponseCopyService(i18n: i18n);
    final scheme = Theme.of(context).colorScheme;
    final explanationLines = result.explanations
        .where((line) => line.trim().isNotEmpty)
        .map(copy.recommendationMessage)
        .toList(growable: false);
    final gateLines = result.gateReasons
        .where((line) => line.trim().isNotEmpty)
        .map(copy.recommendationMessage)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Path + AI badge header.
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.aiUsed
                        ? Icons.auto_awesome_rounded
                        : Icons.shield_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.aiUsed
                          ? i18n.tr('next_meal.ai_polished')
                          : i18n.tr('next_meal.conservative_engine'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlass.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${i18n.tr('next_meal.recommendation_path')}: '
                '${i18n.recommendationPathLabel(result.decisionPath)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: LiquidGlass.onSurfaceMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (explanationLines.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.tr('next_meal.why_these'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlass.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in explanationLines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style:
                                TextStyle(color: LiquidGlass.onSurfaceMuted)),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(
                              fontSize: 13,
                              color: LiquidGlass.onSurface,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (gateLines.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      i18n.tr('next_meal.gate_reasons'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LiquidGlass.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final line in gateLines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '• $line',
                      style: const TextStyle(
                        fontSize: 12,
                        color: LiquidGlass.onSurfaceMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Top recommendation cards.
        Text(
          i18n.tr('next_meal.candidates'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: LiquidGlass.onSurfaceMuted,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        if (result.recommendations.isEmpty)
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Text(
              i18n.tr('next_meal.no_candidates'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LiquidGlass.onSurfaceMuted,
                fontSize: 13,
              ),
            ),
          ),
        for (final rec in result.recommendations.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i18n.foodName(rec.food.id, rec.food.name),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: LiquidGlass.onSurface,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      _DecisionChip(
                          label: i18n.decisionLabel(rec.decision),
                          tone: rec.decision),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i18n.tr(
                      'dashboard.recommendation_macro_line',
                      {
                        'protein': rec.food.proteinG.toStringAsFixed(1),
                        'carbs': rec.food.carbsG.toStringAsFixed(1),
                        'fat': rec.food.fatG.toStringAsFixed(1),
                      },
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: LiquidGlass.onSurfaceMuted,
                    ),
                  ),
                  if (rec.reasons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final reason in rec.reasons.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '· ${copy.recommendationMessage(reason)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LiquidGlass.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        if (result.mechanisticTrace != null) ...[
          const SizedBox(height: 12),
          MechanisticConflictTraceCard(typedResult: result.mechanisticTrace),
        ],
        if (result.mechanisticCandidateScores != null &&
            result.mechanisticCandidateScores!.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Model trace per candidate (educational)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in result.mechanisticCandidateScores!.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MechanisticCandidateScoreLine(score: s),
            ),
        ],
        if (result.rankerUsed != null) ...[
          const SizedBox(height: 6),
          Text(
            'Ranker used: ${result.rankerUsed}',
            style: const TextStyle(
                fontSize: 11, color: LiquidGlass.onSurfaceMuted),
          ),
        ],
        if (result.mechanisticCandidateScores == null) ...[
          const SizedBox(height: 6),
          Text(
            !windowProvided
                ? 'Mechanistic-primary ranking is unavailable because no '
                    'meal-time window was provided. Choose a window above to '
                    'enable it. This is not medical advice.'
                : 'Mechanistic-primary ranking is unavailable for this request '
                    '(insufficient context). Showing the conservative fallback. '
                    'This is not medical advice.',
            style: const TextStyle(
                fontSize: 11, color: LiquidGlass.onSurfaceMuted),
          ),
        ],
      ],
    );
  }
}

class _DecisionChip extends StatelessWidget {
  final String label;
  final String tone;
  const _DecisionChip({required this.label, required this.tone});

  Color _toneColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (tone.toLowerCase()) {
      case 'block':
      case 'discourage':
        return Colors.red.withValues(alpha: 0.85);
      case 'warn':
      case 'require_review':
        return Colors.orange.withValues(alpha: 0.85);
      case 'info':
      case 'defer':
        return scheme.primary;
      case 'allow':
      default:
        return Colors.green.withValues(alpha: 0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(LiquidGlass.radiusXl),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
