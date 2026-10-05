import 'package:flutter/material.dart';

/// Material 3 themes for the app. Colours are placeholders until 6.2 (UX polish).
abstract final class AppTheme {
  static const _seed = Color(0xFF00796B);

  static ThemeData light() =>
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed));

  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );
}
