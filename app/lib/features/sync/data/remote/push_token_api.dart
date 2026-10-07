import 'package:dio/dio.dart';

/// `PUT /auth/devices/<id>/push-token` (server/accounts). Give it the
/// signed-in [Dio]. Throws [DioException] on failure.
class PushTokenApi {
  const PushTokenApi(this._dio);

  final Dio _dio;

  static String path(String deviceId) => '/auth/devices/$deviceId/push-token';

  Future<void> register({required String deviceId, required String token}) =>
      _dio.put<void>(path(deviceId), data: {'token': token});
}
