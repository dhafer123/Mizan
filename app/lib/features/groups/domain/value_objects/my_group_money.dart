import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import 'group_share.dart';

part 'my_group_money.freezed.dart';

/// What my groups mean for my own money: my shares (my spending) and where
/// I stand overall. Computed from rows, never stored.
@freezed
abstract class MyGroupMoney with _$MyGroupMoney {
  const factory MyGroupMoney({
    /// My share of every shared expense, in every group.
    required List<GroupShare> shares,

    /// What others owe me now, summed over the groups where I'm owed.
    required Money owedToMe,

    /// What I owe now, summed over the groups where I owe (not negative).
    required Money iOwe,
  }) = _MyGroupMoney;
}
