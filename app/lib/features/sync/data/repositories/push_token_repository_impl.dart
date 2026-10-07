import 'package:dio/dio.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/push_token_repository.dart';
import '../../domain/value_objects/sync_error.dart';
import '../../domain/value_objects/sync_failure.dart';
import '../remote/push_token_api.dart';

class PushTokenRepositoryImpl implements PushTokenRepository {
  const PushTokenRepositoryImpl(this._api, {required this.deviceId});

  final PushTokenApi _api;

  /// This install's id, as sent with sign-in (the server's device row).
  final Future<String> Function() deviceId;

  @override
  Future<Result<void, SyncFailure>> register(String token) async {
    try {
      await _api.register(deviceId: await deviceId(), token: token);
      return const Ok(null);
    } on DioException catch (e) {
      return Err(
        SyncFailure(
          e.type == DioExceptionType.badResponse
              ? SyncError.server
              : SyncError.offline,
        ),
      );
    }
  }
}
