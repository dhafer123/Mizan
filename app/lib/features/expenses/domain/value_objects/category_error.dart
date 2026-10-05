/// Why a category could not be saved, archived or read.
enum CategoryError {
  nameEmpty,

  /// Longer than `ValidateCategory.maxNameLength`.
  nameTooLong,

  /// Another active category already has this name (ignoring case).
  nameTaken,
  noIcon,

  /// The monthly limit is zero or negative.
  limitNotPositive,

  /// Archiving it would leave no category to file expenses under.
  lastActive,

  /// The category does not exist.
  notFound,

  /// The local database failed.
  storage,
}
