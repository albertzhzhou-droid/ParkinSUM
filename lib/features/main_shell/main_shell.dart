import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/firebase_backend.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_slices.dart';
import '../../core/theme/paper_theme.dart';
import 'app_destinations.dart';
import 'command_palette.dart';
import 'dashboard_page.dart';
import '../analytics/analytics_page.dart';
import '../medications/medication_page.dart';
import '../catalog/catalog_page.dart';
import '../next_meal/next_meal_page.dart';
import '../timeline/timeline_page.dart';
import 'lazy_indexed_stack.dart';
import 'main_tab_route.dart';

/// 主壳：Paper 设计语言（笔记本 / 书籍式布局）。
///
/// Every destination is at most one step away:
/// - Wide layouts (≥ 900 px) keep a sidebar with a "New entry" menu, a
///   search button (⌘K / Ctrl+K), the six primary pages, collapsible groups
///   holding every secondary tool, and pinned workspace/settings entries.
///   Below 1180 px it collapses to an icon rail; tools stay one ⌘K away.
/// - Compact layouts have no bottom dock: chapter tabs sit under each page
///   title, and the header carries a menu button (the same sidebar as a
///   drawer), "New entry", visit preparation and settings.
/// - The command palette searches pages, tools and create actions.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.selectedTabId = 'home', this.onTabSelected});

  final String selectedTabId;
  final ValueChanged<String>? onTabSelected;

  static const double sidebarBreakpoint = 900;
  static const double extendedSidebarBreakpoint = 1180;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _expandedSections = <String>{};

  final List<WidgetBuilder> _pageBuilders = <WidgetBuilder>[
    (_) => const DashboardPage(),
    (_) => const NextMealPage(),
    (_) => const TimelinePage(),
    (_) => const AnalyticsPage(),
    (_) => const MedicationPage(),
    (_) => const CatalogPage(),
  ];

  /// The five chapters, in order. Library covers two routes (my medications
  /// and the foods & drugs catalogue), switched by tabs inside the chapter.
  static const List<MainTabRoute> _chapterRoutes = [
    MainTabRoute.home,
    MainTabRoute.timeline,
    MainTabRoute.nextMeal,
    MainTabRoute.analytics,
    MainTabRoute.medications,
  ];

  static int _chapterIndexFor(MainTabRoute route) =>
      route == MainTabRoute.catalog ? 4 : _chapterRoutes.indexOf(route);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleShortcut);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShortcut);
    super.dispose();
  }

  /// ⌘K / Ctrl+K opens the command palette while the shell is the visible
  /// route (not over a pushed page or an open dialog).
  bool _handleShortcut(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isMetaPressed && !keyboard.isControlPressed) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    _openPalette();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final route = MainTabRoute.fromId(widget.selectedTabId);
    final selectedIndex = _chapterIndexFor(route);
    final i18n = context.appI18n;
    final shell = context.select<AppState, ShellStateSlice>(
      ShellStateSlice.fromState,
    );
    final showAccountActions = FirebaseBackend.enabled;
    final destinations = _destinations(i18n);
    final width = MediaQuery.sizeOf(context).width;
    final useSidebar = width >= MainShell.sidebarBreakpoint;

    final page = LazyIndexedStack(index: route.index, builders: _pageBuilders);

    Widget sidebar({required bool extended, required bool inDrawer}) =>
        PaperSidebar(
          selectedIndex: selectedIndex,
          extended: extended,
          width: inDrawer ? 304 : null,
          showEdge: !inDrawer,
          pinBottom: !inDrawer,
          onDestinationSelected: (index) => _run(() => _selectTab(index)),
          destinations: destinations,
          tagline: i18n.tr('shell.tagline'),
          headerActions: [
            _NewEntryButton(extended: extended, onRun: _run),
            _SearchButton(extended: extended, onPressed: _openPalette),
          ],
          sections: _sections(i18n),
          expandedSections: _expandedSections,
          onToggleSection: (id) => setState(() {
            if (!_expandedSections.remove(id)) _expandedSections.add(id);
          }),
          bottomActions: _bottomActions(context, shell, showAccountActions),
          footer: _SidebarFooter(
            account: showAccountActions
                ? (shell.userEmail ?? shell.userId)
                : null,
            note: i18n.tr('shell.boundary_note'),
          ),
        );

    return PaperShellScope(
      sidebarVisible: useSidebar,
      openMenu: useSidebar
          ? null
          : () => _scaffoldKey.currentState?.openDrawer(),
      menuTooltip: i18n.tr('shell.menu'),
      navigate: (id) => _selectRoute(MainTabRoute.fromId(id)),
      chapters: useSidebar
          ? null
          : PaperChapterTabs(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: _selectTab,
            ),
      buildActions: (ctx) => [
        _NewEntryButton(extended: false, compactHeader: true, onRun: _run),
        IconButton(
          key: const ValueKey('main-care-workspace'),
          tooltip: i18n.tr('shell.care_workspace'),
          icon: const Icon(Icons.assignment_outlined, size: 21),
          onPressed: () => _openTool('care-workspace'),
        ),
        IconButton(
          key: const ValueKey('main-settings'),
          tooltip: i18n.tr('settings.title'),
          icon: const Icon(Icons.settings_outlined, size: 21),
          onPressed: () => _openTool('settings'),
        ),
      ],
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: useSidebar
            ? null
            : Drawer(
                width: 304,
                child: sidebar(extended: true, inDrawer: true),
              ),
        body: useSidebar
            ? Row(
                children: [
                  sidebar(
                    extended: width >= MainShell.extendedSidebarBreakpoint,
                    inDrawer: false,
                  ),
                  const _GutterRule(),
                  Expanded(child: page),
                ],
              )
            : page,
      ),
    );
  }

  /// Closes the drawer (if open) before running a navigation callback.
  void _run(VoidCallback action) {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
    action();
  }

  void _openTool(String id) {
    final tool = appTools(context.appI18n).firstWhere((t) => t.id == id);
    tool.open(context);
  }

  List<PaperSidebarSection> _sections(AppI18n i18n) {
    final tools = appTools(i18n);
    return [
      for (final group in const [
        AppToolGroup.evidence,
        AppToolGroup.data,
        AppToolGroup.operations,
      ])
        PaperSidebarSection(
          id: group.name,
          title: appToolGroupLabel(i18n, group),
          items: [
            for (final tool in tools.where((t) => t.group == group))
              PaperSidebarAction(
                key: ValueKey('tool-${tool.id}'),
                icon: tool.icon,
                label: tool.label,
                onPressed: () => _run(() => tool.open(context)),
              ),
          ],
        ),
    ];
  }

  List<PaperSidebarAction> _bottomActions(
    BuildContext context,
    ShellStateSlice shell,
    bool showAccountActions,
  ) {
    final i18n = context.appI18n;
    final tools = appTools(i18n).where((t) => t.group == AppToolGroup.account);
    return [
      for (final tool in tools)
        PaperSidebarAction(
          key: switch (tool.id) {
            'care-workspace' => const ValueKey('main-care-workspace'),
            'settings' => const ValueKey('main-settings'),
            _ => ValueKey('tool-${tool.id}'),
          },
          icon: tool.icon,
          label: tool.label,
          onPressed: () => _run(() => tool.open(context)),
        ),
      if (showAccountActions)
        PaperSidebarAction(
          icon: Icons.logout,
          label: i18n.tr('common.sign_out'),
          onPressed: shell.isAuthBusy
              ? null
              : () => _run(() => context.read<AppState>().signOut()),
        ),
    ];
  }

  Future<void> _openPalette() {
    final i18n = context.appI18n;
    final pagesGroup = i18n.tr('shell.group.pages');
    final entries = <CommandEntry>[
      for (final action in quickActions(i18n))
        CommandEntry(
          id: 'new-${action.id}',
          icon: action.icon,
          label: action.label,
          group: i18n.tr('shell.new_entry'),
          keywords: const ['new', 'add', 'log', 'record'],
          run: () => action.run(context),
        ),
      for (final (index, destination) in _destinations(i18n).indexed)
        CommandEntry(
          id: 'tab-${destination.id}',
          icon: destination.icon,
          label: destination.label,
          group: pagesGroup,
          run: () => _selectTab(index),
        ),
      CommandEntry(
        id: 'tab-catalog',
        icon: Icons.menu_book_outlined,
        label: i18n.tr('library.catalog'),
        group: pagesGroup,
        keywords: const ['catalog', 'food', 'drug', 'search'],
        run: () => _selectRoute(MainTabRoute.catalog),
      ),
      for (final tool in appTools(i18n))
        CommandEntry(
          id: 'tool-${tool.id}',
          icon: tool.icon,
          label: tool.label,
          group: appToolGroupLabel(i18n, tool.group),
          keywords: tool.keywords,
          run: () => tool.open(context),
        ),
    ];
    _run(() {});
    return showCommandPalette(
      context,
      entries: entries,
      hintText: i18n.tr('shell.search_hint'),
      emptyText: i18n.tr('shell.search_empty'),
    );
  }

  void _selectTab(int index) => _selectRoute(_chapterRoutes[index]);

  void _selectRoute(MainTabRoute route) {
    if (route.id == MainTabRoute.fromId(widget.selectedTabId).id) return;
    final index = route.index;
    debugPrint('[MainShell] tab:selected id=${route.id} index=$index');
    widget.onTabSelected?.call(route.id);
  }

  List<PaperNavDestination> _destinations(AppI18n i18n) {
    return [
      PaperNavDestination(
        id: MainTabRoute.home.id,
        icon: Icons.wb_sunny_outlined,
        selectedIcon: Icons.wb_sunny_rounded,
        label: i18n.tr('nav.today'),
      ),
      PaperNavDestination(
        id: MainTabRoute.timeline.id,
        icon: Icons.view_timeline_outlined,
        selectedIcon: Icons.view_timeline_rounded,
        label: i18n.tr('nav.timeline'),
      ),
      // 下餐推荐：由冲突引擎驱动，可选用本地 AI 润色。
      PaperNavDestination(
        id: MainTabRoute.nextMeal.id,
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome_rounded,
        label: i18n.tr('nav.next_meal'),
      ),
      PaperNavDestination(
        id: MainTabRoute.analytics.id,
        icon: Icons.query_stats_outlined,
        selectedIcon: Icons.query_stats_rounded,
        label: i18n.tr('insights.title'),
      ),
      PaperNavDestination(
        id: MainTabRoute.medications.id,
        icon: Icons.local_library_outlined,
        selectedIcon: Icons.local_library_rounded,
        label: i18n.tr('nav.library'),
      ),
    ];
  }
}

/// "New entry" — the one create button, with a menu for meal, medication
/// intake and observation. Extended: a full-width rubric button; rail: a
/// filled icon; compact header: a plain icon button.
class _NewEntryButton extends StatelessWidget {
  const _NewEntryButton({
    required this.extended,
    required this.onRun,
    this.compactHeader = false,
  });

  final bool extended;
  final bool compactHeader;
  final void Function(VoidCallback action) onRun;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final label = i18n.tr('shell.new_entry');
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (final action in quickActions(i18n))
          MenuItemButton(
            key: ValueKey('quick-${action.id}'),
            leadingIcon: Icon(action.icon, size: 18, color: Paper.accent),
            onPressed: () => onRun(() => action.run(context)),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(action.label),
            ),
          ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        if (compactHeader) {
          return IconButton(
            key: const ValueKey('main-new-entry'),
            tooltip: label,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            onPressed: toggle,
          );
        }
        if (!extended) {
          return Tooltip(
            message: label,
            child: IconButton.filled(
              key: const ValueKey('main-new-entry'),
              onPressed: toggle,
              icon: const Icon(Icons.add_rounded),
            ),
          );
        }
        return FilledButton(
          key: const ValueKey('main-new-entry'),
          onPressed: toggle,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ),
        );
      },
    );
  }
}

/// Opens the command palette; shows the keyboard shortcut when extended.
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.extended, required this.onPressed});

  final bool extended;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.appI18n.tr('shell.search');
    if (!extended) {
      return IconButton(
        key: const ValueKey('main-search'),
        tooltip: label,
        onPressed: onPressed,
        icon: const Icon(Icons.search_rounded),
      );
    }
    final isApple = switch (Theme.of(context).platform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    return OutlinedButton(
      key: const ValueKey('main-search'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: Paper.surface.withValues(alpha: 0.6),
        side: const BorderSide(color: Paper.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Paper.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Paper.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            isApple ? '⌘K' : 'Ctrl K',
            style: const TextStyle(
              fontFamily: Paper.mono,
              fontSize: 11.5,
              color: Paper.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The notebook's margin rule: a faint rubric line just inside the gutter.
class _GutterRule extends StatelessWidget {
  const _GutterRule();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 4,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(width: 1, color: Paper.ribbon.withValues(alpha: 0.22)),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.note, this.account});

  final String note;
  final String? account;

  @override
  Widget build(BuildContext context) {
    final account = this.account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (account != null) ...[
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: Paper.selected,
                child: Text(
                  account.isEmpty ? '·' : account.characters.first,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Paper.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Paper.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        const PaperOrnament(width: 120),
        const SizedBox(height: 8),
        Text(
          note,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: Paper.serif,
            fontStyle: FontStyle.italic,
            fontSize: 12,
            height: 1.4,
            color: Paper.inkMuted,
          ),
        ),
      ],
    );
  }
}
