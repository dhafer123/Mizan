// Task 6.3: medians over several runs of integration_test/perf_test.dart.
//
// Each run's build/perf/*.json copied to build/perf_runs/<n>/, then:
//   dart run tool/perf_summary.dart build/perf_runs
//
// Scrolling counts only frames where something moved (build ≥ 1 ms): the
// engine draws every vsync in the test, so idle frames would flatter it.
import 'dart:convert';
import 'dart:io';

/// The phone's refresh rate: a frame misses if build or raster takes longer.
const _budgetMicros = 1000000 / 90;

double _median(List<num> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid].toDouble()
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

double _percentile(List<num> values, double p) {
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * p).round()].toDouble();
}

Map<String, Object?> _read(Directory run, String name) =>
    jsonDecode(File('${run.path}/$name.json').readAsStringSync())
        as Map<String, Object?>;

void main(List<String> args) {
  final runs =
      Directory(args.isEmpty ? 'build/perf_runs' : args.first)
          .listSync()
          .whereType<Directory>()
          .where((d) => File('${d.path}/sync_500.json').existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (runs.isEmpty) {
    stderr.writeln('No runs with results found.');
    exit(1);
  }

  final open = <num>[];
  final missedPercent = <num>[];
  final buildP99 = <num>[];
  final rasterP99 = <num>[];
  final push = <num>[];
  final pull = <num>[];
  var frames = 0;
  var missed = 0;

  for (final run in runs) {
    open.add(_read(run, 'open_expenses_2000')['millis']! as num);

    final scroll = _read(run, 'scroll_2000');
    final build = (scroll['frame_build_times']! as List).cast<num>();
    final raster = (scroll['frame_rasterizer_times']! as List).cast<num>();
    final moving = [
      for (var i = 0; i < build.length; i++)
        if (build[i] >= 1000) (build: build[i], raster: raster[i]),
    ];
    final late = moving
        .where((f) => f.build > _budgetMicros || f.raster > _budgetMicros)
        .length;
    frames += moving.length;
    missed += late;
    missedPercent.add(100 * late / moving.length);
    buildP99.add(_percentile([for (final f in moving) f.build], 0.99) / 1000);
    rasterP99.add(_percentile([for (final f in moving) f.raster], 0.99) / 1000);

    final sync = _read(run, 'sync_500');
    push.add(sync['push_500_then_pull_millis']! as num);
    pull.add(sync['fresh_pull_500_millis']! as num);
  }

  String ms(num v) => '${v.round()} ms';
  String s(num v) => '${(v / 1000).toStringAsFixed(2)} s';
  stdout.writeln('${runs.length} runs (medians)');
  stdout.writeln(
    'Open Expenses with 2,000 rows: ${ms(_median(open))} '
    '(range ${ms(open.reduce((a, b) => a < b ? a : b))}–'
    '${ms(open.reduce((a, b) => a > b ? a : b))})',
  );
  stdout.writeln(
    'Scroll 2,000: ${_median(missedPercent).toStringAsFixed(2)}% of '
    'moving frames over 11.1 ms (all runs: $missed / $frames); '
    'build p99 ${_median(buildP99).toStringAsFixed(1)} ms, '
    'raster p99 ${_median(rasterP99).toStringAsFixed(1)} ms',
  );
  stdout.writeln(
    'Sync: push 500 + pull back ${s(_median(push))}; '
    'fresh phone pulls 500 ${s(_median(pull))}',
  );
}
