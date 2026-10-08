import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/background/background_sync_task.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/budget_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/di/groups_providers.dart';
import 'package:mizan/app/di/sync_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/auth/data/session/stored_session.dart';
import 'package:mizan/features/auth/data/session/token_pair.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';

import '../../support/fake_alert_log.dart';
import '../../support/fake_alert_notifier.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_budget_repository.dart';
import '../../support/fake_category_repository.dart';
import '../../support/fake_expense_repository.dart';
import '../../support/fake_group_repository.dart';
import '../../support/fake_income_source_repository.dart';
import '../../support/fake_session_store.dart';
import '../../support/fake_sync_repository.dart';

const _session = StoredSession(
  account: Account(id: 'u1', email: 'sami@example.com'),
  tokens: TokenPair(access: 'a', refresh: 'r'),
);

void main() {
  late FakeSyncRepository repo;

  setUp(() => repo = FakeSyncRepository());
  tearDown(() => repo.close());

  ProviderContainer container(FakeSessionStore store) {
    final c = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        syncRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10, 6))),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('signed out: nothing to do, done', () async {
    expect(await runBackgroundSync(container(FakeSessionStore())), isTrue);
    expect(repo.calls, isEmpty);
  });

  test('signed in: claims and syncs that account', () async {
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isTrue,
    );
    expect(repo.claims, ['u1']);
    expect(repo.calls, ['push', 'pull:u1']);
  });

  test('offline or server trouble: asks WorkManager to retry', () async {
    repo.pushFailures.add(const SyncFailure(SyncError.offline));
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isFalse,
    );

    repo.pushFailures.add(const SyncFailure(SyncError.server));
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isFalse,
    );
  });

  test('session over: done, no retry', () async {
    repo.pushFailures.add(const SyncFailure(SyncError.sessionExpired));
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isTrue,
    );
  });

  test('cannot claim the data: retry later', () async {
    repo.claimFailure = const SyncFailure(SyncError.storage);
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isFalse,
    );
    expect(repo.calls, isEmpty);
  });

  group('alerts', () {
    late FakeAlertNotifier notifier;

    ProviderContainer alertsContainer({List<Override> extra = const []}) {
      notifier = FakeAlertNotifier();
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10, 6))),
          expenseRepositoryProvider.overrideWithValue(
            FakeExpenseRepository([
              Expense(
                id: 'e1',
                amount: const Money(130000, Currency.tnd),
                categoryId: 'food',
                date: DateTime.utc(2026, 10, 2),
              ),
            ]),
          ),
          categoryRepositoryProvider.overrideWithValue(
            FakeCategoryRepository([
              DefaultCategories.food.copyWith(
                monthlyLimit: const Money(150000, Currency.tnd),
              ),
            ]),
          ),
          budgetRepositoryProvider.overrideWithValue(FakeBudgetRepository()),
          incomeSourceRepositoryProvider.overrideWithValue(
            FakeIncomeSourceRepository(),
          ),
          groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          alertNotificationsProvider.overrideWithValue(notifier),
          alertLogProvider.overrideWithValue(FakeAlertLog()),
          ...extra,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('sends the alerts due, and not again on the next run', () async {
      final c = alertsContainer();

      await runBackgroundAlerts(c);
      expect(notifier.shown.single, isA<CategoryLimitAlert>());

      await runBackgroundAlerts(c);
      expect(notifier.shown, hasLength(1));
    });

    test('a failure is dropped, not thrown', () async {
      final c = alertsContainer(
        extra: [
          computeBudgetAlertsProvider.overrideWith(
            (ref) => throw StateError('broken'),
          ),
        ],
      );
      await runBackgroundAlerts(c);
      expect(notifier.shown, isEmpty);
    });
  });
}
