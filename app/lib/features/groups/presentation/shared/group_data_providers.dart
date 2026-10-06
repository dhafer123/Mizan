import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/value_objects/group_failure.dart';
import '../../domain/value_objects/group_invite.dart';
import '../../domain/value_objects/invite_preview.dart';

part 'group_data_providers.g.dart';

T _orThrow<T>(Result<T, GroupFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw failure,
};

/// Every group on this phone. A failure becomes the error state.
@Riverpod(retry: noRetry)
Stream<List<Group>> groups(Ref ref) =>
    ref.watch(watchGroupsProvider)().map(_orThrow);

/// One group; null once it's gone.
@Riverpod(retry: noRetry)
Stream<Group?> group(Ref ref, String id) =>
    ref.watch(watchGroupProvider)(id).map(_orThrow);

@Riverpod(retry: noRetry)
Stream<List<Member>> members(Ref ref, String groupId) =>
    ref.watch(watchMembersProvider)(groupId).map(_orThrow);

/// A group's expenses, newest first.
@Riverpod(retry: noRetry)
Stream<List<SharedExpense>> sharedExpenses(Ref ref, String groupId) =>
    ref.watch(watchSharedExpensesProvider)(groupId).map(_orThrow);

/// A fresh invite each time it's watched anew (the sheet opens).
@Riverpod(retry: noRetry)
Future<GroupInvite> invite(Ref ref, String groupId, {String? memberId}) async =>
    _orThrow(
      await ref.watch(createInviteProvider)(groupId, memberId: memberId),
    );

/// What an invite link leads to.
@Riverpod(retry: noRetry)
Future<InvitePreview> invitePreview(Ref ref, String link) async =>
    _orThrow(await ref.watch(previewInviteProvider)(link));
