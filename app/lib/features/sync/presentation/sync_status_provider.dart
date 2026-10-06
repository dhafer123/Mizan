import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/sync_providers.dart';
import '../../expenses/presentation/shared/no_retry.dart';
import '../domain/entities/sync_status.dart';

part 'sync_status_provider.g.dart';

/// What sync is doing, for the indicator and the account section.
@Riverpod(keepAlive: true, retry: noRetry)
Stream<SyncStatus> syncStatus(Ref ref) =>
    ref.watch(syncSchedulerProvider).watchStatus();
