import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/quick_input/data/platform/gemma_expense_llm.dart';
import '../../features/quick_input/data/platform/speech_to_text_recognizer.dart';
import '../../features/quick_input/domain/repositories/expense_llm.dart';
import '../../features/quick_input/domain/repositories/speech_recognizer.dart';
import '../../features/quick_input/domain/usecases/install_assistant.dart';
import '../../features/quick_input/domain/usecases/is_assistant_installed.dart';
import '../../features/quick_input/domain/usecases/listen_to_speech.dart';
import '../../features/quick_input/domain/usecases/parse_quick_input.dart';
import '../../features/quick_input/domain/usecases/stop_listening.dart';
import '../../features/quick_input/domain/usecases/suggest_category.dart';
import '../../features/quick_input/domain/usecases/uninstall_assistant.dart';

part 'quick_input_providers.g.dart';

@Riverpod(keepAlive: true)
SpeechRecognizer speechRecognizer(Ref ref) => SpeechToTextRecognizer();

@Riverpod(keepAlive: true)
ExpenseLlm expenseLlm(Ref ref) => GemmaExpenseLlm();

@Riverpod(keepAlive: true)
ListenToSpeech listenToSpeech(Ref ref) =>
    ListenToSpeech(ref.watch(speechRecognizerProvider));

@Riverpod(keepAlive: true)
StopListening stopListening(Ref ref) =>
    StopListening(ref.watch(speechRecognizerProvider));

@Riverpod(keepAlive: true)
ParseQuickInput parseQuickInput(Ref ref) =>
    ParseQuickInput(ref.watch(expenseLlmProvider));

@Riverpod(keepAlive: true)
IsAssistantInstalled isAssistantInstalled(Ref ref) =>
    IsAssistantInstalled(ref.watch(expenseLlmProvider));

@Riverpod(keepAlive: true)
InstallAssistant installAssistant(Ref ref) =>
    InstallAssistant(ref.watch(expenseLlmProvider));

@Riverpod(keepAlive: true)
UninstallAssistant uninstallAssistant(Ref ref) =>
    UninstallAssistant(ref.watch(expenseLlmProvider));

@Riverpod(keepAlive: true)
SuggestCategory suggestCategory(Ref ref) => const SuggestCategory();
