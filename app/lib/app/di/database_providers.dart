import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import 'core_providers.dart';

part 'database_providers.g.dart';

/// Override with an in-memory database in tests.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open(
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(db.close);
  return db;
}
