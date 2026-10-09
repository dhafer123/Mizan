import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/app_version.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));

    expect(line.substring('version:'.length).trim(), appVersion);
  });
}
