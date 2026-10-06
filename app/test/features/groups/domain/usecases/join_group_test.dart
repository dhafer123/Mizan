import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/groups/domain/usecases/join_group.dart';
import 'package:mizan/features/groups/domain/usecases/preview_invite.dart';
import 'package:mizan/features/groups/domain/value_objects/group_error.dart';
import 'package:mizan/features/groups/domain/value_objects/invite_link.dart';

import '../../../../support/fake_group_repository.dart';

void main() {
  const token = 'aB3_-x9Kq2LmN8pQ7rS1tU4v';

  group('InviteLink', () {
    test('reads the token from a link, a pasted link, or the bare token', () {
      final link = InviteLink.forToken(token);

      expect(link, 'mizan://mizan.app/join/$token');
      expect(InviteLink.tokenFrom(link), token);
      expect(InviteLink.tokenFrom('  $link\n'), token);
      expect(InviteLink.tokenFrom('https://example.com/join/$token'), token);
      expect(InviteLink.tokenFrom(token), token);
    });

    test('refuses anything else', () {
      for (final input in [
        '',
        'hello',
        'mizan://mizan.app/join/',
        'mizan://mizan.app/join/$token/extra',
        'mizan://mizan.app/other/$token',
        'mizan://mizan.app/join/short',
      ]) {
        expect(InviteLink.tokenFrom(input), isNull, reason: input);
      }
    });
  });

  test('joins with the token in the link', () async {
    final repo = FakeGroupRepository();

    final result = await JoinGroup(repo)(InviteLink.forToken(token));

    expect(result.valueOrNull, 'g1');
    expect(repo.tokens, [token]);
  });

  test('a bad link never reaches the server', () async {
    final repo = FakeGroupRepository();

    final joined = await JoinGroup(repo)('not a link');
    final previewed = await PreviewInvite(repo)('not a link');

    expect(joined.failureOrNull?.error, GroupError.invalidLink);
    expect(previewed.failureOrNull?.error, GroupError.invalidLink);
    expect(repo.tokens, isEmpty);
  });
}
