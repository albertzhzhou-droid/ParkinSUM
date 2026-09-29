import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/services/firebase_backend.dart';
import '../../core/services/reminder_notification_privacy_policy.dart';
import '../../core/services/user_logging_reminder_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/user_logging_reminder.dart';

class ReminderCenterPage extends StatefulWidget {
  const ReminderCenterPage({
    super.key,
    this.controller,
    this.controllerFactory,
    this.requireAuthenticatedAccount,
  });

  final UserLoggingReminderController? controller;

  /// Test/integration seam for proving that a UID change creates a fresh,
  /// account-bound controller. Production leaves this null.
  final UserLoggingReminderController Function(String userScope)?
  controllerFactory;

  /// Defaults to the compiled backend mode. Tests can opt into the Firebase
  /// fail-closed lifecycle while retaining an in-memory service graph.
  final bool? requireAuthenticatedAccount;

  @override
  State<ReminderCenterPage> createState() => _ReminderCenterPageState();
}

class _ReminderCenterPageState extends State<ReminderCenterPage>
    with WidgetsBindingObserver {
  UserLoggingReminderController? _controller;
  bool _ownsController = false;
  String? _boundUserScope;
  Future<void>? _controllerLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindForState(Provider.of<AppState>(context));
  }

  @override
  void didUpdateWidget(covariant ReminderCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller &&
        oldWidget.controllerFactory == widget.controllerFactory &&
        oldWidget.requireAuthenticatedAccount ==
            widget.requireAuthenticatedAccount) {
      return;
    }
    _retireCurrentController();
    _bindForState(context.read<AppState>());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retireCurrentController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = _activeController();
      if (controller != null) {
        unawaited(controller.resynchronize());
      }
    }
  }

  bool get _requiresAuthenticatedAccount =>
      widget.requireAuthenticatedAccount ?? FirebaseBackend.enabled;

  String? _desiredUserScope(AppState state) {
    if (_requiresAuthenticatedAccount) {
      if (state.isAuthBusy) return null;
      return state.currentUserId;
    }
    // Local mode is deliberately a single-device namespace. An explicitly
    // injected controller keeps its own scope for isolated feature tests.
    return widget.controller?.userScope ?? 'local_user';
  }

  void _bindForState(AppState state) {
    final desiredScope = _desiredUserScope(state);
    if (desiredScope == null) {
      _retireCurrentController();
      return;
    }

    final injected = widget.controller;
    if (injected != null &&
        _requiresAuthenticatedAccount &&
        injected.userScope != desiredScope) {
      _retireCurrentController();
      return;
    }
    if (_controller != null && _boundUserScope == desiredScope) return;

    _retireCurrentController();
    final controller =
        injected ??
        widget.controllerFactory?.call(desiredScope) ??
        UserLoggingReminderController(userScope: desiredScope);
    _controller = controller;
    _ownsController = injected == null;
    _boundUserScope = desiredScope;
    final load = controller.load();
    _controllerLoad = load;
    unawaited(
      load.whenComplete(() {
        if (identical(_controller, controller)) {
          _controllerLoad = null;
        }
      }),
    );
  }

  void _retireCurrentController() {
    final controller = _controller;
    final ownsController = _ownsController;
    final load = _controllerLoad;
    _controller = null;
    _ownsController = false;
    _boundUserScope = null;
    _controllerLoad = null;
    if (controller == null || !ownsController) return;
    if (load == null) {
      controller.dispose();
      return;
    }
    // load() notifies in finally. Let that bounded operation settle before
    // disposing its ChangeNotifier; the old controller is already detached
    // from the UI and cannot receive any new user action.
    unawaited(load.whenComplete(controller.dispose));
  }

  UserLoggingReminderController? _activeController() {
    final controller = _controller;
    if (controller == null) return null;
    final state = context.read<AppState>();
    if (_desiredUserScope(state) != _boundUserScope) return null;
    return controller;
  }

  bool _leaseIsCurrent(
    UserLoggingReminderController controller,
    String userScope,
  ) =>
      mounted &&
      identical(_controller, controller) &&
      _boundUserScope == userScope &&
      identical(_activeController(), controller);

  Future<void> _reconcileNotificationLocale({required bool updateCopy}) async {
    final controller = _activeController();
    final userScope = _boundUserScope;
    if (controller == null || userScope == null) return;
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final succeeded = await controller.reconcileNotificationLocale(
      appLocaleName: localeName,
      updateCopy: updateCopy,
    );
    if (!_leaseIsCurrent(controller, userScope) || !succeeded || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.appI18n.tr(
            updateCopy
                ? 'reminders.locale_updated_confirmation'
                : 'reminders.locale_retained_confirmation',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final controller = _activeController();
    if (controller == null) {
      return Scaffold(
        key: const ValueKey<String>('reminder-account-unavailable'),
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: PaperAppBar(title: Text(i18n.tr('reminders.title'))),
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PaperAppBar(
        title: Text(i18n.tr('reminders.title')),
        actions: [
          if (controller.supportsScheduledDelivery)
            IconButton(
              key: const ValueKey('reminder-resynchronize'),
              tooltip: i18n.tr('reminders.resynchronize'),
              onPressed: controller.busy
                  ? null
                  : () => controller.resynchronize(),
              icon: const Icon(Icons.sync_outlined),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('reminder-add'),
        onPressed: _addReminder,
        icon: const Icon(Icons.add_alert_outlined),
        label: Text(i18n.tr('reminders.add')),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final lastSync = controller.lastSynchronizedAt;
            final scheduleManifest = controller.scheduleManifest;
            final pendingAttestation = controller.pendingIdentityAttestation;
            final deliveryReadiness = controller.deliveryReadiness;
            final appLocaleName = Localizations.localeOf(
              context,
            ).toLanguageTag();
            final localeDecisionRequired = controller
                .notificationLocaleDecisionRequired(appLocaleName);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 112),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PaperCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.info_outline),
                            title: Text(i18n.tr('reminders.boundary_title')),
                            subtitle: Text(i18n.tr('reminders.boundary_body')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ReminderDeliveryReadinessCard(
                          readiness: deliveryReadiness,
                        ),
                        if (localeDecisionRequired) ...[
                          const SizedBox(height: 12),
                          PaperCard(
                            child: Column(
                              key: const ValueKey(
                                'reminder-locale-reconciliation',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.translate_outlined),
                                  title: Text(
                                    i18n.tr(
                                      'reminders.locale_reconciliation_title',
                                    ),
                                  ),
                                  subtitle: Text(
                                    i18n.tr(
                                      'reminders.locale_reconciliation_body',
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton(
                                      key: const ValueKey(
                                        'reminder-locale-retain',
                                      ),
                                      onPressed: controller.busy
                                          ? null
                                          : () => _reconcileNotificationLocale(
                                              updateCopy: false,
                                            ),
                                      child: Text(
                                        i18n.tr(
                                          'reminders.locale_retain_action',
                                        ),
                                      ),
                                    ),
                                    FilledButton(
                                      key: const ValueKey(
                                        'reminder-locale-update',
                                      ),
                                      onPressed: controller.busy
                                          ? null
                                          : () => _reconcileNotificationLocale(
                                              updateCopy: true,
                                            ),
                                      child: Text(
                                        i18n.tr(
                                          'reminders.locale_update_action',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (!controller.supportsScheduledDelivery)
                          PaperCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.language_outlined),
                              title: Text(i18n.tr('reminders.web_title')),
                              subtitle: Text(i18n.tr('reminders.web_body')),
                            ),
                          ),
                        if (controller.supportsScheduledDelivery &&
                            lastSync != null &&
                            controller.scheduleSystemState ==
                                ReminderScheduleSystemState.verified) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: PaperCard(
                              child: ListTile(
                                key: const ValueKey('reminder-sync-status'),
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.sync_rounded),
                                title: Text(i18n.tr('reminders.synchronized')),
                                subtitle: Text(
                                  i18n.tr('reminders.last_sync', {
                                    'time': TimeOfDay.fromDateTime(
                                      lastSync,
                                    ).format(context),
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (pendingAttestation != null &&
                            pendingAttestation.status !=
                                ReminderPendingIdentityAttestationStatus
                                    .unsupported) ...[
                          const SizedBox(height: 12),
                          PaperCard(
                            child: ListTile(
                              key: const ValueKey(
                                'reminder-pending-identity-attestation',
                              ),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                pendingAttestation.matched
                                    ? Icons.fact_check_outlined
                                    : Icons.warning_amber_rounded,
                              ),
                              title: Text(
                                i18n.tr('reminders.identity_attestation_title'),
                              ),
                              subtitle: Text(switch (pendingAttestation
                                  .status) {
                                ReminderPendingIdentityAttestationStatus
                                    .matched =>
                                  i18n.tr(
                                    'reminders.identity_attestation_matched',
                                    {
                                      'planned':
                                          '${pendingAttestation.plannedCount}',
                                      'installed':
                                          '${pendingAttestation.installedCount}',
                                    },
                                  ),
                                ReminderPendingIdentityAttestationStatus
                                    .drift =>
                                  i18n.tr(
                                    'reminders.identity_attestation_drift',
                                    {
                                      'missing':
                                          '${pendingAttestation.missingCount}',
                                      'extra':
                                          '${pendingAttestation.extraCount}',
                                      'replaced':
                                          '${pendingAttestation.replacedCount}',
                                    },
                                  ),
                                ReminderPendingIdentityAttestationStatus
                                    .uninspectable =>
                                  i18n.tr(
                                    'reminders.identity_attestation_uninspectable',
                                  ),
                                ReminderPendingIdentityAttestationStatus
                                    .unsupported =>
                                  '',
                              }),
                            ),
                          ),
                        ],
                        if (controller.supportsScheduledDelivery &&
                            scheduleManifest != null) ...[
                          const SizedBox(height: 12),
                          PaperCard(
                            child: ListTile(
                              key: const ValueKey('reminder-schedule-capacity'),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                scheduleManifest.accepted
                                    ? Icons.inventory_2_outlined
                                    : Icons.warning_amber_rounded,
                              ),
                              title: Text(
                                i18n.tr('reminders.schedule_capacity_title'),
                              ),
                              subtitle: Text(
                                scheduleManifest.accepted
                                    ? i18n.tr('reminders.schedule_capacity_body', {
                                        'projected':
                                            '${scheduleManifest.projected}',
                                        'limit':
                                            '${scheduleManifest.limit ?? '—'}',
                                        'headroom':
                                            '${scheduleManifest.headroom ?? '—'}',
                                      })
                                    : i18n.tr(
                                        'reminders.schedule_capacity_invalid',
                                        {
                                          'projected':
                                              '${scheduleManifest.projected}',
                                          'limit':
                                              '${scheduleManifest.limit ?? '—'}',
                                        },
                                      ),
                              ),
                            ),
                          ),
                        ],
                        if (controller.error case final error?) ...[
                          const SizedBox(height: 12),
                          Material(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                i18n.tr('reminders.error_$error'),
                                key: const ValueKey('reminder-error'),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (controller.busy &&
                            controller.reminders.isNotEmpty) ...[
                          const LinearProgressIndicator(
                            key: ValueKey('reminder-busy'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (controller.busy && controller.reminders.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (controller.reminders.isEmpty)
                          PaperCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.notifications_none),
                              title: Text(i18n.tr('reminders.empty_title')),
                              subtitle: Text(i18n.tr('reminders.empty_body')),
                            ),
                          )
                        else
                          for (final reminder in controller.reminders) ...[
                            _ReminderTile(
                              reminder: reminder,
                              busy: controller.busy,
                              onToggle: (enabled) =>
                                  _toggleReminder(reminder, enabled),
                              onEdit: () => _editReminder(reminder),
                              onDelete: () => _deleteReminder(reminder),
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addReminder() async {
    final controller = _activeController();
    final userScope = _boundUserScope;
    if (controller == null || userScope == null) return;
    final reminder = await showDialog<UserLoggingReminder>(
      context: context,
      builder: (_) => const _ReminderEditorDialog(),
    );
    if (reminder == null || !_leaseIsCurrent(controller, userScope)) return;
    await controller.save(reminder);
  }

  Future<void> _editReminder(UserLoggingReminder reminder) async {
    final controller = _activeController();
    final userScope = _boundUserScope;
    if (controller == null || userScope == null) return;
    final updated = await showDialog<UserLoggingReminder>(
      context: context,
      builder: (_) => _ReminderEditorDialog(initial: reminder),
    );
    if (updated == null || !_leaseIsCurrent(controller, userScope)) return;
    await controller.save(updated);
  }

  Future<void> _deleteReminder(UserLoggingReminder reminder) async {
    final controller = _activeController();
    final userScope = _boundUserScope;
    if (controller == null || userScope == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('reminder-delete-confirmation'),
        title: Text(context.appI18n.tr('reminders.delete_title')),
        content: Text(
          context.appI18n.tr('reminders.delete_body', {
            'label': reminder.label,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.appI18n.tr('common.cancel')),
          ),
          FilledButton(
            key: const ValueKey('reminder-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.appI18n.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && _leaseIsCurrent(controller, userScope)) {
      await controller.remove(reminder.id);
    }
  }

  Future<void> _toggleReminder(
    UserLoggingReminder reminder,
    bool enabled,
  ) async {
    final controller = _activeController();
    final userScope = _boundUserScope;
    if (controller == null || userScope == null) return;
    if (!_leaseIsCurrent(controller, userScope)) return;
    await controller.toggle(reminder, enabled);
  }
}

class _ReminderDeliveryReadinessCard extends StatelessWidget {
  const _ReminderDeliveryReadinessCard({required this.readiness});

  final ReminderDeliveryReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final platformKey = switch (readiness.profile.platform) {
      ReminderNotificationPlatform.android => 'android',
      ReminderNotificationPlatform.iOS => 'ios',
      ReminderNotificationPlatform.macOS => 'macos',
      ReminderNotificationPlatform.web => 'web',
      ReminderNotificationPlatform.windows => 'windows',
      ReminderNotificationPlatform.linux => 'linux',
      ReminderNotificationPlatform.unknown => 'unknown',
    };
    String evidenceValue(ReminderNotificationCapability capability) =>
        switch (readiness.profile.evidenceFor(capability)) {
          ReminderNotificationCapabilityEvidence.artifactVerified => i18n.tr(
            'reminders.readiness_evidence_artifact_verified',
          ),
          ReminderNotificationCapabilityEvidence.implementedUnverified =>
            i18n.tr('reminders.readiness_evidence_implemented_unverified'),
          ReminderNotificationCapabilityEvidence.unavailable => i18n.tr(
            'reminders.readiness_evidence_unavailable',
          ),
        };
    final adapterValue = switch (readiness.profile.deliveryMode) {
      ReminderNotificationDeliveryMode.planOnly => i18n.tr(
        'reminders.readiness_adapter_plan_only',
      ),
      ReminderNotificationDeliveryMode.scheduled => evidenceValue(
        ReminderNotificationCapability.scheduleAdapter,
      ),
    };
    final permissionInspection = i18n.tr(
      'reminders.readiness_inspection_${_permissionInspectionKey(readiness.permissionInspection)}',
    );

    return Semantics(
      container: true,
      child: PaperCard(
        key: const ValueKey('reminder-delivery-readiness'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fact_check_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          i18n.tr('reminders.readiness_title'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        i18n.tr('reminders.readiness_contract', {
                          'platform': i18n.tr(
                            'reminders.readiness_platform_$platformKey',
                          ),
                          'digest': readiness.capabilityContractSha256
                              .substring(0, 12),
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_local_plan'),
              value: switch (readiness.localPlan) {
                ReminderLocalPlanReadiness.noneConfigured => i18n.tr(
                  'reminders.readiness_local_none',
                ),
                ReminderLocalPlanReadiness.savedLocally => i18n.tr(
                  'reminders.readiness_local_saved',
                ),
              },
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_adapter'),
              value: adapterValue,
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_schedule_request'),
              value: i18n.tr(
                'reminders.readiness_request_${_scheduleRequestKey(readiness.scheduleRequest)}',
              ),
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_permission_request'),
              value: i18n.tr(
                'reminders.readiness_permission_${_permissionRequestKey(readiness.permissionRequest)}',
              ),
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_permission_inspection'),
              value: permissionInspection,
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_body_tap'),
              value: evidenceValue(ReminderNotificationCapability.bodyTap),
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_cold_start'),
              value: evidenceValue(ReminderNotificationCapability.coldStart),
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_background_action'),
              value: evidenceValue(
                ReminderNotificationCapability.backgroundAction,
              ),
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_registry'),
              value: i18n.tr(
                'reminders.readiness_registry_${_registryKey(readiness.registry)}',
              ),
            ),
            _ReminderReadinessLine(
              label: i18n.tr('reminders.readiness_visible_delivery'),
              value: switch (readiness.visibleDelivery) {
                ReminderVisibleDeliveryReadiness.unverified => i18n.tr(
                  'reminders.readiness_visible_unverified',
                ),
                ReminderVisibleDeliveryReadiness.artifactVerified => i18n.tr(
                  'reminders.readiness_visible_artifact_verified',
                ),
              },
            ),
            const SizedBox(height: 8),
            Text(
              i18n.tr('reminders.readiness_boundary'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _scheduleRequestKey(ReminderScheduleRequestReadiness state) =>
      switch (state) {
        ReminderScheduleRequestReadiness.notRequested => 'not_requested',
        ReminderScheduleRequestReadiness.applied => 'applied',
        ReminderScheduleRequestReadiness.rolledBack => 'rolled_back',
        ReminderScheduleRequestReadiness.superseded => 'superseded',
        ReminderScheduleRequestReadiness.unsupported => 'unsupported',
        ReminderScheduleRequestReadiness.failed => 'failed',
        ReminderScheduleRequestReadiness.recoveryRequired =>
          'recovery_required',
      };

  static String _permissionRequestKey(
    ReminderPermissionRequestReadiness state,
  ) => switch (state) {
    ReminderPermissionRequestReadiness.notRequested => 'not_requested',
    ReminderPermissionRequestReadiness.returnedAllowed => 'granted',
    ReminderPermissionRequestReadiness.returnedNotAllowed => 'denied',
    ReminderPermissionRequestReadiness.adapterUnavailable => 'unavailable',
    ReminderPermissionRequestReadiness.failed => 'failed',
  };

  static String _permissionInspectionKey(
    ReminderPermissionInspectionReadiness state,
  ) => switch (state) {
    ReminderPermissionInspectionReadiness.notInspected => 'not_inspected',
    ReminderPermissionInspectionReadiness.enabled => 'enabled',
    ReminderPermissionInspectionReadiness.disabled => 'disabled',
    ReminderPermissionInspectionReadiness.unavailable => 'unavailable',
    ReminderPermissionInspectionReadiness.failed => 'failed',
  };

  static String _registryKey(ReminderRegistryReadiness state) =>
      switch (state) {
        ReminderRegistryReadiness.notInspected => 'not_inspected',
        ReminderRegistryReadiness.matched => 'matched',
        ReminderRegistryReadiness.drift => 'drift',
        ReminderRegistryReadiness.uninspectable => 'uninspectable',
        ReminderRegistryReadiness.unsupported => 'unsupported',
      };
}

class _ReminderReadinessLine extends StatelessWidget {
  const _ReminderReadinessLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    ),
  );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final UserLoggingReminder reminder;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final next = reminder.nextOccurrence(DateTime.now());
    final time = TimeOfDay(
      hour: reminder.hour,
      minute: reminder.minute,
    ).format(context);
    final days = reminder.weekdays.toList()..sort();
    return PaperCard(
      key: ValueKey('reminder-${reminder.id}'),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: reminder.enabled,
            onChanged: busy ? null : onToggle,
            secondary: Icon(
              reminder.kind == UserLoggingReminderKind.mealLog
                  ? Icons.restaurant_outlined
                  : Icons.medication_outlined,
            ),
            title: Text(reminder.label),
            subtitle: Text(
              '$time · ${days.map((day) => i18n.tr('reminders.day_$day')).join(', ')}\n'
              '${i18n.tr('reminders.next')}: ${MaterialLocalizations.of(context).formatMediumDate(next)} $time\n'
              '${i18n.tr('reminders.privacy')}: ${i18n.tr('reminders.privacy_${reminder.notificationPrivacyMode.name}')}',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey('reminder-edit-${reminder.id}'),
                tooltip: i18n.tr('common.edit'),
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('reminder-delete-${reminder.id}'),
                tooltip: i18n.tr('common.delete'),
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog({this.initial});

  final UserLoggingReminder? initial;

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  late final TextEditingController _labelController;
  late UserLoggingReminderKind _kind;
  late TimeOfDay _time;
  late final Set<int> _weekdays;
  late ReminderNotificationPrivacyMode _privacyMode;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _labelController = TextEditingController(text: initial?.label ?? '');
    _kind = initial?.kind ?? UserLoggingReminderKind.intakeLog;
    _time = initial == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: initial.hour, minute: initial.minute);
    _weekdays = initial?.weekdays.toSet() ?? {1, 2, 3, 4, 5, 6, 7};
    _privacyMode =
        initial?.notificationPrivacyMode ??
        ReminderNotificationPrivacyMode.minimal;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return AlertDialog(
      key: const ValueKey('reminder-editor'),
      title: Text(
        i18n.tr(widget.initial == null ? 'reminders.add' : 'reminders.edit'),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<UserLoggingReminderKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: i18n.tr('reminders.kind'),
                ),
                items: [
                  for (final kind in UserLoggingReminderKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(i18n.tr('reminders.kind_${kind.name}')),
                    ),
                ],
                onChanged: (value) => setState(() => _kind = value ?? _kind),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('reminder-label'),
                controller: _labelController,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: i18n.tr('reminders.label'),
                  helperText: i18n.tr('reminders.label_help'),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ReminderNotificationPrivacyMode>(
                key: const ValueKey('reminder-privacy-mode'),
                initialValue: _privacyMode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: i18n.tr('reminders.privacy'),
                  helperText: i18n.tr('reminders.privacy_help'),
                ),
                items: [
                  for (final mode in ReminderNotificationPrivacyMode.values)
                    DropdownMenuItem(
                      value: mode,
                      child: Text(i18n.tr('reminders.privacy_${mode.name}')),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _privacyMode = value ?? _privacyMode),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final presentation =
                      ReminderNotificationPrivacyPolicy.resolve(
                        mode: _privacyMode,
                        localeName: Localizations.localeOf(
                          context,
                        ).toLanguageTag(),
                      );
                  return Semantics(
                    container: true,
                    label: i18n.tr('reminders.privacy_preview'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i18n.tr('reminders.privacy_preview'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              presentation.title,
                              key: const ValueKey(
                                'reminder-privacy-preview-title',
                              ),
                            ),
                            Text(
                              presentation.body,
                              key: const ValueKey(
                                'reminder-privacy-preview-body',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              i18n.tr(
                                _privacyMode ==
                                        ReminderNotificationPrivacyMode.minimal
                                    ? 'reminders.privacy_minimal_boundary'
                                    : 'reminders.privacy_generic_boundary',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('reminder-time'),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_time.format(context)),
              ),
              const SizedBox(height: 10),
              Text(i18n.tr('reminders.days')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(i18n.tr('reminders.day_$day')),
                      selected: _weekdays.contains(day),
                      onSelected: (selected) => setState(() {
                        selected ? _weekdays.add(day) : _weekdays.remove(day);
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.tr('common.cancel')),
        ),
        FilledButton(
          key: const ValueKey('reminder-save'),
          onPressed: _save,
          child: Text(i18n.tr('common.save')),
        ),
      ],
    );
  }

  void _save() {
    final label = _labelController.text.trim();
    if (label.isEmpty || _weekdays.isEmpty) {
      setState(() => _error = context.appI18n.tr('reminders.validation'));
      return;
    }
    Navigator.of(context).pop(
      UserLoggingReminder(
        id: widget.initial?.id ?? 'reminder_${newReminderActivationToken()}',
        kind: _kind,
        label: label,
        minuteOfDay: _time.hour * 60 + _time.minute,
        weekdays: Set.unmodifiable(_weekdays),
        enabled: widget.initial?.enabled ?? true,
        notificationPrivacyMode: _privacyMode,
        notificationLocaleCode:
            ReminderNotificationPrivacyPolicy.supportedLanguageCode(
              Localizations.localeOf(context).toLanguageTag(),
            ),
        notificationLocaleDecisionCode:
            ReminderNotificationPrivacyPolicy.supportedLanguageCode(
              Localizations.localeOf(context).toLanguageTag(),
            ),
      ),
    );
  }
}
