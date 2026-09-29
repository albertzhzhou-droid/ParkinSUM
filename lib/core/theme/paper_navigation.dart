import 'package:flutter/material.dart';

import 'paper_theme.dart';

/// Published by the main shell so tab pages can render the shell's global
/// actions (visit preparation, settings, sign-out) in their own header when
/// there is no sidebar to hold them. This keeps exactly one header per
/// screen instead of a shell bar stacked on top of a page bar.
class PaperShellScope extends InheritedWidget {
  const PaperShellScope({
    super.key,
    required this.sidebarVisible,
    required this.buildActions,
    this.openMenu,
    this.menuTooltip,
    this.chapters,
    this.navigate,
    required super.child,
  });

  /// Whether the desktop sidebar is on screen (and already shows actions).
  final bool sidebarVisible;

  /// Opens the navigation drawer on compact layouts.
  final VoidCallback? openMenu;
  final String? menuTooltip;

  /// Chapter tabs shown under compact page headers (replaces a bottom dock).
  final PreferredSizeWidget? chapters;

  /// Selects a primary chapter by route id (e.g. from an in-page link).
  final ValueChanged<String>? navigate;

  /// Builds the shell's global header actions for compact layouts.
  final List<Widget> Function(BuildContext context) buildActions;

  static PaperShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaperShellScope>();

  /// Whether a primary chapter page built in [context] will show chapter
  /// tabs under its header (compact layout inside the shell). Pages pass this
  /// to [PaperAppBar.chapterTabs] so the header reserves exactly that room.
  static bool showsChapters(BuildContext context) {
    final scope = maybeOf(context);
    return scope != null && !scope.sidebarVisible && scope.chapters != null;
  }

  @override
  bool updateShouldNotify(PaperShellScope oldWidget) =>
      sidebarVisible != oldWidget.sidebarVisible ||
      buildActions != oldWidget.buildActions ||
      openMenu != oldWidget.openMenu ||
      chapters != oldWidget.chapters ||
      navigate != oldWidget.navigate;
}

/// Page header: serif title on the canvas, a faint edge once content
/// scrolls beneath it, and — inside the shell on compact layouts — a menu
/// button that opens the navigation drawer plus the shell's global actions
/// after the page's own.
class PaperAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PaperAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.chapterTabs = false,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;

  /// Set by the primary chapter pages to
  /// `PaperShellScope.showsChapters(context)`: reserves room for, and shows,
  /// the chapter tabs the shell supplies on compact layouts.
  final bool chapterTabs;

  // Chapter tabs add at most this much under a compact tab page header.
  static const double chapterTabsHeight = 48;

  @override
  Size get preferredSize => Size.fromHeight(
    Paper.toolbarHeight +
        (bottom?.preferredSize.height ?? 0) +
        (chapterTabs ? chapterTabsHeight : 0),
  );

  @override
  Widget build(BuildContext context) {
    final scope = PaperShellScope.maybeOf(context);
    final shellActions = scope != null && !scope.sidebarVisible
        ? scope.buildActions(context)
        : const <Widget>[];
    final pageActions = actions ?? const <Widget>[];
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final menu =
        leading == null &&
            !canPop &&
            scope != null &&
            !scope.sidebarVisible &&
            scope.openMenu != null
        ? IconButton(
            key: const ValueKey('main-menu'),
            tooltip: scope.menuTooltip,
            icon: const Icon(Icons.menu_rounded),
            onPressed: scope.openMenu,
          )
        : null;
    final chapters =
        chapterTabs && !canPop && scope != null && !scope.sidebarVisible
        ? scope.chapters
        : null;
    final pageBottom = bottom;
    final PreferredSizeWidget? combinedBottom = chapters == null
        ? pageBottom
        : pageBottom == null
        ? chapters
        : PreferredSize(
            preferredSize: Size.fromHeight(
              chapters.preferredSize.height + pageBottom.preferredSize.height,
            ),
            child: Column(children: [chapters, pageBottom]),
          );
    // With chapter tabs underneath, the tabs name the chapter; the title
    // slot carries the book's running title instead of repeating it.
    final shownTitle = chapters == null
        ? title
        : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PaperMonogram(size: 26),
              SizedBox(width: 10),
              Flexible(child: Text('ParkinSUM')),
            ],
          );
    return AppBar(
      title: shownTitle,
      leading: leading ?? menu,
      titleSpacing: (leading ?? menu) == null && !canPop ? 20 : 4,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: combinedBottom,
      actions: [
        ...pageActions,
        if (pageActions.isNotEmpty && shellActions.isNotEmpty)
          const _ActionDivider(),
        ...shellActions,
      ],
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 22,
        child: VerticalDivider(width: 1, color: Paper.border),
      ),
    );
  }
}

/// One entry in [PaperChapterTabs] / [PaperSidebar].
class PaperNavDestination {
  final String id;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const PaperNavDestination({
    required this.id,
    required this.icon,
    required this.label,
    this.selectedIcon,
  });
}

/// Chapter tabs: the compact-layout navigation, set under the page title
/// like the section tabs of a book instead of a bottom dock. The current
/// chapter is ink with a rubric underline; the row scrolls sideways when the
/// labels (or the text scale) need more room than the screen has.
class PaperChapterTabs extends StatelessWidget implements PreferredSizeWidget {
  const PaperChapterTabs({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PaperNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Size get preferredSize =>
      const Size.fromHeight(PaperAppBar.chapterTabsHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PaperAppBar.chapterTabsHeight,
      width: double.infinity,
      alignment: AlignmentDirectional.centerStart,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Paper.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < destinations.length; i++)
              _TextTab(
                key: ValueKey<String>('main-tab-${destinations[i].id}'),
                label: destinations[i].label,
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

/// Smaller text tabs for sections within one chapter (e.g. the Library's
/// "My medications · Foods & drugs").
class PaperSubTabs extends StatelessWidget {
  const PaperSubTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.keys = const [],
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<Key> keys;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < labels.length; i++)
              _TextTab(
                key: i < keys.length ? keys[i] : null,
                label: labels[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _TextTab extends StatefulWidget {
  const _TextTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_TextTab> createState() => _TextTabState();
}

class _TextTabState extends State<_TextTab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (value) => setState(() => _focused = value),
        borderRadius: BorderRadius.circular(Paper.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _focused ? Paper.accent : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(Paper.radiusSm),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                widget.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: Paper.sans,
                  fontSize: widget.compact ? 13.5 : 14.5,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.selected ? Paper.ink : Paper.inkMuted,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 2,
                  child: AnimatedFractionallySizedBox(
                    duration: Paper.motion(context, Paper.motionMedium),
                    curve: Paper.motionCurve,
                    widthFactor: widget.selected ? 1 : 0,
                    child: const ColoredBox(color: Paper.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A secondary action row in the [PaperSidebar] (a tool, settings, …).
class PaperSidebarAction {
  const PaperSidebarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.key,
  });

  final Key? key;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
}

/// A collapsible, titled group of [PaperSidebarAction]s.
class PaperSidebarSection {
  const PaperSidebarSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<PaperSidebarAction> items;
}

/// Navigation column, styled like the cloth spine of a notebook: brand,
/// shell-supplied header actions (new entry, search), the primary
/// destinations with a ribbon bookmark on the current one, collapsible
/// groups for every secondary tool, pinned bottom actions and a footer.
///
/// With [extended] false it collapses to an icon rail (tooltips carry the
/// labels) that keeps only the primary destinations and bottom actions.
class PaperSidebar extends StatelessWidget {
  const PaperSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.extended = true,
    this.width,
    this.title = 'ParkinSUM',
    this.tagline,
    this.headerActions = const [],
    this.sections = const [],
    this.expandedSections = const {},
    this.onToggleSection,
    this.bottomActions = const [],
    this.footer,
    this.showEdge = true,
    this.pinBottom = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<PaperNavDestination> destinations;
  final bool extended;
  final double? width;
  final String title;
  final String? tagline;
  final List<Widget> headerActions;
  final List<PaperSidebarSection> sections;
  final Set<String> expandedSections;
  final ValueChanged<String>? onToggleSection;
  final List<PaperSidebarAction> bottomActions;
  final Widget? footer;
  final bool showEdge;

  /// Pins [bottomActions] and [footer] below the scrolling list (desktop).
  /// When false (the phone drawer) they scroll with the list so the groups
  /// keep the full height.
  final bool pinBottom;

  static const double extendedWidth = 268;
  static const double collapsedWidth = 76;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bottom = <Widget>[
      if (bottomActions.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Divider(height: 1),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            pinBottom ? 10 : 0,
            8,
            pinBottom ? 10 : 0,
            4,
          ),
          child: Column(
            children: [
              for (final action in bottomActions)
                _SidebarRow(
                  key: action.key,
                  icon: action.icon,
                  label: action.label,
                  selected: false,
                  extended: extended,
                  dense: true,
                  onTap: action.onPressed,
                ),
            ],
          ),
        ),
      ],
      if (footer != null && extended)
        Padding(
          padding: EdgeInsets.fromLTRB(
            pinBottom ? 14 : 4,
            6,
            pinBottom ? 14 : 4,
            16,
          ),
          child: DefaultTextStyle.merge(style: text.bodySmall, child: footer!),
        ),
    ];
    return Container(
      width: width ?? (extended ? extendedWidth : collapsedWidth),
      decoration: BoxDecoration(
        color: Paper.sidebar,
        border: showEdge
            ? const Border(right: BorderSide(color: Paper.border))
            : null,
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(extended ? 20 : 0, 20, 16, 16),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const PaperMonogram(size: 30),
                  if (extended) ...[
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: Paper.serif,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              height: 1.1,
                              color: Paper.ink,
                            ),
                          ),
                          if (tagline != null)
                            Text(
                              tagline!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: Paper.serif,
                                fontStyle: FontStyle.italic,
                                fontSize: 12.5,
                                color: Paper.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (headerActions.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < headerActions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      headerActions[i],
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _SidebarRow(
                      key: ValueKey<String>('main-tab-${destinations[i].id}'),
                      icon: i == selectedIndex
                          ? (destinations[i].selectedIcon ??
                                destinations[i].icon)
                          : destinations[i].icon,
                      label: destinations[i].label,
                      selected: i == selectedIndex,
                      extended: extended,
                      onTap: () => onDestinationSelected(i),
                    ),
                  if (extended)
                    for (final section in sections) ...[
                      const SizedBox(height: 14),
                      _SectionToggle(
                        title: section.title,
                        expanded: expandedSections.contains(section.id),
                        onTap: onToggleSection == null
                            ? null
                            : () => onToggleSection!(section.id),
                      ),
                      ClipRect(
                        child: AnimatedSize(
                          duration: Paper.motion(context, Paper.motionMedium),
                          curve: Paper.motionCurve,
                          alignment: Alignment.topCenter,
                          child: !expandedSections.contains(section.id)
                              ? const SizedBox(width: double.infinity)
                              : Column(
                                  children: [
                                    for (final item in section.items)
                                      _SidebarRow(
                                        key: item.key,
                                        icon: item.icon,
                                        label: item.label,
                                        selected: false,
                                        extended: true,
                                        dense: true,
                                        onTap: item.onPressed,
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  if (!pinBottom) ...[const SizedBox(height: 16), ...bottom],
                ],
              ),
            ),
            if (pinBottom) ...bottom,
          ],
        ),
      ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Paper.radiusSm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Paper.sans,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                    color: Paper.accentInk,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: Paper.motion(context, Paper.motionShort),
                curve: Paper.motionCurve,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Paper.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final bool dense;
  final VoidCallback? onTap;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? Paper.ink : Paper.inkSecondary;
    final radius = BorderRadius.circular(Paper.radiusSm + 2);
    final row = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            splashColor: Colors.transparent,
            highlightColor: Paper.selected,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              constraints: BoxConstraints(minHeight: widget.dense ? 38 : 42),
              padding: EdgeInsets.only(
                left: widget.extended ? 14 : 0,
                right: widget.extended ? 10 : 0,
              ),
              decoration: BoxDecoration(
                color: widget.selected
                    ? Paper.selected
                    : (_hovered ? Paper.hover : Colors.transparent),
                borderRadius: radius,
                border: Border.all(
                  color: _focused ? Paper.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (widget.extended)
                    Positioned(
                      left: -14,
                      top: 0,
                      // The bookmark ribbon drops into the newly selected
                      // row and lifts out of the previous one.
                      child: AnimatedSlide(
                        offset: widget.selected
                            ? Offset.zero
                            : const Offset(0, -0.9),
                        duration: Paper.motion(context, Paper.motionMedium),
                        curve: Paper.motionCurve,
                        child: AnimatedOpacity(
                          opacity: widget.selected ? 1 : 0,
                          duration: Paper.motion(context, Paper.motionShort),
                          child: const CustomPaint(
                            size: Size(6, 22),
                            painter: _RibbonPainter(),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: widget.extended
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: widget.dense ? 18 : 20,
                        color: widget.selected ? Paper.accent : color,
                      ),
                      if (widget.extended) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              widget.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: Paper.sans,
                                fontSize: widget.dense ? 13.5 : 14.5,
                                height: 1.25,
                                fontWeight: widget.selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.extended) return row;
    return Tooltip(message: widget.label, child: row);
  }
}

/// A ribbon bookmark with a swallow-tail notch, marking the current page.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 4)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Paper.ribbon);
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}
