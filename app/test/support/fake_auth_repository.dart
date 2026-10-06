import 'dart:async';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/domain/repositories/auth_repository.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_failure.dart';
import 'package:mizan/features/auth/domain/value_objects/credentials.dart';

/// An in-memory [AuthRepository]. Signed out unless given an [account].
/// Sign-in succeeds with [Account] built from the email unless [failure] is set.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._account]);

  Account? _account;
  final _changes = StreamController<Account?>.broadcast();

  /// When set, sign-up, sign-in and log-out fail with this.
  AuthFailure? failure;

  /// When set, [watchAccount] emits this error instead of the account.
  AuthFailure? watchFailure;

  /// Calls in order, e.g. `signUp`, `logIn`, `logOut`.
  final calls = <String>[];
  final credentials = <Credentials>[];

  /// Completes sign-in calls; replace it to hold a call open.
  Completer<void>? gate;

  Account? get account => _account;

  @override
  Stream<Account?> watchAccount() async* {
    if (watchFailure case final failure?) throw failure;
    yield _account;
    yield* _changes.stream;
  }

  @override
  Future<Result<Account, AuthFailure>> signUp(Credentials credentials) =>
      _signIn('signUp', credentials);

  @override
  Future<Result<Account, AuthFailure>> logIn(Credentials credentials) =>
      _signIn('logIn', credentials);

  Future<Result<Account, AuthFailure>> _signIn(
    String call,
    Credentials credentials,
  ) async {
    calls.add(call);
    this.credentials.add(credentials);
    await gate?.future;
    if (failure case final failure?) return Err(failure);
    final account = Account(
      id: 'user-1',
      email: credentials.email,
      displayName: credentials.displayName,
    );
    _set(account);
    return Ok(account);
  }

  @override
  Future<Result<void, AuthFailure>> logOut() async {
    calls.add('logOut');
    await gate?.future;
    if (failure case final failure?) return Err(failure);
    _set(null);
    return const Ok(null);
  }

  void _set(Account? account) {
    _account = account;
    _changes.add(account);
  }
}
