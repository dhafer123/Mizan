/// Why a group action failed.
enum GroupError {
  nameEmpty,

  /// Longer than the limit (`GroupNames`).
  nameTooLong,

  /// The group isn't on this phone (anymore).
  notFound,

  /// The payer isn't a member of the group.
  unknownMember,

  /// Groups are shared through the server: they need an account.
  signedOut,

  /// Not an invite link (or token) this app understands.
  invalidLink,

  /// The server can't be reached.
  offline,

  /// The server doesn't know this group (yet): it hasn't synced, or this
  /// account isn't in it.
  notSynced,
  inviteNotFound,
  inviteExpired,

  /// Someone else already joined with this invite.
  inviteUsed,
  alreadyMember,

  /// The placeholder was claimed by someone else.
  placeholderTaken,

  /// The server answered with something unexpected.
  server,

  /// The local database failed.
  storage,
}
