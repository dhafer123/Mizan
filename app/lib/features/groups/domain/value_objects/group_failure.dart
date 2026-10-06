import '../../../../core/result/failure.dart';
import 'group_error.dart';

class GroupFailure extends Failure {
  const GroupFailure(this.error);

  final GroupError error;

  @override
  String get message => switch (error) {
    GroupError.nameEmpty => 'Enter a name.',
    GroupError.nameTooLong => 'The name is too long.',
    GroupError.notFound => 'This group is no longer on this phone.',
    GroupError.unknownMember => 'The payer must be in the group.',
    GroupError.signedOut => 'Sign in to share expenses with a group.',
    GroupError.invalidLink => "This isn't a Mizan invite link.",
    GroupError.offline => "You're offline. Connect and try again.",
    GroupError.notSynced =>
      "This group isn't on the server yet. Sync, then try again.",
    GroupError.inviteNotFound => "This invite doesn't exist.",
    GroupError.inviteExpired => 'This invite has expired. Ask for a new one.',
    GroupError.inviteUsed => 'This invite was already used. Ask for a new one.',
    GroupError.alreadyMember => "You're already in this group.",
    GroupError.placeholderTaken => 'Someone already joined as this member.',
    GroupError.server => 'Something went wrong on the server. Try again.',
    GroupError.storage => "Couldn't save on this device. Try again.",
  };

  @override
  bool operator ==(Object other) =>
      other is GroupFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
