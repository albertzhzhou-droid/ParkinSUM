import 'package:flutter/material.dart';

import 'paper_theme.dart';

/// Cream "paper" canvas behind every route, with a faint, fixed grain like
/// the tooth of a notebook page. The grain is generated once from a fixed
/// seed and cached behind a [RepaintBoundary]; it never animates (a moving
/// decorative background would need a pause control and can trigger
/// vestibular symptoms).
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: CustomPaint(painter: _PaperGrainPainter()),
        ),
        child,
      ],
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Paper.canvas);
    // Deterministic LCG so every frame and every run paints identical grain.
    var seed = 0x2F6E2B1;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final dark = Paint()..color = const Color(0x0C4A3A28);
    final light = Paint()..color = const Color(0x14FFFFFF);
    final count = (size.width * size.height / 700).clamp(0, 9000).toInt();
    for (var i = 0; i < count; i++) {
      final offset = Offset(next() * size.width, next() * size.height);
      canvas.drawCircle(offset, 0.5 + next() * 0.6, i.isEven ? dark : light);
    }
  }

  @override
  bool shouldRepaint(_PaperGrainPainter oldDelegate) => false;
}

/// A fleuron rule — hairlines either side of a small lozenge with two
/// points — used between sections the way a book separates its parts.
class PaperOrnament extends StatelessWidget {
  const PaperOrnament({super.key, this.width = 180, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: width,
          height: 14,
          child: CustomPaint(painter: _FleuronRulePainter(color ?? Paper.gilt)),
        ),
      ),
    );
  }
}

class _FleuronRulePainter extends CustomPainter {
  const _FleuronRulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final line = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 0.8;
    final fill = Paint()..color = color;
    canvas.drawLine(Offset(0, cy), Offset(cx - 16, cy), line);
    canvas.drawLine(Offset(cx + 16, cy), Offset(size.width, cy), line);
    final lozenge = Path()
      ..moveTo(cx, cy - 5)
      ..lineTo(cx + 5, cy)
      ..lineTo(cx, cy + 5)
      ..lineTo(cx - 5, cy)
      ..close();
    canvas.drawPath(lozenge, fill);
    canvas.drawCircle(Offset(cx - 10, cy), 1.6, fill);
    canvas.drawCircle(Offset(cx + 10, cy), 1.6, fill);
  }

  @override
  bool shouldRepaint(_FleuronRulePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A featured "plate": a sheet framed by a hairline and an inset gilt rule,
/// the way an illustrated plate is framed in a well-made book.
class PaperPlate extends StatelessWidget {
  const PaperPlate({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final outer = BorderRadius.circular(Paper.radiusLg);
    final inner = BorderRadius.circular(Paper.radiusLg - 4);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Paper.surface,
        borderRadius: outer,
        border: Border.all(color: Paper.border),
        boxShadow: Paper.shadowResting,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: inner,
            border: Border.all(color: Paper.gilt.withValues(alpha: 0.35)),
          ),
          child: ClipRRect(
            borderRadius: inner,
            child: Material(
              type: MaterialType.transparency,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A paragraph that opens with a raised serif initial in rubric, as a book
/// chapter does.
class PaperInitialParagraph extends StatelessWidget {
  const PaperInitialParagraph(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Paper.inkSecondary);
    if (text.isEmpty) return Text(text, style: base);
    final initial = text.characters.first;
    final rest = text.characters.skip(1).toString();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: initial,
            style: const TextStyle(
              fontFamily: Paper.serif,
              fontSize: 30,
              height: 1.0,
              fontWeight: FontWeight.w500,
              color: Paper.accent,
            ),
          ),
          TextSpan(text: rest),
        ],
      ),
      style: base,
    );
  }
}

/// Fades and lifts its child into place once, when it first appears.
///
/// [order] staggers siblings (each step waits a little longer), so a page's
/// sections settle top to bottom instead of popping in together. Rebuilds do
/// not replay the animation; give the widget a new key to replay it (e.g. a
/// fresh result). Skipped entirely under reduced motion.
class PaperReveal extends StatefulWidget {
  const PaperReveal({
    super.key,
    required this.child,
    this.order = 0,
    this.storageId,
  });

  final Widget child;
  final int order;

  /// When set, the reveal plays only the first time this widget appears on
  /// its page — scrolling it out of a lazy list and back does not replay it.
  final String? storageId;

  static const Duration _step = Duration(milliseconds: 55);

  @override
  State<PaperReveal> createState() => _PaperRevealState();
}

class _PaperRevealState extends State<PaperReveal>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final base = Paper.motion(context, Paper.motionLong);
    if (base == Duration.zero) return;
    final id = widget.storageId;
    if (id != null) {
      final bucket = PageStorage.maybeOf(context);
      final key = 'paper-reveal:$id';
      if (bucket?.readState(context, identifier: key) == true) return;
      bucket?.writeState(context, true, identifier: key);
    }
    final delay = PaperReveal._step * widget.order.clamp(0, 8);
    final total = base + delay;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    _curve = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Paper.motionCurve,
      ),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// A bar that grows from zero on first appearance and eases to new values
/// afterwards (e.g. when a chart's range changes). [factor] is 0..1 of the
/// available extent along [axis].
class PaperGrowBar extends StatelessWidget {
  const PaperGrowBar({
    super.key,
    required this.factor,
    required this.child,
    this.axis = Axis.vertical,
  });

  final double factor;
  final Widget child;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: factor.clamp(0.0, 1.0)),
      duration: Paper.motion(context, Paper.motionMedium * 2),
      curve: Paper.motionCurve,
      builder: (context, value, child) => FractionallySizedBox(
        alignment: axis == Axis.vertical
            ? Alignment.bottomCenter
            : AlignmentDirectional.centerStart,
        heightFactor: axis == Axis.vertical ? value : null,
        widthFactor: axis == Axis.horizontal ? value : null,
        child: child,
      ),
      child: child,
    );
  }
}

/// An opaque sheet: white fill, hairline edge, optional resting shadow.
class PaperSurface extends StatelessWidget {
  const PaperSurface({
    super.key,
    required this.child,
    this.borderRadius = Paper.radiusLg,
    this.padding = EdgeInsets.zero,
    this.color,
    this.border,
    this.boxShadow,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Paper.surface,
        borderRadius: radius,
        border:
            border ?? Border.all(color: Paper.border, width: Paper.hairline),
        boxShadow: boxShadow ?? Paper.shadowResting,
      ),
      child: ClipRRect(
        borderRadius: radius,
        // Transparent Material inside the fill so descendant ListTiles and
        // InkWells paint their ink above the opaque sheet, not beneath it.
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The standard content card. When [onTap] is set the card gains a hover
/// edge, a pointer cursor and an ink response.
class PaperCard extends StatefulWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = Paper.radiusLg,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  State<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<PaperCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final radius = BorderRadius.circular(widget.borderRadius);
    final edge = _focused
        ? Paper.accent
        : (_hovered && interactive ? Paper.borderStrong : Paper.border);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: widget.color ?? Paper.surface,
        borderRadius: radius,
        border: Border.all(color: edge, width: _focused ? 2 : Paper.hairline),
        boxShadow: _hovered && interactive
            ? Paper.shadowFloating
            : Paper.shadowResting,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
    if (!interactive) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        child: card,
      ),
    );
  }
}

/// Primary call-to-action: terracotta filled button with an optional icon.
class PaperButton extends StatelessWidget {
  const PaperButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
  });

  final Widget label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final icon = leadingIcon;
    if (icon == null) {
      return FilledButton(onPressed: onPressed, child: label);
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: label,
    );
  }
}

/// Semantic tone for pills, notes and stat icons.
enum PaperTone { neutral, accent, success, warning, danger, info }

extension PaperToneColors on PaperTone {
  Color get foreground => switch (this) {
    PaperTone.neutral => Paper.inkSecondary,
    PaperTone.accent => Paper.accentInk,
    PaperTone.success => Paper.success,
    PaperTone.warning => Paper.warning,
    PaperTone.danger => Paper.danger,
    PaperTone.info => Paper.info,
  };

  Color get background => switch (this) {
    PaperTone.neutral => Paper.surfaceSunken,
    PaperTone.accent => Paper.accentSoft,
    PaperTone.success => Paper.successSoft,
    PaperTone.warning => Paper.warningSoft,
    PaperTone.danger => Paper.dangerSoft,
    PaperTone.info => Paper.infoSoft,
  };
}

/// Compact tonal label, e.g. a decision state or a source tag.
class PaperPill extends StatelessWidget {
  const PaperPill({
    super.key,
    required this.label,
    this.tone = PaperTone.neutral,
    this.icon,
  });

  final String label;
  final PaperTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = tone.foreground;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(Paper.radiusXs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Paper.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading: optional small-caps eyebrow, serif title, muted
/// subtitle and an optional trailing action.
class PaperSectionHeader extends StatelessWidget {
  const PaperSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: Paper.accentInk,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(title, style: text.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: Paper.serif,
                    fontStyle: FontStyle.italic,
                    fontSize: 14.5,
                    height: 1.4,
                    color: Paper.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// A figure with its caption: serif numeral over a muted label.
class PaperStat extends StatelessWidget {
  const PaperStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.tone = PaperTone.neutral,
  });

  final String value;
  final String label;
  final IconData? icon;
  final PaperTone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: PaperSurface(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(Paper.radiusSm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(icon, size: 18, color: tone.foreground),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              value,
              maxLines: 1,
              style: text.displaySmall?.copyWith(fontSize: 32, height: 1.05),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(color: Paper.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet callout for boundaries, provenance and caveats.
class PaperNote extends StatelessWidget {
  const PaperNote({
    super.key,
    required this.child,
    this.icon = Icons.info_outline_rounded,
    this.tone = PaperTone.neutral,
  });

  final Widget child;
  final IconData icon;
  final PaperTone tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(Paper.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: tone.foreground),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: tone == PaperTone.neutral
                      ? Paper.inkSecondary
                      : tone.foreground,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ParkinSUM's typographic mark: a serif "P" on a clay tile.
class PaperMonogram extends StatelessWidget {
  const PaperMonogram({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Paper.clay,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Text(
          'P',
          style: TextStyle(
            fontFamily: Paper.serif,
            fontSize: size * 0.62,
            fontWeight: FontWeight.w600,
            height: 1.0,
            color: Paper.canvas,
          ),
        ),
      ),
    );
  }
}

/// One option in a [PaperSelectField].
class PaperSelectOption<T> {
  final T value;
  final String label;
  final String? helper;
  final IconData? icon;

  const PaperSelectOption({
    required this.value,
    required this.label,
    this.helper,
    this.icon,
  });
}

/// Replacement for `DropdownButtonFormField` that opens a centred picker
/// panel instead of expanding inline (inline menus previously stacked
/// unreadably on the analytics page).
///
/// - Tap / Enter opens [Paper.showModal] listing the options.
/// - Hover and focus give the pointed option a warm wash.
/// - The current option carries a check mark and the accent tint.
class PaperSelectField<T> extends StatefulWidget {
  final String label;
  final T value;
  final List<PaperSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? helper;

  const PaperSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
  });

  PaperSelectOption<T>? get selected => options
      .where((o) => o.value == value)
      .cast<PaperSelectOption<T>?>()
      .firstWhere((_) => true, orElse: () => null);

  @override
  State<PaperSelectField<T>> createState() => _PaperSelectFieldState<T>();
}

class _PaperSelectFieldState<T> extends State<PaperSelectField<T>> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final radius = BorderRadius.circular(Paper.radiusMd);
    return Semantics(
      label: widget.label,
      value: selected?.label,
      hint: widget.helper,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onFocusChange: (focused) => setState(() => _focused = focused),
          onHover: (hovered) => setState(() => _hovered = hovered),
          borderRadius: radius,
          onTap: () async {
            final picked = await Paper.showModal<T>(
              context: context,
              builder: (ctx) => _PaperSelectSheet<T>(
                title: widget.label,
                helper: widget.helper,
                options: widget.options,
                currentValue: widget.value,
              ),
            );
            if (picked != null && picked != widget.value) {
              widget.onChanged(picked);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: Paper.surface,
              borderRadius: radius,
              border: Border.all(
                color: _focused
                    ? Paper.accent
                    : (_hovered ? Paper.borderStrong : const Color(0xFFDCD2BF)),
                width: _focused ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Paper.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected?.label ?? '—',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Paper.ink,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 20,
                  color: Paper.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperSelectSheet<T> extends StatefulWidget {
  final String title;
  final String? helper;
  final List<PaperSelectOption<T>> options;
  final T currentValue;

  const _PaperSelectSheet({
    required this.title,
    required this.options,
    required this.currentValue,
    this.helper,
  });

  @override
  State<_PaperSelectSheet<T>> createState() => _PaperSelectSheetState<T>();
}

class _PaperSelectSheetState<T> extends State<_PaperSelectSheet<T>> {
  int? _hoverIdx;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width.clamp(260, 460).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: media.size.height * 0.72,
        ),
        child: Material(
          color: Colors.transparent,
          child: PaperSurface(
            borderRadius: Paper.radiusXl,
            boxShadow: Paper.shadowFloating,
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.helper != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      widget.helper!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Paper.inkMuted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(right: 8),
                    itemCount: widget.options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) => _optionRow(context, index),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionRow(BuildContext context, int index) {
    final opt = widget.options[index];
    final isSelected = opt.value == widget.currentValue;
    final isHovered = _hoverIdx == index;
    final radius = BorderRadius.circular(Paper.radiusSm + 2);
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverIdx = index),
      onExit: (_) => setState(() {
        if (_hoverIdx == index) _hoverIdx = null;
      }),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? Paper.accentSoft
              : (isHovered ? Paper.hover : Colors.transparent),
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            focusColor: Paper.surfaceSunken,
            onTap: () => Navigator.of(context).pop(opt.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  if (opt.icon != null) ...[
                    Icon(
                      opt.icon,
                      size: 18,
                      color: isSelected ? Paper.accentInk : Paper.inkMuted,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected ? Paper.accentInk : Paper.ink,
                          ),
                        ),
                        if (opt.helper != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            opt.helper!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Paper.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Paper.accent,
                            size: 20,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
