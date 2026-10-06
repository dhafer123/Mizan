/// What a history entry records (the server's history kinds).
enum ChangeKind {
  created,
  changed,

  /// A value that lost a same-field conflict: a later edit replaced it.
  overwritten,
  deleted,
  restored,

  /// An edit that arrived after the row was deleted: delete won.
  discarded,
}
