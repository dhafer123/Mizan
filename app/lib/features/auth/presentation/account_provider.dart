import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/auth_providers.dart';
import '../../expenses/presentation/shared/no_retry.dart';
import '../domain/entities/account.dart';

part 'account_provider.g.dart';

/// The signed-in account, or null in local-only mode. Follows sign-in,
/// sign-out and the server ending the session.
@Riverpod(keepAlive: true, retry: noRetry)
Stream<Account?> account(Ref ref) => ref.watch(watchAccountProvider)();
