import 'package:mizan/core/result/failure.dart';
import 'package:mizan/core/result/result.dart';
import 'package:test/test.dart';

class _TestFailure extends Failure {
  const _TestFailure(this.message);

  @override
  final String message;

  @override
  bool operator ==(Object other) =>
      other is _TestFailure && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

void main() {
  const Result<int, _TestFailure> ok = Ok(2);
  const Result<int, _TestFailure> err = Err(_TestFailure('boom'));

  test('Ok exposes its value', () {
    expect(ok.isOk, isTrue);
    expect(ok.isErr, isFalse);
    expect(ok.valueOrNull, 2);
    expect(ok.failureOrNull, isNull);
  });

  test('Err exposes its failure', () {
    expect(err.isOk, isFalse);
    expect(err.isErr, isTrue);
    expect(err.valueOrNull, isNull);
    expect(err.failureOrNull?.message, 'boom');
  });

  test('fold picks the matching branch', () {
    expect(ok.fold((v) => 'v$v', (f) => f.message), 'v2');
    expect(err.fold((v) => 'v$v', (f) => f.message), 'boom');
  });

  test('map transforms Ok and passes Err through', () {
    expect(ok.map((v) => v * 10), const Ok<int, _TestFailure>(20));
    expect(
      err.map((v) => v * 10),
      const Err<int, _TestFailure>(_TestFailure('boom')),
    );
  });

  test('flatMap chains, stopping at the first Err', () {
    Result<int, _TestFailure> half(int v) =>
        v.isEven ? Ok(v ~/ 2) : const Err(_TestFailure('odd'));

    expect(ok.flatMap(half), const Ok<int, _TestFailure>(1));
    expect(
      ok.flatMap(half).flatMap(half),
      const Err<int, _TestFailure>(_TestFailure('odd')),
    );
    expect(
      err.flatMap(half),
      const Err<int, _TestFailure>(_TestFailure('boom')),
    );
  });

  test('switch over a Result is exhaustive', () {
    String describe(Result<int, _TestFailure> r) => switch (r) {
      Ok(:final value) => 'ok $value',
      Err(:final failure) => 'err ${failure.message}',
    };

    expect(describe(ok), 'ok 2');
    expect(describe(err), 'err boom');
  });

  test('value equality and readable toString', () {
    expect(const Ok<int, _TestFailure>(2), const Ok<int, _TestFailure>(2));
    expect(
      const Ok<int, _TestFailure>(2).hashCode,
      const Ok<int, _TestFailure>(2).hashCode,
    );
    expect(
      const Ok<int, _TestFailure>(2),
      isNot(const Ok<int, _TestFailure>(3)),
    );
    expect(ok.toString(), 'Ok(2)');
    expect(err.toString(), 'Err(_TestFailure: boom)');
  });
}
