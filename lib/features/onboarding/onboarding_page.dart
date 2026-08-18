import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/constants/profile_options.dart';
import '../../core/models/drug_definition.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/usecases/explanation_copy_service.dart';
import 'onboarding_flow.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _overrideController = TextEditingController();
  final _doseController = TextEditingController();
  final _medicationSearchController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _activeDrugIds = <String>{};

  int _currentStep = 0;
  bool _didLoadInitialValues = false;
  bool _isSubmitting = false;
  late String _registrationRegion;
  late String _displayLocale;
  String? _dietProfileRegion;
  late String _swallowingTextureMode;
  bool _localAiConsentEnabled = false;
  bool _recordInitialIntake = false;
  String? _initialIntakeDrugId;
  DateTime? _initialIntakeAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialValues) return;
    final state = context.read<AppState>();
    final profile = state.userProfile;
    _registrationRegion = profile.registrationRegion;
    _displayLocale = profile.displayLocale;
    _dietProfileRegion =
        profile.dietProfileRegion ?? profile.registrationRegion;
    _swallowingTextureMode = profile.swallowingTextureMode;
    _localAiConsentEnabled = profile.hasCurrentLocalAiConsent;
    _overrideController.text = profile.contentJurisdictionOverride.join(', ');
    _activeDrugIds.addAll(state.activeDrugs.map((drug) => drug.id));
    if (_activeDrugIds.isNotEmpty) {
      _initialIntakeDrugId = _activeDrugIds.first;
    }
    _initialIntakeAt = DateTime.now();
    _didLoadInitialValues = true;
  }

  @override
  void dispose() {
    _overrideController.dispose();
    _doseController.dispose();
    _medicationSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n.fromLocaleTag(_displayLocale);
    final steps = _buildSteps(state, i18n);

    return Scaffold(
      appBar: AppBar(title: Text(i18n.tr('onboarding.appbar'))),
      body: SafeArea(
        child: Stepper(
          controller: _scrollController,
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepTapped: _goToStep,
          controlsBuilder: (context, details) {
            // Stepper builds controls for every step, including collapsed and
            // outgoing animated content. Keep only the active controls in the
            // focus tree so keyboard users and device tests never encounter
            // duplicate Continue/Back actions.
            if (details.stepIndex != _currentStep) {
              return const SizedBox.shrink();
            }
            final isLast = _currentStep == steps.length - 1;
            return Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: ValueKey(
                      isLast ? 'onboarding-finish' : 'onboarding-next',
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : isLast
                        ? _finish
                        : _next,
                    icon: _isSubmitting && isLast
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isLast ? Icons.check : Icons.arrow_forward),
                    label: Text(
                      isLast
                          ? i18n.tr('onboarding.finish')
                          : i18n.tr('onboarding.next'),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    TextButton.icon(
                      key: const ValueKey('onboarding-back'),
                      onPressed: _isSubmitting ? null : _back,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(i18n.tr('onboarding.back')),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: steps,
        ),
      ),
    );
  }

  List<Step> _buildSteps(AppState state, AppI18n i18n) {
    return [
      Step(
        title: Text(i18n.tr('onboarding.step_safety')),
        subtitle: Text(i18n.tr('onboarding.step_safety_subtitle')),
        isActive: _currentStep >= 0,
        state: _stepState(0),
        content: _Panel(
          children: [
            _IconLine(
              icon: Icons.health_and_safety_outlined,
              title: const ExplanationCopyService().resolveForLocale(
                'onboarding_safety_education_title',
                locale: i18n.languageFamily,
                fallback: i18n.tr('onboarding.safety_education_title'),
              ),
              body: const ExplanationCopyService().resolveForLocale(
                'onboarding_safety_education_body',
                locale: i18n.languageFamily,
                fallback: i18n.tr('onboarding.safety_education_body'),
              ),
            ),
            const SizedBox(height: 12),
            _IconLine(
              icon: Icons.privacy_tip_outlined,
              title: const ExplanationCopyService().resolveForLocale(
                'onboarding_account_scope_title',
                locale: i18n.languageFamily,
                fallback: i18n.tr('onboarding.account_scope_title'),
              ),
              body: const ExplanationCopyService().resolveForLocale(
                'onboarding_account_scope_body',
                locale: i18n.languageFamily,
                fallback: i18n.tr('onboarding.account_scope_body'),
              ),
            ),
          ],
        ),
      ),
      Step(
        title: Text(i18n.tr('onboarding.step_profile')),
        subtitle: Text(i18n.tr('onboarding.step_profile_subtitle')),
        isActive: _currentStep >= 1,
        state: _stepState(1),
        content: _Panel(
          children: [
            GlassSelectField<String>(
              label: i18n.tr('onboarding.registration_region'),
              helper: i18n.tr('onboarding.registration_region_help'),
              value: _registrationRegion,
              options: kSupportedRegistrationRegions
                  .map(
                    (value) => GlassSelectOption<String>(
                      value: value,
                      label: i18n.regionLabel(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _registrationRegion = value;
                  _dietProfileRegion ??= value;
                  _displayLocale = defaultLocaleForRegion(
                    value,
                    _displayLocale,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            GlassSelectField<String>(
              label: i18n.tr('onboarding.display_language'),
              helper: i18n.tr('onboarding.display_language_help'),
              value: _displayLocale,
              options: kSupportedDisplayLocales
                  .map(
                    (value) => GlassSelectOption<String>(
                      value: value,
                      label: i18n.localeLabel(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _displayLocale = value),
            ),
          ],
        ),
      ),
      Step(
        title: Text(i18n.tr('onboarding.step_medications')),
        subtitle: Text(i18n.tr('onboarding.step_medications_subtitle')),
        isActive: _currentStep >= 2,
        state: _stepState(2),
        content: _Panel(
          children: [
            Text(
              i18n.tr('onboarding.active_medications_help'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('onboarding-medication-search'),
              controller: _medicationSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: i18n.tr('catalog.search'),
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon: _medicationSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: i18n.tr('common.close'),
                        onPressed: () {
                          _medicationSearchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            _medicationPicker(state, i18n),
            if (_activeDrugIds.isNotEmpty) ...[
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _recordInitialIntake,
                title: Text(i18n.tr('onboarding.record_initial_intake')),
                subtitle: Text(
                  i18n.tr('onboarding.record_initial_intake_help'),
                ),
                onChanged: (value) => setState(() {
                  _recordInitialIntake = value;
                  _initialIntakeDrugId ??= _activeDrugIds.first;
                  _initialIntakeAt ??= DateTime.now();
                }),
              ),
              if (_recordInitialIntake) ...[
                const SizedBox(height: 8),
                GlassSelectField<String>(
                  label: i18n.tr('onboarding.initial_intake_drug'),
                  helper: i18n.tr('onboarding.initial_intake_drug_help'),
                  value: _initialIntakeDrugId ?? _activeDrugIds.first,
                  options: _activeDrugIds
                      .map((id) => state.medRepo.getById(id))
                      .whereType<DrugDefinition>()
                      .map(
                        (drug) => GlassSelectOption<String>(
                          value: drug.id,
                          label: i18n.medicationName(drug.id, drug.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _initialIntakeDrugId = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(i18n.tr('onboarding.initial_intake_time')),
                  subtitle: Text(_formatDateTime(context, _initialIntakeAt!)),
                  trailing: TextButton(
                    onPressed: _pickInitialIntakeTime,
                    child: Text(i18n.tr('onboarding.change_time')),
                  ),
                ),
                TextField(
                  controller: _doseController,
                  decoration: InputDecoration(
                    labelText: i18n.tr('onboarding.initial_intake_note'),
                    helperText: i18n.tr('onboarding.initial_intake_note_help'),
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      Step(
        title: Text(i18n.tr('onboarding.step_preferences')),
        subtitle: Text(i18n.tr('onboarding.step_preferences_subtitle')),
        isActive: _currentStep >= 3,
        state: _stepState(3),
        content: _Panel(
          children: [
            GlassSelectField<String>(
              label: i18n.tr('onboarding.diet_profile_region'),
              helper: i18n.tr('onboarding.diet_profile_region_help'),
              value: _dietProfileRegion ?? _registrationRegion,
              options: kSupportedRegistrationRegions
                  .map(
                    (value) => GlassSelectOption<String>(
                      value: value,
                      label: i18n.regionLabel(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _dietProfileRegion = value),
            ),
            const SizedBox(height: 12),
            GlassSelectField<String>(
              label: i18n.tr('onboarding.swallowing_texture_mode'),
              helper: i18n.tr('onboarding.swallowing_texture_mode_help'),
              value: _swallowingTextureMode,
              options: kSupportedTextureModes
                  .map(
                    (value) => GlassSelectOption<String>(
                      value: value,
                      label: i18n.textureModeLabel(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _swallowingTextureMode = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _overrideController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: i18n.tr('onboarding.content_override'),
                helperText: i18n.tr('onboarding.content_override_help'),
                prefixIcon: const Icon(Icons.public_outlined),
              ),
            ),
          ],
        ),
      ),
      Step(
        title: Text(i18n.tr('onboarding.step_review')),
        subtitle: Text(i18n.tr('onboarding.step_review_subtitle')),
        isActive: _currentStep >= 4,
        state: _stepState(4),
        content: _Panel(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _localAiConsentEnabled,
              title: Text(i18n.tr('onboarding.local_ai_consent')),
              subtitle: Text(i18n.tr('onboarding.local_ai_consent_help')),
              onChanged: (value) =>
                  setState(() => _localAiConsentEnabled = value),
            ),
            const Divider(height: 28),
            _SummaryRow(
              label: i18n.tr('onboarding.summary_region'),
              value: i18n.regionLabel(_registrationRegion),
            ),
            _SummaryRow(
              label: i18n.tr('onboarding.summary_language'),
              value: i18n.localeLabel(_displayLocale),
            ),
            _SummaryRow(
              label: i18n.tr('onboarding.summary_active_meds'),
              value: '${_activeDrugIds.length}',
            ),
            _SummaryRow(
              label: i18n.tr('onboarding.summary_initial_intake'),
              value: _recordInitialIntake
                  ? i18n.tr('common.yes')
                  : i18n.tr('common.no'),
            ),
            _SummaryRow(
              label: i18n.tr('onboarding.summary_texture'),
              value: i18n.textureModeLabel(_swallowingTextureMode),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _medicationPicker(AppState state, AppI18n i18n) {
    final query = _medicationSearchController.text.trim().toLowerCase();
    final drugs = state.medRepo.allDrugs
        .where((drug) {
          if (query.isEmpty) return true;
          final localizedName = i18n
              .medicationName(drug.id, drug.displayName)
              .toLowerCase();
          return localizedName.contains(query) ||
              drug.genericName.toLowerCase().contains(query) ||
              drug.sourceSystem.toLowerCase().contains(query) ||
              drug.jurisdiction.toLowerCase().contains(query);
        })
        .toList(growable: false);
    if (drugs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(i18n.tr('onboarding.no_medications_available')),
      );
    }
    return ConstrainedBox(
      key: const ValueKey('onboarding-medication-picker'),
      constraints: const BoxConstraints(maxHeight: 420),
      child: Scrollbar(
        child: ListView.builder(
          primary: false,
          shrinkWrap: true,
          itemCount: drugs.length,
          itemBuilder: (context, index) {
            final drug = drugs[index];
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _activeDrugIds.contains(drug.id),
              title: Text(i18n.medicationName(drug.id, drug.displayName)),
              subtitle: Text(
                [
                  i18n.sourceSystemLabel(drug.sourceSystem),
                  i18n.regionLabel(drug.jurisdiction),
                  i18n.routeLabel(drug.route),
                  i18n.dosageFormLabel(drug.dosageForm),
                ].join(' · '),
              ),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _activeDrugIds.add(drug.id);
                  _initialIntakeDrugId ??= drug.id;
                } else {
                  _activeDrugIds.remove(drug.id);
                  if (_initialIntakeDrugId == drug.id) {
                    _initialIntakeDrugId = _activeDrugIds.isEmpty
                        ? null
                        : _activeDrugIds.first;
                  }
                  if (_activeDrugIds.isEmpty) {
                    _recordInitialIntake = false;
                  }
                }
              }),
            );
          },
        ),
      ),
    );
  }

  StepState _stepState(int step) {
    if (_currentStep == step) return StepState.editing;
    if (_currentStep > step) return StepState.complete;
    return StepState.indexed;
  }

  void _next() {
    _goToStep(_currentStep + 1);
  }

  void _back() {
    _goToStep(_currentStep - 1);
  }

  void _goToStep(int step) {
    if (step < 0 || step > 4 || step == _currentStep) return;
    setState(() => _currentStep = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _finish() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final state = context.read<AppState>();
    final draft = OnboardingDraft(
      registrationRegion: _registrationRegion,
      displayLocale: _displayLocale,
      dietProfileRegion: _dietProfileRegion,
      swallowingTextureMode: _swallowingTextureMode,
      localAiConsentEnabled: _localAiConsentEnabled,
      contentJurisdictionOverrideText: _overrideController.text,
      activeDrugIds: _activeDrugIds.toList(growable: false),
      initialIntakeDrugId: _recordInitialIntake ? _initialIntakeDrugId : null,
      initialIntakeAt: _recordInitialIntake ? _initialIntakeAt : null,
      initialIntakeDoseNote: _doseController.text,
    );
    try {
      final initialDrugId = draft.initialIntakeDrugId;
      final intake = draft.buildInitialIntake(
        intakeId: state.newId('intake'),
        drug: initialDrugId == null
            ? null
            : state.medRepo.getById(initialDrugId),
      );
      await state.completeOnboarding(
        profile: draft.buildProfile(
          state.userProfile,
          patientId: state.currentUserId ?? state.userProfile.patientId,
          consentRecordedAt: DateTime.now().toUtc(),
        ),
        activeDrugIds: draft.activeDrugIds,
        initialIntake: intake,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppI18n.fromLocaleTag(
              _displayLocale,
            ).tr('onboarding.finish_failed', {'error': '$error'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickInitialIntakeTime() async {
    final initial = _initialIntakeAt ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;
    setState(() {
      _initialIntakeAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(value);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date $time';
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _IconLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: LiquidGlass.seed, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
