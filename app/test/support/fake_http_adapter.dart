import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A scripted [HttpClientAdapter]: a "mocked dio" that never opens a socket.
/// [handler] answers each request; use [json] to build a response, or throw
/// [offline] to simulate no network. Every request is kept in [requests].
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  FutureOr<ResponseBody> Function(RequestOptions request) handler;
  final requests = <RequestOptions>[];

  /// Requests to [path], in order.
  List<RequestOptions> to(String path) =>
      requests.where((r) => r.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(int status, [Object? body]) =>
      ResponseBody.fromString(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  static Never offline(RequestOptions request) => throw DioException(
    requestOptions: request,
    type: DioExceptionType.connectionError,
    message: 'offline',
  );
}

/// A [Dio] on [adapter], like the app's (base URL, JSON).
Dio fakeDio(FakeHttpAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://mizan.test'))..httpClientAdapter = adapter;
