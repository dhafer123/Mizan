import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/currency.dart';

part 'group.freezed.dart';

/// People sharing expenses, e.g. a flat. One currency per group.
@freezed
abstract class Group with _$Group {
  const factory Group({
    required String id,
    required String name,
    required Currency currency,
  }) = _Group;
}
