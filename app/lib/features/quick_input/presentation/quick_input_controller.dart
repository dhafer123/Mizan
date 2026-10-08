import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/core_providers.dart';
import '../../../app/di/quick_input_providers.dart';
import '../../../core/result/result.dart';
import '../../expenses/domain/value_objects/expense_source.dart';
import 'quick_input_state.dart';

part 'quick_input_controller.g.dart';

/// Runs one quick input: listen, type or photograph a receipt; read it with
/// the rules and maybe the assistant; then hand the items to the
/// confirmation view. Saving is the
/// confirmation view's job, after the user checks the items.
@riverpod
class QuickInputController extends _$QuickInputController {
  StreamSubscription<Object?>? _listening;

  @override
  QuickInputState build() {
    // Ref can't be used while disposing: take the use case now.
    final stopListening = ref.read(stopListeningProvider);
    ref.onDispose(() {
      unawaited(_listening?.cancel());
      unawaited(stopListening());
    });
    return const QuickTyping();
  }

  void listen() {
    unawaited(_listening?.cancel());
    state = const QuickListening();
    _listening = ref.read(listenToSpeechProvider)().listen((update) {
      switch (update) {
        case Ok(:final value) when value.isFinal:
          unawaited(_read(value.text, fromVoice: true));
        case Ok(:final value):
          state = QuickListening(value.text);
        case Err(:final failure):
          state = QuickFailed(failure.message);
      }
    });
  }

  /// Ends listening now; what was heard is read.
  Future<void> stop() => ref.read(stopListeningProvider)();

  void type() {
    unawaited(_listening?.cancel());
    unawaited(ref.read(stopListeningProvider)());
    state = const QuickTyping();
  }

  Future<void> submit(String text) => _read(text, fromVoice: false);

  /// Takes (or picks) a receipt photo and reads it. Backing out of the
  /// camera returns to typing.
  Future<void> scanReceipt({required bool fromGallery}) async {
    unawaited(_listening?.cancel());
    unawaited(ref.read(stopListeningProvider)());
    final photo = await ref.read(takeReceiptPhotoProvider)(
      fromGallery: fromGallery,
    );
    if (!ref.mounted) return;
    switch (photo) {
      case Err(:final failure):
        state = QuickFailed(failure.message, receipt: true);
      case Ok(value: null):
        state = const QuickTyping();
      case Ok(value: final path?):
        state = const QuickScanning();
        final read = await ref.read(scanReceiptProvider)(
          path,
          currency: ref.read(appCurrencyProvider),
          today: ref.read(clockProvider).now(),
        );
        if (!ref.mounted) return;
        state = switch (read) {
          Ok(:final value) => QuickConfirming(
            value,
            source: ExpenseSource.receipt,
          ),
          Err(:final failure) => QuickFailed(failure.message, receipt: true),
        };
    }
  }

  Future<void> _read(String text, {required bool fromVoice}) async {
    final stopwatch = fromVoice ? (Stopwatch()..start()) : null;
    state = QuickReading(text);
    final parse = await ref.read(parseQuickInputProvider)(
      text,
      currency: ref.read(appCurrencyProvider),
    );
    if (!ref.mounted) return;
    state = QuickConfirming(
      parse,
      source: fromVoice ? ExpenseSource.voice : ExpenseSource.manual,
      sinceSpeech: stopwatch,
    );
  }
}
