// Task 6.3's performance numbers, on the phone in profile mode:
// scrolling 2,000 expenses, and syncing 500 ops with a real server.
//
// WARNING: like every on-device test, this uninstalls the app before and
// after the run, wiping the phone's local Mizan data and the downloaded
// assistant. Use a phone whose data is synced, or a spare one.
//
// 1. Start the server on the PC so the phone can reach it (same Wi-Fi):
//      cd server; .venv\Scripts\python manage.py runserver 0.0.0.0:8000
// 2. From app/, with the phone connected:
//      flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart
//        --target=integration_test/perf_test.dart
//        --dart-define=MIZAN_PERF_URL=http://<PC's LAN IP>:8000
// 3. Results land in build/perf/*.json; copy them into docs/METRICS.md.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/router/app_router.dart';
import 'package:mizan/core/clock/system_clock.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/auth/data/remote/auth_api.dart';
import 'package:mizan/features/auth/data/remote/auth_interceptor.dart';
import 'package:mizan/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mizan/features/auth/domain/usecases/log_in.dart';
import 'package:mizan/features/auth/domain/usecases/sign_up.dart';
import 'package:mizan/features/auth/domain/usecases/validate_credentials.dart';
import 'package:mizan/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/expenses/presentation/expense_list/expense_list_screen.dart';
import 'package:mizan/features/expenses/presentation/expense_list/expense_tile.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';
import 'package:mizan/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:mizan/features/sync/domain/usecases/claim_local_data.dart';
import 'package:mizan/features/sync/domain/usecases/sync_now.dart';

import '../test/support/app_harness.dart';
import '../test/support/fake_session_store.dart';
import '../test/support/test_database.dart';

const _serverUrl = String.fromEnvironment('MIZAN_PERF_URL');

/// With --dart-define=MIZAN_PERF_TRACE=true the scroll also records a full
/// timeline with each widget's build and layout (slower, so its frame times
/// aren't the metric): build/perf/scroll_2000_trace.json, for finding jank.
const _trace = bool.fromEnvironment('MIZAN_PERF_TRACE');

const _categories = ['food', 'transport', 'study', 'leisure', 'rent'];
const _notes = ['Coffee', 'Taxi', 'Printing', 'Cinema', 'Groceries', null];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrolling 2,000 expenses', (tester) async {
    final app = AppHarness();
    await app.boot(tester);

    // 2,000 in the harness's month (it's 6 October there), through the use
    // case like the app (each with its outbox row).
    final add = app.container.read(addExpenseProvider);
    await tester.runAsync(() async {
      for (var i = 0; i < 2000; i++) {
        await add(
          amount: Money(500 + (i * 37) % 30000, Currency.tnd),
          categoryId: _categories[i % _categories.length],
          date: DateTime.utc(2026, 10, 1 + i % 6),
          note: _notes[i % _notes.length],
        );
      }
    });

    // Opening the list: from the tap until the first rows are on screen,
    // with the engine drawing at the screen's rate.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final opening = Stopwatch()..start();
    app.container.read(appRouterProvider).go(AppRoutes.expenses);
    while (find.byType(ExpenseTile).evaluate().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    opening.stop();
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseListScreen), findsOneWidget);

    final list = find.byType(Scrollable).last;

    /// A finger's flick: one move per frame, as a touch screen sends them,
    /// timestamped at 90 Hz so the list knows the finger's speed and keeps
    /// going after it lets go. The engine draws at the screen's own rate
    /// (`fullyLive`) and the test waits in real time, as in the app:
    /// `tester.fling` and `pumpAndSettle` would jump the list several rows
    /// per frame, which no finger or screen does.
    Future<void> flick(double dy) async {
      const frames = 12;
      const frame = Duration(microseconds: 11111);
      final finger = await tester.startGesture(tester.getCenter(list));
      for (var i = 1; i <= frames; i++) {
        await finger.moveBy(Offset(0, dy / frames), timeStamp: frame * i);
        await Future<void>.delayed(frame);
      }
      await finger.up(timeStamp: frame * frames);
      // Long enough for the fling to coast to a stop.
      await Future<void>.delayed(const Duration(milliseconds: 2500));
    }

    Future<void> scroll() async {
      // Down through the list, then back up.
      for (var i = 0; i < 12; i++) {
        await flick(-900);
      }
      for (var i = 0; i < 12; i++) {
        await flick(900);
      }
    }

    if (_trace) {
      debugProfileBuildsEnabled = true;
      debugProfileLayoutsEnabled = true;
      await binding.traceAction(
        scroll,
        streams: const ['Dart', 'Embedder', 'GC'],
        reportKey: 'scroll_2000_trace',
      );
      debugProfileBuildsEnabled = false;
      debugProfileLayoutsEnabled = false;
    } else {
      await binding.watchPerformance(scroll, reportKey: 'scroll_2000');
    }
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;
    (binding.reportData ??= {})['open_expenses_2000'] = {
      'millis': opening.elapsedMilliseconds,
    };

    await app.shutDown(tester);
  });

  testWidgets('syncing 500 ops', (tester) async {
    expect(_serverUrl, isNotEmpty, reason: 'Pass MIZAN_PERF_URL');
    const clock = SystemClock();
    final ids = UuidV7Generator(clock);
    final email = 'perf-${ids.newId()}@example.com';
    const password = 'a-long-perf-password';

    /// One phone: its own database, session and sync client.
    Future<
      ({
        AppDatabase db,
        AuthRepositoryImpl auth,
        SyncNow syncNow,
        ClaimLocalData claim,
        AddExpense add,
      })
    >
    phone() async {
      final db = openTestDatabase(ids: ids, clock: clock);
      addTearDown(db.close);
      final sessions = FakeSessionStore()..id = ids.newId();
      final publicDio = Dio(BaseOptions(baseUrl: _serverUrl));
      final authApi = AuthApi(publicDio);
      final auth = AuthRepositoryImpl(authApi, sessions, platform: 'android');
      addTearDown(auth.dispose);
      final apiDio = Dio(BaseOptions(baseUrl: _serverUrl))
        ..interceptors.add(
          AuthInterceptor(
            store: sessions,
            api: authApi,
            retryDio: publicDio,
            onSessionExpired: auth.endExpiredSession,
          ),
        );
      final sync = SyncRepositoryImpl(
        db: db,
        api: SyncApi(apiDio),
        clock: clock,
        deviceId: sessions.deviceId,
        signedIn: () async => await sessions.read() != null,
      );
      return (
        db: db,
        auth: auth,
        syncNow: SyncNow(sync, clock),
        claim: ClaimLocalData(sync),
        add: AddExpense(
          ExpenseRepositoryImpl(db.expensesDao),
          ids,
          const ValidateExpense(clock),
        ),
      );
    }

    await tester.runAsync(() async {
      // Phone A: a fresh account, 500 expenses written offline, one sync.
      final a = await phone();
      final account = (await SignUp(a.auth, const ValidateCredentials())(
        email: email,
        password: password,
      )).valueOrNull!;
      // As the app's sync loop does: the local data becomes the account's,
      // then the (empty) first sync.
      await a.claim(account.id);
      await a.syncNow(accountId: account.id);
      final today = DateTime.now().toUtc();
      for (var i = 0; i < 500; i++) {
        await a.add(
          amount: Money(1000 + i, Currency.tnd),
          categoryId: _categories[i % _categories.length],
          date: DateTime.utc(today.year, today.month, today.day),
          note: 'perf $i',
        );
      }
      final pushing = Stopwatch()..start();
      final pushed = await a.syncNow(accountId: account.id);
      pushing.stop();
      expect(pushed.isOk, isTrue, reason: '$pushed');
      final (pushReport, _) = pushed.valueOrNull!;
      expect(pushReport.pushed, 500);

      // Phone B: the same account signs in and pulls all 500.
      final b = await phone();
      await LogIn(b.auth, const ValidateCredentials())(
        email: email,
        password: password,
      );
      await b.claim(account.id);
      final pulling = Stopwatch()..start();
      final pulled = await b.syncNow(accountId: account.id);
      pulling.stop();
      expect(pulled.isOk, isTrue, reason: '$pulled');
      final (pullReport, _) = pulled.valueOrNull!;
      expect(pullReport.pulled, greaterThanOrEqualTo(500));

      (binding.reportData ??= {})['sync_500'] = {
        'push_500_then_pull_millis': pushing.elapsedMilliseconds,
        'fresh_pull_500_millis': pulling.elapsedMilliseconds,
        'pushed': pushReport.pushed,
        'pulled_on_fresh_phone': pullReport.pulled,
      };
    });
  });
}
