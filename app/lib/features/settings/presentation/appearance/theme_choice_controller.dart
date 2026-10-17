import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/settings_providers.dart';
import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../domain/value_objects/theme_choice.dart';

part 'theme_choice_controller.g.dart';

/// The light / dark choice. A preference that can't be read follows the
/// phone rather than holding the app on an error.
@Riverpod(keepAlive: true, retry: noRetry)
class ThemeChoiceController extends _$ThemeChoiceController {
  @override
  Future<ThemeChoice> build() async =>
      switch (await ref.read(getThemeChoiceProvider)()) {
        Ok(:final value) => value,
        Err() => ThemeChoice.system,
      };

  /// Applies [choice] at once and saves it. Returns the failure to show if
  /// saving failed (it still applies until the app closes).
  Future<Failure?> choose(ThemeChoice choice) async {
    state = AsyncData(choice);
    return (await ref.read(setThemeChoiceProvider)(choice)).failureOrNull;
  }
}

extension ThemeChoiceMode on ThemeChoice {
  ThemeMode get themeMode => switch (this) {
    ThemeChoice.system => ThemeMode.system,
    ThemeChoice.light => ThemeMode.light,
    ThemeChoice.dark => ThemeMode.dark,
  };

  String get label => switch (this) {
    ThemeChoice.system => 'Same as the phone',
    ThemeChoice.light => 'Light',
    ThemeChoice.dark => 'Dark',
  };
}
