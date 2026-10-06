import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';

import 'fake_sync_server.dart';

/// Where a simulated phone's requests go: the in-memory [FakeSyncServer],
/// or a real server over HTTP.
abstract interface class SimBackend {
  /// [body] is the encoded request body, as dio hands it to an adapter.
  Future<ResponseBody> handle(RequestOptions request, Stream<Uint8List>? body);
}

class FakeBackend implements SimBackend {
  FakeBackend(this.server);

  final FakeSyncServer server;

  @override
  Future<ResponseBody> handle(
    RequestOptions request,
    Stream<Uint8List>? body,
  ) async {
    final answer = switch (request.path) {
      SyncApi.pushPath => server.push(
        jsonDecode(jsonEncode(request.data)) as Map<String, Object?>,
      ),
      SyncApi.pullPath => server.pull(
        request.queryParameters['since'] as int,
        request.queryParameters['limit'] as int,
        group: request.queryParameters['group'] as String?,
      ),
      final path => throw StateError('No route for $path'),
    };
    return ResponseBody.fromString(
      jsonEncode(answer),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// A real server: requests go over the network as they are.
class RealBackend implements SimBackend {
  final _http = HttpClientAdapter();

  @override
  Future<ResponseBody> handle(
    RequestOptions request,
    Stream<Uint8List>? body,
  ) => _http.fetch(request, body, null);
}

/// One phone's connection. Offline: every request fails. Online, a push
/// response may be lost after the server applied it (a timeout), so the
/// client retries ops the server already has: the idempotency path.
class SimLink implements HttpClientAdapter {
  SimLink(this._backend, this._random, {this.loseResponses = 0.1});

  final SimBackend _backend;
  final Random _random;
  var online = true;
  double loseResponses;
  var lost = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!online) throw _down(options, 'offline');
    final response = await _backend.handle(options, requestStream);
    if (options.path == SyncApi.pushPath &&
        _random.nextDouble() < loseResponses) {
      lost++;
      throw _down(options, 'response lost');
    }
    return response;
  }

  static DioException _down(RequestOptions options, String why) => DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    message: why,
  );

  @override
  void close({bool force = false}) {}
}
