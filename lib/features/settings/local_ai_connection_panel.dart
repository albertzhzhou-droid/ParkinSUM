import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/response_copy_service.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/usecases/local_ai_recommendation_adapter.dart';

/// Connection settings for the optional local AI wording/rerank path
/// (provider, model names, localhost endpoints, timeout) plus a live
/// availability check.
///
/// Moved out of the user-facing Analytics page into Settings → Advanced:
/// it is operator configuration, not an insight. Consent itself stays in the
/// profile form; this panel never enables AI on its own.
class LocalAiConnectionPanel extends StatefulWidget {
  const LocalAiConnectionPanel({super.key});

  @override
  State<LocalAiConnectionPanel> createState() => _LocalAiConnectionPanelState();
}

class _LocalAiConnectionPanelState extends State<LocalAiConnectionPanel> {
  final _modelController = TextEditingController();
  final _medicalModelController = TextEditingController();
  final _ollamaEndpointController = TextEditingController();
  final _openAiCompatEndpointController = TextEditingController();
  final _timeoutController = TextEditingController();
  String _providerPreference = LocalAiProviders.auto;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final profile = context.read<AppState>().userProfile;
    _providerPreference = profile.localAiProviderPreference;
    _modelController.text = profile.localAiModel;
    _medicalModelController.text = profile.localAiMedicalModel;
    _ollamaEndpointController.text = profile.localAiOllamaEndpoint;
    _openAiCompatEndpointController.text = profile.localAiOpenAiCompatEndpoint;
    _timeoutController.text = '${profile.localAiTimeoutMs}';
    _loaded = true;
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

  Future<void> _save(BuildContext context) async {
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
    final copy = ResponseCopyService(i18n: i18n);
    final status = state.localAiAvailability;
    const gap = SizedBox(height: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.tr('analytics.local_ai_help'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        gap,
        PaperSelectField<String>(
          label: i18n.tr('analytics.local_ai_provider'),
          value: _providerPreference,
          options: [
            for (final (provider, icon) in const [
              (LocalAiProviders.auto, Icons.auto_awesome_rounded),
              (LocalAiProviders.ollama, Icons.memory_rounded),
              (LocalAiProviders.openAiCompat, Icons.api_rounded),
            ])
              PaperSelectOption(
                value: provider,
                label: _providerLabel(i18n, provider),
                icon: icon,
              ),
          ],
          onChanged: (value) => setState(() => _providerPreference = value),
        ),
        gap,
        TextField(
          controller: _modelController,
          decoration: InputDecoration(
            labelText: i18n.tr('analytics.local_ai_model'),
          ),
        ),
        gap,
        TextField(
          controller: _medicalModelController,
          decoration: InputDecoration(
            labelText: i18n.tr('analytics.local_ai_medical_model'),
          ),
        ),
        gap,
        TextField(
          controller: _ollamaEndpointController,
          style: const TextStyle(fontFamily: Paper.mono, fontSize: 13.5),
          decoration: InputDecoration(
            labelText: i18n.tr('analytics.local_ai_ollama_endpoint'),
          ),
        ),
        gap,
        TextField(
          controller: _openAiCompatEndpointController,
          style: const TextStyle(fontFamily: Paper.mono, fontSize: 13.5),
          decoration: InputDecoration(
            labelText: i18n.tr('analytics.local_ai_openai_endpoint'),
          ),
        ),
        gap,
        TextField(
          controller: _timeoutController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: i18n.tr('analytics.local_ai_timeout_ms'),
          ),
        ),
        gap,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.save_outlined),
              label: Text(i18n.tr('common.apply')),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  context.read<AppState>().refreshLocalAiAvailability(),
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(i18n.tr('analytics.local_ai_check')),
            ),
          ],
        ),
        if (status != null) ...[
          gap,
          PaperNote(
            icon: status.available
                ? Icons.check_circle_outline_rounded
                : Icons.portable_wifi_off_rounded,
            tone: status.available ? PaperTone.success : PaperTone.neutral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.available
                      ? i18n.tr('analytics.local_ai_status_available')
                      : i18n.tr('analytics.local_ai_status_unavailable'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_providerLabel(i18n, status.provider)} · ${status.model}',
                ),
                Text(
                  '${i18n.tr('analytics.local_ai_medical_model')}: '
                  '${status.medicalModel}'
                  '${status.medicalAvailable ? '' : ' (${i18n.tr('common.optional')})'}',
                ),
                if (status.endpoint.trim().isNotEmpty)
                  Text(
                    status.endpoint,
                    style: const TextStyle(fontFamily: Paper.mono),
                  ),
                Text(copy.recommendationMessage(status.message)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
