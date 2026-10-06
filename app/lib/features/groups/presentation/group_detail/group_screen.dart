import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../add_expense/add_shared_expense_sheet.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';
import 'balances_tab.dart';
import 'expenses_tab.dart';
import 'history_tab.dart';
import 'invite_sheet.dart';

/// A group: who owes what (balances, with members), its expenses, and its
/// edit history. Invite people, add placeholders, add expenses.
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
    final members = ref.watch(membersProvider(group.id)).value;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          actions: [
            IconButton(
              onPressed: () => showInviteSheet(context, group: group),
              icon: const Icon(Icons.person_add_alt_outlined),
              tooltip: 'Invite someone',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Balances'),
              Tab(text: 'Expenses'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            BalancesTab(group: group),
            ExpensesTab(group: group),
            HistoryTab(group: group),
          ],
        ),
        floatingActionButton: members == null || members.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => showAddSharedExpenseSheet(
                  context,
                  group: group,
                  members: members,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add expense'),
              ),
      ),
    );
  }
}
