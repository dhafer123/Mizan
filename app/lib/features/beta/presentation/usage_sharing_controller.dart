import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/beta_providers.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../expenses/presentation/shared/no_retry.dart';

part 'usage_sharing_controller.g.dart';

/// Whether this phone shares anonymous usage counts. A failure to read it
/// becomes the error state.
@Riverpod(retry: noRetry)
class UsageSharingController extends _$UsageSharingController {
  @override
  Future<bool> build() async =>
      switch (await ref.read(getUsageSharingProvider)()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };

  /// Returns the failure to show, or null. Turning it on sends the first
  /// report right away.
  Future<Failure?> setEnabled({required bool enabled}) async {
    final result = await ref.read(setUsageSharingProvider)(enabled: enabled);
    if (!ref.mounted) return result.failureOrNull;
    switch (result) {
      case Ok():
        state = AsyncData(enabled);
        if (enabled) unawaited(ref.read(sendUsageReportProvider)());
        return null;
      case Err(:final failure):
        return failure;
    }
  }
}
