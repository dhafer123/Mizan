import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/sync/data/remote/push_token_api.dart';
import 'package:mizan/features/sync/data/repositories/push_token_repository_impl.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';

import '../../../../support/fake_http_adapter.dart';

void main() {
  test('sends the token for this device, and reports being offline', () async {
    final adapter = FakeHttpAdapter((_) => FakeHttpAdapter.json(204));
    final repository = PushTokenRepositoryImpl(
      PushTokenApi(fakeDio(adapter)),
      deviceId: () async => 'd1',
    );

    expect((await repository.register('t1')).isOk, isTrue);
    final (request,) = (adapter.requests.single,);
    expect(
      (request.method, request.path),
      ('PUT', '/auth/devices/d1/push-token'),
    );
    expect(request.data, {'token': 't1'});

    adapter.handler = FakeHttpAdapter.offline;
    final failed = await repository.register('t1');
    expect(failed.failureOrNull?.error, SyncError.offline);
  });
}
