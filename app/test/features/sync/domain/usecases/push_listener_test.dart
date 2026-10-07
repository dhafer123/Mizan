import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/sync/domain/repositories/push_token_repository.dart';
import 'package:mizan/features/sync/domain/usecases/push_listener.dart';
import 'package:mizan/features/sync/domain/value_objects/push_message.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';

import '../../../../support/fake_push_messaging.dart';

class FakeTokens implements PushTokenRepository {
  final sent = <String>[];
  var online = true;

  @override
  Future<Result<void, SyncFailure>> register(String token) async {
    if (!online) return const Err(SyncFailure(SyncError.offline));
    sent.add(token);
    return const Ok(null);
  }
}

void main() {
  late FakePushMessaging push;
  late FakeTokens tokens;
  late StreamController<String?> accounts;
  late PushListener listener;
  late int syncs;

  Future<void> start({bool available = true}) async {
    push = FakePushMessaging(available: available);
    listener = PushListener(
      push: push,
      tokens: tokens,
      accounts: accounts.stream,
      onDataChanged: () => syncs++,
    );
    await listener.start();
  }

  setUp(() {
    tokens = FakeTokens();
    accounts = StreamController<String?>.broadcast();
    syncs = 0;
  });

  tearDown(() async {
    await listener.dispose();
    await push.close();
    await accounts.close();
  });

  test('a push syncs, and one with a notification is shown', () async {
    await start();
    accounts.add('u1');
    push.incoming
      ..add(const PushMessage(groupId: 'flat'))
      ..add(
        const PushMessage(groupId: 'flat', title: 'Flat', body: 'Ali paid'),
      );
    await pumpEventQueue();

    expect(syncs, 2);
    expect(push.shown.single.body, 'Ali paid');
  });

  test('signed out, pushes are ignored', () async {
    await start();
    accounts.add(null);
    push.incoming.add(const PushMessage(title: 'Flat'));
    await pumpEventQueue();

    expect(syncs, 0);
    expect(push.shown, isEmpty);
  });

  test('the token reaches the server once per account, and a failed send '
      'is retried', () async {
    await start();
    push.tokens.add('t1');
    await pumpEventQueue();
    expect(tokens.sent, isEmpty, reason: 'nobody signed in yet');

    tokens.online = false;
    accounts.add('u1');
    await pumpEventQueue();
    tokens.online = true;
    await listener.retry();
    await listener.retry();
    push.tokens.add('t2');
    accounts.add('u2');
    await pumpEventQueue();

    expect(tokens.sent, ['t1', 't2', 't2']);
  });

  test('a tapped notification opens its group', () async {
    await start();
    accounts.add('u1');
    final opened = listener.openedGroups.first;
    push.taps.add(const PushMessage(groupId: 'flat'));

    expect(await opened, 'flat');
  });

  test('without push (no Firebase config) nothing happens', () async {
    await start(available: false);
    accounts.add('u1');
    push.tokens.add('t1');
    push.incoming.add(const PushMessage(title: 'Flat'));
    await pumpEventQueue();

    expect(syncs, 0);
    expect(tokens.sent, isEmpty);
  });
}
