import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/theme/app_colors.dart';
import 'package:mizan/app/theme/app_theme.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    group('$name theme', () {
      final colors = theme.colorScheme;
      final app = theme.extension<AppColors>()!;
      // Charts and bars sit on cards; cards sit on the page.
      final backgrounds = {
        'card': theme.cardTheme.color!,
        'page': colors.surface,
      };

      test('uses the bundled brand font', () {
        expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
        expect(theme.textTheme.displaySmall?.fontFamily, AppTheme.fontFamily);
      });

      test('every text-on-colour pair is readable (4.5:1)', () {
        final pairs = {
          'onPrimary/primary': (colors.onPrimary, colors.primary),
          'onPrimaryContainer': (
            colors.onPrimaryContainer,
            colors.primaryContainer,
          ),
          'onSecondary/secondary': (colors.onSecondary, colors.secondary),
          'onSecondaryContainer': (
            colors.onSecondaryContainer,
            colors.secondaryContainer,
          ),
          'onTertiary/tertiary': (colors.onTertiary, colors.tertiary),
          'onTertiaryContainer': (
            colors.onTertiaryContainer,
            colors.tertiaryContainer,
          ),
          'onError/error': (colors.onError, colors.error),
          'onErrorContainer': (colors.onErrorContainer, colors.errorContainer),
          'onInverseSurface': (colors.onInverseSurface, colors.inverseSurface),
          for (final (name, surface) in [
            ('surface', colors.surface),
            ('lowest', colors.surfaceContainerLowest),
            ('low', colors.surfaceContainerLow),
            ('container', colors.surfaceContainer),
            ('high', colors.surfaceContainerHigh),
            ('highest', colors.surfaceContainerHighest),
          ]) ...{
            'onSurface/$name': (colors.onSurface, surface),
            'onSurfaceVariant/$name': (colors.onSurfaceVariant, surface),
            'primary/$name': (colors.primary, surface),
            'error/$name': (colors.error, surface),
          },
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(
            _contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name: $fg on $bg',
          );
        }
      });

      test('text on the hero card is readable across its gradient', () {
        for (final background in [app.heroStart, app.heroEnd]) {
          for (final color in [app.onHero, app.onHeroMuted, app.heroNegative]) {
            expect(
              _contrast(color, background),
              greaterThanOrEqualTo(4.5),
              reason: '$color on $background',
            );
          }
          expect(
            _contrast(app.heroAccent, background),
            greaterThanOrEqualTo(3),
            reason: 'accent bar on $background',
          );
        }
      });

      test('has the matching brightness', () {
        expect(
          colors.brightness,
          name == 'dark' ? Brightness.dark : Brightness.light,
        );
      });

      for (final MapEntry(key: where, value: background)
          in backgrounds.entries) {
        test('chart and warning colours stand out on the $where (3:1)', () {
          for (final color in [
            ...app.categories,
            app.chartOther,
            app.warning,
          ]) {
            expect(
              _contrast(color, background),
              greaterThanOrEqualTo(3),
              reason: '$color on $background',
            );
          }
        });

        test('body and error text are readable on the $where (4.5:1)', () {
          for (final color in [colors.onSurface, colors.error]) {
            expect(
              _contrast(color, background),
              greaterThanOrEqualTo(4.5),
              reason: '$color on $background',
            );
          }
        });
      }
    });
  }
}
