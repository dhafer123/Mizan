import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/beta/data/local/secure_usage_sharing_repository.dart';
import 'package:mizan/features/beta/data/remote/beta_api.dart';
import 'package:mizan/features/beta/data/repositories/beta_repository_impl.dart';
import 'package:mizan/features/beta/domain/entities/usage_sharing.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_error.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_failure.dart';
import 'package:mizan/features/beta/domain/value_objects/feedback_message.dart';
import 'package:mizan/features/beta/domain/value_objects/usage_day.dart';
import 'package:mizan/features/beta/domain/value_objects/usage_report.dart';

import '../../../support/fake_http_adapter.dart';

void main() {
  group('BetaRepositoryImpl', () {
    late FakeHttpAdapter adapter;
    late BetaRepositoryImpl repository;

    setUp(() {
      adapter = FakeHttpAdapter((_) => FakeHttpAdapter.json(201));
      repository = BetaRepositoryImpl(BetaApi(fakeDio(adapter)));
    });

    test('posts feedback with no token', () async {
      final result = await repository.sendFeedback(
        const FeedbackMessage(
          message: 'Dark mode please',
          contact: 'sami@example.com',
          appVersion: '0.1.0+1',
        ),
      );

      expect(result, const Ok<void, BetaFailure>(null));
      final request = adapter.to('/beta/feedback').single;
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], isNull);
      expect(request.data, {
        'message': 'Dark mode please',
        'contact': 'sami@example.com',
        'appVersion': '0.1.0+1',
      });
    });

    test('posts usage with ISO days', () async {
      adapter.handler = (_) => FakeHttpAdapter.json(204);

      await repository.sendUsage(
        UsageReport(
          installId: '1b4e28ba-2fa1-4d3b-a3f5-ef19b5a7633b',
          appVersion: '0.1.0+1',
          days: [
            UsageDay(day: DateTime.utc(2026, 10, 8)),
            UsageDay(day: DateTime.utc(2026, 10, 9), manual: 2, voice: 1),
          ],
        ),
      );

      expect(adapter.to('/beta/usage').single.data, {
        'installId': '1b4e28ba-2fa1-4d3b-a3f5-ef19b5a7633b',
        'appVersion': '0.1.0+1',
        'days': [
          {'day': '2026-10-08', 'manual': 0, 'voice': 0, 'receipt': 0},
          {'day': '2026-10-09', 'manual': 2, 'voice': 1, 'receipt': 0},
        ],
      });
    });

    Future<BetaError?> errorFor(FakeHttpAdapter adapter) async =>
        (await BetaRepositoryImpl(BetaApi(fakeDio(adapter))).sendFeedback(
          const FeedbackMessage(message: 'Hi', appVersion: '0.1.0+1'),
        )).failureOrNull?.error;

    test('maps errors', () async {
      expect(
        await errorFor(FakeHttpAdapter(FakeHttpAdapter.offline)),
        BetaError.offline,
      );
      expect(
        await errorFor(
          FakeHttpAdapter(
            (_) => FakeHttpAdapter.json(429, {'code': 'throttled'}),
          ),
        ),
        BetaError.tooManyRequests,
      );
      expect(
        await errorFor(
          FakeHttpAdapter(
            (_) => FakeHttpAdapter.json(400, {'code': 'invalid'}),
          ),
        ),
        BetaError.server,
      );
    });
  });

  group('SecureUsageSharingRepository', () {
    const repository = SecureUsageSharingRepository(FlutterSecureStorage());

    test('nothing stored: sharing is off', () async {
      FlutterSecureStorage.setMockInitialValues({});

      expect(
        await repository.load(),
        const Ok<UsageSharing?, BetaFailure>(null),
      );
    });

    test('saves and loads it back, then forgets it', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final sharing = UsageSharing(
        installId: 'install-1',
        since: DateTime.utc(2026, 10, 8),
        lastSentDay: DateTime.utc(2026, 10, 9),
      );

      await repository.save(sharing);
      expect(await repository.load(), Ok<UsageSharing?, BetaFailure>(sharing));

      await repository.save(sharing.copyWith(lastSentDay: null));
      expect((await repository.load()).valueOrNull?.lastSentDay, isNull);

      await repository.save(null);
      expect(
        await repository.load(),
        const Ok<UsageSharing?, BetaFailure>(null),
      );
    });
  });
}
