import 'package:dio/dio.dart';

import '../../domain/value_objects/auth_error.dart';
import '../../domain/value_objects/auth_failure.dart';

/// Turns a failed sign-up or sign-in call into an [AuthFailure].
///
/// The server's error body is `{"code", "detail", "fields": {name: [{"code", "message"}]}}`
/// (see server/mizan/errors.py); `fields` only comes with `"code": "invalid"`.
abstract final class AuthFailureMapper {
  static AuthFailure fromDio(DioException e, {required bool signUp}) {
    AuthFailure fail(AuthError error) => AuthFailure(error);

    switch (e.type) {
      case DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError:
        return fail(AuthError.offline);
      case DioExceptionType.badResponse:
        break;
      case _:
        return fail(AuthError.server);
    }

    final status = e.response?.statusCode ?? 0;
    final body = e.response?.data;
    final code = body is Map ? body['code'] : null;

    if (status == 429) return fail(AuthError.tooManyAttempts);
    if (status == 401 && code == 'invalid_credentials') {
      return fail(AuthError.invalidCredentials);
    }
    if (status == 400 && code == 'invalid' && body is Map) {
      return _fromFields(body['fields'], signUp: signUp);
    }
    return fail(AuthError.server);
  }

  static AuthFailure _fromFields(Object? fields, {required bool signUp}) {
    if (fields is! Map) return const AuthFailure(AuthError.server);
    List<Object?> codes(String field) => switch (fields[field]) {
      final List<Object?> errors => [
        for (final error in errors)
          if (error is Map) error['code'],
      ],
      _ => const [],
    };

    final email = codes('email');
    if (email.contains('email_taken')) {
      return const AuthFailure(AuthError.emailTaken);
    }
    if (email.isNotEmpty) return const AuthFailure(AuthError.invalidEmail);

    final password = codes('password');
    if (password.isNotEmpty) {
      if (password.contains('blank') || password.contains('required')) {
        return const AuthFailure(AuthError.passwordRequired);
      }
      if (!signUp) return const AuthFailure(AuthError.invalidCredentials);
      return const AuthFailure(AuthError.weakPassword);
    }

    if (codes('displayName').isNotEmpty) {
      return const AuthFailure(AuthError.displayNameTooLong);
    }
    return const AuthFailure(AuthError.server);
  }
}
