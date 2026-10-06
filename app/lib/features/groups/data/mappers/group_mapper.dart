import '../../../../app/db/app_database.dart';
import '../../../expenses/data/mappers/expense_mapper.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';

abstract final class GroupMapper {
  /// Throws [FormatException] for a currency this app version can't read.
  static Group toDomain(GroupRow row) => Group(
    id: row.id,
    name: row.name,
    currency: ExpenseMapper.currencyFromCode(row.currency),
  );

  /// A new row (version 0).
  static GroupRow toRow(Group group) => GroupRow(
    id: group.id,
    name: group.name,
    currency: group.currency.code,
    version: 0,
    deleted: false,
  );

  static Member memberToDomain(MemberRow row) => Member(
    id: row.id,
    groupId: row.groupId,
    userId: row.userId,
    displayName: row.displayName,
  );

  /// A new row (version 0).
  static MemberRow memberToRow(Member member) => MemberRow(
    id: member.id,
    groupId: member.groupId,
    userId: member.userId,
    displayName: member.displayName,
    version: 0,
    deleted: false,
  );
}
