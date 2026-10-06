import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/settings_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../core/result/result.dart';
import '../../auth/presentation/account_section.dart';
import '../../expenses/presentation/shared/failure_message.dart';
import '../domain/value_objects/lock_status.dart';
import 'lock/app_lock_controller.dart';
import 'lock/lock_status_provider.dart';

/// The account (sign in / log out), the app lock (PIN, biometrics) and
/// exporting expenses.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ref
          .watch(lockStatusProvider)
          .when(
            skipLoadingOnReload: true,
            data: (status) => _SettingsList(status: status),
            error: (error, _) => _LoadError(
              message: failureMessage(error),
              onRetry: () => ref.invalidate(lockStatusProvider),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }
}

class _SettingsList extends ConsumerStatefulWidget {
  const _SettingsList({required this.status});

  final LockStatus status;

  @override
  ConsumerState<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends ConsumerState<_SettingsList> {
  var _exporting = false;
  var _busy = false;

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  void _show(String message) => _messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _setLock(bool on) async {
    if (on) {
      final saved = await context.push<bool>(AppRoutes.pin);
      if (saved != true || !mounted) return;
      ref.read(appLockProvider.notifier).setEnabled(enabled: true);
      ref.invalidate(lockStatusProvider);
      _show('App lock is on.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off the app lock?'),
        content: const Text(
          'Anyone with your phone unlocked will be able to open Mizan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await ref.read(disableLockProvider)();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        ref.read(appLockProvider.notifier).setEnabled(enabled: false);
        ref.invalidate(lockStatusProvider);
        _show('App lock is off.');
      case Err(:final failure):
        _show(failure.message);
    }
  }

  Future<void> _changePin() async {
    final saved = await context.push<bool>(AppRoutes.pin);
    if (saved == true && mounted) _show('PIN changed.');
  }

  Future<void> _setBiometrics(bool on) async {
    setState(() => _busy = true);
    final result = await ref.read(setBiometricUnlockProvider)(enabled: on);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(lockStatusProvider);
    if (result case Err(:final failure)) _show(failure.message);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final result = await ref.read(exportExpensesCsvProvider)();
    if (!mounted) return;
    setState(() => _exporting = false);
    switch (result) {
      case Ok(value: final count?):
        _show(count == 1 ? 'Exported 1 expense.' : 'Exported $count expenses.');
      case Ok():
        break; // Cancelled in the picker.
      case Err(:final failure):
        _show(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final theme = Theme.of(context);
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
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        header('Account'),
        const AccountSection(),
        header('Security'),
        SwitchListTile(
          value: status.enabled,
          onChanged: _busy ? null : _setLock,
          secondary: const Icon(Icons.lock_outline),
          title: const Text('App lock'),
          subtitle: const Text(
            'Ask for a PIN when Mizan opens, or after a minute away.',
          ),
        ),
        if (status.enabled) ...[
          ListTile(
            enabled: !_busy,
            onTap: _changePin,
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change PIN'),
          ),
          SwitchListTile(
            value: status.biometrics,
            onChanged: _busy || !status.biometricsAvailable
                ? null
                : _setBiometrics,
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Unlock with fingerprint or face'),
            subtitle: status.biometricsAvailable
                ? const Text('Your PIN still works too.')
                : const Text('Not set up on this phone.'),
          ),
        ],
        header('Data'),
        ListTile(
          enabled: !_exporting,
          onTap: _export,
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Export expenses'),
          subtitle: const Text(
            'Save every expense as a CSV file for a spreadsheet.',
          ),
          trailing: _exporting
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
