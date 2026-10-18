import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The app's few haptics, each for a moment that matters. None with reduced
/// motion (the phone's or the app's); otherwise the phone's own vibration
/// settings still apply. Call while the [BuildContext] is mounted, before a
/// sheet closes.
abstract final class Haptics {
  /// Something was saved: an expense, income, a limit.
  static void saved(BuildContext context) =>
      _play(context, HapticFeedback.lightImpact);

  /// Something was deleted (and can still be undone).
  static void deleted(BuildContext context) =>
      _play(context, HapticFeedback.mediumImpact);

  /// Money changed hands between friends.
  static void settled(BuildContext context) =>
      _play(context, HapticFeedback.heavyImpact);

  /// A small choice: a tab, Penny's next line.
  static void tick(BuildContext context) =>
      _play(context, HapticFeedback.selectionClick);

  static void _play(BuildContext context, Future<void> Function() feedback) {
    if (!context.mounted || MediaQuery.disableAnimationsOf(context)) return;
    unawaited(feedback());
  }
}
