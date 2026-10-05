import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/expenses_providers.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import 'no_retry.dart';

part 'categories_provider.g.dart';

/// Every category, archived ones included. A failure becomes the error state.
@Riverpod(retry: noRetry)
Stream<List<Category>> categories(Ref ref) => ref
    .watch(watchCategoriesProvider)()
    .map(
      (result) => switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      },
    );
