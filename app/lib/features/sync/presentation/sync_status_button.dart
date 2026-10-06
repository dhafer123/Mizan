import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/sync_providers.dart';
import '../../../app/router/app_router.dart';
import '../domain/entities/sync_status.dart';
import '../domain/value_objects/sync_phase.dart';
import 'sync_status_provider.dart';

/// The sync indicator for an app bar: signed out, offline, syncing, up to
/// date, or changes waiting. Tap for details and "Sync now".
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
    final pending = status.outbox.pending;
    final (icon, tooltip) = switch (status.phase) {
      SyncPhase.signedOut => (Icons.cloud_off_outlined, 'Not syncing: sign in'),
      SyncPhase.offline => (Icons.cloud_off, 'Offline'),
      SyncPhase.syncing => (Icons.cloud_sync_outlined, 'Syncing'),
      SyncPhase.error => (Icons.sync_problem, 'Sync problem'),
      SyncPhase.idle when pending > 0 => (
        Icons.cloud_upload_outlined,
        'Changes waiting to sync',
      ),
      SyncPhase.idle => (Icons.cloud_done_outlined, 'Synced'),
    };
    return IconButton(
      tooltip: tooltip,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const SyncDetailsSheet(),
      ),
      icon: Badge(
        isLabelVisible: pending > 0 && status.phase != SyncPhase.signedOut,
        label: Text('$pending'),
        child: Icon(icon),
      ),
    );
  }
}

/// Sync status in words, with "Sync now" or "Sign in".
class SyncDetailsSheet extends ConsumerWidget {
  const SyncDetailsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
    final theme = Theme.of(context);
    final pending = status.outbox.pending;
    final rejected = status.outbox.rejected;

    final headline = switch (status.phase) {
      SyncPhase.signedOut => 'Local only',
      SyncPhase.offline => 'Offline',
      SyncPhase.syncing => 'Syncing…',
      SyncPhase.error => "Couldn't sync",
      SyncPhase.idle when pending > 0 => 'Waiting to sync',
      SyncPhase.idle => 'Up to date',
    };
    final lines = [
      if (status.phase == SyncPhase.signedOut)
        'Your data is only on this phone. Sign in to back it up and share '
            'expenses with roommates.',
      if (status.failure case final failure?
          when status.phase != SyncPhase.signedOut)
        failure.message,
      if (pending > 0 && status.phase != SyncPhase.signedOut)
        pending == 1
            ? '1 change is waiting to sync.'
            : '$pending changes are waiting to sync.',
      if (rejected > 0)
        rejected == 1
            ? "1 change couldn't be saved on the server and was undone."
            : "$rejected changes couldn't be saved on the server and were "
                  'undone.',
      if (status.lastSyncAt case final at?
          when status.phase != SyncPhase.signedOut)
        'Last synced ${_ago(at, DateTime.now())}.',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(headline, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: 16),
            if (status.phase == SyncPhase.signedOut)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.login);
                },
                child: const Text('Sign in'),
              )
            else
              FilledButton.icon(
                onPressed:
                    status.phase == SyncPhase.syncing ||
                        status.phase == SyncPhase.offline
                    ? null
                    : ref.read(syncSchedulerProvider).syncNow,
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime at, DateTime now) {
    final minutes = now.difference(at).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return hours == 1 ? '1 hour ago' : '$hours hours ago';
    final days = hours ~/ 24;
    return days == 1 ? 'yesterday' : '$days days ago';
  }
}
