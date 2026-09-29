import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/profile_options.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/services/firebase_backend.dart';
import '../../core/state/app_state.dart';
import '../../core/state/persisted_value_mutation.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/product_upgrade_queue.dart';
import '../main_shell/app_destinations.dart';
import 'local_ai_connection_panel.dart';
import '../onboarding/onboarding_flow.dart';
import 'change_password_dialog.dart';

class SettingsCapabilityPage extends StatefulWidget {
  const SettingsCapabilityPage({super.key, this.initialQueue});

  final ProductUpgradeQueue? initialQueue;

  @override
  State<SettingsCapabilityPage> createState() => _SettingsCapabilityPageState();
}

class _SettingsCapabilityPageState extends State<SettingsCapabilityPage> {
  final _overrideController = TextEditingController();
  bool _didLoad = false;
  late String _registrationRegion;
  late String _displayLocale;
  late String _dietProfileRegion;
  late String _textureMode;
  bool _localAiConsent = false;
  Future<ProductUpgradeQueue>? _queueFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    final profile = context.read<AppState>().userProfile;
    _registrationRegion = profile.registrationRegion;
    _displayLocale = profile.displayLocale;
    _dietProfileRegion =
        profile.dietProfileRegion ?? profile.registrationRegion;
    _textureMode = profile.swallowingTextureMode;
    _localAiConsent = profile.hasCurrentLocalAiConsent;
    _overrideController.text = profile.contentJurisdictionOverride.join(', ');
    _queueFuture = widget.initialQueue == null
        ? DefaultAssetBundle.of(context)
              .loadString('config/complete_app_upgrade_queue.json')
              .then(ProductUpgradeQueue.fromJsonText)
        : Future<ProductUpgradeQueue>.value(widget.initialQueue);
    // The queue section is built lazily (it sits below the fold on narrow
    // layouts). Mark a load failure as observed so it is not reported as an
    // uncaught error; the FutureBuilder still shows it once visible.
    _queueFuture!.ignore();
    _didLoad = true;
  }

  @override
  void dispose() {
    _overrideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n.fromLocaleTag(_displayLocale);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PaperAppBar(title: Text(i18n.tr('settings.title'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final insets = paperPageInsets(
              constraints.maxWidth,
              maxWidth: 1180,
              top: 8,
            );
            final wide = constraints.maxWidth - insets.horizontal >= 900;
            final profile = <Widget>[
              _sectionTitle(
                context,
                Icons.manage_accounts_outlined,
                i18n.tr('settings.profile'),
              ),
              const SizedBox(height: 10),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profileFields(i18n),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        key: const ValueKey('settings-save-profile'),
                        onPressed: state.isSavingUserProfile
                            ? null
                            : _saveProfile,
                        icon: state.isSavingUserProfile
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(i18n.tr('common.save')),
                      ),
                    ),
                  ],
                ),
              ),
            ];
            final account = <Widget>[
              _sectionTitle(
                context,
                Icons.account_circle_outlined,
                i18n.tr('settings.account'),
              ),
              const SizedBox(height: 10),
              _accountCard(state, i18n),
            ];
            final queue = <Widget>[
              _sectionTitle(
                context,
                Icons.route_outlined,
                i18n.tr('settings.queue'),
              ),
              const SizedBox(height: 10),
              _upgradeQueue(i18n),
            ];
            // Tools used to be a grid of large tiles at the top of this page
            // (the only way to reach them). They now live in the sidebar and
            // ⌘K palette too, so here they are a compact grouped index.
            final tools = <Widget>[
              _sectionTitle(
                context,
                Icons.hub_outlined,
                i18n.tr('settings.capabilities'),
              ),
              const SizedBox(height: 10),
              _toolIndex(i18n),
            ];
            // Operator-level connection settings for the optional local AI
            // path, folded away by default (moved here from Analytics).
            final advanced = <Widget>[
              PaperCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: const ValueKey('settings-local-ai-advanced'),
                  leading: const Icon(
                    Icons.memory_rounded,
                    color: Paper.accent,
                  ),
                  title: Text(i18n.tr('settings.local_ai_advanced')),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: const [LocalAiConnectionPanel()],
                ),
              ),
            ];
            const gap = SizedBox(height: 24);
            if (!wide) {
              return ListView(
                padding: insets,
                children: [
                  ...profile,
                  gap,
                  ...account,
                  const SizedBox(height: 12),
                  ...advanced,
                  gap,
                  ...tools,
                  gap,
                  ...queue,
                ],
              );
            }
            return ListView(
              padding: insets,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...profile,
                          gap,
                          ...account,
                          const SizedBox(height: 12),
                          ...advanced,
                          gap,
                          ...queue,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: tools,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _profileFields(AppI18n i18n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaperSelectField<String>(
          label: i18n.tr('onboarding.registration_region'),
          helper: i18n.tr('onboarding.registration_region_help'),
          value: _registrationRegion,
          options: [
            for (final region in kSupportedRegistrationRegions)
              PaperSelectOption(value: region, label: i18n.regionLabel(region)),
          ],
          onChanged: (value) => setState(() {
            _registrationRegion = value;
            _displayLocale = defaultLocaleForRegion(value, _displayLocale);
          }),
        ),
        const SizedBox(height: 12),
        PaperSelectField<String>(
          label: i18n.tr('onboarding.display_language'),
          helper: i18n.tr('onboarding.display_language_help'),
          value: _displayLocale,
          options: [
            for (final locale in kSupportedDisplayLocales)
              PaperSelectOption(value: locale, label: i18n.localeLabel(locale)),
          ],
          onChanged: (value) => setState(() => _displayLocale = value),
        ),
        const SizedBox(height: 12),
        PaperSelectField<String>(
          label: i18n.tr('onboarding.diet_profile_region'),
          helper: i18n.tr('onboarding.diet_profile_region_help'),
          value: _dietProfileRegion,
          options: [
            for (final region in kSupportedRegistrationRegions)
              PaperSelectOption(value: region, label: i18n.regionLabel(region)),
          ],
          onChanged: (value) => setState(() => _dietProfileRegion = value),
        ),
        const SizedBox(height: 12),
        PaperSelectField<String>(
          label: i18n.tr('onboarding.swallowing_texture_mode'),
          helper: i18n.tr('onboarding.swallowing_texture_mode_help'),
          value: _textureMode,
          options: [
            for (final mode in kSupportedTextureModes)
              PaperSelectOption(
                value: mode,
                label: i18n.textureModeLabel(mode),
              ),
          ],
          onChanged: (value) => setState(() => _textureMode = value),
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
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _localAiConsent,
          title: Text(i18n.tr('onboarding.local_ai_consent')),
          subtitle: Text(i18n.tr('onboarding.local_ai_consent_help')),
          onChanged: (value) => setState(() => _localAiConsent = value),
        ),
      ],
    );
  }

  Widget _toolIndex(AppI18n i18n) {
    final tools = appTools(i18n).where((tool) => tool.id != 'settings');
    final groups = <AppToolGroup, List<AppTool>>{};
    for (final tool in tools) {
      groups.putIfAbsent(tool.group, () => []).add(tool);
    }
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                appToolGroupLabel(i18n, entry.key).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.3,
                  color: Paper.accentInk,
                ),
              ),
            ),
            for (final tool in entry.value)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(tool.icon, size: 20, color: Paper.accent),
                title: Text(tool.label),
                subtitle: tool.subtitle == null ? null : Text(tool.subtitle!),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Paper.inkFaint,
                ),
                onTap: () => tool.open(context),
              ),
          ],
        ],
      ),
    );
  }

  Widget _accountCard(AppState state, AppI18n i18n) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (FirebaseBackend.enabled) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(
                state.currentUserEmail ?? state.currentUserId ?? 'Account',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n.tr('onboarding.account_scope_body')),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(
                      state.currentUserEmailVerified
                          ? Icons.verified_outlined
                          : Icons.pending_outlined,
                      size: 18,
                    ),
                    label: Text(
                      i18n.tr(
                        state.currentUserEmailVerified
                            ? 'settings.email_verified'
                            : 'settings.email_unverified',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.canChangePassword)
                  OutlinedButton.icon(
                    key: const ValueKey('settings-change-password'),
                    onPressed: state.isAuthBusy
                        ? null
                        : () => _changePassword(i18n),
                    icon: const Icon(Icons.password_outlined),
                    label: Text(i18n.tr('settings.change_password')),
                  ),
                if (!state.currentUserEmailVerified)
                  OutlinedButton.icon(
                    onPressed: state.isAuthBusy
                        ? null
                        : () => _sendVerification(i18n),
                    icon: const Icon(Icons.mark_email_unread_outlined),
                    label: Text(i18n.tr('settings.send_verification')),
                  ),
                OutlinedButton.icon(
                  onPressed: state.isAuthBusy
                      ? null
                      : () => _refreshVerification(i18n),
                  icon: const Icon(Icons.refresh),
                  label: Text(i18n.tr('settings.refresh_verification')),
                ),
                OutlinedButton.icon(
                  onPressed: state.isAuthBusy ? null : state.signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(i18n.tr('common.sign_out')),
                ),
              ],
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phonelink_lock_outlined),
              title: Text(i18n.tr('settings.local_mode')),
              subtitle: Text(i18n.tr('onboarding.account_scope_body')),
            ),
        ],
      ),
    );
  }

  Widget _upgradeQueue(AppI18n i18n) {
    return FutureBuilder<ProductUpgradeQueue>(
      future: _queueFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return PaperCard(child: Text(i18n.tr('common.error')));
        }
        final queue = snapshot.data!;
        final items = [...queue.items]
          ..sort((left, right) {
            final status = _statusRank(
              left.status,
            ).compareTo(_statusRank(right.status));
            return status != 0 ? status : right.score.compareTo(left.score);
          });
        return PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(i18n.tr('settings.queue_help')),
              const SizedBox(height: 6),
              Text(
                i18n.tr('settings.reviewed', {'date': queue.reviewedAt}),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Divider(height: 28),
              for (final item in items)
                _UpgradeQueueTile(item: item, i18n: i18n),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final state = context.read<AppState>();
    final i18n = AppI18n.fromLocaleTag(_displayLocale);
    final overrides = _overrideController.text
        .split(',')
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    var nextProfile = state.userProfile.copyWith(
      registrationRegion: _registrationRegion,
      displayLocale: _displayLocale,
      dietProfileRegion: _dietProfileRegion,
      swallowingTextureMode: _textureMode,
      contentJurisdictionOverride: overrides,
    );
    nextProfile = nextProfile.withLocalAiConsentDecision(
      enabled: _localAiConsent,
      recordedAt: DateTime.now().toUtc(),
      source: 'settings',
    );
    try {
      final result = await state.saveUserProfile(nextProfile);
      if (!mounted) return;
      final message =
          result.status ==
              PersistedValueMutationStatus.committedWithRefreshFailure
          ? i18n.tr('settings.saved_refresh_pending')
          : i18n.tr('settings.saved');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.tr('settings.save_failed', {'error': '$error'})),
        ),
      );
    }
  }

  Future<void> _sendVerification(AppI18n i18n) async {
    try {
      await context.read<AppState>().sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('settings.verification_sent'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.tr('settings.auth_action_failed', {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<void> _refreshVerification(AppI18n i18n) async {
    try {
      await context.read<AppState>().refreshEmailVerificationStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('settings.verification_refreshed'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.tr('settings.auth_action_failed', {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<void> _changePassword(AppI18n i18n) async {
    final state = context.read<AppState>();
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangePasswordDialog(
        i18n: i18n,
        onChangePassword: (currentPassword, newPassword) =>
            state.changePassword(
              currentPassword: currentPassword,
              newPassword: newPassword,
            ),
      ),
    );
    if (!mounted || changed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(i18n.tr('settings.password_changed'))),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Paper.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );
  }
}

class _UpgradeQueueTile extends StatelessWidget {
  const _UpgradeQueueTile({required this.item, required this.i18n});

  final ProductUpgradeItem item;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: color.withValues(alpha: 0.07),
      child: ExpansionTile(
        leading: Icon(_statusIcon(item.status), color: color),
        title: Text(item.title),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(label: Text(item.priority)),
            Chip(label: Text(_statusLabel(item.status))),
            Chip(
              label: Text(
                i18n.tr('settings.score', {'score': '${item.score}'}),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.currentGap),
          const SizedBox(height: 10),
          for (final criterion in item.acceptanceCriteria)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(criterion)),
                ],
              ),
            ),
          if (item.dependencies.isNotEmpty)
            Text('Depends on: ${item.dependencies.join(', ')}'),
        ],
      ),
    );
  }
}

int _statusRank(ProductUpgradeStatus status) => switch (status) {
  ProductUpgradeStatus.inProgress => 0,
  ProductUpgradeStatus.queued => 1,
  ProductUpgradeStatus.researchRequired => 2,
  ProductUpgradeStatus.externalDependency => 3,
  ProductUpgradeStatus.shipped => 4,
};

String _statusLabel(ProductUpgradeStatus status) => switch (status) {
  ProductUpgradeStatus.shipped => 'Shipped',
  ProductUpgradeStatus.inProgress => 'In progress',
  ProductUpgradeStatus.queued => 'Queued',
  ProductUpgradeStatus.researchRequired => 'Research required',
  ProductUpgradeStatus.externalDependency => 'External dependency',
};

IconData _statusIcon(ProductUpgradeStatus status) => switch (status) {
  ProductUpgradeStatus.shipped => Icons.verified_outlined,
  ProductUpgradeStatus.inProgress => Icons.construction_outlined,
  ProductUpgradeStatus.queued => Icons.schedule_outlined,
  ProductUpgradeStatus.researchRequired => Icons.biotech_outlined,
  ProductUpgradeStatus.externalDependency => Icons.handshake_outlined,
};

Color _statusColor(ProductUpgradeStatus status) => switch (status) {
  ProductUpgradeStatus.shipped => Colors.green.shade700,
  ProductUpgradeStatus.inProgress => Colors.blue.shade700,
  ProductUpgradeStatus.queued => Colors.orange.shade800,
  ProductUpgradeStatus.researchRequired => Colors.purple.shade700,
  ProductUpgradeStatus.externalDependency => Colors.red.shade700,
};
