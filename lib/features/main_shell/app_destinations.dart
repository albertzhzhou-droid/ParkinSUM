import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/state/app_state.dart';
import '../algorithm_observatory/algorithm_observatory_page.dart';
import '../care_workspace/care_workspace_page.dart';
import '../diagnostics/capability_rollout_page.dart';
import '../diagnostics/data_integrity_page.dart';
import '../diagnostics/engineering_diagnostics_page.dart';
import '../diagnostics/operational_observability_page.dart';
import '../diagnostics/rule_audit_trail_page.dart';
import '../diagnostics/rule_test_workbench_page.dart';
import '../entry/entry_page.dart';
import '../import/import_page.dart';
import '../legal/privacy_disclaimer_page.dart';
import '../reminders/reminder_center_page.dart';
import '../settings/personal_log_handoff_page.dart';
import '../settings/portable_data_package_page.dart';
import '../settings/privacy_safe_support_bundle_page.dart';
import '../settings/purpose_bound_consent_page.dart';
import '../settings/recoverable_event_history_page.dart';
import '../settings/settings_capability_page.dart';
import '../timeline/timeline_page.dart';

/// Single source of truth for every secondary destination and global action.
///
/// The sidebar, the compact drawer, the ⌘K command palette and the settings
/// index all read this list, so a page is reachable in one step from
/// anywhere instead of only through the settings grid.

enum AppToolGroup { evidence, data, operations, account }

class AppTool {
  const AppTool({
    required this.id,
    required this.group,
    required this.icon,
    required this.label,
    required this.builder,
    this.subtitle,
    this.keywords = const [],
  });

  final String id;
  final AppToolGroup group;
  final IconData icon;
  final String label;
  final String? subtitle;
  final WidgetBuilder builder;
  final List<String> keywords;

  Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
}

String appToolGroupLabel(AppI18n i18n, AppToolGroup group) => switch (group) {
  AppToolGroup.evidence => i18n.tr('shell.group.evidence'),
  AppToolGroup.data => i18n.tr('shell.group.data'),
  AppToolGroup.operations => i18n.tr('shell.group.operations'),
  AppToolGroup.account => i18n.tr('shell.workspace'),
};

/// All secondary destinations, grouped. Order within a group is the order
/// shown in navigation.
List<AppTool> appTools(AppI18n i18n) {
  final zh = i18n.languageFamily == 'zh';
  return [
    AppTool(
      id: 'observatory',
      group: AppToolGroup.evidence,
      icon: Icons.insights_outlined,
      label: i18n.tr('observatory.title'),
      keywords: const ['algorithm', 'trace', 'mechanism', 'model'],
      builder: (routeContext) {
        final repository = routeContext.read<AppState>().services.appRepository;
        return AlgorithmObservatoryPage(
          service: routeContext
              .read<AppState>()
              .services
              .algorithmObservatoryService,
          onSaveReplayCapsule: repository.saveMechanisticReplayCapsule,
          loadSavedReplayCapsules: repository.loadMechanisticReplayCapsules,
        );
      },
    ),
    AppTool(
      id: 'rule-audit',
      group: AppToolGroup.evidence,
      icon: Icons.fact_check_outlined,
      label: zh ? '规则审计轨迹（合成演示）' : 'Rule audit trail (synthetic demo)',
      subtitle: zh
          ? '固定合成输入，逐条展示规则为何触发、未触发或无法判断。'
          : 'Fixed synthetic inputs show why each rule fired, did not fire, or remained unknown.',
      keywords: const ['rules', 'audit', 'explanation'],
      builder: (_) => const RuleAuditTrailPage(),
    ),
    AppTool(
      id: 'rule-workbench',
      group: AppToolGroup.evidence,
      icon: Icons.rule_folder_outlined,
      label: zh ? '规则测试工作台（仅合成案例）' : 'Rule test workbench (synthetic only)',
      subtitle: zh
          ? '在临时工作区检查规则包与预期结果；不会保存或启用规则。'
          : 'Check rule packs against expected results in a disposable workspace; nothing is saved or activated.',
      keywords: const ['rules', 'test', 'workbench'],
      builder: (_) => RuleTestWorkbenchPage(localeTag: i18n.localeTag),
    ),
    AppTool(
      id: 'data-integrity',
      group: AppToolGroup.evidence,
      icon: Icons.data_thresholding_outlined,
      label: i18n.tr('settings.data_integrity'),
      keywords: const ['sources', 'integrity', 'catalog'],
      builder: (_) => const DataIntegrityPage(),
    ),
    AppTool(
      id: 'diagnostics',
      group: AppToolGroup.evidence,
      icon: Icons.science_outlined,
      label: i18n.tr('diagnostics.title'),
      keywords: const ['engineering', 'debug', 'fhir', 'cds hooks'],
      builder: (_) => const EngineeringDiagnosticsPage(),
    ),
    AppTool(
      id: 'import',
      group: AppToolGroup.data,
      icon: Icons.cloud_download_outlined,
      label: i18n.tr('settings.data_import'),
      keywords: const ['import', 'sources', 'usda', 'ciqual'],
      builder: (_) => const ImportPage(),
    ),
    AppTool(
      id: 'reminders',
      group: AppToolGroup.data,
      icon: Icons.notifications_active_outlined,
      label: i18n.tr('reminders.title'),
      keywords: const ['reminder', 'notification'],
      builder: (_) => const ReminderCenterPage(),
    ),
    AppTool(
      id: 'portable',
      group: AppToolGroup.data,
      icon: Icons.inventory_2_outlined,
      label: i18n.tr('portable.title'),
      keywords: const ['export', 'backup', 'package'],
      builder: (_) => const PortableDataPackagePage(),
    ),
    AppTool(
      id: 'handoff',
      group: AppToolGroup.data,
      icon: Icons.picture_as_pdf_outlined,
      label: i18n.tr('handoff.title'),
      keywords: const ['pdf', 'summary', 'clinician', 'visit'],
      builder: (_) => const PersonalLogHandoffPage(),
    ),
    AppTool(
      id: 'support',
      group: AppToolGroup.data,
      icon: Icons.support_agent_outlined,
      label: i18n.tr('support.title'),
      keywords: const ['support', 'bundle', 'help'],
      builder: (_) => const PrivacySafeSupportBundlePage(),
    ),
    AppTool(
      id: 'consent',
      group: AppToolGroup.data,
      icon: Icons.verified_user_outlined,
      label: i18n.tr('consent.title'),
      keywords: const ['consent', 'privacy', 'ai'],
      builder: (_) => const PurposeBoundConsentPage(),
    ),
    AppTool(
      id: 'history',
      group: AppToolGroup.data,
      icon: Icons.history_outlined,
      label: i18n.tr('history.title'),
      keywords: const ['undo', 'restore', 'deleted'],
      builder: (_) => const RecoverableEventHistoryPage(),
    ),
    AppTool(
      id: 'operations',
      group: AppToolGroup.operations,
      icon: Icons.monitor_heart_outlined,
      label: i18n.tr('operations.title'),
      keywords: const ['observability', 'telemetry'],
      builder: (_) => const OperationalObservabilityPage(),
    ),
    AppTool(
      id: 'rollout',
      group: AppToolGroup.operations,
      icon: Icons.admin_panel_settings_outlined,
      label: i18n.tr('rollout.title'),
      keywords: const ['rollout', 'feature flags', 'capability'],
      builder: (_) => const CapabilityRolloutPage(),
    ),
    AppTool(
      id: 'care-workspace',
      group: AppToolGroup.account,
      icon: Icons.assignment_outlined,
      label: i18n.tr('shell.care_workspace'),
      keywords: const ['visit', 'follow-up', 'questions'],
      builder: (_) => const CareWorkspacePage(),
    ),
    AppTool(
      id: 'settings',
      group: AppToolGroup.account,
      icon: Icons.settings_outlined,
      label: i18n.tr('settings.title'),
      keywords: const ['profile', 'language', 'region', 'account'],
      builder: (_) => const SettingsCapabilityPage(),
    ),
    AppTool(
      id: 'privacy',
      group: AppToolGroup.account,
      icon: Icons.privacy_tip_outlined,
      label: i18n.tr('privacy.title'),
      keywords: const ['disclaimer', 'legal', 'boundary'],
      builder: (_) => const PrivacyDisclaimerPage(),
    ),
  ];
}

/// A global "create" action available from every screen.
class QuickAction {
  const QuickAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
  });

  final String id;
  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext context) run;
}

List<QuickAction> quickActions(AppI18n i18n) => [
  QuickAction(
    id: 'meal',
    icon: Icons.restaurant_outlined,
    label: i18n.tr('dashboard.add_meal'),
    run: (context) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EntryPage())),
  ),
  QuickAction(
    id: 'intake',
    icon: Icons.medication_outlined,
    label: i18n.tr('timeline.add_intake'),
    run: (context) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const IntakeEditorPage())),
  ),
  QuickAction(
    id: 'observation',
    icon: Icons.monitor_heart_outlined,
    label: i18n.tr('shell.action.observation'),
    run: openObservationEditor,
  ),
];
