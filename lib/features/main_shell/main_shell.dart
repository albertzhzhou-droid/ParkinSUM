import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/firebase_backend.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import 'dashboard_page.dart';
import '../analytics/analytics_page.dart';
import '../medications/medication_page.dart';
import '../catalog/catalog_page.dart';
import '../legal/privacy_disclaimer_page.dart';
import '../next_meal/next_meal_page.dart';
import '../timeline/timeline_page.dart';

/// 主壳：底部导航 — 现在使用 Liquid Glass 设计语言。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  final List<Widget> _pages = <Widget>[
    const DashboardPage(),
    const NextMealPage(),
    const TimelinePage(),
    const AnalyticsPage(),
    const MedicationPage(),
    const CatalogPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final state = context.watch<AppState>();
    final showAccountBar = FirebaseBackend.enabled;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // We deliberately do NOT use `extendBody: true`. With a floating glass
      // nav bar, extending the body behind it caused the dashboard FAB
      // ("Add a meal") to sit underneath the bar. Letting Scaffold reserve
      // the nav-bar height keeps the FAB visible; the BackdropFilter still
      // samples the static LiquidGlassBackground for the frosted look.
      extendBodyBehindAppBar: true,
      appBar: showAccountBar
          ? GlassAppBar(
              title: Text(
                state.currentUserEmail ?? state.currentUserId ?? 'Account',
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: 'Privacy & Disclaimer',
                  icon: const Icon(Icons.privacy_tip_outlined, size: 20),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyDisclaimerPage(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: i18n.tr('common.sign_out'),
                  icon: const Icon(Icons.logout, size: 20),
                  onPressed: state.isAuthBusy
                      ? null
                      : () => context.read<AppState>().signOut(),
                ),
              ],
            )
          : null,
      body: _pages[_idx],
      bottomNavigationBar: GlassNavBar(
        selectedIndex: _idx,
        onDestinationSelected: (v) => setState(() => _idx = v),
        destinations: [
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
        ],
      ),
    );
  }
}
