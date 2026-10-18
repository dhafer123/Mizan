import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/settings_providers.dart';
import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/presentation/shared/no_retry.dart';

part 'reduce_motion_controller.g.dart';

/// The app's own "Reduce motion" switch. On, it holds the app still as if
/// the phone asked (`MizanApp` sets `disableAnimations`); off, the app
/// follows the phone. A preference that can't be read counts as off.
@Riverpod(keepAlive: true, retry: noRetry)
class ReduceMotionController extends _$ReduceMotionController {
  @override
  Future<bool> build() async =>
      switch (await ref.read(getReduceMotionProvider)()) {
        Ok(:final value) => value,
        Err() => false,
      };

  /// Applies [on] at once and saves it. Returns the failure to show if
  /// saving failed (it still applies until the app closes).
  Future<Failure?> set({required bool on}) async {
    state = AsyncData(on);
    return (await ref.read(setReduceMotionProvider)(on: on)).failureOrNull;
  }
}
