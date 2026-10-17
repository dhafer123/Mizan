import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/settings_providers.dart';
import '../../../expenses/presentation/shared/no_retry.dart';

part 'onboarding_controller.g.dart';

/// Whether to show onboarding on opening the app. If that can't be read,
/// it isn't shown: it must never stand between the user and their data.
@Riverpod(keepAlive: true, retry: noRetry)
class OnboardingController extends _$OnboardingController {
  @override
  Future<bool> build() async =>
      (await ref.read(needsOnboardingProvider)()).valueOrNull ?? false;

  /// Finished or skipped. It isn't shown again this run even if saving the
  /// flag fails (then it may show again on the next start).
  Future<void> finish() async {
    state = const AsyncData(false);
    await ref.read(finishOnboardingProvider)();
  }
}
