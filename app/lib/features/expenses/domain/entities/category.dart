import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'category.freezed.dart';

/// A spending category. Archived categories are hidden from pickers but keep
/// their name and icon for the expenses already in them.
@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required String name,

    /// An icon key, e.g. `food`; the UI maps it to a glyph.
    required String icon,
    Money? monthlyLimit,
    @Default(false) bool archived,
  }) = _Category;
}
