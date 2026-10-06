import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../auth/presentation/account_provider.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../add_expense/add_shared_expense_sheet.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';
import '../shared/name_sheet.dart';
import 'invite_sheet.dart';

/// A group's members and expenses. Invite people, add placeholders for
/// those not on the app yet (each can be invited to claim their place
/// later), and add expenses.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    return switch (group) {
      AsyncData(value: final Group group) => _Loaded(group: group),
      AsyncData() => Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "This group isn't on this phone yet. It appears once it syncs.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: LoadError(
          message: failureMessage(error),
          onRetry: () => ref.invalidate(groupProvider(groupId)),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            onPressed: () => showInviteSheet(context, group: group),
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: 'Invite someone',
          ),
        ],
      ),
      body: ref
          .watch(membersProvider(group.id))
          .when(
            data: (members) => _MemberList(group: group, members: members),
            error: (error, _) => LoadError(
              message: failureMessage(error),
              onRetry: () => ref.invalidate(membersProvider(group.id)),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
      floatingActionButton: switch (ref.watch(membersProvider(group.id))) {
        AsyncData(value: final members) when members.isNotEmpty =>
          FloatingActionButton.extended(
            onPressed: () => showAddSharedExpenseSheet(
              context,
              group: group,
              members: members,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        _ => null,
      },
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({required this.group, required this.members});

  final Group group;
  final List<Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(accountProvider).value?.id;
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.only(
        bottom: 88 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
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
        if (members.length == 1)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Just you so far. Invite your roommates, or add them as '
              'members now and invite them later.',
            ),
          ),
        for (final member in members)
          ListTile(
            leading: CircleAvatar(
              child: Text(member.displayName.characters.first.toUpperCase()),
            ),
            title: Text(
              member.userId == me && me != null
                  ? '${member.displayName} (you)'
                  : member.displayName,
            ),
            subtitle: member.isPlaceholder
                ? const Text('Not on Mizan yet')
                : null,
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
        const Divider(),
        _Expenses(group: group, members: members),
      ],
    );
  }
}

/// The group's expenses, newest first (the full history comes in 4.3).
class _Expenses extends ConsumerWidget {
  const _Expenses({required this.group, required this.members});

  final Group group;
  final List<Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final names = {for (final m in members) m.id: m.displayName};
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c.name,
    };
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        'Expenses',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return ref
        .watch(sharedExpensesProvider(group.id))
        .when(
          data: (expenses) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('No expenses yet. Add the first one.'),
                ),
              for (final e in expenses)
                ListTile(
                  title: Text(
                    categories[e.categoryId] ??
                        '${e.shares.length}-way expense',
                  ),
                  subtitle: Text(
                    'Paid by ${names[e.payerId] ?? 'a former member'} · '
                    '${MaterialLocalizations.of(context).formatMediumDate(e.date)}',
                  ),
                  trailing: Text(const MoneyFormatter().format(e.amount)),
                ),
            ],
          ),
          error: (error, _) => LoadError(
            message: failureMessage(error),
            onRetry: () => ref.invalidate(sharedExpensesProvider(group.id)),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
  }
}
