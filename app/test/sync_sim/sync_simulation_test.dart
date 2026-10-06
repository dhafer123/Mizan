// The sync simulation (TASKS.md 3.7, ARCHITECTURE.md §11): random multi-
// device scenarios against the in-memory server, each checking the four
// sync invariants. See sync_scenario.dart.
//
//   flutter test test/sync_sim                                  # 1000, new seed
//   SYNC_SIM_SEED=1234 SYNC_SIM_SCENARIOS=1 flutter test test/sync_sim
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';
import 'fake_sync_server.dart';
import 'sim_network.dart';
import 'sync_scenario.dart';

final _count =
    int.tryParse(Platform.environment['SYNC_SIM_SCENARIOS'] ?? '') ?? 1000;
final _baseSeed =
    int.tryParse(Platform.environment['SYNC_SIM_SEED'] ?? '') ??
    Random().nextInt(1 << 30);

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print('Sync simulation covered: ${SimStats.summary()}');
  });

  setUpAll(() {
    useSystemSqliteOnWindows();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    // ignore: avoid_print
    print('Sync simulation: $_count scenarios from seed $_baseSeed');
  });

  for (var i = 0; i < _count; i++) {
    final seed = _baseSeed + i;
    test('scenario $seed', () async {
      final random = Random(seed);
      final server = FakeSyncServer(pageSize: 1 + random.nextInt(8));
      await SyncScenario(
        seed,
        backend: FakeBackend(server),
        fake: server,
      ).run();
    });
  }
}
