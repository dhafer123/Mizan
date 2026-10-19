import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/result/result.dart';
import '../../../auth/presentation/account_provider.dart';
import '../../domain/entities/group.dart';

/// Asks before leaving [group], then leaves it. Completes with true once
/// left (the group is gone from this phone). A refusal, e.g. a balance that
/// isn't 0, shows in the dialog.
Future<bool> showLeaveGroupDialog(BuildContext context, {required Group group}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => LeaveGroupDialog(group: group),
    ).then((left) => left ?? false);

class LeaveGroupDialog extends ConsumerStatefulWidget {
  const LeaveGroupDialog({required this.group, super.key});

  final Group group;

  @override
  ConsumerState<LeaveGroupDialog> createState() => _LeaveGroupDialogState();
}

class _LeaveGroupDialogState extends ConsumerState<LeaveGroupDialog> {
  String? _error;
  var _leaving = false;

  Future<void> _leave() async {
    setState(() {
      _leaving = true;
      _error = null;
    });
    final result = await ref.read(leaveGroupProvider)(
      groupId: widget.group.id,
      accountId: ref.read(accountProvider).value?.id,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _leaving = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Leave ${widget.group.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Its expenses and payments leave this phone. You can leave once '
            'your balance is 0. To come back, ask a member for a new invite.',
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              key: const Key('leave-error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _leaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('leave-confirm'),
          onPressed: _leaving ? null : _leave,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Text(_leaving ? 'Leaving…' : 'Leave'),
        ),
      ],
    );
  }
}
