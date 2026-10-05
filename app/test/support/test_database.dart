import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/clock.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/ids/id_generator.dart';
import 'package:sqlite3/open.dart';

import 'sequential_id_generator.dart';

final testNow = DateTime.utc(2026, 10, 6, 9);

/// A fresh in-memory database. Close it in `tearDown`.
AppDatabase openTestDatabase({IdGenerator? ids, Clock? clock}) {
  useSystemSqliteOnWindows();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase.memory(),
    ids: ids ?? SequentialIdGenerator(),
    clock: clock ?? FakeClock(testNow),
  );
}

/// Host tests need a native SQLite. Linux and macOS have one; on Windows use
/// the one that ships with the OS (`winsqlite3.dll`) instead of bundling one.
void useSystemSqliteOnWindows() {
  if (Platform.isWindows) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open('winsqlite3.dll'),
    );
  }
}
