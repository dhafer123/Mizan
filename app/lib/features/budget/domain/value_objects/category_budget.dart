import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/category.dart';

part 'category_budget.freezed.dart';

/// One category's spending in a month against its limit.
@freezed
abstract class CategoryBudget with _$CategoryBudget {
  const factory CategoryBudget({
    /// Null for expenses filed under a category this device doesn't know.
    required Category? category,
    required Money spent,

    /// The category's standing monthly limit; null for none.
    Money? limit,
  }) = _CategoryBudget;

  const CategoryBudget._();

  /// What is left of the limit; negative when over. Null without a limit.
  Money? get left => limit == null ? null : limit! - spent;

  bool get isOver => left?.isNegative ?? false;

  /// Whole percent of the limit spent, rounded down; over 100 when over.
  /// Null without a limit.
  int? get usedPercent =>
      limit == null ? null : spent.minorUnits * 100 ~/ limit!.minorUnits;
}
