import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/groups/data/remote/groups_api.dart';
import '../../features/groups/data/repositories/group_repository_impl.dart';
import '../../features/groups/domain/repositories/group_repository.dart';
import '../../features/groups/domain/usecases/add_placeholder_member.dart';
import '../../features/groups/domain/usecases/add_shared_expense.dart';
import '../../features/groups/domain/usecases/compute_shares.dart';
import '../../features/groups/domain/usecases/create_group.dart';
import '../../features/groups/domain/usecases/create_invite.dart';
import '../../features/groups/domain/usecases/join_group.dart';
import '../../features/groups/domain/usecases/preview_invite.dart';
import '../../features/groups/domain/usecases/watch_group.dart';
import '../../features/groups/domain/usecases/watch_groups.dart';
import '../../features/groups/domain/usecases/watch_members.dart';
import '../../features/groups/domain/usecases/watch_shared_expenses.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'database_providers.dart';

part 'groups_providers.g.dart';

/// Override with a fake in tests.
@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) => GroupRepositoryImpl(
  ref.watch(appDatabaseProvider).groupsDao,
  ref.watch(appDatabaseProvider).sharedExpensesDao,
  GroupsApi(ref.watch(apiDioProvider)),
);

@Riverpod(keepAlive: true)
WatchGroups watchGroups(Ref ref) =>
    WatchGroups(ref.watch(groupRepositoryProvider));

@Riverpod(keepAlive: true)
WatchGroup watchGroup(Ref ref) =>
    WatchGroup(ref.watch(groupRepositoryProvider));

@Riverpod(keepAlive: true)
WatchMembers watchMembers(Ref ref) =>
    WatchMembers(ref.watch(groupRepositoryProvider));

@Riverpod(keepAlive: true)
CreateGroup createGroup(Ref ref) => CreateGroup(
  ref.watch(groupRepositoryProvider),
  ref.watch(idGeneratorProvider),
);

@Riverpod(keepAlive: true)
AddPlaceholderMember addPlaceholderMember(Ref ref) => AddPlaceholderMember(
  ref.watch(groupRepositoryProvider),
  ref.watch(idGeneratorProvider),
);

@Riverpod(keepAlive: true)
CreateInvite createInvite(Ref ref) =>
    CreateInvite(ref.watch(groupRepositoryProvider));

@Riverpod(keepAlive: true)
PreviewInvite previewInvite(Ref ref) =>
    PreviewInvite(ref.watch(groupRepositoryProvider));

@Riverpod(keepAlive: true)
JoinGroup joinGroup(Ref ref) => JoinGroup(ref.watch(groupRepositoryProvider));

@Riverpod(keepAlive: true)
WatchSharedExpenses watchSharedExpenses(Ref ref) =>
    WatchSharedExpenses(ref.watch(groupRepositoryProvider));

@Riverpod(keepAlive: true)
ComputeShares computeShares(Ref ref) => const ComputeShares();

@Riverpod(keepAlive: true)
AddSharedExpense addSharedExpense(Ref ref) => AddSharedExpense(
  ref.watch(groupRepositoryProvider),
  ref.watch(idGeneratorProvider),
  ref.watch(clockProvider),
  ref.watch(computeSharesProvider),
);
