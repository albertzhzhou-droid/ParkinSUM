import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ParkinSUM "Liquid Glass" design tokens + Material theme.
///
/// Inspired by Apple's Liquid Glass language: layered translucency, soft
/// luminous gradients, hairline 1px hairlines, and material that picks up
/// the colour underneath. Implemented entirely with stock Flutter widgets
/// (`BackdropFilter`, `ImageFilter.blur`, `Container` gradients) so the
/// project stays dependency-light.
class LiquidGlass {
  const LiquidGlass._();

  // ---------- core color tokens (light) ------------------------------------
  static const Color background = Color(0xFFF5F4FB); // softer than pure white
  static const Color tintA = Color(0xFFB8C3FF); // periwinkle
  static const Color tintB = Color(0xFFFFC9D8); // blush
  static const Color tintC = Color(0xFFC9F2E7); // mint
  static const Color seed = Color(0xFF5B6CFF);
  static const Color onSurface = Color(0xFF1B1B25);
  static const Color onSurfaceMuted = Color(0xFF5A5C72);
  static const Color stroke = Color(0x1A0A0A1A); // ~10% black hairline
  static const Color glassFill = Color(0x66FFFFFF); // 40% white
  static const Color glassFillSoft = Color(0x33FFFFFF); // 20% white

  // ---------- shape tokens -------------------------------------------------
  static const double radiusSm = 14;
  static const double radiusMd = 22;
  static const double radiusLg = 28;
  static const double radiusXl = 36;
  static const double hairline = 1.0;

  // ---------- blur tokens (sigma) ------------------------------------------
  static const double blurSm = 12;
  static const double blurMd = 24;
  static const double blurLg = 36;

  /// Material 3 theme tuned to feel premium under Liquid Glass surfaces.
  static ThemeData themeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: Colors.white.withValues(alpha: 0.78),
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: glassFill,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: stroke, width: hairline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            color: onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: onSurface),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.primary.withValues(alpha: 0.55)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassFillSoft,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: stroke, width: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: stroke, width: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: stroke,
        thickness: hairline,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glassFillSoft,
        side: const BorderSide(color: stroke),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.86),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        barrierColor: Colors.black.withValues(alpha: 0.20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: stroke, width: hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.86),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        modalBackgroundColor: Colors.white.withValues(alpha: 0.86),
        modalBarrierColor: Colors.black.withValues(alpha: 0.20),
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: stroke, width: hairline),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      // Selection surfaces: popup menus / M3 menus / dropdown menus.
      // Without explicit theming the defaults render a dark drop-shadow +
      // primary-tinted Material on top of a translucent canvas, which the
      // user perceives as an unreadable black shadow. We replace each of
      // them with a hairline-bordered translucent white panel.
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: stroke, width: hairline),
        ),
        textStyle: const TextStyle(
          color: onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.92),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              side: const BorderSide(color: stroke, width: hairline),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.92),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              side: const BorderSide(color: stroke, width: hairline),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: glassFillSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: stroke, width: hairline),
          ),
        ),
      ),
      // Selectable list items (DropdownMenuItem etc.) get a translucent
      // hover/selection state so the user can see what they're pointing at.
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return seed.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.pressed)) {
              return seed.withValues(alpha: 0.16);
            }
            return Colors.transparent;
          }),
          foregroundColor: const WidgetStatePropertyAll(onSurface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      ),
    );
  }

  /// Show a dialog with a frosted-glass barrier (`BackdropFilter` blur over
  /// everything beneath the dialog). Drop-in replacement for
  /// `showDialog<T>(...)`; existing call sites can adopt this incrementally.
  static Future<T?> showGlassDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // Use a near-transparent barrier; the blur is drawn by the
      // `_FrostedBarrier` below, on top of the page content.
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondary) {
        return _FrostedBarrier(
          animation: anim,
          child: Center(child: builder(ctx)),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: Transform.scale(
            scale: 0.96 + 0.04 * curved.value,
            child: child,
          ),
        );
      },
    );
  }

  /// Show a modal bottom sheet whose backdrop is frosted glass instead of a
  /// flat black scrim.
  static Future<T?> showGlassModalBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) {
        return _FrostedBarrier(
          animation: const AlwaysStoppedAnimation<double>(1.0),
          blockTaps: false,
          child: GlassSurface(
            borderRadius: radiusLg,
            blurSigma: blurLg,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(top: false, child: builder(ctx)),
          ),
        );
      },
    );
  }
}

/// One option in a [GlassSelectField].
class GlassSelectOption<T> {
  final T value;
  final String label;
  final String? helper;
  final IconData? icon;

  const GlassSelectOption({
    required this.value,
    required this.label,
    this.helper,
    this.icon,
  });
}

/// Drop-in replacement for `DropdownButtonFormField` that opens a frosted
/// glass picker dialog instead of expanding inline (which previously caused
/// stacked / unreadable text on the analytics page).
///
/// Behaviour:
/// - Tap the field → `LiquidGlass.showGlassDialog` opens a hairline-bordered
///   translucent panel listing the options.
/// - Hover / focus / press shows a subtle seed-tinted highlight on the
///   pointed item.
/// - The currently-selected item gets a check mark + a stronger seed tint.
class GlassSelectField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<GlassSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? helper;

  const GlassSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
  });

  GlassSelectOption<T>? get _selected => options
      .where((o) => o.value == value)
      .cast<GlassSelectOption<T>?>()
      .firstWhere(
        (_) => true,
        orElse: () => null,
      );

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LiquidGlass.radiusMd),
          onTap: () async {
            final picked = await LiquidGlass.showGlassDialog<T>(
              context: context,
              builder: (ctx) => _GlassSelectSheet<T>(
                title: label,
                helper: helper,
                options: options,
                currentValue: value,
              ),
            );
            if (picked != null && picked != value) onChanged(picked);
          },
          child: GlassSurface(
            borderRadius: LiquidGlass.radiusMd,
            blurSigma: LiquidGlass.blurSm,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: LiquidGlass.onSurfaceMuted,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected?.label ?? '—',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: LiquidGlass.onSurface,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 20,
                  color: LiquidGlass.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSelectSheet<T> extends StatefulWidget {
  final String title;
  final String? helper;
  final List<GlassSelectOption<T>> options;
  final T currentValue;

  const _GlassSelectSheet({
    required this.title,
    required this.options,
    required this.currentValue,
    this.helper,
  });

  @override
  State<_GlassSelectSheet<T>> createState() => _GlassSelectSheetState<T>();
}

class _GlassSelectSheetState<T> extends State<_GlassSelectSheet<T>> {
  int? _hoverIdx;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width.clamp(260, 460).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: media.size.height * 0.7,
        ),
        child: GlassSurface(
          borderRadius: LiquidGlass.radiusLg,
          blurSigma: LiquidGlass.blurLg,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: LiquidGlass.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              if (widget.helper != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.helper!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: LiquidGlass.onSurfaceMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final opt = widget.options[index];
                    final isSelected = opt.value == widget.currentValue;
                    final isHovered = _hoverIdx == index;
                    final highlight = isSelected
                        ? scheme.primary.withValues(alpha: 0.18)
                        : isHovered
                            ? scheme.primary.withValues(alpha: 0.10)
                            : Colors.transparent;
                    final border = isSelected
                        ? Border.all(
                            color: scheme.primary.withValues(alpha: 0.55),
                            width: 1,
                          )
                        : Border.all(color: Colors.transparent);
                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoverIdx = index),
                      onExit: (_) => setState(() {
                        if (_hoverIdx == index) _hoverIdx = null;
                      }),
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: highlight,
                          border: border,
                          borderRadius:
                              BorderRadius.circular(LiquidGlass.radiusMd),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(LiquidGlass.radiusMd),
                            onTap: () => Navigator.of(context).pop(opt.value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  if (opt.icon != null) ...[
                                    Icon(
                                      opt.icon,
                                      size: 18,
                                      color: isSelected
                                          ? scheme.primary
                                          : LiquidGlass.onSurfaceMuted,
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          opt.label,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? scheme.primary
                                                : LiquidGlass.onSurface,
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                        if (opt.helper != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            opt.helper!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: LiquidGlass.onSurfaceMuted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 140),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(
                                            scale: anim, child: child),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            key: const ValueKey('check'),
                                            color: scheme.primary,
                                            size: 20,
                                          )
                                        : const SizedBox(
                                            key: ValueKey('empty'),
                                            width: 20,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backdrop-blurred barrier used by `LiquidGlass.showGlassDialog` and
/// `showGlassModalBottomSheet`. Animates the blur in along with the route
/// transition so the frosting feels physical.
class _FrostedBarrier extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final bool blockTaps;

  const _FrostedBarrier({
    required this.animation,
    required this.child,
    this.blockTaps = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final sigma = LiquidGlass.blurLg * animation.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: !blockTaps,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

/// Animated multi-radial-gradient wallpaper used as the global background.
/// All glass surfaces (cards, app bars, nav bars) sample the colour from
/// this layer through a `BackdropFilter`.
class LiquidGlassBackground extends StatefulWidget {
  final Widget child;

  const LiquidGlassBackground({super.key, required this.child});

  @override
  State<LiquidGlassBackground> createState() => _LiquidGlassBackgroundState();
}

class _LiquidGlassBackgroundState extends State<LiquidGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 22))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: LiquidGlass.background),
            // Three slow-drifting radial blooms.
            _bloom(
              alignment: Alignment(
                -0.7 + 0.3 * _wave(t, 0),
                -0.6 + 0.2 * _wave(t, 0.33),
              ),
              color: LiquidGlass.tintA,
              radius: 0.9,
              opacity: 0.65,
            ),
            _bloom(
              alignment: Alignment(
                0.6 + 0.25 * _wave(t, 0.5),
                -0.4 + 0.3 * _wave(t, 0.66),
              ),
              color: LiquidGlass.tintB,
              radius: 0.95,
              opacity: 0.55,
            ),
            _bloom(
              alignment: Alignment(
                -0.2 + 0.4 * _wave(t, 0.75),
                0.7 + 0.2 * _wave(t, 0.1),
              ),
              color: LiquidGlass.tintC,
              radius: 1.0,
              opacity: 0.55,
            ),
            widget.child,
          ],
        );
      },
    );
  }

  static double _wave(double t, double phase) {
    final v = (t + phase) % 1.0;
    // smooth triangle: 0 → 1 → 0
    return v < 0.5 ? v * 2 : 2 - v * 2;
  }

  Widget _bloom({
    required Alignment alignment,
    required Color color,
    required double radius,
    required double opacity,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: radius,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

/// Frosted glass surface. Applies backdrop blur, a translucent tint, and a
/// hairline border with a soft inner highlight that reads as bevelled edge.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = LiquidGlass.radiusMd,
    this.blurSigma = LiquidGlass.blurMd,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tint ?? LiquidGlass.glassFill).withValues(alpha: 0.55),
                (tint ?? LiquidGlass.glassFillSoft).withValues(alpha: 0.30),
              ],
            ),
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: LiquidGlass.hairline,
                ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Drop-in glass card.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = LiquidGlass.radiusMd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = GlassSurface(
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );
    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: surface,
      ),
    );
  }
}

/// Pill-shaped frosted button.
class GlassButton extends StatelessWidget {
  final Widget label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: GlassSurface(
        borderRadius: LiquidGlass.radiusXl,
        blurSigma: LiquidGlass.blurSm,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(LiquidGlass.radiusXl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    child: label,
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

/// Frosted top app bar that floats above the content with a hairline edge.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  const GlassAppBar({super.key, this.title, this.actions, this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: GlassSurface(
          borderRadius: LiquidGlass.radiusXl,
          blurSigma: LiquidGlass.blurLg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (leading != null) leading!,
              if (title != null)
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: LiquidGlass.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    child: title!,
                  ),
                ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating frosted bottom navigation bar.
class GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GlassNavDestination> destinations;

  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GlassSurface(
        borderRadius: LiquidGlass.radiusXl,
        blurSigma: LiquidGlass.blurLg,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _GlassNavItem(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GlassNavDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const GlassNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });
}

class _GlassNavItem extends StatelessWidget {
  final GlassNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _GlassNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : LiquidGlass.onSurfaceMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LiquidGlass.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LiquidGlass.radiusLg),
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? (destination.selectedIcon ?? destination.icon)
                    : destination.icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
