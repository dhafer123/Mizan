/// Why sending feedback or usage counts failed.
enum BetaError {
  /// The feedback message is blank.
  emptyMessage,

  /// The feedback message is longer than `FeedbackMessage.maxLength`.
  messageTooLong,

  /// The contact is longer than `FeedbackMessage.maxContactLength`.
  contactTooLong,

  /// The server couldn't be reached.
  offline,

  /// Too many messages from this network for now.
  tooManyRequests,

  /// The server refused it or answered something unreadable.
  server,

  /// Secure storage failed.
  storage,
}
