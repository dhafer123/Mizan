import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/settings_providers.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../domain/value_objects/lock_status.dart';

part 'lock_status_provider.g.dart';

/// Whether the lock is on and what can unlock it. A failure becomes the
/// error state. Invalidate it after changing the lock.
@Riverpod(retry: noRetry)
Future<LockStatus> lockStatus(Ref ref) async =>
    switch (await ref.watch(getLockStatusProvider)()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
