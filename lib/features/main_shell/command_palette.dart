import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/paper_theme.dart';

/// One searchable entry in the command palette.
class CommandEntry {
  const CommandEntry({
    required this.id,
    required this.icon,
    required this.label,
    required this.group,
    required this.run,
    this.keywords = const [],
  });

  final String id;
  final IconData icon;
  final String label;
  final String group;
  final List<String> keywords;

  /// Executed after the palette has closed.
  final VoidCallback run;

  bool matches(List<String> tokens) {
    if (tokens.isEmpty) return true;
    final haystack = [label, group, ...keywords].join(' ').toLowerCase();
    return tokens.every(haystack.contains);
  }
}

/// Opens the palette (⌘K / Ctrl+K). Every page, tool and create action is one
/// search away, so navigation never needs more than a keystroke and a word.
Future<void> showCommandPalette(
  BuildContext context, {
  required List<CommandEntry> entries,
  required String hintText,
  required String emptyText,
}) async {
  final picked = await showGeneralDialog<CommandEntry>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Paper.ink.withValues(alpha: 0.24),
    transitionDuration: Paper.motion(context, Paper.motionMedium),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.62),
        child: _CommandPalette(
          entries: entries,
          hintText: hintText,
          emptyText: emptyText,
        ),
      ),
    ),
    // The palette settles down into place as it fades in.
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Paper.motionCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
  picked?.run();
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({
    required this.entries,
    required this.hintText,
    required this.emptyText,
  });

  final List<CommandEntry> entries;
  final String hintText;
  final String emptyText;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  static const double _rowHeight = 44;
  static const double _headerHeight = 30;

  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;

  List<CommandEntry> get _results {
    final tokens = _query.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final matches = widget.entries.where((e) => e.matches(tokens)).toList();
    if (tokens.isEmpty) return matches;
    // Prefix matches on the label first; otherwise keep registry order.
    final first = tokens.first;
    matches.sort((a, b) {
      final pa = a.label.toLowerCase().startsWith(first) ? 0 : 1;
      final pb = b.label.toLowerCase().startsWith(first) ? 0 : 1;
      return pa.compareTo(pb);
    });
    return matches;
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + delta) % count);
    _revealSelected();
  }

  void _revealSelected() {
    if (!_scroll.hasClients) return;
    final results = _results;
    var offset = 0.0;
    String? group;
    for (var i = 0; i < results.length && i <= _selected; i++) {
      if (results[i].group != group) {
        group = results[i].group;
        offset += _headerHeight;
      }
      if (i < _selected) offset += _rowHeight;
    }
    final viewport = _scroll.position.viewportDimension;
    final current = _scroll.offset;
    if (offset < current + _headerHeight) {
      _scroll.jumpTo((offset - _headerHeight).clamp(0, double.infinity));
    } else if (offset + _rowHeight > current + viewport) {
      _scroll.jumpTo(offset + _rowHeight - viewport);
    }
  }

  void _open(CommandEntry entry) => Navigator.of(context).pop(entry);

  @override
  Widget build(BuildContext context) {
    final results = _results;
    if (_selected >= results.length) _selected = 0;
    final width = MediaQuery.sizeOf(context).width;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (width - 32).clamp(280, 620).toDouble(),
        maxHeight: 500,
      ),
      child: Material(
        color: Colors.transparent,
        child: PaperSurface(
          borderRadius: Paper.radiusXl,
          boxShadow: Paper.shadowFloating,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _move(1, results.length);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _move(-1, results.length);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                  child: TextField(
                    key: const ValueKey('command-palette-query'),
                    controller: _query,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() => _selected = 0),
                    onSubmitted: (_) {
                      if (results.isNotEmpty) _open(results[_selected]);
                    },
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.emptyText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Paper.inkMuted),
                          ),
                        )
                      : ListView(
                          controller: _scroll,
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          children: _rows(results),
                        ),
                ),
                const Divider(height: 1),
                const _KeyHints(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _rows(List<CommandEntry> results) {
    final rows = <Widget>[];
    String? group;
    for (var i = 0; i < results.length; i++) {
      final entry = results[i];
      if (entry.group != group) {
        group = entry.group;
        rows.add(
          SizedBox(
            height: _headerHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
              child: Text(
                group.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Paper.accentInk,
                ),
              ),
            ),
          ),
        );
      }
      final selected = i == _selected;
      rows.add(
        SizedBox(
          height: _rowHeight,
          child: Material(
            color: selected ? Paper.selected : Colors.transparent,
            borderRadius: BorderRadius.circular(Paper.radiusSm + 2),
            child: InkWell(
              key: ValueKey('command-${entry.id}'),
              borderRadius: BorderRadius.circular(Paper.radiusSm + 2),
              onTap: () => _open(entry),
              onHover: (hovering) {
                if (hovering && _selected != i) setState(() => _selected = i);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      entry.icon,
                      size: 18,
                      color: selected ? Paper.accent : Paper.inkMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: Paper.ink,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.keyboard_return_rounded,
                        size: 16,
                        color: Paper.inkMuted,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return rows;
  }
}

class _KeyHints extends StatelessWidget {
  const _KeyHints();

  @override
  Widget build(BuildContext context) {
    Widget key(String label) => Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Paper.surfaceSunken,
        border: Border.all(color: Paper.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: Paper.mono,
          fontSize: 10.5,
          color: Paper.inkSecondary,
        ),
      ),
    );
    const gap = SizedBox(width: 12);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            key('↑'),
            key('↓'),
            gap,
            key('↵'),
            gap,
            key('esc'),
            const Spacer(),
            const PaperMonogram(size: 16),
          ],
        ),
      ),
    );
  }
}
