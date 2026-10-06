import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/features/groups/domain/entities/history_entry.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/value_objects/change_kind.dart';
import 'package:mizan/features/groups/presentation/group_detail/history_text.dart';

void main() {
  final text = HistoryText(
    members: const [
      Member(id: 'm-sami', groupId: 'g', userId: 'u1', displayName: 'Sami'),
      Member(id: 'm-ali', groupId: 'g', userId: 'u2', displayName: 'Ali'),
      Member(id: 'm-nour', groupId: 'g', displayName: 'Nour'),
    ],
    currency: Currency.tnd,
    myUserId: 'u1',
    categoryNames: const {'food': 'Food'},
    formatDate: (day) => '${day.day}/${day.month}',
  );

  String describe(
    ChangeKind kind, {
    String entity = 'shared_expenses',
    String entityId = 'e1',
    String field = '',
    Object? from,
    Object? to,
    String? by = 'u2',
  }) => text.describe(
    HistoryEntry(
      id: 'h',
      entity: entity,
      entityId: entityId,
      kind: kind,
      field: field,
      oldValue: from,
      newValue: to,
      changedBy: by,
      changedAt: DateTime.utc(2026, 10, 6),
    ),
  );

  test('field changes read as "who changed what from → to"', () {
    expect(
      describe(
        ChangeKind.changed,
        field: 'amountMinor',
        from: 120000,
        to: 150000,
      ),
      'Ali changed amount 120.000 DT → 150.000 DT',
    );
    expect(
      describe(
        ChangeKind.changed,
        field: 'payerId',
        from: 'm-ali',
        to: 'm-nour',
      ),
      'Ali changed payer Ali → Nour',
    );
    expect(
      describe(ChangeKind.changed, field: 'split', from: {}, to: {}),
      'Ali changed the split',
    );
  });

  test('whole-row events, joins, and lost edits', () {
    expect(describe(ChangeKind.created, by: 'u1'), 'You added an expense');
    expect(
      describe(
        ChangeKind.changed,
        entity: 'members',
        entityId: 'm-ali',
        field: 'userId',
        from: null,
        to: 'u2',
      ),
      'Ali joined as Ali',
    );
    expect(
      describe(ChangeKind.discarded, field: 'amountMinor', by: 'u9'),
      "Someone's change to the amount was dropped: the expense had been deleted",
    );
    expect(
      describe(
        ChangeKind.overwritten,
        field: 'categoryId',
        from: 'food',
        to: null,
      ),
      'Ali changed category Food → none, replacing an edit made at the same '
      'time',
    );
  });
}
