import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/di/quick_input_providers.dart';
import '../../../core/result/result.dart';
import '../../expenses/presentation/shared/no_retry.dart';
import 'assistant_model.dart';

part 'assistant_model_controller.g.dart';

/// Downloads and deletes the assistant model. Kept alive so a download
/// goes on when Settings closes.
@Riverpod(keepAlive: true, retry: noRetry)
class AssistantModelController extends _$AssistantModelController {
  StreamSubscription<Object?>? _download;

  @override
  Future<AssistantModel> build() async {
    ref.onDispose(() => unawaited(_download?.cancel()));
    return AssistantModel(
      installed: await ref.read(isAssistantInstalledProvider)(),
    );
  }

  void download() {
    if (state.value?.downloading ?? false) return;
    state = const AsyncData(AssistantModel(installed: false, progress: 0));
    _download = ref
        .read(installAssistantProvider)()
        .listen(
          (update) => state = AsyncData(switch (update) {
            Ok(value: 100) => const AssistantModel(installed: true),
            Ok(:final value) => AssistantModel(
              installed: false,
              progress: value,
            ),
            Err(:final failure) => AssistantModel(
              installed: false,
              error: failure.message,
            ),
          }),
        );
  }

  Future<void> delete() async {
    final result = await ref.read(uninstallAssistantProvider)();
    state = AsyncData(switch (result) {
      Ok() => const AssistantModel(installed: false),
      Err(:final failure) => AssistantModel(
        installed: true,
        error: failure.message,
      ),
    });
  }
}
