import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/load_error.dart';
import '../../../../app/widgets/skeleton.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../add_expense/add_shared_expense_sheet.dart';
import '../settle_up/settle_up_tab.dart';
import '../shared/group_data_providers.dart';
import '../shared/leave_group_dialog.dart';
import 'balances_tab.dart';
import 'expenses_tab.dart';
import 'history_tab.dart';
import 'invite_sheet.dart';

/// A group: who owes what (balances, with members), how to settle up, its
/// expenses, and its edit history. Invite people, add placeholders, add
/// expenses, or leave.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    // Data first, even while refreshing: falling back to the skeleton would
    // rebuild the tabs and jump back to Balances mid-action.
    return switch (group) {
      AsyncValue(value: final Group group) => _Loaded(group: group),
      AsyncValue(hasValue: true) => Scaffold(
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
      _ => Scaffold(appBar: AppBar(), body: const SkeletonList()),
    };
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.group});

  final Group group;

  /// Back to the list once left: this screen's group is gone.
  Future<void> _leave(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (await showLeaveGroupDialog(context, group: group)) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(group.id)).value;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          actions: [
            IconButton(
              onPressed: () => showInviteSheet(context, group: group),
              icon: const Icon(Icons.person_add_alt_outlined),
              tooltip: 'Invite someone',
            ),
            PopupMenuButton<void>(
              key: const Key('group-menu'),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _leave(context),
                  child: const ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Leave group'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          // Scrollable, so each label gets its own width: four fixed
          // equal tabs squeezed "Expenses" into "History" on phones.
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'Balances'),
              Tab(text: 'Settle up'),
              Tab(text: 'Expenses'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            BalancesTab(group: group),
            SettleUpTab(group: group),
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
