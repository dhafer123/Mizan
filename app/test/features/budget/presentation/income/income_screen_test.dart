import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/budget_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/presentation/income/income_screen.dart';

import '../../../../support/fake_income_source_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

final _sources = [
  IncomeSource(
    id: 's1',
    name: 'Grant',
    amount: _dt(450),
    schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
  ),
  IncomeSource(
    id: 's2',
    name: 'Birthday',
    amount: _dt(50),
    schedule: IncomeSchedule.oneOff(date: DateTime.utc(2026, 10, 20)),
  ),
  IncomeSource(
    id: 's3',
    name: 'Tutoring',
    amount: _dt(120),
    schedule: const IncomeSchedule.irregular(),
  ),
];

Future<FakeIncomeSourceRepository> _pump(
  WidgetTester tester, {
  List<IncomeSource>? sources,
}) async {
  final repository = FakeIncomeSourceRepository(sources ?? _sources);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 10, 6, 9)),
        ),
        idGeneratorProvider.overrideWithValue(
          SequentialIdGenerator(prefix: 'n'),
        ),
        incomeSourceRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: IncomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists sources by name, with their schedule', (tester) async {
    await _pump(tester);

    final birthday = tester.getTopLeft(find.text('Birthday')).dy;
    final grant = tester.getTopLeft(find.text('Grant')).dy;
    expect(birthday, lessThan(grant));
    expect(find.text('Monthly on day 15'), findsOneWidget);
    expect(find.text('Once, on Tue, Oct 20'), findsOneWidget);
    expect(find.text('Irregular, about this much a month'), findsOneWidget);
    expect(find.text('450.000 DT'), findsOneWidget);
  });

  testWidgets('an empty list explains what income is for', (tester) async {
    await _pump(tester, sources: const []);

    expect(find.text('No income yet'), findsOneWidget);
  });

  group('add', () {
    testWidgets('a monthly source', (tester) async {
      final repository = await _pump(tester, sources: const []);
      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Name'), 'Grant');
      await tester.enterText(_field('Amount'), '450');
      await tester.enterText(_field('Day of the month'), '15');
      await _save(tester);

      expect(repository.live, [
        IncomeSource(
          id: 'n1',
          name: 'Grant',
          amount: _dt(450),
          schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
        ),
      ]);
      expect(find.text('Monthly on day 15'), findsOneWidget);
    });

    testWidgets('a one-off source dated today by default', (tester) async {
      final repository = await _pump(tester, sources: const []);
      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Name'), 'Birthday');
      await tester.enterText(_field('Amount'), '50');
      await tester.tap(find.text('One-off'));
      await tester.pumpAndSettle();
      expect(find.text('Tue, Oct 6'), findsOneWidget);
      await _save(tester);

      expect(
        repository.live.single.schedule,
        IncomeSchedule.oneOff(date: DateTime.utc(2026, 10, 6)),
      );
    });

    testWidgets('an irregular source', (tester) async {
      final repository = await _pump(tester, sources: const []);
      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Name'), 'Tutoring');
      await tester.enterText(_field('Amount'), '120');
      await tester.tap(find.text('Irregular'));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(repository.live.single.schedule, const IncomeSchedule.irregular());
    });

    testWidgets('validation errors show on their fields', (tester) async {
      final repository = await _pump(tester, sources: const []);
      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();

      await _save(tester);
      expect(find.text('Enter an amount.'), findsOneWidget);

      await tester.enterText(_field('Amount'), '450');
      await _save(tester);
      expect(find.text('Enter a name.'), findsOneWidget);

      await tester.enterText(_field('Name'), 'Grant');
      await tester.enterText(_field('Day of the month'), '32');
      await _save(tester);
      expect(find.text('Pick a day between 1 and 31.'), findsOneWidget);

      await tester.enterText(_field('Day of the month'), 'x');
      await _save(tester);
      expect(find.text('Pick a day between 1 and 31.'), findsOneWidget);

      expect(repository.live, isEmpty);
    });

    testWidgets('a storage failure shows, and the form stays', (tester) async {
      final repository = await _pump(tester, sources: const []);
      repository.writeFailure = const BudgetFailure(BudgetError.storage);
      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Name'), 'Grant');
      await tester.enterText(_field('Amount'), '450');
      await tester.enterText(_field('Day of the month'), '15');
      await _save(tester);

      expect(
        find.text("Couldn't save on this device. Try again."),
        findsOneWidget,
      );
      expect(find.text('Add income'), findsNWidgets(2)); // title and button
    });
  });

  group('edit', () {
    testWidgets('starts from the source and saves changes', (tester) async {
      final repository = await _pump(tester);
      await tester.tap(find.text('Grant'));
      await tester.pumpAndSettle();

      expect(find.text('Edit income'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Day of the month')).controller!.text,
        '15',
      );
      await tester.enterText(_field('Amount'), '500');
      await _save(tester);

      expect(repository.live.singleWhere((s) => s.id == 's1').amount, _dt(500));
    });

    testWidgets('delete asks first', (tester) async {
      final repository = await _pump(tester);
      await tester.tap(find.text('Tutoring'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Tutoring?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.live, hasLength(3));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(repository.live.map((s) => s.id), isNot(contains('s3')));
      expect(find.text('Tutoring'), findsNothing);
    });
  });
}
