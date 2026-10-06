import '../../../../core/result/failure.dart';
import 'sync_error.dart';

class SyncFailure extends Failure {
  const SyncFailure(this.error);

  final SyncError error;

  @override
  String get message => switch (error) {
    SyncError.offline => "You're offline. Changes will sync when you're back.",
    SyncError.server => "The server had a problem. We'll try again soon.",
    SyncError.sessionExpired => 'Your session ended. Sign in again to sync.',
    SyncError.storage => "Couldn't read or save data on this phone.",
    SyncError.accountChanged => 'Another account signed in. Sync restarted.',
  };

  @override
  bool operator ==(Object other) =>
      other is SyncFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
