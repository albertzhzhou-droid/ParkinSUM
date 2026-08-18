import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/firebase_backend.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import 'dashboard_page.dart';
import '../analytics/analytics_page.dart';
import '../medications/medication_page.dart';
import '../catalog/catalog_page.dart';
import '../diagnostics/engineering_diagnostics_page.dart';
import '../diagnostics/data_integrity_page.dart';
import '../legal/privacy_disclaimer_page.dart';
import '../next_meal/next_meal_page.dart';
import '../timeline/timeline_page.dart';
import 'lazy_indexed_stack.dart';
import 'main_tab_route.dart';

/// 主壳：底部导航 — 现在使用 Liquid Glass 设计语言。
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.selectedTabId = 'home', this.onTabSelected});

  final String selectedTabId;
  final ValueChanged<String>? onTabSelected;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<WidgetBuilder> _pageBuilders = <WidgetBuilder>[
    (_) => const DashboardPage(),
    (_) => const NextMealPage(),
    (_) => const TimelinePage(),
    (_) => const AnalyticsPage(),
    (_) => const MedicationPage(),
    (_) => const CatalogPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = MainTabRoute.fromId(widget.selectedTabId).index;
    final i18n = context.appI18n;
    final state = context.watch<AppState>();
    // The bar used to render only in Firebase mode, which left the privacy &
    // disclaimer page unreachable in local/public-demo mode once onboarding was
    // done. It now always renders; only the account-specific bits are gated.
    final showAccountActions = FirebaseBackend.enabled;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // We deliberately do NOT use `extendBody: true`. With a floating glass
      // nav bar, extending the body behind it caused the dashboard FAB
      // ("Add a meal") to sit underneath the bar. Letting Scaffold reserve
      // the nav-bar height keeps the FAB visible; the BackdropFilter still
      // samples the static LiquidGlassBackground for the frosted look.
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(
          showAccountActions
              ? (state.currentUserEmail ?? state.currentUserId ?? 'Account')
              : i18n.tr('onboarding.appbar'),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: i18n.tr('runtime.validation_source'),
            icon: const Icon(Icons.data_thresholding_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DataIntegrityPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: i18n.tr('diagnostics.title'),
            icon: const Icon(Icons.science_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EngineeringDiagnosticsPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Privacy & Disclaimer',
            icon: const Icon(Icons.privacy_tip_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyDisclaimerPage(),
              ),
            ),
          ),
          if (showAccountActions)
            IconButton(
              tooltip: i18n.tr('common.sign_out'),
              icon: const Icon(Icons.logout, size: 20),
              onPressed: state.isAuthBusy
                  ? null
                  : () => context.read<AppState>().signOut(),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final destinations = _destinations(i18n);
          final useRail = constraints.maxWidth >= 900;
          final page = LazyIndexedStack(
            index: selectedIndex,
            builders: _pageBuilders,
          );
          if (!useRail) return page;
          final extended = constraints.maxWidth >= 1180;
          return Row(
            children: [
              SafeArea(
                right: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 76, 8, 12),
                  child: GlassSurface(
                    borderRadius: LiquidGlass.radiusXl,
                    blurSigma: LiquidGlass.blurLg,
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: selectedIndex,
                      extended: extended,
                      minWidth: 72,
                      minExtendedWidth: 220,
                      groupAlignment: -0.65,
                      onDestinationSelected: _selectTab,
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(
                              destination.selectedIcon ?? destination.icon,
                            ),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: page),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 900
          ? null
          : GlassNavBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: _selectTab,
              destinations: _destinations(i18n),
            ),
    );
  }

  void _selectTab(int index) {
    final route = MainTabRoute.fromIndex(index);
    if (route.id == MainTabRoute.fromId(widget.selectedTabId).id) return;
    debugPrint('[MainShell] tab:selected id=${route.id} index=$index');
    widget.onTabSelected?.call(route.id);
  }

  List<GlassNavDestination> _destinations(AppI18n i18n) {
    return [
      GlassNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: i18n.tr('nav.home'),
      ),
      // 下餐推荐：以前藏在「分析」页底部，现在作为独立的主导航条目，
      // 主要由冲突引擎驱动，可选用本地 AI 润色。
      GlassNavDestination(
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome_rounded,
        label: i18n.tr('nav.next_meal'),
      ),
      GlassNavDestination(
        icon: Icons.restaurant_outlined,
        selectedIcon: Icons.restaurant_rounded,
        label: i18n.tr('nav.timeline'),
      ),
      GlassNavDestination(
        icon: Icons.show_chart_outlined,
        selectedIcon: Icons.show_chart_rounded,
        label: i18n.tr('nav.analytics'),
      ),
      GlassNavDestination(
        icon: Icons.medication_outlined,
        selectedIcon: Icons.medication_rounded,
        label: i18n.tr('nav.meds'),
      ),
      GlassNavDestination(
        icon: Icons.search_outlined,
        selectedIcon: Icons.search_rounded,
        label: i18n.tr('nav.catalog'),
      ),
    ];
  }
}
