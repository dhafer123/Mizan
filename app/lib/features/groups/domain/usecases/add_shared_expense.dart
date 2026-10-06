import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/ids/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/shared_expense.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_error.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/split.dart';
import '../value_objects/split_error.dart';
import '../value_objects/split_failure.dart';
import 'compute_shares.dart';

/// Records an expense [payerId] paid for some of the group, dated today.
/// The shares come from [split] (`ComputeShares`), so they always add up to
/// [amount]. Works offline. Fails with a [GroupFailure] or [SplitFailure].
class AddSharedExpense {
  const AddSharedExpense(
    this._repository,
    this._ids,
    this._clock, [
    this._computeShares = const ComputeShares(),
  ]);

  final GroupRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;
  final ComputeShares _computeShares;

  Future<Result<SharedExpense, Failure>> call({
    required String groupId,
    required String payerId,
    required Money amount,
    required Split split,
    String? categoryId,
  }) async {
    final group = await _repository.getGroup(groupId);
    if (group case Err(:final failure)) return Err(failure);
    final currency = group.valueOrNull?.currency;
    if (currency == null) return const Err(GroupFailure(GroupError.notFound));
    if (amount.currency != currency) {
      return const Err(SplitFailure(SplitError.currencyMismatch));
    }

    final members = await _repository.getMembers(groupId);
    if (members case Err(:final failure)) return Err(failure);
    final memberIds = {for (final m in members.valueOrNull!) m.id};
    if (!memberIds.contains(payerId)) {
      return const Err(GroupFailure(GroupError.unknownMember));
    }

    final shares = _computeShares(amount, split, groupMemberIds: memberIds);
    if (shares case Err(:final failure)) return Err(failure);

    final expense = SharedExpense(
      id: _ids.newId(),
      groupId: groupId,
      payerId: payerId,
      amount: amount,
      date: _clock.now().calendarDay,
      split: split,
      shares: shares.valueOrNull!,
      categoryId: categoryId,
    );
    final saved = await _repository.addExpense(expense);
    return saved.map((_) => expense);
  }
}
