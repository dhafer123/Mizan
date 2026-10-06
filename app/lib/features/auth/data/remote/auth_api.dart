import 'package:dio/dio.dart';

import '../../../../core/result/result.dart';
import '../../domain/value_objects/auth_error.dart';
import '../../domain/value_objects/auth_failure.dart';
import '../../domain/value_objects/credentials.dart';
import '../mappers/session_mapper.dart';
import '../session/stored_session.dart';
import '../session/token_pair.dart';
import 'auth_failure_mapper.dart';
import 'device_info.dart';

/// The server's `/auth/*` endpoints. Give it a [Dio] *without* the
/// `AuthInterceptor`: none of these calls carry an access token.
class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  static const signUpPath = '/auth/signup';
  static const logInPath = '/auth/login';
  static const refreshPath = '/auth/refresh';
  static const logOutPath = '/auth/logout';

  Future<Result<StoredSession, AuthFailure>> signUp(
    Credentials credentials,
    DeviceInfo device,
  ) => _session(signUpPath, signUp: true, {
    'email': credentials.email,
    'password': credentials.password,
    'displayName': credentials.displayName ?? '',
    'device': device.toJson(),
  });

  Future<Result<StoredSession, AuthFailure>> logIn(
    Credentials credentials,
    DeviceInfo device,
  ) => _session(logInPath, signUp: false, {
    'email': credentials.email,
    'password': credentials.password,
    'device': device.toJson(),
  });

  Future<Result<StoredSession, AuthFailure>> _session(
    String path,
    Map<String, Object?> body, {
    required bool signUp,
  }) async {
    try {
      final response = await _dio.post<Object?>(path, data: body);
      return Ok(SessionMapper.sessionFromJson(response.data));
    } on DioException catch (e) {
      return Err(AuthFailureMapper.fromDio(e, signUp: signUp));
    } on FormatException {
      return const Err(AuthFailure(AuthError.server));
    }
  }

  /// A new token pair. Throws the [DioException] (the caller needs to tell
  /// "rejected" from "offline") or a [FormatException] for a bad body.
  Future<TokenPair> refresh(String refreshToken) async {
    final response = await _dio.post<Object?>(
      refreshPath,
      data: {'refresh': refreshToken},
    );
    return SessionMapper.tokensFromJson(response.data);
  }

  /// Revokes the refresh token and forgets the device. Throws on failure.
  Future<void> logOut({
    required String refreshToken,
    required String deviceId,
  }) => _dio.post<void>(
    logOutPath,
    data: {'refresh': refreshToken, 'deviceId': deviceId},
  );
}
