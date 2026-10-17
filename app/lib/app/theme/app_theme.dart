import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 themes in the brand's colours: navy, royal blue, cyan, soft
/// white and amber (the app icon and the mascot sheet).
///
/// The schemes are set by hand rather than from a seed: a seed turns the
/// royal blue into lavender, and cyan can't be text on white. In light mode
/// royal blue leads and cyan only fills; in dark mode the surfaces are navy
/// and cyan leads, like the icon's glow. `app_theme_test.dart` checks every
/// text pair for contrast.
abstract final class AppTheme {
  static const fontFamily = 'Manrope';

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2D4BD8),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDDE3FF),
    onPrimaryContainer: Color(0xFF0B1A6B),
    secondary: Color(0xFF00687A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFC6F3FB),
    onSecondaryContainer: Color(0xFF002E36),
    tertiary: Color(0xFF8A5300),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFDDB0),
    onTertiaryContainer: Color(0xFF2C1700),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF7F8FF),
    onSurface: Color(0xFF12152E),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F2FC),
    surfaceContainer: Color(0xFFEAEDFA),
    surfaceContainerHigh: Color(0xFFE3E7F6),
    surfaceContainerHighest: Color(0xFFDDE1F2),
    onSurfaceVariant: Color(0xFF444A66),
    outline: Color(0xFF747A99),
    outlineVariant: Color(0xFFC4C8DE),
    inverseSurface: Color(0xFF282C45),
    onInverseSurface: Color(0xFFEFF0FF),
    inversePrimary: Color(0xFFB8C4FF),
    surfaceTint: Color(0xFF2D4BD8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF22D3EE),
    onPrimary: Color(0xFF00363F),
    primaryContainer: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFDCE4FF),
    secondary: Color(0xFFA9B8FF),
    onSecondary: Color(0xFF13246B),
    secondaryContainer: Color(0xFF2A3A86),
    onSecondaryContainer: Color(0xFFDDE3FF),
    tertiary: Color(0xFFFFC46B),
    onTertiary: Color(0xFF452B00),
    tertiaryContainer: Color(0xFF634000),
    onTertiaryContainer: Color(0xFFFFDDB0),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0B1026),
    onSurface: Color(0xFFE4E7FF),
    surfaceContainerLowest: Color(0xFF070B1C),
    surfaceContainerLow: Color(0xFF121834),
    surfaceContainer: Color(0xFF161D3D),
    surfaceContainerHigh: Color(0xFF1D2548),
    surfaceContainerHighest: Color(0xFF252E55),
    onSurfaceVariant: Color(0xFFB5BBDC),
    outline: Color(0xFF7F86A8),
    outlineVariant: Color(0xFF3A4166),
    inverseSurface: Color(0xFFE4E7FF),
    onInverseSurface: Color(0xFF1B2040),
    inversePrimary: Color(0xFF00687A),
    surfaceTint: Color(0xFF22D3EE),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData light() => _build(lightScheme, AppColors.light);

  static ThemeData dark() => _build(darkScheme, AppColors.dark);

  static ThemeData _build(ColorScheme colors, AppColors appColors) {
    final base = ThemeData(colorScheme: colors, fontFamily: fontFamily);
    final text = base.textTheme;
    return base.copyWith(
      extensions: [appColors],
      scaffoldBackgroundColor: colors.surface,
      // Bold, slightly tight headings and big numbers; the rest as Material.
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(fontWeight: FontWeight.w800),
        displayMedium: text.displayMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          // A hairline edge, so cards read on the navy page too.
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: colors.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
      ),
      // Floating, so a snackbar never covers the add buttons' labels.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: colors.surfaceContainerHighest,
      ),
    );
  }
}
