/// ParkinSUM "Paper" design system.
///
/// A warm, bookish language for a research tool that people read closely —
/// a well-kept notebook: cream paper with a faint grain, sheets with hairline
/// edges, brown-black ink, a serif voice, small-caps running heads, fleuron
/// rules, and one rubric terracotta reserved for primary actions and focus. It deliberately avoids blur, translucency and glossy
/// gradients — every surface is opaque, so text contrast is predictable and
/// nothing on screen moves unless the user asked it to.
///
/// Typefaces (all SIL OFL 1.1, bundled under assets/fonts/):
/// - Source Serif 4 (display optical size) for headings and figures,
/// - Geist for interface and body copy,
/// - Geist Mono for identifiers, codes and rule ids.
///
/// Components live in `paper_widgets.dart` and `paper_navigation.dart`; both
/// are re-exported here so feature code imports a single file.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'paper_widgets.dart' show PaperBackground;

export 'paper_layout.dart';
export 'paper_navigation.dart';
export 'paper_widgets.dart';

/// Design tokens and theme factory for the Paper design system.
class Paper {
  const Paper._();

  // ---------- typefaces ------------------------------------------------------
  static const String sans = 'Geist';
  static const String serif = 'SourceSerif4Display';
  static const String mono = 'GeistMono';

  /// Optional host-installed fallbacks for scripts absent from the bundled
  /// Latin-oriented typefaces. These families are not bundled or fetched;
  /// Flutter continues to the platform fallback if they are unavailable.
  /// CJK stays on the platform fallback so it can choose locale-appropriate
  /// regional glyph forms instead of imposing one Noto CJK locale globally.
  static const List<String> scriptFontFallback = <String>[
    'Noto Sans Devanagari',
    'Noto Sans Thai',
    'Noto Sans Arabic',
    'Noto Naskh Arabic',
    'Noto Naskh Arabic UI',
  ];

  // ---------- neutrals (warm, paper-like) -----------------------------------
  /// Page canvas behind everything.
  static const Color canvas = Color(0xFFF6F1E6);

  /// Side navigation and recessed panels; one step darker than [canvas].
  static const Color sidebar = Color(0xFFEEE6D6);

  /// Cards, dialogs, inputs — the "sheet of paper" on the canvas.
  static const Color surface = Color(0xFFFFFDF8);

  /// Inset wells: code blocks, quiet stat tiles, table headers.
  static const Color surfaceSunken = Color(0xFFF3EDE1);

  /// Hover wash for rows and quiet buttons.
  static const Color hover = Color(0xFFE9E1D0);

  /// Selected navigation row / segmented selection.
  static const Color selected = Color(0xFFE2D8C3);

  /// Hairline dividers and card edges.
  static const Color border = Color(0xFFE2D9C8);

  /// Input and outlined-button edges. Decorative: the control's label and
  /// focus ring carry the affordance, so this does not need 3:1 contrast.
  static const Color borderStrong = Color(0xFFCBBFA8);

  /// Primary text.
  static const Color ink = Color(0xFF2A2420);

  /// Secondary text that still carries meaning.
  static const Color inkSecondary = Color(0xFF453D35);

  /// Captions and helper text. 5.1:1 on [canvas], 4.6:1 on [sidebar].
  static const Color inkMuted = Color(0xFF6E655A);

  /// Placeholders, disabled glyphs, decorative rules. Not for body text.
  static const Color inkFaint = Color(0xFFA39888);

  // ---------- accent -----------------------------------------------------------
  /// Rubric terracotta — the red of a rubricated manuscript — used for
  /// primary actions, links and focus. White text on it is 5.7:1; as text on
  /// [canvas] it is 5.0:1.
  static const Color accent = Color(0xFFA84B2A);
  static const Color accentHover = Color(0xFF943F22);
  static const Color accentPressed = Color(0xFF7F351C);

  /// Tinted wash behind selected chips and callouts.
  static const Color accentSoft = Color(0xFFF3E2D6);

  /// Text colour on [accentSoft].
  static const Color accentInk = Color(0xFF6E2E17);

  /// Lighter clay for purely decorative marks (monogram, dots, rules).
  static const Color clay = Color(0xFFD97757);

  /// Muted gilt for ornaments (fleurons, plate rules). Decorative only.
  static const Color gilt = Color(0xFFA8874A);

  /// Ribbon bookmark on the selected navigation entry. Decorative only.
  static const Color ribbon = Color(0xFF8E2F24);

  // ---------- semantic tones (muted to sit on paper) -------------------------
  static const Color success = Color(0xFF3F7A55);
  static const Color successSoft = Color(0xFFE6F0E7);
  static const Color warning = Color(0xFF94600F);
  static const Color warningSoft = Color(0xFFF8EEDB);
  static const Color danger = Color(0xFFB3372B);
  static const Color dangerSoft = Color(0xFFF9E4E0);
  static const Color info = Color(0xFF3D6390);
  static const Color infoSoft = Color(0xFFE4ECF5);

  // ---------- shape ------------------------------------------------------------
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double hairline = 1.0;

  // ---------- motion -----------------------------------------------------------
  /// Hover washes, tab underlines, small state changes.
  static const Duration motionShort = Duration(milliseconds: 160);

  /// Chapter changes, section unfolding, chart bars settling.
  static const Duration motionMedium = Duration(milliseconds: 260);

  /// Content entering a page.
  static const Duration motionLong = Duration(milliseconds: 420);

  /// Decelerating curve used for everything that enters or settles.
  static const Curve motionCurve = Curves.easeOutCubic;

  /// [duration], or zero when the platform asks for reduced motion
  /// (iOS "Reduce Motion", Android "Remove animations", etc.). Every Paper
  /// animation goes through this, so the app is still with that setting on.
  static Duration motion(BuildContext context, Duration duration) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : duration;

  // ---------- layout -----------------------------------------------------------
  static const double toolbarHeight = 64;

  /// Maximum width of a reading column for pushed pages on wide screens.
  static const double readableWidth = 1040;

  /// Soft, warm elevation used by floating surfaces (menus, dialogs, FABs).
  static const List<BoxShadow> shadowFloating = [
    BoxShadow(color: Color(0x14201A10), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A201A10), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Barely-there lift for resting cards.
  static const List<BoxShadow> shadowResting = [
    BoxShadow(color: Color(0x08201A10), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Material 3 theme expressing the Paper language.
  static ThemeData themeData() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accentSoft,
      onPrimaryContainer: accentInk,
      secondary: Color(0xFF5E5A51),
      onSecondary: Colors.white,
      secondaryContainer: selected,
      onSecondaryContainer: ink,
      tertiary: success,
      onTertiary: Colors.white,
      tertiaryContainer: successSoft,
      onTertiaryContainer: Color(0xFF1F4A2E),
      error: danger,
      onError: Colors.white,
      errorContainer: dangerSoft,
      onErrorContainer: Color(0xFF6E1D15),
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      surfaceDim: Color(0xFFEAE3D5),
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceSunken,
      surfaceContainerHigh: Color(0xFFEFE8DA),
      surfaceContainerHighest: Color(0xFFE8E0D0),
      outline: borderStrong,
      outlineVariant: border,
      shadow: Color(0xFF201A10),
      scrim: Color(0xFF1F1E1D),
      inverseSurface: Color(0xFF2B2A27),
      onInverseSurface: Color(0xFFF5F4EE),
      inversePrimary: Color(0xFFF0A585),
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: sans,
      fontFamilyFallback: scriptFontFallback,
      // Transparent so the grained [PaperBackground] shows through; pushed
      // routes get their own paper from [PaperPageTransitionsBuilder].
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: canvas,
      splashFactory: InkRipple.splashFactory,
      splashColor: ink.withValues(alpha: 0.05),
      highlightColor: ink.withValues(alpha: 0.04),
      hoverColor: ink.withValues(alpha: 0.035),
      focusColor: accent.withValues(alpha: 0.12),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PaperPageTransitionsBuilder(),
          TargetPlatform.fuchsia: PaperPageTransitionsBuilder(),
          TargetPlatform.linux: PaperPageTransitionsBuilder(),
          TargetPlatform.windows: PaperPageTransitionsBuilder(),
          TargetPlatform.macOS: PaperPageTransitionsBuilder(),
          TargetPlatform.iOS: PaperPageTransitionsBuilder(cupertino: true),
        },
      ),
    );

    final text = _textTheme(
      base.textTheme,
    ).apply(fontFamilyFallback: scriptFontFallback);
    final buttonShape = WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm + 2)),
    );
    const buttonPadding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );
    const buttonMinSize = WidgetStatePropertyAll(Size(48, 44));
    const buttonLabel = WidgetStatePropertyAll(
      TextStyle(
        fontFamily: sans,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    );
    final hairlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: Color(0xFFDCD2BF)),
    );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: const IconThemeData(color: inkSecondary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0.6,
        shadowColor: const Color(0x33201A10),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        toolbarHeight: toolbarHeight,
        titleSpacing: 20,
        titleTextStyle: const TextStyle(
          fontFamily: serif,
          fontSize: 23,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
          height: 1.2,
          color: ink,
        ),
        iconTheme: const IconThemeData(color: inkSecondary, size: 22),
        actionsIconTheme: const IconThemeData(color: inkSecondary, size: 21),
        actionsPadding: const EdgeInsets.only(right: 8),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border, width: hairline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: hairline,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: inkMuted,
        textColor: ink,
        titleTextStyle: text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: inkMuted),
        leadingAndTrailingTextStyle: text.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd - 2),
        ),
        selectedColor: accentInk,
        selectedTileColor: accentSoft,
        minVerticalPadding: 10,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonLabel,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return border;
            if (states.contains(WidgetState.pressed)) return accentPressed;
            if (states.contains(WidgetState.hovered)) return accentHover;
            return accent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? inkFaint : Colors.white,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: ink, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonLabel,
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? inkFaint : ink,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return hover;
            return surface;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: accent, width: 2);
            }
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: border);
            }
            return const BorderSide(color: borderStrong);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinSize,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          shape: buttonShape,
          textStyle: buttonLabel,
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? inkFaint : accent,
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return accent.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return accent.withValues(alpha: 0.07);
            }
            return null;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: accent, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonLabel,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(surface),
          foregroundColor: const WidgetStatePropertyAll(ink),
          side: const WidgetStatePropertyAll(BorderSide(color: borderStrong)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(44)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm + 2),
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? inkFaint : inkSecondary,
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return selected;
            if (states.contains(WidgetState.hovered)) return hover;
            return null;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: accent, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: surface,
        foregroundColor: ink,
        hoverColor: hover,
        focusColor: accentSoft,
        splashColor: selected,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 5,
        highlightElevation: 2,
        extendedTextStyle: buttonLabel.value,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: buttonLabel,
          shape: buttonShape,
          side: const WidgetStatePropertyAll(BorderSide(color: borderStrong)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? selected : surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? inkFaint : ink,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hoverColor: const Color(0xFFFFFEFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: inkMuted, fontSize: 14.5),
        floatingLabelStyle: const TextStyle(
          color: inkSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: inkFaint),
        helperStyle: const TextStyle(color: inkMuted, fontSize: 12.5),
        prefixIconColor: inkMuted,
        suffixIconColor: inkMuted,
        border: hairlineBorder,
        enabledBorder: hairlineBorder,
        disabledBorder: hairlineBorder.copyWith(
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: hairlineBorder.copyWith(
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: hairlineBorder.copyWith(
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: hairlineBorder.copyWith(
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accentSoft,
        disabledColor: surfaceSunken,
        checkmarkColor: accentInk,
        deleteIconColor: inkMuted,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(
          fontFamily: sans,
          color: inkSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: sans,
          color: accentInk,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return const Color(0xFF8C887D);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return const Color(0xFFE8E0D0);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return borderStrong;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0xFF8C887D), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : const Color(0xFF8C887D),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: Color(0xFFE8E0D0),
        thumbColor: accent,
        overlayColor: Color(0x1FA84B2A),
        valueIndicatorColor: Color(0xFF2B2A27),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Color(0xFFE8E0D0),
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: inkMuted,
        indicatorColor: accent,
        dividerColor: border,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontFamily: sans,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: sans,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        iconColor: inkSecondary,
        collapsedIconColor: inkMuted,
        textColor: ink,
        collapsedTextColor: ink,
        tilePadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x40201A10),
        elevation: 16,
        barrierColor: ink.withValues(alpha: 0.28),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: border, width: hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x33201A10),
        modalBackgroundColor: surface,
        modalBarrierColor: ink.withValues(alpha: 0.28),
        elevation: 8,
        modalElevation: 8,
        showDragHandle: true,
        dragHandleColor: borderStrong,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: border, width: hairline),
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2B2A27),
        contentTextStyle: const TextStyle(
          fontFamily: sans,
          color: Color(0xFFF5F4EE),
          fontSize: 14,
          height: 1.4,
        ),
        actionTextColor: const Color(0xFFF0A585),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2B2A27),
          borderRadius: BorderRadius.circular(radiusXs),
        ),
        textStyle: const TextStyle(
          fontFamily: sans,
          color: Color(0xFFF5F4EE),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(borderStrong.withValues(alpha: 0.9)),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: accent,
        textColor: Colors.white,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(surfaceSunken),
        headingTextStyle: text.labelLarge?.copyWith(color: inkSecondary),
        dataTextStyle: text.bodyMedium,
        dividerThickness: hairline,
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: sidebar,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: sidebar,
        indicatorColor: selected,
        selectedIconTheme: const IconThemeData(color: ink),
        unselectedIconTheme: const IconThemeData(color: inkMuted),
        selectedLabelTextStyle: text.labelLarge?.copyWith(color: ink),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(color: inkMuted),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: sidebar,
        headerForegroundColor: ink,
        dividerColor: border,
        headerHeadlineStyle: text.headlineMedium,
        todayBorder: const BorderSide(color: accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: surfaceSunken,
        hourMinuteColor: surfaceSunken,
        dayPeriodBorderSide: const BorderSide(color: borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.22),
        selectionHandleColor: accent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x33201A10),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: border, width: hairline),
        ),
        textStyle: const TextStyle(
          fontFamily: sans,
          color: ink,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Color(0x33201A10)),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              side: const BorderSide(color: border, width: hairline),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Color(0x33201A10)),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              side: const BorderSide(color: border, width: hairline),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: hairlineBorder,
          enabledBorder: hairlineBorder,
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return selected;
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return hover;
            }
            return Colors.transparent;
          }),
          foregroundColor: const WidgetStatePropertyAll(ink),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      ),
    );
  }

  /// Serif for display/headline/title-large; Geist for everything else.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle serifStyle(double size, FontWeight weight, double tracking) =>
        TextStyle(
          fontFamily: serif,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: 1.18,
          color: ink,
        );
    TextStyle sansStyle(
      double size,
      FontWeight weight, {
      double height = 1.45,
      double tracking = 0,
      Color color = ink,
    }) => TextStyle(
      fontFamily: sans,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: color,
    );
    return base.copyWith(
      displayLarge: serifStyle(52, FontWeight.w400, -1.0),
      displayMedium: serifStyle(42, FontWeight.w400, -0.8),
      displaySmall: serifStyle(34, FontWeight.w400, -0.6),
      headlineLarge: serifStyle(30, FontWeight.w400, -0.5),
      headlineMedium: serifStyle(26, FontWeight.w400, -0.4),
      headlineSmall: serifStyle(22, FontWeight.w500, -0.3),
      titleLarge: serifStyle(20, FontWeight.w500, -0.2),
      titleMedium: sansStyle(16, FontWeight.w600, height: 1.35, tracking: -0.1),
      titleSmall: sansStyle(14, FontWeight.w600, height: 1.35),
      bodyLarge: sansStyle(16, FontWeight.w400, height: 1.55),
      bodyMedium: sansStyle(14, FontWeight.w400, height: 1.5),
      bodySmall: sansStyle(12.5, FontWeight.w400, color: inkMuted),
      labelLarge: sansStyle(14, FontWeight.w500, height: 1.3),
      labelMedium: sansStyle(12.5, FontWeight.w500, height: 1.3),
      labelSmall: sansStyle(
        11.5,
        FontWeight.w600,
        height: 1.3,
        tracking: 0.3,
        color: inkMuted,
      ),
    );
  }

  /// Opens a centred modal panel over a warm scrim. Replacement for
  /// `showDialog` when the content is a custom [PaperSurface]-style panel.
  static Future<T?> showModal<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: ink.withValues(alpha: 0.28),
      transitionDuration: motion(context, motionMedium),
      pageBuilder: (ctx, anim, secondary) =>
          SafeArea(child: Center(child: builder(ctx))),
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Modal bottom sheet on a white sheet with a drag handle.
  static Future<T?> showSheet<T>({
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
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: builder(ctx),
        ),
      ),
    );
  }
}

/// Page transition that (a) uses a quiet fade-forward motion, or Cupertino
/// on iOS so the back-swipe keeps working, and (b) keeps pushed pages in a
/// centred reading column on wide screens. The first route (the app shell)
/// stays full-bleed so its sidebar can sit on the window edge.
class PaperPageTransitionsBuilder extends PageTransitionsBuilder {
  const PaperPageTransitionsBuilder({this.cupertino = false});

  final bool cupertino;

  static const PageTransitionsBuilder _fade =
      FadeForwardsPageTransitionsBuilder(backgroundColor: Paper.canvas);
  static const PageTransitionsBuilder _cupertino =
      CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final content = route.isFirst
        ? child
        : PaperBackground(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Paper.readableWidth,
                ),
                child: child,
              ),
            ),
          );
    return (cupertino ? _cupertino : _fade).buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      content,
    );
  }
}
