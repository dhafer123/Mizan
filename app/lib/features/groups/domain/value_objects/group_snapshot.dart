import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/group.dart';
import '../entities/member.dart';
import 'group_ledger.dart';

part 'group_snapshot.freezed.dart';

/// One group with its live members and money rows.
@freezed
abstract class GroupSnapshot with _$GroupSnapshot {
  const factory GroupSnapshot({
    required Group group,
    required List<Member> members,
    required GroupLedger ledger,
  }) = _GroupSnapshot;
}
