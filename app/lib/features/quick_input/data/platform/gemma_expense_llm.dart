import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/expense_llm.dart';
import '../../domain/value_objects/quick_input_error.dart';
import '../../domain/value_objects/quick_input_failure.dart';

/// [ExpenseLlm] on flutter_gemma 0.12.6 (MediaPipe) with Qwen2.5 0.5B
/// Instruct, 8-bit (~547 MB, Apache-2.0, not gated: no token in the app).
/// Runs on the CPU, greedy decoding, one fresh session per phrase.
///
/// The download skips Android's foreground service (it would need more
/// permissions); on Wi-Fi it ends well inside the 9-minute job limit, and
/// the plugin retries.
class GemmaExpenseLlm implements ExpenseLlm {
  GemmaExpenseLlm();

  static const modelFile =
      'Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
  static const modelUrl =
      'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/'
      'resolve/main/$modelFile';

  /// Prompt plus answer; the model's KV cache holds 1280.
  static const _maxTokens = 1024;

  Future<void>? _initialized;
  InferenceModel? _model;

  Future<void> _init() => _initialized ??= FlutterGemma.initialize();

  InferenceInstallationBuilder get _builder => FlutterGemma.installModel(
    modelType: ModelType.qwen,
  ).fromNetwork(modelUrl, foreground: false);

  @override
  Future<bool> isInstalled() async {
    try {
      await _init();
      return await FlutterGemma.isModelInstalled(modelFile);
    } on Object {
      return false;
    }
  }

  @override
  Stream<Result<int, QuickInputFailure>> install() {
    final controller = StreamController<Result<int, QuickInputFailure>>();
    unawaited(() async {
      try {
        await _init();
        await _builder
            .withProgress((percent) => controller.add(Ok(percent)))
            .install();
        controller.add(const Ok(100));
      } on Object {
        controller.add(
          const Err(QuickInputFailure(QuickInputError.downloadFailed)),
        );
      } finally {
        await controller.close();
      }
    }());
    return controller.stream;
  }

  @override
  Future<Result<void, QuickInputFailure>> uninstall() async {
    try {
      await _init();
      await _model?.close();
      _model = null;
      if (await FlutterGemma.isModelInstalled(modelFile)) {
        await FlutterGemma.uninstallModel(modelFile);
      }
      return const Ok(null);
    } on Object {
      return const Err(QuickInputFailure(QuickInputError.llmFailed));
    }
  }

  @override
  Future<Result<String, QuickInputFailure>> complete(String prompt) async {
    try {
      await _init();
      if (!await FlutterGemma.isModelInstalled(modelFile)) {
        return const Err(QuickInputFailure(QuickInputError.modelNotInstalled));
      }
      // After a restart the model is installed but not active; install()
      // only marks it active then (no download).
      if (!FlutterGemma.hasActiveModel()) await _builder.install();
      final model = _model ??= await FlutterGemma.getActiveModel(
        maxTokens: _maxTokens,
        preferredBackend: PreferredBackend.cpu,
      );
      final session = await model.createSession(temperature: 0, topK: 1);
      try {
        await session.addQueryChunk(Message.text(text: prompt, isUser: true));
        return Ok(await session.getResponse());
      } finally {
        await session.close();
      }
    } on Object {
      return const Err(QuickInputFailure(QuickInputError.llmFailed));
    }
  }
}
