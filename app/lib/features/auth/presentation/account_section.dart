import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/auth_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../core/result/result.dart';
import '../../expenses/presentation/shared/failure_message.dart';
import '../../sync/presentation/sync_status_provider.dart';
import '../domain/entities/account.dart';
import 'account_provider.dart';

/// The Settings rows for the account: "Sign in" in local-only mode, or who
/// is signed in and "Log out".
class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key});

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  var _busy = false;

  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _signIn() async {
    final signedIn = await context.push<bool>(AppRoutes.login);
    if (signedIn == true && mounted) _show('Signed in.');
  }

  Future<void> _logOut() async {
    final pending = ref.read(syncStatusProvider).value?.outbox.pending ?? 0;
    final unsynced = switch (pending) {
      0 => '',
      1 => '\n\n1 change hasn\'t synced yet. ',
      _ => '\n\n$pending changes haven\'t synced yet. ',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          'Your data stays on this phone. It stops syncing until you sign '
          'in again.'
          '$unsynced${pending == 0 ? '' : 'If you then sign in to a different '
                    'account, they will be deleted from this phone.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await ref.read(logOutProvider)();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        _show('Logged out.');
      case Err(:final failure):
        _show(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(accountProvider)
        .when(
          skipLoadingOnReload: true,
          data: (account) =>
              account == null ? _signedOut() : _signedIn(account),
          error: (error, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(failureMessage(error)),
            trailing: TextButton(
              onPressed: () => ref.invalidate(accountProvider),
              child: const Text('Try again'),
            ),
          ),
          loading: () => const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Account'),
            trailing: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }

  Widget _signedOut() => ListTile(
    onTap: _signIn,
    leading: const Icon(Icons.cloud_off_outlined),
    title: const Text('Sign in to sync'),
    subtitle: const Text(
      'Mizan works offline. Sign in to back up your data and share '
      'expenses with roommates.',
    ),
    trailing: const Icon(Icons.chevron_right),
  );

  Widget _signedIn(Account account) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(account.displayName ?? account.email),
        subtitle: account.displayName == null ? null : Text(account.email),
      ),
      ListTile(
        enabled: !_busy,
        onTap: _logOut,
        leading: const Icon(Icons.logout),
        title: const Text('Log out'),
        trailing: _busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    ],
  );
}
