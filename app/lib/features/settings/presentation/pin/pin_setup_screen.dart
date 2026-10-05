import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/settings_providers.dart';
import '../../../../core/result/result.dart';
import '../../domain/usecases/validate_pin.dart';
import '../../domain/value_objects/settings_error.dart';
import '../lock/pin_pad.dart';

/// Choose a PIN, then type it again. Pops `true` once it is saved (which
/// turns the lock on, or changes the PIN).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  var _pin = '';

  /// The first entry, once the user moves on to confirm it.
  String? _first;
  String? _error;
  var _saving = false;

  bool get _confirming => _first != null;

  void _digit(String d) {
    if (_saving || _pin.length >= ValidatePin.maxLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _next() async {
    if (!_confirming) {
      if (const ValidatePin()(_pin) case Err(:final failure)) {
        setState(() => _error = failure.message);
        return;
      }
      setState(() {
        _first = _pin;
        _pin = '';
      });
      return;
    }

    setState(() => _saving = true);
    final result = await ref.read(setPinProvider)(
      pin: _first!,
      confirmation: _pin,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failure.message;
          _pin = '';
          // A mismatch starts over; anything else lets them retry the save.
          if (failure.error == SettingsError.pinMismatch) _first = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set a PIN')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _confirming ? 'Enter it again' : 'Choose a 4 to 6 digit PIN',
                  style: theme.textTheme.titleMedium,
                ),
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
                PinPad(onDigit: _digit, onDelete: _delete),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _pin.length >= ValidatePin.minLength && !_saving
                      ? _next
                      : null,
                  child: Text(_confirming ? 'Save PIN' : 'Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
