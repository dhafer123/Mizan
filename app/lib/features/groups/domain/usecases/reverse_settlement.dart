import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/ids/id_generator.dart';
import '../../../../core/result/result.dart';
import '../entities/settlement.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_error.dart';
import '../value_objects/group_failure.dart';

/// Undoes a payment recorded by mistake with a reversing settlement: the
/// same amount flowing back, so the two cancel out in every balance. The
/// original is never edited or deleted (insert-only). A payment can be
/// reversed once, and a reversal can't itself be reversed (record a new
/// payment instead). Works offline; if another phone reversed it first, the
/// server refuses this one and it disappears after the next sync.
class ReverseSettlement {
  const ReverseSettlement(this._repository, this._ids, this._clock);

  final GroupRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<Settlement, GroupFailure>> call({
    required String groupId,
    required String settlementId,
  }) async {
    final ledger = await _repository.getLedger(groupId);
    if (ledger case Err(:final failure)) return Err(failure);
    final ledgerValue = ledger.valueOrNull!;
    final original = ledgerValue.settlements
        .where((s) => s.id == settlementId)
        .firstOrNull;
    if (original == null) return const Err(GroupFailure(GroupError.notFound));
    if (original.reversesId != null || ledgerValue.isReversed(original.id)) {
      return const Err(GroupFailure(GroupError.notReversible));
    }

    final reversal = Settlement.reversal(
      original,
      id: _ids.newId(),
      date: _clock.now().calendarDay,
    );
    final saved = await _repository.addSettlement(reversal);
    return saved.map((_) => reversal);
  }
}
