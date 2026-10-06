import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/usecases/add_placeholder_member.dart';
import 'package:mizan/features/groups/domain/usecases/create_group.dart';
import 'package:mizan/features/groups/domain/value_objects/group_error.dart';
import 'package:mizan/features/groups/domain/value_objects/group_failure.dart';

import '../../../../support/fake_group_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  late FakeGroupRepository repo;
  late CreateGroup create;

  const me = Account(id: '7', email: 'sami@example.com', displayName: 'Sami');

  setUp(() {
    repo = FakeGroupRepository();
    create = CreateGroup(repo, SequentialIdGenerator());
  });

  test('creates the group with this account as its first member', () async {
    final result = await create(
      name: '  Flat 4B ',
      currency: Currency.tnd,
      me: me,
    );

    final group = result.valueOrNull!;
    expect((group.name, group.currency), ('Flat 4B', Currency.tnd));
    expect(
      (repo.members.single.groupId, repo.members.single.userId),
      (group.id, '7'),
    );
    expect(repo.members.single.displayName, 'Sami');
  });

  test('needs an account and a name', () async {
    Future<GroupError?> error(String name, Account? account) async =>
        (await create(
          name: name,
          currency: Currency.tnd,
          me: account,
        )).failureOrNull?.error;

    expect(await error('Flat', null), GroupError.signedOut);
    expect(await error('   ', me), GroupError.nameEmpty);
    expect(await error('x' * 61, me), GroupError.nameTooLong);
    expect(repo.groups, isEmpty);
  });

  test("a member's name falls back to the email's first part", () {
    expect(
      CreateGroup.displayNameOf(
        const Account(id: '7', email: 'sami.b@example.com'),
      ),
      'sami.b',
    );
  });

  test('a placeholder has no user until someone claims it', () async {
    final add = AddPlaceholderMember(repo, SequentialIdGenerator());

    final ali = await add(groupId: 'g1', name: ' Ali ');
    final blank = await add(groupId: 'g1', name: '');

    expect(ali.valueOrNull!.isPlaceholder, isTrue);
    expect(ali.valueOrNull!.displayName, 'Ali');
    expect(
      blank,
      const Err<Member, GroupFailure>(GroupFailure(GroupError.nameEmpty)),
    );
    expect(repo.members, hasLength(1));
  });
}
