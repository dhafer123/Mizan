// The sync simulation (test/sync_sim) against the real Django server: the
// same random scenarios and invariant checks, so the in-memory fake server
// can't drift from the real rules unnoticed.
//
//   MIZAN_E2E_URL=http://127.0.0.1:8000 flutter test test_e2e
//   (the server needs AUTH_THROTTLE_RATE raised: each scenario signs up)
@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../test/support/test_database.dart';
import '../test/sync_sim/sim_network.dart';
import '../test/sync_sim/sync_scenario.dart';

final _serverUrl = Platform.environment['MIZAN_E2E_URL'];
final _count =
    int.tryParse(Platform.environment['SYNC_SIM_REAL_SCENARIOS'] ?? '') ?? 25;
final _baseSeed =
    int.tryParse(Platform.environment['SYNC_SIM_SEED'] ?? '') ??
    Random().nextInt(1 << 30);

void main() {
  setUpAll(() {
    useSystemSqliteOnWindows();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    // ignore: avoid_print
    print('Sync simulation (real server): $_count scenarios from $_baseSeed');
  });
  tearDownAll(() {
    // ignore: avoid_print
    print('Covered: ${SimStats.summary()}');
  });

  for (var i = 0; i < _count; i++) {
    final seed = _baseSeed + i;
    test(
      'scenario $seed on the real server',
      () async {
        final signup = await Dio(BaseOptions(baseUrl: _serverUrl!))
            .post<Map<String, Object?>>(
              '/auth/signup',
              data: {
                'email':
                    'sim-$seed-${DateTime.now().microsecondsSinceEpoch}'
                    '@example.com',
                'password': 'a-long-simulation-password',
              },
            );
        final access = signup.data!['access']! as String;
        await SyncScenario(
          seed,
          backend: RealBackend(),
          baseUrl: _serverUrl!,
          headers: {'Authorization': 'Bearer $access'},
        ).run();
      },
      skip: _serverUrl == null ? 'Set MIZAN_E2E_URL to run' : false,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
