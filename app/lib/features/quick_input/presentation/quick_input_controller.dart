import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/core_providers.dart';
import '../../../app/di/quick_input_providers.dart';
import '../../../core/result/result.dart';
import 'quick_input_state.dart';

part 'quick_input_controller.g.dart';

/// Runs one quick input: listen (or type), read with the rules and maybe the
/// assistant, then hand the items to the confirmation view. Saving is the
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
      fromVoice: fromVoice,
      sinceSpeech: stopwatch,
    );
  }
}
