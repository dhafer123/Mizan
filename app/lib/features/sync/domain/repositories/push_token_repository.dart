import '../../../../core/result/result.dart';
import '../value_objects/sync_failure.dart';

/// The server's copy of this phone's push token, so it knows where to send
/// pushes for the signed-in account.
abstract interface class PushTokenRepository {
  Future<Result<void, SyncFailure>> register(String token);
}
