import '../../domain/entities/account.dart';
import '../session/stored_session.dart';
import '../session/token_pair.dart';

/// JSON for the server's auth responses and for the stored session. Both use
/// the same shape: `{"user": {"id", "email", "displayName"}, "access", "refresh"}`.
/// Bad input throws a [FormatException].
abstract final class SessionMapper {
  static Account accountFromJson(Object? json) {
    if (json case {
      'id': final String id,
      'email': final String email,
    } when id.isNotEmpty && email.isNotEmpty) {
      final name = json['displayName'];
      return Account(
        id: id,
        email: email,
        displayName: name is String && name.isNotEmpty ? name : null,
      );
    }
    throw const FormatException('Not an account');
  }

  static Map<String, Object?> accountToJson(Account account) => {
    'id': account.id,
    'email': account.email,
    'displayName': account.displayName ?? '',
  };

  static TokenPair tokensFromJson(Object? json) {
    if (json case {
      'access': final String access,
      'refresh': final String refresh,
    } when access.isNotEmpty && refresh.isNotEmpty) {
      return TokenPair(access: access, refresh: refresh);
    }
    throw const FormatException('Not a token pair');
  }

  static StoredSession sessionFromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Not a session');
    }
    return StoredSession(
      account: accountFromJson(json['user']),
      tokens: tokensFromJson(json),
    );
  }

  static Map<String, Object?> sessionToJson(StoredSession session) => {
    'user': accountToJson(session.account),
    'access': session.tokens.access,
    'refresh': session.tokens.refresh,
  };
}
