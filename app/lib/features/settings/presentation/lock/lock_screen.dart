import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/settings_providers.dart';
import '../../../../core/result/result.dart';
import '../../domain/usecases/validate_pin.dart';
import '../../domain/value_objects/lock_status.dart';
import '../../domain/value_objects/settings_error.dart';
import 'app_lock_controller.dart';
import 'lock_status_provider.dart';
import 'pin_pad.dart';

/// Covers the app until the PIN (or a fingerprint or face, if turned on)
/// checks out. Shown above the navigator, so it uses no tooltips or
/// snackbars.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  var _pin = '';
  String? _error;
  var _busy = false;
  var _askedBiometrics = false;

  bool get _biometrics =>
      ref.read(lockStatusProvider).value?.biometrics ?? false;

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint once, as soon as the screen shows.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskBiometrics());
  }

  Future<void> _maybeAskBiometrics() async {
    if (_askedBiometrics || !mounted) return;
    final LockStatus status;
    try {
      status = await ref.read(lockStatusProvider.future);
    } on Object {
      return; // The PIN still works.
    }
    if (!mounted || !status.biometrics) return;
    _askedBiometrics = true;
    await _unlockWithBiometrics();
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref.read(unlockWithBiometricsProvider)();
    if (!mounted) return;
    setState(() => _busy = false);
    // A failed or cancelled check says nothing: the PIN is right here.
    if (result is Ok) ref.read(appLockProvider.notifier).unlock();
  }

  Future<void> _submit() async {
    if (_busy || _pin.length < ValidatePin.minLength) return;
    setState(() => _busy = true);
    final result = await ref.read(unlockWithPinProvider)(_pin);
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.read(appLockProvider.notifier).unlock();
      case Err(:final failure):
        setState(() {
          _busy = false;
          _pin = '';
          _error = failure.error == SettingsError.wrongPin
              ? 'Wrong PIN. Try again.'
              : failure.message;
        });
    }
  }

  void _digit(String d) {
    if (_busy || _pin.length >= ValidatePin.maxLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Rebuild when the status arrives, for the fingerprint key.
    ref.watch(lockStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Mizan is locked', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Enter your PIN'),
                const SizedBox(height: 24),
                PinDots(count: _pin.length),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: _error == null
                        ? null
                        : Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                  ),
                ),
                PinPad(
                  onDigit: _digit,
                  onDelete: _delete,
                  extra: _biometrics
                      ? IconButton(
                          onPressed: _unlockWithBiometrics,
                          icon: const Icon(
                            Icons.fingerprint,
                            size: 32,
                            semanticLabel: 'Unlock with fingerprint or face',
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _pin.length >= ValidatePin.minLength && !_busy
                      ? _submit
                      : null,
                  child: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
