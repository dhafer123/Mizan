import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/remote/auth_api.dart';
import '../../features/auth/data/remote/auth_interceptor.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/session/secure_session_store.dart';
import '../../features/auth/data/session/session_store.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/log_in.dart';
import '../../features/auth/domain/usecases/log_out.dart';
import '../../features/auth/domain/usecases/sign_up.dart';
import '../../features/auth/domain/usecases/validate_credentials.dart';
import '../../features/auth/domain/usecases/watch_account.dart';
import 'core_providers.dart';

part 'auth_providers.g.dart';

/// The Django server. Defaults to the host machine as seen from the Android
/// emulator; for a phone, run with
/// `--dart-define=MIZAN_API_URL=http://<your PC's LAN IP>:8000`.
@Riverpod(keepAlive: true)
String apiBaseUrl(Ref ref) => const String.fromEnvironment(
  'MIZAN_API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

BaseOptions _options(String baseUrl) => BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: const Duration(seconds: 10),
  sendTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 20),
  contentType: Headers.jsonContentType,
  responseType: ResponseType.json,
);

/// For calls without an access token: `/auth/*`, and the interceptor's
/// retries.
@Riverpod(keepAlive: true)
Dio publicDio(Ref ref) {
  final dio = Dio(_options(ref.watch(apiBaseUrlProvider)));
  ref.onDispose(dio.close);
  return dio;
}

/// For the signed-in API (sync, groups): adds the access token and
/// refreshes it on a 401.
@Riverpod(keepAlive: true)
Dio apiDio(Ref ref) {
  final dio = Dio(_options(ref.watch(apiBaseUrlProvider)));
  final repository = ref.watch(authRepositoryImplProvider);
  dio.interceptors.add(
    AuthInterceptor(
      store: ref.watch(sessionStoreProvider),
      api: ref.watch(authApiProvider),
      retryDio: ref.watch(publicDioProvider),
      onSessionExpired: repository.endExpiredSession,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
}

@Riverpod(keepAlive: true)
SessionStore sessionStore(Ref ref) => SecureSessionStore(
  const FlutterSecureStorage(),
  ref.watch(idGeneratorProvider),
);

@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) => AuthApi(ref.watch(publicDioProvider));

@Riverpod(keepAlive: true)
AuthRepositoryImpl authRepositoryImpl(Ref ref) {
  final repository = AuthRepositoryImpl(
    ref.watch(authApiProvider),
    ref.watch(sessionStoreProvider),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
  );
  ref.onDispose(repository.dispose);
  return repository;
}

/// Override this with a fake in tests.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => ref.watch(authRepositoryImplProvider);

@Riverpod(keepAlive: true)
SignUp signUp(Ref ref) =>
    SignUp(ref.watch(authRepositoryProvider), const ValidateCredentials());

@Riverpod(keepAlive: true)
LogIn logIn(Ref ref) =>
    LogIn(ref.watch(authRepositoryProvider), const ValidateCredentials());

@Riverpod(keepAlive: true)
LogOut logOut(Ref ref) => LogOut(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
WatchAccount watchAccount(Ref ref) =>
    WatchAccount(ref.watch(authRepositoryProvider));
