import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../auth/presentation/account_provider.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../../domain/value_objects/group_balances.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';
import '../shared/name_sheet.dart';
import 'invite_sheet.dart';

/// "You owe / you're owed", then every member with their balance. Invite
/// placeholders, or add one.
class BalancesTab extends ConsumerWidget {
  const BalancesTab({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(group.id));
    final balances = ref.watch(groupBalancesProvider(group.id));
    return switch ((members, balances)) {
      (AsyncData(value: final members), AsyncData(value: final balances)) =>
        _Balances(group: group, members: members, balances: balances),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => LoadError(
        message: failureMessage(error),
        onRetry: () => ref
          ..invalidate(membersProvider(group.id))
          ..invalidate(groupBalancesProvider(group.id)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Balances extends ConsumerWidget {
  const _Balances({
    required this.group,
    required this.members,
    required this.balances,
  });

  final Group group;
  final List<Member> members;
  final GroupBalances balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(accountProvider).value?.id;
    final myMember = members.where((m) => m.userId == me && me != null);
    final theme = Theme.of(context);
    const formatter = MoneyFormatter();

    return ListView(
      padding: EdgeInsets.only(
        bottom: 88 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (myMember.isNotEmpty)
          _Standing(standing: balances.of(myMember.first.id)),
        if (members.length == 1)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Just you so far. Invite your roommates, or add them as '
              'members now and invite them later.',
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            '${members.length} ${members.length == 1 ? 'member' : 'members'}'
            ' · ${group.currency.code}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final member in members)
          ListTile(
            key: Key('member-${member.id}'),
            leading: CircleAvatar(
              child: Text(member.displayName.characters.first.toUpperCase()),
            ),
            title: Text(
              member.userId == me && me != null
                  ? '${member.displayName} (you)'
                  : member.displayName,
            ),
            subtitle: Text(
              [
                _balanceText(balances.of(member.id), formatter),
                if (member.isPlaceholder) 'not on Mizan yet',
              ].join(' · '),
            ),
            trailing: member.isPlaceholder
                ? TextButton(
                    onPressed: () =>
                        showInviteSheet(context, group: group, member: member),
                    child: const Text('Invite'),
                  )
                : null,
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              onPressed: () => showNameSheet(
                context,
                title: 'Add a member',
                label: 'Name',
                action: 'Add',
                onSave: (name) => ref.read(addPlaceholderMemberProvider)(
                  groupId: group.id,
                  name: name,
                ),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add a member'),
            ),
          ),
        ),
      ],
    );
  }

  static String _balanceText(
    (Standing, Money)? standing,
    MoneyFormatter formatter,
  ) => switch (standing) {
    (Standing.owed, final amount) => 'gets back ${formatter.format(amount)}',
    (Standing.owes, final amount) => 'owes ${formatter.format(amount)}',
    _ => 'settled up',
  };
}

/// This account's standing, at the top.
class _Standing extends StatelessWidget {
  const _Standing({required this.standing});

  final (Standing, Money)? standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const formatter = MoneyFormatter();
    final (title, color) = switch (standing) {
      (Standing.owed, final amount) => (
        "You're owed ${formatter.format(amount)}",
        theme.colorScheme.primary,
      ),
      (Standing.owes, final amount) => (
        'You owe ${formatter.format(amount)}',
        theme.colorScheme.error,
      ),
      _ => ("You're all settled up", theme.colorScheme.onSurface),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          title,
          key: const Key('my-standing'),
          style: theme.textTheme.titleLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}
