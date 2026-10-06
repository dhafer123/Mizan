import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/di/groups_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/money/money_formatter.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/presentation/account_provider.dart';
import 'package:mizan/features/groups/domain/entities/group.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';
import 'package:mizan/features/groups/presentation/add_expense/add_shared_expense_sheet.dart';

import '../../../../support/fake_category_repository.dart';
import '../../../../support/fake_group_repository.dart';
import '../../../../support/sequential_id_generator.dart';

const _group = Group(id: 'g1', name: 'Flat 4B', currency: Currency.tnd);
const _members = [
  Member(id: 'a', groupId: 'g1', userId: 'u1', displayName: 'Sami'),
  Member(id: 'b', groupId: 'g1', userId: 'u2', displayName: 'Ali'),
  Member(id: 'c', groupId: 'g1', displayName: 'Nour'),
];

String _dt(int millimes) =>
    const MoneyFormatter().format(Money(millimes, Currency.tnd));

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final repo = FakeGroupRepository()
    ..groups.add(_group)
    ..members.addAll(_members);
  bool? result;

  Future<void> open() async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10, 6))),
          idGeneratorProvider.overrideWithValue(
            SequentialIdGenerator(prefix: 's'),
          ),
          groupRepositoryProvider.overrideWithValue(repo),
          categoryRepositoryProvider.overrideWithValue(
            FakeCategoryRepository(),
          ),
          accountProvider.overrideWith(
            (ref) => Stream.value(
              const Account(id: 'u1', email: 'sami@example.com'),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showAddSharedExpenseSheet(
                  context,
                  group: _group,
                  members: _members,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> amount(String text) async {
    await tester.enterText(find.byKey(const Key('amount')), text);
    await tester.pump();
  }

  Future<void> type(String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> value(String memberId, String text) async {
    await tester.enterText(find.byKey(Key('value-$memberId')), text);
    await tester.pump();
  }

  Future<void> toggle(String memberId) async {
    await tester.tap(find.byKey(Key('include-$memberId')));
    await tester.pump();
  }

  Map<String, String> get shares => {
    for (final id in ['a', 'b', 'c'])
      id: tester.widget<Text>(find.byKey(Key('share-$id'))).data!,
  };

  bool get canSave =>
      tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed !=
      null;

  String? get problem => switch (find.byKey(const Key('split-problem'))) {
    final f when f.evaluate().isEmpty => null,
    final f => tester.widget<Text>(f).data,
  };

  Future<void> save() async {
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('equal: previews rounded shares, among the chosen members', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.open();
    expect(h.canSave, isFalse, reason: 'no amount yet');

    await h.amount('100');
    // Largest remainder: the extra millime goes to the lowest id.
    expect(h.shares, {'a': _dt(33334), 'b': _dt(33333), 'c': _dt(33333)});
    await h.toggle('c');
    expect(h.shares, {'a': _dt(50000), 'b': _dt(50000), 'c': ''});
    expect(h.canSave, isTrue);

    await h.save();
    final saved = h.repo.expenses.single;
    expect(saved.split, const Split.equal({'a', 'b'}));
    expect(saved.payerId, 'a', reason: 'this account pays by default');
    expect(saved.shares, {
      'a': const Money(50000, Currency.tnd),
      'b': const Money(50000, Currency.tnd),
    });
    expect(h.result, isTrue);
  });

  testWidgets('exact: save stays off until the amounts add up', (tester) async {
    final h = _Harness(tester);
    await h.open();
    await h.amount('90');
    await h.type('Exact');

    await h.value('a', '50');
    expect(h.canSave, isFalse);
    expect(h.problem, 'The amounts must add up to the total.');

    await h.value('b', '40');
    expect(h.problem, isNull);
    expect(h.shares, {'a': _dt(50000), 'b': _dt(40000), 'c': _dt(0)});
    expect(h.canSave, isTrue);

    await h.save();
    expect(h.repo.expenses.single.shares.values.map((m) => m.minorUnits), [
      50000,
      40000,
      0,
    ]);
  });

  testWidgets('percentage: must total 100%', (tester) async {
    final h = _Harness(tester);
    await h.open();
    await h.amount('100');
    await h.type('%');

    await h.value('a', '50');
    await h.value('b', '25');
    await h.value('c', '20');
    expect(h.canSave, isFalse);
    expect(h.problem, 'The percentages must add up to 100%.');

    await h.value('c', '25');
    expect(h.shares, {'a': _dt(50000), 'b': _dt(25000), 'c': _dt(25000)});
    await h.save();
    expect(
      h.repo.expenses.single.split,
      const Split.percentage({'a': 5000, 'b': 2500, 'c': 2500}),
    );
  });

  testWidgets('shares: in proportion to whole-number weights', (tester) async {
    final h = _Harness(tester);
    await h.open();
    await h.amount('90');
    await h.type('Shares');

    await h.value('a', '0');
    expect(h.canSave, isFalse);
    expect(h.problem, 'At least one person needs a share above zero.');

    await h.value('a', '2');
    await h.value('b', '1');
    expect(h.shares, {'a': _dt(60000), 'b': _dt(30000), 'c': _dt(0)});
    await h.save();
    expect(
      h.repo.expenses.single.split,
      const Split.shares({'a': 2, 'b': 1, 'c': 0}),
    );
  });
}
