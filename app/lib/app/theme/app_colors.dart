import 'package:flutter/material.dart';

/// Colours the Material scheme has no slot for, each with a light and a dark
/// value, checked for contrast in `app_theme_test.dart`:
/// - category colours (chart slices, category avatars), 3:1 on cards and
///   the page (WCAG non-text contrast);
/// - the "nearly at the limit" warning, 3:1;
/// - the Home hero card's gradient and the text on it, 4.5:1.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.categories,
    required this.chartOther,
    required this.warning,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroNegative,
    required this.heroAccent,
  });

  /// One colour per category slot (see `categoryColor`).
  final List<Color> categories;

  /// The "other categories" slice and unknown categories.
  final Color chartOther;

  /// A budget at 80% or more, not yet over.
  final Color warning;

  /// The hero card's gradient, top left to bottom right.
  final Color heroStart;
  final Color heroEnd;

  /// Text on the hero card: main, secondary, and a negative amount.
  final Color onHero;
  final Color onHeroMuted;
  final Color heroNegative;

  /// Bars and highlights on the hero card: the cyan glow.
  final Color heroAccent;

  static const light = AppColors(
    categories: [
      Color(0xFF2D4BD8), // royal blue
      Color(0xFF00869E), // cyan, deepened to stand out on white
      Color(0xFFB86E00), // amber
      Color(0xFFC2185B), // pink
      Color(0xFF6D3FD1), // violet
      Color(0xFF2E7D32), // green
      Color(0xFFD84315), // orange
      Color(0xFF0277BD), // sky
    ],
    chartOther: Color(0xFF747A99),
    warning: Color(0xFFB45309),
    heroStart: Color(0xFF2D4BD8),
    heroEnd: Color(0xFF18206B),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFD6DDFF),
    heroNegative: Color(0xFFFFD0C9),
    heroAccent: Color(0xFF22D3EE),
  );

  static const dark = AppColors(
    categories: [
      Color(0xFF8FA2FF), // periwinkle
      Color(0xFF22D3EE), // cyan
      Color(0xFFFFC46B), // amber
      Color(0xFFF48FB1), // pink
      Color(0xFFB39DFF), // violet
      Color(0xFF81C784), // green
      Color(0xFFFF8A65), // orange
      Color(0xFF4FC3F7), // sky
    ],
    chartOther: Color(0xFF9AA0BD),
    warning: Color(0xFFFFC46B),
    heroStart: Color(0xFF1E3A8A),
    heroEnd: Color(0xFF101638),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFC7D2FF),
    heroNegative: Color(0xFFFFB4AB),
    heroAccent: Color(0xFF22D3EE),
  );

  /// The theme's colours; the matching built-in set if a theme has none (a
  /// bare `MaterialApp` in a widget test).
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppColors copyWith({
    List<Color>? categories,
    Color? chartOther,
    Color? warning,
    Color? heroStart,
    Color? heroEnd,
    Color? onHero,
    Color? onHeroMuted,
    Color? heroNegative,
    Color? heroAccent,
  }) => AppColors(
    categories: categories ?? this.categories,
    chartOther: chartOther ?? this.chartOther,
    warning: warning ?? this.warning,
    heroStart: heroStart ?? this.heroStart,
    heroEnd: heroEnd ?? this.heroEnd,
    onHero: onHero ?? this.onHero,
    onHeroMuted: onHeroMuted ?? this.onHeroMuted,
    heroNegative: heroNegative ?? this.heroNegative,
    heroAccent: heroAccent ?? this.heroAccent,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      categories: [
        for (var i = 0; i < categories.length; i++)
          mix(categories[i], other.categories[i % other.categories.length]),
      ],
      chartOther: mix(chartOther, other.chartOther),
      warning: mix(warning, other.warning),
      heroStart: mix(heroStart, other.heroStart),
      heroEnd: mix(heroEnd, other.heroEnd),
      onHero: mix(onHero, other.onHero),
      onHeroMuted: mix(onHeroMuted, other.onHeroMuted),
      heroNegative: mix(heroNegative, other.heroNegative),
      heroAccent: mix(heroAccent, other.heroAccent),
    );
  }
}
