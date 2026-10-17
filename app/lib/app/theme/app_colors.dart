import 'package:flutter/material.dart';

/// Colours the Material scheme has no slot for: the chart palette and the
/// "nearly at the limit" warning. Each has a light and a dark value with at
/// least 3:1 contrast against the card it sits on (WCAG non-text contrast).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.chart,
    required this.chartOther,
    required this.warning,
  });

  /// Category slices, in rank order.
  final List<Color> chart;

  /// The "other categories" slice.
  final Color chartOther;

  /// A budget at 80% or more, not yet over.
  final Color warning;

  static const light = AppColors(
    chart: [
      Color(0xFF2D4BD8), // royal blue
      Color(0xFF00869E), // cyan, deepened to stand out on white
      Color(0xFFB86E00), // amber
      Color(0xFFC2185B), // pink
    ],
    chartOther: Color(0xFF747A99),
    warning: Color(0xFFB45309),
  );

  static const dark = AppColors(
    chart: [
      Color(0xFF8FA2FF), // periwinkle
      Color(0xFF22D3EE), // cyan
      Color(0xFFFFC46B), // amber
      Color(0xFFF48FB1), // pink
    ],
    chartOther: Color(0xFF9AA0BD),
    warning: Color(0xFFFFC46B),
  );

  /// The theme's colours; the light ones if a theme has none (a bare
  /// `MaterialApp` in a widget test).
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppColors copyWith({List<Color>? chart, Color? chartOther, Color? warning}) =>
      AppColors(
        chart: chart ?? this.chart,
        chartOther: chartOther ?? this.chartOther,
        warning: warning ?? this.warning,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      chart: [
        for (var i = 0; i < chart.length; i++)
          Color.lerp(chart[i], other.chart[i % other.chart.length], t)!,
      ],
      chartOther: Color.lerp(chartOther, other.chartOther, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
