import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/auth/data/session/secure_session_store.dart';
import 'package:mizan/features/auth/data/session/stored_session.dart';
import 'package:mizan/features/auth/data/session/token_pair.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';

import '../../../../support/sequential_id_generator.dart';

const _session = StoredSession(
  account: Account(id: '12', email: 'ali@example.com'),
  tokens: TokenPair(access: 'a', refresh: 'r'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SecureSessionStore newStore() => SecureSessionStore(
    const FlutterSecureStorage(),
    SequentialIdGenerator(prefix: 'device-'),
  );

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('nothing stored: signed out', () async {
    expect(await newStore().read(), isNull);
  });

  test('a written session survives a restart', () async {
    await newStore().write(_session);

    expect(await newStore().read(), _session);
  });

  test('clear signs out but keeps the device id', () async {
    final store = newStore();
    final id = await store.deviceId();
    await store.write(_session);

    await store.clear();

    expect(await store.read(), isNull);
    expect(await newStore().read(), isNull);
    expect(await newStore().deviceId(), id);
  });

  test('the device id is made once and kept', () async {
    final first = await newStore().deviceId();

    expect(first, 'device-1');
    expect(await newStore().deviceId(), first);
  });

  test('an unreadable session is dropped: signed out', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureSessionStore.sessionKey: '{"user": "not an account"}',
    });

    expect(await newStore().read(), isNull);
    expect(
      await const FlutterSecureStorage().containsKey(
        key: SecureSessionStore.sessionKey,
      ),
      isFalse,
    );
  });

  test('tokens never show up in toString', () {
    expect(_session.toString(), isNot(contains('access: a')));
    expect(_session.tokens.toString(), 'TokenPair(***)');
  });
}
