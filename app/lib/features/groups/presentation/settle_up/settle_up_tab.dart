import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/value_objects/group_ledger.dart';
import '../../domain/value_objects/transfer.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';
import 'record_payment_sheet.dart';

/// The fewest payments that settle the group (`SimplifyDebts`), each with a
/// "Record" action, then the payments made so far. A payment recorded by
/// mistake is undone with a reversing payment, never edited or deleted.
class SettleUpTab extends ConsumerWidget {
  const SettleUpTab({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(group.id));
    final transfers = ref.watch(suggestedTransfersProvider(group.id));
    final ledger = ref.watch(groupLedgerProvider(group.id));
    return switch ((members, transfers, ledger)) {
      (
        AsyncData(value: final members),
        AsyncData(value: final transfers),
        AsyncData(value: final ledger),
      ) =>
        _SettleUp(
          group: group,
          members: members,
          transfers: transfers,
          ledger: ledger,
        ),
      (AsyncError(:final error), _, _) ||
      (_, AsyncError(:final error), _) ||
      (_, _, AsyncError(:final error)) => LoadError(
        message: failureMessage(error),
        onRetry: () => ref
          ..invalidate(membersProvider(group.id))
          ..invalidate(groupBalancesProvider(group.id))
          ..invalidate(groupLedgerProvider(group.id)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SettleUp extends ConsumerWidget {
  const _SettleUp({
    required this.group,
    required this.members,
    required this.transfers,
    required this.ledger,
  });

  final Group group;
  final List<Member> members;
  final List<Transfer> transfers;
  final GroupLedger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final names = {for (final m in members) m.id: m.displayName};
    String name(String id) => names[id] ?? 'a former member';
    const formatter = MoneyFormatter();
    final dates = MaterialLocalizations.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return ListView(
      padding: EdgeInsets.only(
        bottom: 88 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        header('Suggested payments'),
        if (transfers.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Everyone is settled up.'),
          ),
        for (final (i, t) in transfers.indexed)
          ListTile(
            key: Key('transfer-$i'),
            leading: const Icon(Icons.arrow_forward),
            title: Text('${name(t.fromMemberId)} pays ${name(t.toMemberId)}'),
            subtitle: Text(formatter.format(t.amount)),
            trailing: FilledButton.tonal(
              onPressed: () => showRecordPaymentSheet(
                context,
                group: group,
                members: members,
                fromMemberId: t.fromMemberId,
                toMemberId: t.toMemberId,
                amount: t.amount,
              ),
              child: const Text('Record'),
            ),
          ),
        if (members.length > 1)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: () => showRecordPaymentSheet(
                  context,
                  group: group,
                  members: members,
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Record another payment'),
              ),
            ),
          ),
        const Divider(),
        header('Payments'),
        if (ledger.settlements.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('No payments yet.'),
          ),
        for (final s in ledger.settlements)
          ListTile(
            key: Key('settlement-${s.id}'),
            title: Text(
              s.reversesId == null
                  ? '${name(s.fromMemberId)} paid ${name(s.toMemberId)}'
                  : 'Undo: ${name(s.toMemberId)} → ${name(s.fromMemberId)}',
            ),
            subtitle: Text(
              [
                formatter.format(s.amount),
                dates.formatMediumDate(s.date),
                if (ledger.isReversed(s.id)) 'undone',
              ].join(' · '),
            ),
            trailing: s.reversesId == null && !ledger.isReversed(s.id)
                ? TextButton(
                    onPressed: () => _undo(context, ref, s, name),
                    child: const Text('Undo'),
                  )
                : null,
          ),
      ],
    );
  }

  Future<void> _undo(
    BuildContext context,
    WidgetRef ref,
    Settlement s,
    String Function(String) name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo this payment?'),
        content: Text(
          'This records ${const MoneyFormatter().format(s.amount)} going back '
          'from ${name(s.toMemberId)} to ${name(s.fromMemberId)}, so the '
          'payment no longer counts. Both stay in the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Undo payment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(reverseSettlementProvider)(
      groupId: group.id,
      settlementId: s.id,
    );
    if (result case Err(:final failure)) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
