import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/quick_input/data/platform/gemma_expense_llm.dart';
import '../../features/quick_input/data/platform/image_picker_receipt_camera.dart';
import '../../features/quick_input/data/platform/mlkit_receipt_scanner.dart';
import '../../features/quick_input/data/platform/speech_to_text_recognizer.dart';
import '../../features/quick_input/domain/repositories/expense_llm.dart';
import '../../features/quick_input/domain/repositories/receipt_camera.dart';
import '../../features/quick_input/domain/repositories/receipt_scanner.dart';
import '../../features/quick_input/domain/repositories/speech_recognizer.dart';
import '../../features/quick_input/domain/usecases/ask_llm_category.dart';
import '../../features/quick_input/domain/usecases/install_assistant.dart';
import '../../features/quick_input/domain/usecases/is_assistant_installed.dart';
import '../../features/quick_input/domain/usecases/listen_to_speech.dart';
import '../../features/quick_input/domain/usecases/load_category_memory.dart';
import '../../features/quick_input/domain/usecases/parse_quick_input.dart';
import '../../features/quick_input/domain/usecases/read_receipt.dart';
import '../../features/quick_input/domain/usecases/scan_receipt.dart';
import '../../features/quick_input/domain/usecases/stop_listening.dart';
import '../../features/quick_input/domain/usecases/suggest_category.dart';
import '../../features/quick_input/domain/usecases/take_receipt_photo.dart';
import '../../features/quick_input/domain/usecases/uninstall_assistant.dart';

import 'expenses_providers.dart';

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

@Riverpod(keepAlive: true)
ReceiptCamera receiptCamera(Ref ref) => ImagePickerReceiptCamera();

@Riverpod(keepAlive: true)
ReceiptScanner receiptScanner(Ref ref) => MlKitReceiptScanner();

@Riverpod(keepAlive: true)
TakeReceiptPhoto takeReceiptPhoto(Ref ref) =>
    TakeReceiptPhoto(ref.watch(receiptCameraProvider));

@Riverpod(keepAlive: true)
ScanReceipt scanReceipt(Ref ref) => ScanReceipt(
  ref.watch(receiptScannerProvider),
  ReadReceipt(ref.watch(expenseLlmProvider)),
);

@Riverpod(keepAlive: true)
LoadCategoryMemory loadCategoryMemory(Ref ref) =>
    LoadCategoryMemory(ref.watch(expenseRepositoryProvider));

@Riverpod(keepAlive: true)
AskLlmCategory askLlmCategory(Ref ref) =>
    AskLlmCategory(ref.watch(expenseLlmProvider));
