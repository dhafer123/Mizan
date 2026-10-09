import 'package:freezed_annotation/freezed_annotation.dart';

import 'category_source.dart';

part 'category_suggestion.freezed.dart';

/// A category to pre-select for an expense; the user can change it.
@freezed
abstract class CategorySuggestion with _$CategorySuggestion {
  const factory CategorySuggestion({
    required String categoryId,
    required CategorySource source,
  }) = _CategorySuggestion;
}
