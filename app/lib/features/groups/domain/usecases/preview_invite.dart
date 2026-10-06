import '../../../../core/result/result.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_error.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/invite_link.dart';
import '../value_objects/invite_preview.dart';

/// What a pasted or opened invite link leads to, before joining.
class PreviewInvite {
  const PreviewInvite(this._repository);

  final GroupRepository _repository;

  Future<Result<InvitePreview, GroupFailure>> call(String link) async {
    final token = InviteLink.tokenFrom(link);
    if (token == null) return const Err(GroupFailure(GroupError.invalidLink));
    return _repository.previewInvite(token);
  }
}
