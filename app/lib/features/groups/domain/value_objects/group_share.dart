import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'group_share.freezed.dart';

/// My share of one shared expense: what counts as my spending (not what I
/// paid for others).
@freezed
abstract class GroupShare with _$GroupShare {
  const factory GroupShare({
    required String groupId,
    required String expenseId,
    required Money amount,

    /// The expense's category, or null for none.
    String? categoryId,
    required DateTime date,
  }) = _GroupShare;
}
