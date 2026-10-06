import 'package:dio/dio.dart';

import '../../../../app/db/app_database.dart';
import '../../../../core/result/result.dart';
import '../../../../core/result/storage_errors_as_failures.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/repositories/group_repository.dart';
import '../../domain/value_objects/group_error.dart';
import '../../domain/value_objects/group_failure.dart';
import '../../domain/value_objects/group_invite.dart';
import '../../domain/value_objects/group_ledger.dart';
import '../../domain/value_objects/group_snapshot.dart';
import '../../domain/value_objects/invite_preview.dart';
import '../db/groups_dao.dart';
import '../db/settlements_dao.dart';
import '../db/shared_expenses_dao.dart';
import '../mappers/group_mapper.dart';
import '../mappers/history_mapper.dart';
import '../mappers/settlement_mapper.dart';
import '../mappers/shared_expense_mapper.dart';
import '../remote/groups_api.dart';

/// [GroupRepository] over the local tables (writes queue sync ops) and the
/// server's invite endpoints. Nothing is thrown past this class.
class GroupRepositoryImpl implements GroupRepository {
  const GroupRepositoryImpl(
    this._dao,
    this._expenses,
    this._settlements,
    this._api,
  );

  final GroupsDao _dao;
  final SharedExpensesDao _expenses;
  final SettlementsDao _settlements;
  final GroupsApi _api;

  static const _storage = GroupFailure(GroupError.storage);

  /// The server's error codes (server/groups/services.py).
  static const _codes = {
    'group_not_found': GroupError.notSynced,
    'not_a_placeholder': GroupError.placeholderTaken,
    'invite_not_found': GroupError.inviteNotFound,
    'invite_expired': GroupError.inviteExpired,
    'invite_used': GroupError.inviteUsed,
    'already_member': GroupError.alreadyMember,
    'placeholder_taken': GroupError.placeholderTaken,
  };

  @override
  Stream<Result<List<Group>, GroupFailure>> watchGroups() => _dao
      .watchGroups()
      .map<Result<List<Group>, GroupFailure>>(
        (rows) => Ok([for (final row in rows) GroupMapper.toDomain(row)]),
      )
      .transform(storageErrorsAsFailures(_storage));

  @override
  Stream<Result<Group?, GroupFailure>> watchGroup(String id) => _dao
      .watchGroup(id)
      .map<Result<Group?, GroupFailure>>(
        (row) => Ok(row == null ? null : GroupMapper.toDomain(row)),
      )
      .transform(storageErrorsAsFailures(_storage));

  @override
  Stream<Result<List<Member>, GroupFailure>> watchMembers(String groupId) =>
      _dao
          .watchMembers(groupId)
          .map<Result<List<Member>, GroupFailure>>(
            (rows) =>
                Ok([for (final row in rows) GroupMapper.memberToDomain(row)]),
          )
          .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<Group?, GroupFailure>> getGroup(String id) => _read(() async {
    final row = await _dao.findGroup(id);
    return row == null || row.deleted ? null : GroupMapper.toDomain(row);
  });

  @override
  Future<Result<List<Member>, GroupFailure>> getMembers(String groupId) =>
      _read(() async {
        final rows = await _dao.getMembers(groupId);
        return [for (final row in rows) GroupMapper.memberToDomain(row)];
      });

  @override
  Stream<Result<List<SharedExpense>, GroupFailure>> watchExpenses(
    String groupId,
  ) => _expenses
      .watchGroup(groupId)
      .map<Result<List<SharedExpense>, GroupFailure>>(
        (rows) =>
            Ok([for (final row in rows) SharedExpenseMapper.toDomain(row)]),
      )
      .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<void, GroupFailure>> addExpense(SharedExpense expense) =>
      _write(
        () => _expenses.insertSharedExpense(SharedExpenseMapper.toRow(expense)),
      );

  @override
  Stream<Result<GroupLedger, GroupFailure>> watchLedger(String groupId) => _dao
      .watchLedger(groupId)
      .map<Result<GroupLedger, GroupFailure>>((rows) => Ok(_ledger(rows)))
      .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<GroupLedger, GroupFailure>> getLedger(String groupId) =>
      _read(() async => _ledger(await _dao.watchLedger(groupId).first));

  static GroupLedger _ledger(
    (List<SharedExpenseRow>, List<SettlementRow>) rows,
  ) => GroupLedger(
    expenses: [for (final row in rows.$1) SharedExpenseMapper.toDomain(row)],
    settlements: [for (final row in rows.$2) SettlementMapper.toDomain(row)],
  );

  @override
  Stream<Result<List<GroupSnapshot>, GroupFailure>> watchAllGroups() => _dao
      .watchEverything()
      .map<Result<List<GroupSnapshot>, GroupFailure>>(
        (groups) => Ok([
          for (final (group, members, expenses, settlements) in groups)
            GroupSnapshot(
              group: GroupMapper.toDomain(group),
              members: [for (final m in members) GroupMapper.memberToDomain(m)],
              ledger: _ledger((expenses, settlements)),
            ),
        ]),
      )
      .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<void, GroupFailure>> addSettlement(Settlement settlement) =>
      _write(
        () => _settlements.insertSettlement(SettlementMapper.toRow(settlement)),
      );

  @override
  Stream<Result<List<HistoryEntry>, GroupFailure>> watchHistory(
    String groupId,
  ) => _dao
      .watchHistory(groupId)
      .map<Result<List<HistoryEntry>, GroupFailure>>(
        (rows) => Ok([for (final row in rows) HistoryMapper.toDomain(row)]),
      )
      .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<void, GroupFailure>> add(Group group, Member founder) => _write(
    () => _dao.insertGroup(
      GroupMapper.toRow(group),
      GroupMapper.memberToRow(founder),
    ),
  );

  @override
  Future<Result<void, GroupFailure>> addMember(Member member) =>
      _write(() => _dao.insertMember(GroupMapper.memberToRow(member)));

  @override
  Future<Result<GroupInvite, GroupFailure>> createInvite(
    String groupId, {
    String? memberId,
  }) => _call(() => _api.createInvite(groupId, memberId: memberId));

  @override
  Future<Result<InvitePreview, GroupFailure>> previewInvite(String token) =>
      _call(() => _api.preview(token));

  @override
  Future<Result<String, GroupFailure>> join(String token) =>
      _call(() => _api.join(token));

  static Future<Result<T, GroupFailure>> _read<T>(
    Future<T> Function() read,
  ) async {
    try {
      return Ok(await read());
    } on Object {
      return const Err(_storage);
    }
  }

  static Future<Result<void, GroupFailure>> _write(
    Future<void> Function() write,
  ) async {
    try {
      await write();
      return const Ok(null);
    } on Object {
      return const Err(_storage);
    }
  }

  static Future<Result<T, GroupFailure>> _call<T>(
    Future<T> Function() call,
  ) async {
    try {
      return Ok(await call());
    } on DioException catch (e) {
      return Err(GroupFailure(_fromDio(e)));
    } on FormatException {
      return const Err(GroupFailure(GroupError.server));
    }
  }

  static GroupError _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError:
        return GroupError.offline;
      case DioExceptionType.badResponse:
        final body = e.response?.data;
        // A 401 the interceptor couldn't refresh: the session ended.
        if (e.response?.statusCode == 401) return GroupError.signedOut;
        return (body is Map ? _codes[body['code']] : null) ?? GroupError.server;
      case _:
        return GroupError.server;
    }
  }
}
