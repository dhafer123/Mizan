import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/settings_providers.dart';
import '../../expenses/presentation/shared/no_retry.dart';

part 'voice_hint_controller.g.dart';

/// Whether Home points out voice input (until it's first used). If that
/// can't be read, the hint stays hidden: it's only a nudge.
@Riverpod(keepAlive: true, retry: noRetry)
class VoiceHintController extends _$VoiceHintController {
  @override
  Future<bool> build() async =>
      (await ref.read(shouldShowVoiceHintProvider)()).valueOrNull ?? false;

  /// Voice input was opened. Hidden at once, even if saving fails (then it
  /// may show again on the next start).
  Future<void> dismiss() async {
    if (state.value != true) return;
    state = const AsyncData(false);
    await ref.read(dismissVoiceHintProvider)();
  }
}
