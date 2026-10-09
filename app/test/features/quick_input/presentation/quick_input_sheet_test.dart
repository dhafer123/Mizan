import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/di/quick_input_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_source.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';
import 'package:mizan/features/quick_input/presentation/quick_input_sheet.dart';
import 'package:mizan/features/quick_input/presentation/quick_input_timings.dart';

import '../../../support/fake_category_repository.dart';
import '../../../support/fake_expense_llm.dart';
import '../../../support/fake_expense_repository.dart';
import '../../../support/fake_receipt_camera.dart';
import '../../../support/fake_receipt_scanner.dart';
import '../../../support/fake_speech_recognizer.dart';
import '../../../support/sequential_id_generator.dart';

final _today = DateTime.utc(2026, 10, 6);

/// Opens the sheet from a button, like Home does, and records its result.
class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final expenses = FakeExpenseRepository();
  final speech = FakeSpeechRecognizer();
  final llm = FakeExpenseLlm(installed: false);
  final camera = FakeReceiptCamera();
  final scanner = FakeReceiptScanner(const [
    'Café Le Baron',
    '05/10/2026',
    'TOTAL  3,000',
  ]);
  late ProviderContainer container;
  int? saved;
  var closed = false;

  Future<void> open({bool listen = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(
            FakeClock(_today.add(const Duration(hours: 9))),
          ),
          idGeneratorProvider.overrideWithValue(
            SequentialIdGenerator(prefix: 'e'),
          ),
          expenseRepositoryProvider.overrideWithValue(expenses),
          categoryRepositoryProvider.overrideWithValue(
            FakeCategoryRepository(),
          ),
          speechRecognizerProvider.overrideWithValue(speech),
          expenseLlmProvider.overrideWithValue(llm),
          receiptCameraProvider.overrideWithValue(camera),
          receiptScannerProvider.overrideWithValue(scanner),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () async {
                    saved = await showQuickInputSheet(context, listen: listen);
                    closed = true;
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder amountField(int index) =>
      find.widgetWithText(TextField, 'Amount').at(index);

  Finder whatField(int index) =>
      find.widgetWithText(TextField, 'What').at(index);

  Future<void> save() async {
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('speaking shows what is heard, then the items to check, and '
      'saves them as voice expenses', (tester) async {
    final h = _Harness(tester);
    await h.open();

    expect(find.text('Listening…'), findsOneWidget);
    expect(h.speech.listens, 1);
    h.speech.hear('kahwa 1.5');
    await tester.pumpAndSettle();
    expect(find.text('kahwa 1.5'), findsOneWidget);

    h.speech.hear('kahwa 1.5 w taxi 8', isFinal: true);
    await tester.pumpAndSettle();

    expect(find.text('Check before saving'), findsOneWidget);
    expect(find.text('“kahwa 1.5 w taxi 8”'), findsOneWidget);
    expect(find.text('Save 2'), findsOneWidget);
    // Suggested from the keywords.
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    // Nothing is saved before the user confirms.
    expect(h.expenses.live, isEmpty);

    await h.save();

    expect(h.saved, 2);
    expect(
      h.expenses.live.map((e) => (e.note, e.amount, e.categoryId, e.source)),
      unorderedEquals([
        ('kahwa', const Money(1500, Currency.tnd), 'food', ExpenseSource.voice),
        (
          'taxi',
          const Money(8000, Currency.tnd),
          'transport',
          ExpenseSource.voice,
        ),
      ]),
    );
    // The time from the end of speech to the items was recorded.
    expect(h.container.read(quickInputTimingsProvider), hasLength(1));
  });

  testWidgets('typed input can be edited before saving, as manual', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.open(listen: false);
    expect(h.speech.listens, 0);

    await tester.enterText(find.byType(TextField), 'zorblax 12');
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    await tester.enterText(h.amountField(0), '13.5');
    await tester.enterText(h.whatField(0), 'gift');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await h.save();

    final saved = h.expenses.live.single;
    expect(saved.note, 'gift');
    expect(saved.amount, const Money(13500, Currency.tnd));
    expect(saved.categoryId, 'other');
    expect(saved.source, ExpenseSource.manual);
    // Typing isn't timed.
    expect(h.container.read(quickInputTimingsProvider), isEmpty);
  });

  testWidgets('an item without a category or with a bad amount is shown on '
      'its card, and nothing is saved', (tester) async {
    final h = _Harness(tester);
    await h.open(listen: false);
    await tester.enterText(find.byType(TextField), 'zorblax 12');
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    await h.save(); // Unknown word: no category suggested.
    expect(find.text('Pick a category.'), findsOneWidget);

    await tester.enterText(h.amountField(0), 'abc');
    await h.save();
    expect(find.textContaining('amount', findRichText: true), findsWidgets);
    expect(h.expenses.live, isEmpty);
    expect(h.closed, isFalse);
  });

  testWidgets('removing an item saves only the rest', (tester) async {
    final h = _Harness(tester);
    await h.open();
    h.speech.hear('kahwa 1.5 w taxi 8', isFinal: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    await h.save();

    expect(h.expenses.live.single.note, 'kahwa');
  });

  testWidgets('an unsure phrase is marked, and points to the assistant when '
      'it is not downloaded', (tester) async {
    final h = _Harness(tester);
    await h.open();
    h.speech.hear('2 cafés 3dt', isFinal: true);
    await tester.pumpAndSettle();

    expect(find.text('Check this one'), findsWidgets);
    expect(find.textContaining('get it in Settings'), findsOneWidget);
  });

  testWidgets('with the assistant, an unsure phrase is read by it', (
    tester,
  ) async {
    final h = _Harness(tester);
    h.llm
      ..installed = true
      ..answer = const Ok('{"items":[{"label":"kahwa","amount":"1.500"}]}');
    await h.open();
    h.speech.hear('kahwa b dinar w nos', isFinal: true);
    await tester.pumpAndSettle();

    expect(find.text('Read by the on-device assistant.'), findsOneWidget);
    expect(find.text('1.500'), findsOneWidget);
  });

  testWidgets('no amount found: an empty state with a way back', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.open();
    h.speech.hear('hello there', isFinal: true);
    await tester.pumpAndSettle();

    expect(find.textContaining('No amount found'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Listening…'), findsOneWidget);
    expect(h.speech.listens, 2);
  });

  testWidgets('a microphone failure says why and offers typing', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.open();
    h.speech.fail(const QuickInputFailure(QuickInputError.micUnavailable));
    await tester.pumpAndSettle();

    expect(find.textContaining("can't use the microphone"), findsOneWidget);
    await tester.tap(find.text('Type instead'));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsOneWidget);
  });

  testWidgets('Done stops listening', (tester) async {
    final h = _Harness(tester);
    await h.open();
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(h.speech.stops, greaterThanOrEqualTo(1));
  });

  group('receipts', () {
    testWidgets('a scanned receipt shows its total and date, and saves as a '
        'receipt expense', (tester) async {
      final h = _Harness(tester);
      await h.open(listen: false);

      await tester.tap(find.text('Scan receipt'));
      await tester.pumpAndSettle();

      expect(h.camera.calls, [false]);
      expect(find.text('Check before saving'), findsOneWidget);
      expect(find.text('3.000'), findsOneWidget);
      expect(find.text('Café Le Baron'), findsWidgets);
      expect(find.textContaining('Oct 5'), findsOneWidget);
      expect(h.expenses.live, isEmpty);

      // The shop isn't a known word: pick the category.
      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      await h.save();

      final saved = h.expenses.live.single;
      expect(saved.amount, const Money(3000, Currency.tnd));
      expect(saved.date, DateTime.utc(2026, 10, 5));
      expect(saved.note, 'Café Le Baron');
      expect(saved.source, ExpenseSource.receipt);
    });

    testWidgets('from photos uses the gallery', (tester) async {
      final h = _Harness(tester);
      await h.open(listen: false);
      await tester.tap(find.text('From photos'));
      await tester.pumpAndSettle();
      expect(h.camera.calls, [true]);
    });

    testWidgets('backing out of the camera returns to typing', (tester) async {
      final h = _Harness(tester);
      h.camera.result = const Ok(null);
      await h.open(listen: false);
      await tester.tap(find.text('Scan receipt'));
      await tester.pumpAndSettle();
      expect(find.text('Quick add'), findsOneWidget);
    });

    testWidgets('a failed photo says why, and trying again takes another', (
      tester,
    ) async {
      final h = _Harness(tester);
      h.scanner.failure = const QuickInputFailure(QuickInputError.ocrFailed);
      await h.open(listen: false);
      await tester.tap(find.text('Scan receipt'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't read the photo"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(h.camera.calls, [false, false]);
    });

    testWidgets('no total on the receipt: an empty state for receipts', (
      tester,
    ) async {
      final h = _Harness(tester);
      h.scanner.rows = const ['Merci de votre visite'];
      await h.open(listen: false);
      await tester.tap(find.text('Scan receipt'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No total found on this receipt'),
        findsOneWidget,
      );
    });

    testWidgets('the receipt button works while listening', (tester) async {
      final h = _Harness(tester);
      await h.open();
      await tester.tap(find.byTooltip('Scan a receipt'));
      await tester.pumpAndSettle();
      expect(h.camera.calls, [false]);
      expect(find.text('3.000'), findsOneWidget);
    });
  });

  group('categories', () {
    Future<void> typeAndRead(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
    }

    testWidgets('one correction changes the next suggestion', (tester) async {
      final h = _Harness(tester);
      await h.open(listen: false);
      await typeAndRead(tester, 'kahwa 2');
      // Keywords: food.
      expect(find.text('Food'), findsOneWidget);

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leisure').last);
      await tester.pumpAndSettle();
      await h.save();
      expect(h.expenses.live.single.categoryId, 'leisure');

      // Next time, the same note is filed as the user did.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await typeAndRead(tester, 'kahwa 3');
      expect(find.text('Leisure'), findsOneWidget);
      expect(find.text('From your past choices'), findsOneWidget);
    });

    testWidgets('the assistant suggests for an unknown note', (tester) async {
      final h = _Harness(tester);
      h.llm
        ..installed = true
        ..answer = const Ok('{"category":"Study"}');
      await h.open(listen: false);
      await typeAndRead(tester, 'zorblax 12');

      expect(find.text('Study'), findsOneWidget);
      expect(find.text('Suggested by the assistant'), findsOneWidget);
      expect(h.llm.prompts.single, contains('"zorblax"'));
    });
  });
}
