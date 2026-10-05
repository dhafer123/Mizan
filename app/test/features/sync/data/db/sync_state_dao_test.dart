import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';

import '../../../../support/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('starts at cursor 0, never synced', () async {
    final state = await db.syncStateDao.read();
    expect(state.cursor, 0);
    expect(state.lastSyncAt, isNull);
  });

  test('saves and overwrites the single row', () async {
    await db.syncStateDao.saveCursor(41, testNow);
    await db.syncStateDao.saveCursor(57, testNow.add(const Duration(hours: 1)));

    final state = await db.syncStateDao.read();
    expect(state.cursor, 57);
    expect(state.lastSyncAt, testNow.add(const Duration(hours: 1)));
    expect(await db.select(db.syncState).get(), hasLength(1));
  });

  test('only row id 1 is allowed', () async {
    await expectLater(
      db
          .into(db.syncState)
          .insert(SyncStateCompanion.insert(id: const Value(2))),
      throwsA(anything),
    );
  });
}
