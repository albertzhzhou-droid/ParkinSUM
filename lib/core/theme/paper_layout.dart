import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'paper_theme.dart';

/// Layout primitives for the Paper design system.
///
/// Pages used to be one long column of cards regardless of window width. These
/// helpers let a page use the width it is given: centred reading measure,
/// masonry columns for independent cards, and a controls/results split.

/// Horizontal insets that keep content inside [maxWidth] while the scroll view
/// itself stays full width (so the wheel and scrollbar work in the margins).
EdgeInsets paperPageInsets(
  double availableWidth, {
  double maxWidth = 1180,
  double top = 12,
  double bottom = 40,
}) {
  final gutter = availableWidth >= 720 ? 28.0 : 16.0;
  final side = math.max(gutter, (availableWidth - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Scrollable page body with a centred measure. Drop-in for a page-level
/// `ListView(children: …)`.
class PaperScrollPage extends StatelessWidget {
  const PaperScrollPage({
    super.key,
    required this.children,
    this.maxWidth = 1180,
    this.top = 12,
    this.bottom = 40,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        controller: controller,
        padding: paperPageInsets(
          constraints.maxWidth,
          maxWidth: maxWidth,
          top: top,
          bottom: bottom,
        ),
        children: children,
      ),
    );
  }
}

/// Distributes independent cards into as many columns as fit
/// ([minColumnWidth] each, at most [maxColumns]). Order is preserved
/// row-by-row, so the first cards stay at the top of the page. Falls back to
/// a single column on narrow widths.
class PaperColumns extends StatelessWidget {
  const PaperColumns({
    super.key,
    required this.children,
    this.minColumnWidth = 400,
    this.maxColumns = 3,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit =
            ((constraints.maxWidth + spacing) / (minColumnWidth + spacing))
                .floor();
        final count = fit
            .clamp(1, math.min(maxColumns, children.length))
            .toInt();
        if (count <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        final columns = List.generate(count, (_) => <Widget>[]);
        for (var i = 0; i < children.length; i++) {
          columns[i % count].add(children[i]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < count; c++) ...[
              if (c > 0) SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns[c].length; i++) ...[
                      if (i > 0) SizedBox(height: spacing),
                      columns[c][i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Controls beside results. On wide screens the [primary] pane is a fixed
/// width column with its own scroll, divided from the [secondary] pane by a
/// hairline, so inputs stay visible while results change. On narrow screens
/// both stack in one scroll view (primary first).
class PaperSplit extends StatelessWidget {
  const PaperSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryWidth = 380,
    this.breakpoint = 940,
    this.secondaryKey,
  });

  final List<Widget> primary;
  final List<Widget> secondary;
  final double primaryWidth;
  final double breakpoint;

  /// Key for the scroll view that holds [secondary] (or the single stacked
  /// scroll view on narrow screens).
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return ListView(
            key: secondaryKey,
            padding: paperPageInsets(constraints.maxWidth, maxWidth: 760),
            children: [...primary, const SizedBox(height: 16), ...secondary],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: primaryWidth + 28,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 12, 0, 40),
                children: primary,
              ),
            ),
            const SizedBox(width: 24),
            const VerticalDivider(width: 1, color: Paper.border),
            Expanded(
              child: LayoutBuilder(
                builder: (context, inner) => ListView(
                  key: secondaryKey,
                  // Left-aligned against the divider, capped at a reading
                  // measure; spare width stays on the right.
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    math.max(28, inner.maxWidth - 24 - 860),
                    40,
                  ),
                  children: secondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
