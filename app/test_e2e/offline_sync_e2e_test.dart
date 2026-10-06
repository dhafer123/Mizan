// End-to-end: the real sync client against a real Mizan server.
//
// Run against a server you started (see server/README.md):
//   MIZAN_E2E_URL=http://127.0.0.1:8000 flutter test test_e2e
// Skipped when MIZAN_E2E_URL is not set. CI runs it in the e2e workflow.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/system_clock.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/auth/data/remote/auth_api.dart';
import 'package:mizan/features/auth/data/remote/auth_interceptor.dart';
import 'package:mizan/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mizan/features/auth/domain/usecases/sign_up.dart';
import 'package:mizan/features/auth/domain/usecases/validate_credentials.dart';
import 'package:mizan/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/delete_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/edit_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';
import 'package:mizan/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:mizan/features/sync/domain/usecases/claim_local_data.dart';
import 'package:mizan/features/sync/domain/usecases/sync_now.dart';
import 'package:mizan/features/sync/domain/usecases/sync_scheduler.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_phase.dart';

import '../test/support/fake_session_store.dart';
import '../test/support/fake_sync_repository.dart';
import '../test/support/test_database.dart';

final _serverUrl = Platform.environment['MIZAN_E2E_URL'];

/// The phone's network: real HTTP, unless airplane mode is on.
class _Radio implements HttpClientAdapter {
  final _real = HttpClientAdapter();
  var airplaneMode = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (airplaneMode) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'airplane mode',
      );
    }
    return _real.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _real.close(force: force);
}

Future<void> _until(
  bool Function() condition, {
  required String what,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  test(
    'airplane mode → 5 edits → online: the server has all 5',
    () async {
      // --- A phone: local DB, session storage, network, sync loop ---
      const clock = SystemClock();
      final ids = UuidV7Generator(clock);
      final db = openTestDatabase(ids: ids, clock: clock);
      addTearDown(db.close);
      final sessions = FakeSessionStore()..id = ids.newId();
      final radio = _Radio();
      Dio dio() =>
          Dio(BaseOptions(baseUrl: _serverUrl!))..httpClientAdapter = radio;
      final publicDio = dio();
      final authApi = AuthApi(publicDio);
      final auth = AuthRepositoryImpl(authApi, sessions, platform: 'android');
      addTearDown(auth.dispose);
      final apiDio = dio()
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
      final connectivity = FakeConnectivity();
      addTearDown(connectivity.close);
      final scheduler = SyncScheduler(
        syncNow: SyncNow(sync, clock),
        claim: ClaimLocalData(sync),
        lastSyncAt: sync.lastSyncAt,
        accounts: auth.watchAccount().map((a) => a?.id),
        online: connectivity.watchOnline(),
        outbox: sync.watchOutbox(),
        background: FakeBackgroundSync(),
        debounce: const Duration(milliseconds: 200),
      )..start();
      addTearDown(scheduler.dispose);

      final expenses = ExpenseRepositoryImpl(db.expensesDao);
      final validate = const ValidateExpense(clock);
      final add = AddExpense(expenses, ids, validate);
      final edit = EditExpense(expenses, validate);
      final delete = DeleteExpense(expenses);

      /// Everything the server holds for this user, read over the test's
      /// own network (not the phone's), so it works in airplane mode too.
      Future<List<Map<String, Object?>>> serverChanges() async {
        final session = await sessions.read();
        final check = Dio(BaseOptions(baseUrl: _serverUrl!))
          ..options.headers['Authorization'] =
              'Bearer ${session!.tokens.access}';
        final page = (await check.get<Map<String, Object?>>(
          SyncApi.pullPath,
          queryParameters: {'since': 0, 'limit': 500},
        )).data!;
        return (page['changes']! as List).cast<Map<String, Object?>>();
      }

      Future<Map<Object?, Map<Object?, Object?>>> serverExpenses() async => {
        for (final c in await serverChanges())
          if (c['entity'] == 'expenses')
            (c['state']! as Map)['id']: c['state']! as Map,
      };

      // --- Sign up a fresh account; the first sync runs ---
      final email = 'e2e-${ids.newId()}@example.com';
      final signedUp = await SignUp(auth, const ValidateCredentials())(
        email: email,
        password: 'a-long-e2e-password',
      );
      expect(signedUp.isOk, isTrue, reason: '$signedUp');
      await _until(
        () => scheduler.status.lastSyncAt != null,
        what: 'the first sync',
      );

      // --- Airplane mode, then 5 edits ---
      radio.airplaneMode = true;
      connectivity.online = false;
      await _until(
        () => scheduler.status.phase == SyncPhase.offline,
        what: 'offline status',
      );

      Future<Expense> spend(int millimes, String note) async {
        final result = await add(
          amount: Money(millimes, Currency.tnd),
          categoryId: 'food',
          date: DateTime.now().toUtc(),
          note: note,
        );
        return result.valueOrNull!;
      }

      final coffee = (await spend(3500, 'coffee')).id; // 1
      final taxi = await spend(8000, 'taxi'); // 2
      final lunch = (await spend(12000, 'lunch')).id; // 3
      await edit(taxi.copyWith(amount: const Money(9000, Currency.tnd))); // 4
      await delete(lunch); // 5

      // Let the debounce fire: the scheduler must not reach the server.
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(scheduler.status.phase, SyncPhase.offline);
      expect(scheduler.status.outbox.pending, 5);
      // The server has none of them yet.
      expect(await serverExpenses(), isEmpty);

      // --- Back online ---
      radio.airplaneMode = false;
      connectivity.online = true;
      await _until(
        () =>
            scheduler.status.phase == SyncPhase.idle &&
            scheduler.status.outbox.pending == 0,
        what: 'the outbox to drain',
      );
      expect(scheduler.status.outbox.rejected, 0);

      // --- What does the server have? Ask it directly, as this user ---
      final changes = await serverChanges();
      final rows = await serverExpenses();
      expect(rows.keys.toSet(), {coffee, taxi.id, lunch});
      expect(rows[coffee]!['amountMinor'], 3500);
      expect(rows[taxi.id]!['amountMinor'], 9000, reason: 'the edit');
      expect(rows[lunch]!['deleted'], isTrue, reason: 'the delete');

      final history = [
        for (final c in changes.where((c) => c['entity'] == 'entity_history'))
          c['state']! as Map,
      ];
      final events = [
        for (final h in history) '${h['kind']}:${h['entityId']}:${h['field']}',
      ];
      expect(events, [
        'created:$coffee:',
        'created:${taxi.id}:',
        'created:$lunch:',
        'changed:${taxi.id}:amountMinor',
        'deleted:$lunch:',
      ], reason: 'all 5 edits, in order');

      // And the phone agrees with the server.
      final local = await db.expensesDao.findById(taxi.id);
      expect((local!.amountMinor, local.version), (9000, 2));
    },
    skip: _serverUrl == null ? 'Set MIZAN_E2E_URL to run' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
