import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/response_copy_service.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/usecases/local_ai_recommendation_adapter.dart';
import '../import/import_page.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late final TextEditingController _modelController;
  late final TextEditingController _medicalModelController;
  late final TextEditingController _ollamaEndpointController;
  late final TextEditingController _openAiCompatEndpointController;
  late final TextEditingController _timeoutController;
  String _providerPreference = LocalAiProviders.auto;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController();
    _medicalModelController = TextEditingController();
    _ollamaEndpointController = TextEditingController();
    _openAiCompatEndpointController = TextEditingController();
    _timeoutController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.read<AppState>().userProfile;
    _providerPreference = profile.localAiProviderPreference;
    _modelController.text = profile.localAiModel;
    _medicalModelController.text = profile.localAiMedicalModel;
    _ollamaEndpointController.text = profile.localAiOllamaEndpoint;
    _openAiCompatEndpointController.text = profile.localAiOpenAiCompatEndpoint;
    _timeoutController.text = '${profile.localAiTimeoutMs}';
  }

  @override
  void dispose() {
    _modelController.dispose();
    _medicalModelController.dispose();
    _ollamaEndpointController.dispose();
    _openAiCompatEndpointController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  String _providerLabel(AppI18n i18n, String provider) {
    switch (provider) {
      case LocalAiProviders.ollama:
        return i18n.tr('analytics.local_ai_provider_ollama');
      case LocalAiProviders.openAiCompat:
        return i18n.tr('analytics.local_ai_provider_openai');
      default:
        return i18n.tr('analytics.local_ai_provider_auto');
    }
  }

  String? _recommendationTemplateSummary(AppState state, AppI18n i18n) {
    final region = state.recommendationTemplateCountryCode;
    final mealSlot = state.recommendationTemplateMealSlot;
    final texture = state.recommendationTemplateTextureLevel;
    if (region == null || mealSlot == null || texture == null) {
      return null;
    }
    return i18n.tr(
      'dashboard.recommendation_template',
      {
        'region': i18n.regionLabel(region),
        'mealSlot': i18n.mealSlotLabel(mealSlot),
        'texture': i18n.textureClassLabel(texture),
      },
    );
  }

  Future<void> _saveLocalAiSettings(BuildContext context) async {
    final timeoutMs = int.tryParse(_timeoutController.text.trim()) ?? 4000;
    await context.read<AppState>().saveLocalAiSettings(
          providerPreference: _providerPreference,
          model: _modelController.text.trim().isEmpty
              ? LocalAiRecommendedModels.gemmaText
              : _modelController.text.trim(),
          medicalModel: _medicalModelController.text.trim().isEmpty
              ? LocalAiRecommendedModels.medGemmaText
              : _medicalModelController.text.trim(),
          ollamaEndpoint: _ollamaEndpointController.text.trim(),
          openAiCompatEndpoint: _openAiCompatEndpointController.text.trim(),
          timeoutMs: timeoutMs,
        );
    if (!context.mounted) return;
    await context.read<AppState>().refreshLocalAiAvailability();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final trend = state.proteinTrend;
    final localAiStatus = state.localAiAvailability;
    final replayReport = state.latestReplayBenchmarkReport;
    final copy = ResponseCopyService(i18n: i18n);

    return Scaffold(
      appBar: AppBar(title: Text(i18n.tr('analytics.title'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('analytics.localization'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.tr(
                      'analytics.localization_language',
                      {
                        'value':
                            i18n.localeLabel(state.userProfile.displayLocale),
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.tr(
                      'analytics.localization_region',
                      {
                        'value': i18n.regionLabel(
                          state.userProfile.registrationRegion,
                        ),
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.tr(
                      'analytics.localization_timezone',
                      {'value': state.userProfile.timezone},
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.tr(
                      'analytics.localization_override',
                      {
                        'value': state
                                .userProfile.contentJurisdictionOverride.isEmpty
                            ? i18n.tr('analytics.localization_override_none')
                            : state.userProfile.contentJurisdictionOverride
                                .join(', '),
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.tr(
                      'analytics.localization_texture_mode',
                      {
                        'value': i18n.textureModeLabel(
                          state.userProfile.swallowingTextureMode,
                        ),
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.tr('analytics.localization_help'),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('analytics.local_ai'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(i18n.tr('analytics.local_ai_enable')),
                    subtitle: Text(i18n.tr('analytics.local_ai_help')),
                    value: state.userProfile.localAiConsentEnabled,
                    onChanged: (value) =>
                        context.read<AppState>().setLocalAiConsent(value),
                  ),
                  GlassSelectField<String>(
                    label: i18n.tr('analytics.local_ai_provider'),
                    value: _providerPreference,
                    options: [
                      GlassSelectOption(
                        value: LocalAiProviders.auto,
                        label: _providerLabel(i18n, LocalAiProviders.auto),
                        icon: Icons.auto_awesome_rounded,
                      ),
                      GlassSelectOption(
                        value: LocalAiProviders.ollama,
                        label: _providerLabel(i18n, LocalAiProviders.ollama),
                        icon: Icons.memory_rounded,
                      ),
                      GlassSelectOption(
                        value: LocalAiProviders.openAiCompat,
                        label:
                            _providerLabel(i18n, LocalAiProviders.openAiCompat),
                        icon: Icons.api_rounded,
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _providerPreference = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: i18n.tr('analytics.local_ai_model'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _medicalModelController,
                    decoration: InputDecoration(
                      labelText: i18n.tr('analytics.local_ai_medical_model'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ollamaEndpointController,
                    decoration: InputDecoration(
                      labelText: i18n.tr('analytics.local_ai_ollama_endpoint'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _openAiCompatEndpointController,
                    decoration: InputDecoration(
                      labelText: i18n.tr('analytics.local_ai_openai_endpoint'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timeoutController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: i18n.tr('analytics.local_ai_timeout_ms'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _saveLocalAiSettings(context),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(i18n.tr('common.apply')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context
                            .read<AppState>()
                            .refreshLocalAiAvailability(),
                        icon: const Icon(Icons.health_and_safety_outlined),
                        label: Text(i18n.tr('analytics.local_ai_check')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${i18n.tr('analytics.recommendation_path')}: '
                    '${copy.recommendationPath(state.recommendationDecisionPath)}',
                  ),
                  if (_recommendationTemplateSummary(state, i18n)
                      case final summary?) ...[
                    const SizedBox(height: 8),
                    Text(summary),
                  ],
                  if (localAiStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localAiStatus.available
                          ? i18n.tr('analytics.local_ai_status_available')
                          : i18n.tr('analytics.local_ai_status_unavailable'),
                    ),
                    Text(
                      '${_providerLabel(i18n, localAiStatus.provider)} · ${localAiStatus.model}',
                    ),
                    Text(
                      '${i18n.tr('analytics.local_ai_medical_model')}: '
                      '${localAiStatus.medicalModel}'
                      '${localAiStatus.medicalAvailable ? '' : ' (${i18n.tr('common.optional')})'}',
                    ),
                    if (localAiStatus.endpoint.trim().isNotEmpty)
                      Text(localAiStatus.endpoint),
                    Text(
                      copy.recommendationMessage(localAiStatus.message),
                    ),
                  ],
                  if (state.recommendationExplanations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr('analytics.recommendation_explanations'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    for (final line in state.recommendationExplanations.take(4))
                      Text('• ${copy.recommendationMessage(line)}'),
                  ],
                  if (state.recommendationGateReasons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('analytics.recommendation_gate_reasons'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          for (final reason
                              in state.recommendationGateReasons.take(4))
                            Text(
                              '• ${copy.recommendationMessage(reason)}',
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    i18n.tr('dashboard.recommendations'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (state.recommendations.isEmpty)
                    Text(i18n.tr('dashboard.no_recommendations'))
                  else
                    for (final recommendation in state.recommendations.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${i18n.foodName(recommendation.food.id, recommendation.food.name)}'
                          ' · ${recommendation.score.toStringAsFixed(0)}'
                          ' · ${i18n.decisionLabel(recommendation.decision)}',
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('analytics.replay_benchmark'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(i18n.tr('analytics.replay_benchmark_help')),
                  const SizedBox(height: 8),
                  FilledButton.icon(
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
                  if (state.latestReplayBenchmarkError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr(
                        'analytics.replay_report_error',
                        {'error': state.latestReplayBenchmarkError!},
                      ),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  if (replayReport != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      i18n.tr('analytics.replay_last_report'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${replayReport.datasetVersion} · ${replayReport.generatedAtIso}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      i18n.tr(
                        'analytics.replay_cases',
                        {'count': '${replayReport.cases.length}'},
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: SelectableText(
                        replayReport.toMarkdown(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('analytics.import_tools'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(i18n.tr('analytics.import_tools_help')),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ImportPage()),
                      ),
                      icon: const Icon(Icons.folder_zip_outlined),
                      label: Text(i18n.tr('analytics.open_import_tools')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('analytics.protein_trend'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(i18n.tr('analytics.average_protein',
                      {'value': state.averageProtein.toStringAsFixed(1)})),
                  const SizedBox(height: 8),
                  if (trend.isEmpty) Text(i18n.tr('analytics.no_trend')),
                  for (final point in trend.reversed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${point.protein.toStringAsFixed(1)} g'),
                      subtitle: Text(_formatDateTime(point.time)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
