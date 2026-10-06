import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/entities/member.dart';
import '../../domain/value_objects/change_kind.dart';

/// Turns history entries into sentences: "Ali changed amount 120.000 DT →
/// 150.000 DT". Names come from the group's members: the account that made
/// a change is the member it claimed, and "You" for this account.
class HistoryText {
  HistoryText({
    required List<Member> members,
    required this.currency,
    required this.myUserId,
    required this.categoryNames,
    required this.formatDate,
  }) : _byUser = {
         for (final m in members)
           if (m.userId != null) m.userId!: m.displayName,
       },
       _byMember = {for (final m in members) m.id: m.displayName};

  final Currency currency;
  final String? myUserId;
  final Map<String, String> categoryNames;
  final String Function(DateTime day) formatDate;
  final Map<String, String> _byUser;
  final Map<String, String> _byMember;

  static const _labels = {
    'amountMinor': 'amount',
    'payerId': 'payer',
    'date': 'date',
    'split': 'split',
    'shares': 'shares',
    'categoryId': 'category',
    'displayName': 'name',
    'name': 'name',
  };

  String describe(HistoryEntry e) {
    final who = _who(e.changedBy);
    final label = _labels[e.field] ?? e.field;
    final what = switch (e.entity) {
      'shared_expenses' => 'an expense',
      'members' => _byMember[e.entityId] ?? 'a member',
      _ => 'the group',
    };
    return switch (e.kind) {
      ChangeKind.created when e.entity == 'groups' => '$who created the group',
      ChangeKind.created => '$who added $what',
      ChangeKind.deleted => '$who deleted $what',
      ChangeKind.restored => '$who restored $what',
      ChangeKind.changed when e.field == 'userId' => '$who joined as $what',
      ChangeKind.changed => '$who changed ${_change(e, label)}',
      ChangeKind.overwritten =>
        '$who changed ${_change(e, label)}, replacing an edit made at the '
            'same time',
      ChangeKind.discarded =>
        "$who's change to the $label was dropped: "
            '${e.entity == 'shared_expenses' ? 'the expense' : what} had been '
            'deleted',
    };
  }

  String _who(String? userId) => userId != null && userId == myUserId
      ? 'You'
      : _byUser[userId] ?? 'Someone';

  /// "amount 120.000 DT → 150.000 DT", or "the split" when the values don't
  /// read well as text.
  String _change(HistoryEntry e, String label) {
    final from = _value(e.field, e.oldValue);
    final to = _value(e.field, e.newValue);
    if (from == null || to == null) return 'the $label';
    return '$label $from → $to';
  }

  String? _value(String field, Object? value) => switch ((field, value)) {
    ('amountMinor', final int minor) => const MoneyFormatter().format(
      Money(minor, currency),
    ),
    ('payerId', final String id) => _byMember[id] ?? 'a former member',
    ('categoryId', final String id) => categoryNames[id] ?? id,
    ('categoryId', null) => 'none',
    ('date', final String iso) => switch (DateTime.tryParse(iso)) {
      final day? => formatDate(day),
      null => null,
    },
    ('name' || 'displayName', final String text) => text,
    _ => null,
  };
}
