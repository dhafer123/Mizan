/// Where an outbox op is in its life. Stored by name; do not rename.
enum OutboxStatus {
  /// Waiting to be pushed (or to be retried).
  pending,

  /// Included in a push that has not answered yet.
  sending,

  /// The server refused it for good (e.g. `not_a_member`); kept for the UI.
  rejected,
}
