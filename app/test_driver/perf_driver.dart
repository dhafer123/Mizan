// Runs integration_test/perf_test.dart on a phone in profile mode and saves
// what it reports to build/perf/<key>.json. See that file for how to run it.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final dir = Directory('build/perf')..createSync(recursive: true);
    for (final MapEntry(:key, :value) in (data ?? {}).entries) {
      File(
        '${dir.path}/$key.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
    }
  },
);
