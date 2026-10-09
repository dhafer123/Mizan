import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/quick_input_providers.dart';
import '../../../core/result/result.dart';
import '../../expenses/presentation/shared/no_retry.dart';
import '../domain/value_objects/category_memory.dart';

part 'category_memory_provider.g.dart';

/// What the user's expenses teach about categories, for the confirmation
/// sheet. Re-read each time the sheet opens, so the last save counts. A
/// storage failure just means no memory: the other tiers still suggest.
@Riverpod(retry: noRetry)
Future<CategoryMemory> categoryMemory(Ref ref) async =>
    switch (await ref.watch(loadCategoryMemoryProvider)()) {
      Ok(:final value) => value,
      Err() => CategoryMemory.empty,
    };
