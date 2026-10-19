import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/di/groups_providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/widgets/empty_state.dart';
import '../../../../app/widgets/load_error.dart';
import '../../../../app/widgets/skeleton.dart';
import '../../../../core/result/result.dart';
import '../../../auth/presentation/account_provider.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../../mascot/presentation/penny_pose.dart';
import '../../domain/entities/group.dart';
import '../shared/group_data_providers.dart';
import '../shared/leave_group_dialog.dart';
import '../shared/name_sheet.dart';

/// The groups this account is in. Create one, join with an invite link, or
/// leave one (from its menu).
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.joinGroup),
            icon: const Icon(Icons.link),
            tooltip: 'Join with a link',
          ),
        ],
      ),
      body: ref
          .watch(groupsProvider)
          .when(
            data: (groups) =>
                groups.isEmpty ? const _Empty() : _GroupList(groups: groups),
            error: (error, _) => LoadError(
              message: failureMessage(error),
              onRetry: () => ref.invalidate(groupsProvider),
            ),
            loading: () => const SkeletonList(),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createGroup(context, ref),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('New group'),
      ),
    );
  }
}

/// Asks for a name, creates the group, and opens it.
Future<void> createGroup(BuildContext context, WidgetRef ref) async {
  Group? created;
  final saved = await showNameSheet(
    context,
    title: 'New group',
    label: 'Name, e.g. "Flat 4B"',
    action: 'Create',
    onSave: (name) async {
      final result = await ref.read(createGroupProvider)(
        name: name,
        currency: ref.read(appCurrencyProvider),
        me: ref.read(accountProvider).value,
      );
      if (result case Ok(:final value)) created = value;
      return result;
    },
  );
  if (saved == true && created != null && context.mounted) {
    await context.push(AppRoutes.group(created!.id));
  }
}

class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(accountProvider).value != null;
    return EmptyState(
      penny: PennyArt.friends,
      title: 'No groups yet',
      message: signedIn
          ? 'Share rent, groceries or a trip. Create a group, or join one '
                'with an invite link.'
          : 'Groups sync through your account. Sign in to create or join '
                'one.',
      action: signedIn
          ? OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.joinGroup),
              icon: const Icon(Icons.link),
              label: const Text('Join with a link'),
            )
          : FilledButton(
              onPressed: () => context.push(AppRoutes.login),
              child: const Text('Sign in'),
            ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups});

  final List<Group> groups;

  Future<void> _leave(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await showLeaveGroupDialog(context, group: group)) {
      messenger.showSnackBar(SnackBar(content: Text('You left ${group.name}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Clear of the add button and the system inset.
      padding: EdgeInsets.only(
        bottom: 88 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        for (final group in groups)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
            title: Text(group.name),
            subtitle: Text(group.currency.code),
            onTap: () => context.push(AppRoutes.group(group.id)),
            trailing: PopupMenuButton<void>(
              key: Key('group-menu-${group.id}'),
              tooltip: 'More for ${group.name}',
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _leave(context, group),
                  child: const ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Leave group'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
