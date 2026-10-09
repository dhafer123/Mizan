import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ids/random_id_generator.dart';
import '../../features/beta/data/local/secure_usage_sharing_repository.dart';
import '../../features/beta/data/remote/beta_api.dart';
import '../../features/beta/data/repositories/beta_repository_impl.dart';
import '../../features/beta/domain/repositories/beta_repository.dart';
import '../../features/beta/domain/repositories/usage_sharing_repository.dart';
import '../../features/beta/domain/usecases/get_usage_sharing.dart';
import '../../features/beta/domain/usecases/send_feedback.dart';
import '../../features/beta/domain/usecases/send_usage_report.dart';
import '../../features/beta/domain/usecases/set_usage_sharing.dart';
import '../app_version.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'expenses_providers.dart';

part 'beta_providers.g.dart';

/// Anonymous: the public [Dio], never the signed-in one (ADR 0019).
@Riverpod(keepAlive: true)
BetaRepository betaRepository(Ref ref) =>
    BetaRepositoryImpl(BetaApi(ref.watch(publicDioProvider)));

@Riverpod(keepAlive: true)
UsageSharingRepository usageSharingRepository(Ref ref) =>
    const SecureUsageSharingRepository(FlutterSecureStorage());

@Riverpod(keepAlive: true)
SendFeedback sendFeedback(Ref ref) =>
    SendFeedback(ref.watch(betaRepositoryProvider), appVersion);

@Riverpod(keepAlive: true)
GetUsageSharing getUsageSharing(Ref ref) =>
    GetUsageSharing(ref.watch(usageSharingRepositoryProvider));

@Riverpod(keepAlive: true)
SetUsageSharing setUsageSharing(Ref ref) => SetUsageSharing(
  ref.watch(usageSharingRepositoryProvider),
  const RandomIdGenerator(),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
SendUsageReport sendUsageReport(Ref ref) => SendUsageReport(
  ref.watch(usageSharingRepositoryProvider),
  ref.watch(expenseRepositoryProvider),
  ref.watch(betaRepositoryProvider),
  ref.watch(clockProvider),
  appVersion,
);
