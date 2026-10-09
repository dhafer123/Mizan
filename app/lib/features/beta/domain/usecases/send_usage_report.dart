import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../entities/usage_sharing.dart';
import '../repositories/beta_repository.dart';
import '../repositories/usage_sharing_repository.dart';
import '../value_objects/beta_error.dart';
import '../value_objects/beta_failure.dart';
import '../value_objects/usage_report.dart';
import 'build_usage_report.dart';

/// Sends the usage counts once a day, only if the user opted in. Each report
/// carries the last days again (see [BuildUsageReport]), so a day sent early
/// is corrected the next day, and a failed send is retried next time.
class SendUsageReport {
  const SendUsageReport(
    this._sharing,
    this._expenses,
    this._beta,
    this._clock,
    this._appVersion, [
    this._build = const BuildUsageReport(),
  ]);

  final UsageSharingRepository _sharing;
  final ExpenseRepository _expenses;
  final BetaRepository _beta;
  final Clock _clock;
  final String _appVersion;
  final BuildUsageReport _build;

  /// `Ok(true)` when a report was sent, `Ok(false)` when sharing is off or
  /// today's report was already sent.
  Future<Result<bool, BetaFailure>> call() async {
    final UsageSharing? sharing;
    switch (await _sharing.load()) {
      case Ok(:final value):
        sharing = value;
      case Err(:final failure):
        return Err(failure);
    }
    final today = _clock.now().calendarDay;
    if (sharing == null || sharing.lastSentDay == today) return const Ok(false);

    final expenses = switch (await _expenses.getAll()) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (expenses == null) return const Err(BetaFailure(BetaError.storage));

    final report = UsageReport(
      installId: sharing.installId,
      appVersion: _appVersion,
      days: _build(expenses: expenses, since: sharing.since, today: today),
    );
    if (report.days.isEmpty) return const Ok(false);
    if (await _beta.sendUsage(report) case Err(:final failure)) {
      return Err(failure);
    }
    return (await _sharing.save(
      sharing.copyWith(lastSentDay: today),
    )).map((_) => true);
  }
}
