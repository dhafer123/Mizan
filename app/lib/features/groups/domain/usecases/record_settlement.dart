import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/ids/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../entities/settlement.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_error.dart';
import '../value_objects/group_failure.dart';

/// Records that [fromMemberId] paid [toMemberId] [amount] (a suggested
/// transfer, or part of one), dated today. Works offline. Settlements are
/// never edited: a mistake is undone with `ReverseSettlement`.
class RecordSettlement {
  const RecordSettlement(this._repository, this._ids, this._clock);

  final GroupRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<Settlement, GroupFailure>> call({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required Money amount,
  }) async {
    Err<Settlement, GroupFailure> fail(GroupError e) => Err(GroupFailure(e));

    if (!amount.isPositive) return fail(GroupError.amountNotPositive);
    if (fromMemberId == toMemberId) return fail(GroupError.sameMember);
    final group = await _repository.getGroup(groupId);
    if (group case Err(:final failure)) return Err(failure);
    final currency = group.valueOrNull?.currency;
    if (currency == null) return fail(GroupError.notFound);
    if (amount.currency != currency) return fail(GroupError.currencyMismatch);

    final members = await _repository.getMembers(groupId);
    if (members case Err(:final failure)) return Err(failure);
    final ids = {for (final m in members.valueOrNull!) m.id};
    if (!ids.contains(fromMemberId) || !ids.contains(toMemberId)) {
      return fail(GroupError.unknownMember);
    }

    final settlement = Settlement(
      id: _ids.newId(),
      groupId: groupId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amount: amount,
      date: _clock.now().calendarDay,
    );
    final saved = await _repository.addSettlement(settlement);
    return saved.map((_) => settlement);
  }
}
