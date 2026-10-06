import '../../../../core/result/result.dart';
import 'group_error.dart';
import 'group_failure.dart';

/// Name rules for groups and members (the server's limits).
abstract final class GroupNames {
  static const maxGroupName = 60;
  static const maxMemberName = 50;

  /// [name] trimmed, or why it can't be used.
  static Result<String, GroupFailure> validate(
    String name, {
    required int max,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Err(GroupFailure(GroupError.nameEmpty));
    if (trimmed.length > max) {
      return const Err(GroupFailure(GroupError.nameTooLong));
    }
    return Ok(trimmed);
  }
}
