import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/quick_input_providers.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';
import 'package:mizan/features/quick_input/presentation/assistant_settings_section.dart';
import 'package:mizan/features/quick_input/presentation/quick_input_timings.dart';

import '../../../support/fake_expense_llm.dart';

Future<ProviderContainer> _pump(WidgetTester tester, FakeExpenseLlm llm) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [expenseLlmProvider.overrideWithValue(llm)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const AssistantSettingsSection();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('downloads after a confirmation, then offers to delete', (
    tester,
  ) async {
    final llm = FakeExpenseLlm(installed: false);
    await _pump(tester, llm);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(find.textContaining('550 MB: use Wi-Fi'), findsOneWidget);
    await tester.tap(find.text('Download').last);
    await tester.pumpAndSettle();

    expect(llm.installed, isTrue);
    expect(find.textContaining('Ready.'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(llm.installed, isFalse);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('a failed download says why and offers a retry', (tester) async {
    final llm = FakeExpenseLlm(installed: false)
      ..installUpdates = const [
        Ok(10),
        Err(QuickInputFailure(QuickInputError.downloadFailed)),
      ];
    await _pump(tester, llm);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download').last);
    await tester.pumpAndSettle();

    expect(find.textContaining("download didn't finish"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows the median voice timing', (tester) async {
    final container = await _pump(tester, FakeExpenseLlm());
    expect(find.textContaining('Nothing measured yet'), findsOneWidget);

    container.read(quickInputTimingsProvider.notifier)
      ..add(const Duration(milliseconds: 300))
      ..add(const Duration(milliseconds: 900))
      ..add(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.text('Median 500 ms over 3 phrase(s), this session.'),
      findsOneWidget,
    );
  });

  test('median of an even count is the mean of the middle two', () {
    expect(
      medianOf(const [
        Duration(milliseconds: 100),
        Duration(milliseconds: 400),
        Duration(milliseconds: 200),
        Duration(milliseconds: 300),
      ]),
      const Duration(milliseconds: 250),
    );
    expect(medianOf(const []), isNull);
  });
}
