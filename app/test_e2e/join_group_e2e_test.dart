// End-to-end: joining a group from a second phone, against a real server.
//
//   MIZAN_E2E_URL=http://127.0.0.1:8000 flutter test test_e2e
// Skipped when MIZAN_E2E_URL is not set. CI runs it in the e2e workflow.
@TestOn('vm')
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/system_clock.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/auth/data/remote/auth_api.dart';
import 'package:mizan/features/auth/data/remote/auth_interceptor.dart';
import 'package:mizan/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/domain/usecases/sign_up.dart';
import 'package:mizan/features/auth/domain/usecases/validate_credentials.dart';
import 'package:mizan/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mizan/features/expenses/domain/usecases/add_expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/groups/data/remote/groups_api.dart';
import 'package:mizan/features/groups/data/repositories/group_repository_impl.dart';
import 'package:mizan/features/groups/domain/usecases/add_placeholder_member.dart';
import 'package:mizan/features/groups/domain/usecases/add_shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/create_group.dart';
import 'package:mizan/features/groups/domain/usecases/create_invite.dart';
import 'package:mizan/features/groups/domain/usecases/join_group.dart';
import 'package:mizan/features/groups/domain/usecases/preview_invite.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';
import 'package:mizan/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:mizan/features/sync/domain/usecases/claim_local_data.dart';
import 'package:mizan/features/sync/domain/usecases/sync_now.dart';

import '../test/support/fake_session_store.dart';
import '../test/support/test_database.dart';

final _serverUrl = Platform.environment['MIZAN_E2E_URL'];

const _clock = SystemClock();
final _ids = UuidV7Generator(_clock);

/// One phone: its own database, account and network, the real stack.
class _Phone {
  _Phone._(this.db, this.account, this.groups, this._sync, this._dio);

  final AppDatabase db;
  final Account account;
  final GroupRepositoryImpl groups;
  final SyncRepositoryImpl _sync;
  final Dio _dio;

  static Future<_Phone> signUp(String name) async {
    final db = openTestDatabase(ids: _ids, clock: _clock);
    final sessions = FakeSessionStore()..id = _ids.newId();
    Dio dio() => Dio(BaseOptions(baseUrl: _serverUrl!));
    final publicDio = dio();
    final authApi = AuthApi(publicDio);
    final auth = AuthRepositoryImpl(authApi, sessions, platform: 'android');
    final apiDio = dio()
      ..interceptors.add(
        AuthInterceptor(
          store: sessions,
          api: authApi,
          retryDio: publicDio,
          onSessionExpired: auth.endExpiredSession,
        ),
      );
    final account = (await SignUp(auth, const ValidateCredentials())(
      email: 'e2e-${_ids.newId()}@example.com',
      password: 'a-long-e2e-password',
      displayName: name,
    )).valueOrNull!;
    final sync = SyncRepositoryImpl(
      db: db,
      api: SyncApi(apiDio),
      clock: _clock,
      deviceId: sessions.deviceId,
      signedIn: () async => true,
    );
    await ClaimLocalData(sync)(account.id);
    await auth.dispose();
    final groups = GroupRepositoryImpl(
      db.groupsDao,
      db.sharedExpensesDao,
      GroupsApi(apiDio),
    );
    return _Phone._(db, account, groups, sync, apiDio);
  }

  Future<void> sync() async {
    final result = await SyncNow(_sync, _clock)(accountId: account.id);
    expect(result.isOk, isTrue, reason: '$result');
  }

  Future<Map<String, String?>> members(String groupId) async => {
    for (final m in await (db.select(
      db.members,
    )..where((m) => m.groupId.equals(groupId))).get())
      m.displayName: m.userId,
  };

  Future<void> close() async {
    _dio.close();
    await db.close();
  }
}

void main() {
  test(
    'a second phone joins a group as its placeholder',
    () async {
      final sami = await _Phone.signUp('Sami');
      final ali = await _Phone.signUp('Ali');
      addTearDown(sami.close);
      addTearDown(ali.close);

      // Sami creates the group offline-style (local writes), adds Ali as a
      // placeholder, then syncs.
      final group = (await CreateGroup(sami.groups, _ids)(
        name: 'Flat 4B',
        currency: Currency.tnd,
        me: sami.account,
      )).valueOrNull!;
      final placeholder = (await AddPlaceholderMember(sami.groups, _ids)(
        groupId: group.id,
        name: 'Ali',
      )).valueOrNull!;
      await sami.sync();

      // Ali's phone already synced something of its own, so its cursor is
      // past the group's rows: only the backfill can bring them.
      final expenses = ExpenseRepositoryImpl(ali.db.expensesDao);
      await AddExpense(expenses, _ids, const ValidateExpense(_clock))(
        amount: const Money(3500, Currency.tnd),
        categoryId: 'food',
        date: DateTime.now().toUtc(),
      );
      await ali.sync();

      final invite = (await CreateInvite(sami.groups)(
        group.id,
        memberId: placeholder.id,
      )).valueOrNull!;
      final preview = (await PreviewInvite(ali.groups)(
        invite.link,
      )).valueOrNull!;
      expect((preview.groupName, preview.memberName), ('Flat 4B', 'Ali'));

      final joined = await JoinGroup(ali.groups)(invite.link);
      expect(joined.valueOrNull, group.id);
      await ali.sync();

      expect((await ali.db.groupsDao.findGroup(group.id))!.name, 'Flat 4B');
      final expected = {'Sami': sami.account.id, 'Ali': ali.account.id};
      expect(await ali.members(group.id), expected);
      expect(await ali.db.select(ali.db.groupBackfills).get(), isEmpty);

      // Sami's phone sees the claim, and the invite can't be used again.
      await sami.sync();
      expect(await sami.members(group.id), expected);
      final again = await JoinGroup(sami.groups)(invite.link);
      expect(again.isErr, isTrue);

      // Ali records expenses on his phone; the server checks the shares
      // against the split (same rounding) and Sami's phone gets them.
      final memberIds = [
        for (final m in await ali.db.groupsDao.getMembers(group.id)) m.id,
      ]..sort();
      final add = AddSharedExpense(ali.groups, _ids, _clock);
      for (final split in [
        Split.equal(memberIds.toSet()),
        Split.percentage({memberIds.first: 3333, memberIds.last: 6667}),
      ]) {
        final added = await add(
          groupId: group.id,
          payerId: placeholder.id,
          amount: const Money(100001, Currency.tnd),
          split: split,
        );
        expect(added.isOk, isTrue, reason: '$added');
      }
      await ali.sync();
      expect(await ali.db.outboxDao.pending(), isEmpty);
      expect(
        (await ali.db.select(ali.db.outbox).get()).where(
          (o) => o.rejectReason != null,
        ),
        isEmpty,
        reason: 'the server accepted both',
      );
      await sami.sync();
      final onSami = await sami.db.select(sami.db.sharedExpenses).get();
      expect(onSami, hasLength(2));
      for (final e in onSami) {
        final total = e.shares.values.fold<int>(0, (a, b) => a + (b! as int));
        expect(total, 100001);
      }
    },
    skip: _serverUrl == null ? 'Set MIZAN_E2E_URL to run' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
