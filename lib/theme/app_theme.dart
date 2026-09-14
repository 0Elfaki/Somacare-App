import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SomaCare Design System - single source of truth
/// ─────────────────────────────────────────────────────────────────────────────
///
/// One palette, one type scale, one set of shapes, for BOTH the student and
/// doctor sides of the app. Screens must never hard-code a hex value: every
/// colour a screen needs has a semantic name here.
///
/// The palette is the "medical light" system the student dashboard already
/// used (off-white page, white cards, hairline borders, one blue accent plus
/// a small set of status hues). The doctor side now renders from exactly the
/// same tokens, so the two halves of the product read as one app.
///
/// Role accents: the ONLY sanctioned difference between the two sides is
/// [AppColors.studentAccent] vs [AppColors.doctorAccent], used for the active
/// bottom-nav item and role-specific hero banners. Everything else is shared.

// ─── Legacy dark palette (onboarding + login only) ──────────────────────────
//
// The onboarding flow and the login screen are deliberately a dark, full-bleed
// brand moment and were built against these exact values. They are frozen here
// so the rest of the app can evolve without breaking those two screens.
class LegacyDarkColors {
  static const Color pageBg = Color(0xFF0B1518);
  static const Color screenBg = Color(0xFF12282E);
  static const Color surface = Color(0xFF1C363D);
  static const Color border = Color(0x14FFFFFF); // 8% white

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0x99FFFFFF); // 60%

  static const Color primary = Color(0xFF7C49E6);
  static const Color lime = Color(0xFFD8FF4A);
  static const Color error = Color(0xFFFF5C72);
}

/// Every colour in the app. Nothing outside this class may declare a `Color(0x…)`.
class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  /// The one blue. Headers, primary buttons, active states, links.
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  /// 10% / 16% primary washes for icon chips and selected rows.
  static const Color primaryWash = Color(0x1A2563EB);
  static const Color primaryTint = Color(0x282563EB);

  // ── Status hues ──────────────────────────────────────────────────────────
  /// Success / "active" / confirmed. One green - not four.
  static const Color success = Color(0xFF0D9488);
  static const Color successDark = Color(0xFF0F766E);
  static const Color successWash = Color(0x1A0D9488);
  static const Color successTint = Color(0x280D9488);

  /// Pending / expiring / needs attention.
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFB45309);
  static const Color warningWash = Color(0x1AF59E0B);
  static const Color warningTint = Color(0x28F59E0B);

  /// Urgent / emergency / destructive.
  static const Color error = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFF991B1B);
  static const Color errorWash = Color(0x1ADC2626);
  static const Color errorTint = Color(0x28DC2626);

  /// Emphasis surface for AI-assisted and wellness content. Deliberately
  /// not a standalone "AI color" - same brand family as everything else,
  /// so AI-assisted features don't visually announce themselves as a
  /// separate, flashier product. (Brand maroon-600/700; the rest of the
  /// app migrates to this family in a later pass.)
  static const Color accent = Color(0xFF8B1E3F);
  static const Color accentDark = Color(0xFF6B1730);
  static const Color accentWash = Color(0x1A8B1E3F);
  static const Color accentTint = Color(0x288B1E3F);

  /// Neutral / informational.
  static const Color info = primaryLight;
  static const Color infoWash = Color(0x1A3B82F6);
  static const Color infoTint = Color(0x283B82F6);

  // ── Role accents ─────────────────────────────────────────────────────────
  static const Color studentAccent = primary;
  static const Color doctorAccent = success;

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color pageBg = Color(0xFFF8FAFC);
  static const Color screenBg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceInverse = Color(0xFF0F172A);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFEDF1F5);
  static const Color scrim = Color(0x660F172A);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// 15.8:1 on [surface] - passes WCAG AAA.
  static const Color textPrimary = Color(0xFF1E293B);

  /// 4.76:1 on [surface] - passes WCAG AA for body text.
  static const Color textSecondary = Color(0xFF64748B);

  /// 2.8:1 - decorative only. Never use for text a user must read; use
  /// [textSecondary] instead. Kept for borders, dividers and disabled icons.
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onDark = Color(0xFFFFFFFF);

  // ── Opaque status surfaces ───────────────────────────────────────────────
  // The flat equivalents of the `*Wash` tints, for badges and callout cards
  // that sit ON a white card - where a translucent wash would let the card
  // show through and read as a different colour than the same badge on the
  // page background.
  static const Color primarySurface = Color(0xFFEFF6FF);
  static const Color successSurface = Color(0xFFECFDF5);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color errorSurface = Color(0xFFFEF2F2);
  static const Color accentSurface = Color(0xFFE0E7FF);

  // ── Extra neutrals ───────────────────────────────────────────────────────
  /// Between [textPrimary] and [textSecondary]. 9.4:1 on white.
  static const Color textStrong = Color(0xFF334155);

  /// A heavier rule than [border], for dashed drop zones and dividers that
  /// must read against a tinted card.
  static const Color borderStrong = Color(0xFFCBD5E1);

  // ── Solid tile fills ─────────────────────────────────────────────────────
  // The quick-action grid puts white text and icons directly on a saturated
  // fill. Several of the status hues above are too light for that: white on
  // `warning` is 2.1:1 and on `success` is 3.5:1, both well under the 4.5:1
  // WCAG AA threshold. These are the darkened equivalents that pass.
  static const Color fillBlue = primary; // 5.2:1 with white
  static const Color fillTeal = successDark; // 4.6:1
  static const Color fillPurple = accent; // 6.2:1
  static const Color fillAmber = warningDark; // 5.2:1
  static const Color fillRed = error; // 4.8:1

  // ── On inverse surfaces ──────────────────────────────────────────────────
  // The status hues above are picked for legibility on white. On the dark
  // inverse surface (snack bars, tooltips) they fall below 3:1, so these
  // lightened pairs are used there instead.
  static const Color successOnDark = Color(0xFF2DD4BF);
  static const Color warningOnDark = Color(0xFFFBBF24);
  static const Color errorOnDark = Color(0xFFF87171);
  static const Color infoOnDark = Color(0xFF93C5FD);
}

/// Mobile-money provider brand marks.
///
/// These are the providers' own trademarked colours, reproduced exactly so the
/// payment options are recognisable. They are deliberately outside [AppColors]:
/// they are not part of the design system and must never be substituted for a
/// nearby token.
class PaymentBrandColors {
  static const Color mpesaGreen = Color(0xFF00A650);
  static const Color mpesaYellow = Color(0xFFFFCC00);
  static const Color mpesaAmber = Color(0xFFFFAA00);
  static const Color mtnYellow = Color(0xFFFFCB05);
  static const Color airtelRed = Color(0xFFE4002B);
}

/// Type scale.
///
/// Raised from the previous scale, which bottomed out at 8.5px - well below
/// the ~11px floor at which text stays legible on a phone, and far below the
/// 16px browsers use as their body default. Body copy is now 15px and the
/// smallest label is 11px.
class AppTypography {
  static const String display = 'Fraunces';
  static const String ui = 'Inter';
  static const String mono = 'IBM Plex Mono';

  static const double displayLarge = 28;
  static const double displayMedium = 24;
  static const double displaySmall = 20;
  static const double headlineLarge = 20;
  static const double headlineMedium = 18;
  static const double headlineSmall = 16;
  static const double titleLarge = 16;
  static const double titleMedium = 15;
  static const double titleSmall = 13.5;
  static const double bodyLarge = 15;
  static const double bodyMedium = 13.5;
  static const double bodySmall = 12.5;
  static const double labelLarge = 14;
  static const double labelMedium = 12.5;
  static const double labelSmall = 11;
}

/// Elevation. These are light-theme shadows - soft, low-opacity, and tinted
/// with the slate used everywhere else, not pure black.
class AppShadows {
  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> navBar = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 20, offset: Offset(0, -4)),
  ];
}

/// 4pt spacing scale.
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  /// The horizontal gutter every screen uses.
  static const double gutter = 16.0;

  /// Bottom padding for scroll views that sit above a bottom nav bar.
  static const double bottomNavClearance = 32.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double tile = 14.0;
  static const double card = 16.0;
  static const double lg = 20.0;
  static const double full = 999.0;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius tileAll = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Motion. Durations and curves are named so animations across the app agree.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;
}

/// Minimum interactive sizes, per WCAG 2.2 target-size and the Material
/// touch-target guidance.
class AppTouch {
  /// Every tappable thing must present at least this much hit area.
  static const double minTarget = 48.0;

  /// Minimum gap between two adjacent targets.
  static const double minGap = 8.0;
}

/// Text-style factories. Prefer `Theme.of(context).textTheme` where possible;
/// these exist for the many places that need a one-off size or colour.
class BloomTextStyles {
  /// Fraunces - display and headings.
  static TextStyle fraunces({
    double size = AppTypography.displayMedium,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: AppTypography.display,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Inter - body and UI.
  static TextStyle inter({
    double size = AppTypography.bodyLarge,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) => TextStyle(
    fontFamily: AppTypography.ui,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
  );

  /// IBM Plex Mono - data, prices, dosages, timestamps.
  static TextStyle mono({
    double size = AppTypography.bodySmall,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
  }) => TextStyle(
    fontFamily: AppTypography.mono,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  /// The all-caps eyebrow used above section titles and inside hero banners.
  static TextStyle eyebrow({Color color = AppColors.primary}) => TextStyle(
    fontFamily: AppTypography.ui,
    fontSize: AppTypography.labelSmall,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    color: color,
  );
}

// ─── Theme ───────────────────────────────────────────────────────────────────

/// The app theme.
///
/// Note on history: this used to be built as `Brightness.dark` with a
/// `ColorScheme.dark`, while every colour value in it was light. That lie made
/// Flutter's own widgets (dialogs, snack bars, menus, text-selection handles,
/// the keyboard appearance, the status-bar icons) pick dark-theme defaults and
/// render light-on-light. The theme is now honestly declared as light.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryWash,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.success,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.successWash,
    onSecondaryContainer: AppColors.successDark,
    tertiary: AppColors.accent,
    onTertiary: AppColors.onPrimary,
    error: AppColors.error,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.errorWash,
    onErrorContainer: AppColors.errorDark,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.pageBg,
    surfaceContainer: AppColors.surfaceMuted,
    surfaceContainerHigh: AppColors.surfaceMuted,
    surfaceContainerHighest: AppColors.surfaceMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.borderSubtle,
    scrim: AppColors.scrim,
    inverseSurface: AppColors.surfaceInverse,
    onInverseSurface: AppColors.onDark,
  );

  final textTheme = _buildTextTheme(AppColors.textPrimary);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.pageBg,
    canvasColor: AppColors.pageBg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: textTheme,

    // ── App bar ─────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.pageBg,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: AppSpacing.lg,
      titleTextStyle: BloomTextStyles.fraunces(
        size: AppTypography.headlineMedium,
        weight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      actionsIconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 22,
      ),
      // Dark status-bar glyphs, because the app bar is light.
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),

    // ── Containers ──────────────────────────────────────────────────────────
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      titleTextStyle: BloomTextStyles.fraunces(
        size: AppTypography.headlineSmall,
        weight: FontWeight.w600,
      ),
      contentTextStyle: BloomTextStyles.inter(
        size: AppTypography.bodyLarge,
        color: AppColors.textSecondary,
        height: 1.45,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      textStyle: BloomTextStyles.inter(size: AppTypography.bodyLarge),
    ),

    // ── Buttons ─────────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size.fromHeight(AppTouch.minTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        textStyle: BloomTextStyles.inter(
          size: AppTypography.labelLarge,
          weight: FontWeight.w700,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(AppTouch.minTarget),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        textStyle: BloomTextStyles.inter(
          size: AppTypography.labelLarge,
          weight: FontWeight.w700,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size.fromHeight(AppTouch.minTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        textStyle: BloomTextStyles.inter(
          size: AppTypography.labelLarge,
          weight: FontWeight.w700,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(AppTouch.minTarget, AppTouch.minTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        textStyle: BloomTextStyles.inter(
          size: AppTypography.labelLarge,
          weight: FontWeight.w600,
        ),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(AppTouch.minTarget, AppTouch.minTarget),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      focusElevation: 3,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),

    // ── Inputs ──────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.error, width: 1.4),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.error, width: 1.8),
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      hintStyle: BloomTextStyles.inter(
        size: AppTypography.bodyLarge,
        color: AppColors.textSecondary,
      ),
      // A real, always-visible label - not a placeholder that vanishes on focus.
      labelStyle: BloomTextStyles.inter(
        size: AppTypography.bodyLarge,
        color: AppColors.textSecondary,
      ),
      floatingLabelStyle: BloomTextStyles.inter(
        size: AppTypography.labelMedium,
        weight: FontWeight.w600,
        color: AppColors.primary,
      ),
      errorStyle: BloomTextStyles.inter(
        size: AppTypography.labelMedium,
        weight: FontWeight.w500,
        color: AppColors.error,
      ),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
    ),

    // ── Selection controls ──────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? AppColors.textMuted
            : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.surfaceMuted,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.border,
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(AppColors.onPrimary),
      side: const BorderSide(color: AppColors.border, width: 1.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textMuted,
      ),
    ),

    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.surfaceMuted,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primaryWash,
    ),

    // ── Chips & badges ──────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      labelStyle: BloomTextStyles.inter(
        size: AppTypography.labelMedium,
        weight: FontWeight.w600,
      ),
      secondaryLabelStyle: BloomTextStyles.inter(
        size: AppTypography.labelMedium,
        weight: FontWeight.w600,
        color: AppColors.onPrimary,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
      side: const BorderSide(color: AppColors.border),
      showCheckmark: false,
    ),

    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.error,
      textColor: AppColors.onPrimary,
      smallSize: 8,
      largeSize: 18,
    ),

    // ── Navigation ──────────────────────────────────────────────────────────
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: BloomTextStyles.inter(
        size: AppTypography.labelSmall,
        weight: FontWeight.w700,
      ),
      unselectedLabelStyle: BloomTextStyles.inter(
        size: AppTypography.labelSmall,
        weight: FontWeight.w500,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryWash,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        BloomTextStyles.inter(
          size: AppTypography.labelSmall,
          weight: FontWeight.w600,
        ),
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppColors.border,
      labelStyle: BloomTextStyles.inter(
        size: AppTypography.labelLarge,
        weight: FontWeight.w700,
      ),
      unselectedLabelStyle: BloomTextStyles.inter(
        size: AppTypography.labelLarge,
        weight: FontWeight.w500,
      ),
    ),

    // ── Feedback ────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceInverse,
      contentTextStyle: BloomTextStyles.inter(
        size: AppTypography.bodyLarge,
        color: AppColors.onDark,
      ),
      actionTextColor: AppColors.primaryLight,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      elevation: 4,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceMuted,
      circularTrackColor: Colors.transparent,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(
        color: AppColors.surfaceInverse,
        borderRadius: AppRadius.smAll,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      textStyle: BloomTextStyles.inter(
        size: AppTypography.labelMedium,
        color: AppColors.onDark,
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),

    // ── Misc ────────────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
      titleTextStyle: BloomTextStyles.inter(
        size: AppTypography.titleSmall,
        weight: FontWeight.w600,
      ),
      subtitleTextStyle: BloomTextStyles.inter(
        size: AppTypography.bodyMedium,
        color: AppColors.textSecondary,
      ),
      minVerticalPadding: AppSpacing.md,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primaryTint,
      selectionHandleColor: AppColors.primary,
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

// ─── Shared TextTheme ────────────────────────────────────────────────────────

TextTheme _buildTextTheme(Color base) => TextTheme(
  displayLarge: BloomTextStyles.fraunces(
    size: AppTypography.displayLarge,
    weight: FontWeight.w600,
    color: base,
    height: 1.15,
  ),
  displayMedium: BloomTextStyles.fraunces(
    size: AppTypography.displayMedium,
    weight: FontWeight.w600,
    color: base,
    height: 1.18,
  ),
  displaySmall: BloomTextStyles.fraunces(
    size: AppTypography.displaySmall,
    weight: FontWeight.w600,
    color: base,
    height: 1.2,
  ),
  headlineLarge: BloomTextStyles.fraunces(
    size: AppTypography.headlineLarge,
    weight: FontWeight.w600,
    color: base,
    height: 1.25,
  ),
  headlineMedium: BloomTextStyles.fraunces(
    size: AppTypography.headlineMedium,
    weight: FontWeight.w600,
    color: base,
    height: 1.3,
  ),
  headlineSmall: BloomTextStyles.fraunces(
    size: AppTypography.headlineSmall,
    weight: FontWeight.w600,
    color: base,
    height: 1.3,
  ),
  titleLarge: BloomTextStyles.inter(
    size: AppTypography.titleLarge,
    weight: FontWeight.w600,
    color: base,
    height: 1.35,
  ),
  titleMedium: BloomTextStyles.inter(
    size: AppTypography.titleMedium,
    weight: FontWeight.w600,
    color: base,
    height: 1.35,
  ),
  titleSmall: BloomTextStyles.inter(
    size: AppTypography.titleSmall,
    weight: FontWeight.w600,
    color: base,
    height: 1.35,
  ),
  bodyLarge: BloomTextStyles.inter(
    size: AppTypography.bodyLarge,
    color: base,
    height: 1.5,
  ),
  bodyMedium: BloomTextStyles.inter(
    size: AppTypography.bodyMedium,
    color: base,
    height: 1.5,
  ),
  bodySmall: BloomTextStyles.inter(
    size: AppTypography.bodySmall,
    color: base,
    height: 1.45,
  ),
  labelLarge: BloomTextStyles.inter(
    size: AppTypography.labelLarge,
    weight: FontWeight.w600,
    color: base,
  ),
  labelMedium: BloomTextStyles.inter(
    size: AppTypography.labelMedium,
    weight: FontWeight.w600,
    color: base,
    letterSpacing: 0.1,
  ),
  labelSmall: BloomTextStyles.inter(
    size: AppTypography.labelSmall,
    weight: FontWeight.w600,
    color: base,
    letterSpacing: 0.2,
  ),
);

// ─── Backwards-compatible entry points ───────────────────────────────────────
//
// The app has exactly one theme. These aliases exist so any caller that still
// asks for a "dark" or "light" theme keeps compiling and gets the real one.

ThemeData buildDarkTheme() => buildAppTheme();

ThemeData buildLightTheme() => buildAppTheme();
