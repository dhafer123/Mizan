// Fails if line coverage of pure code (lib/core/ and lib/**/domain/) is below
// a threshold. Reads the lcov file written by `flutter test --coverage`.
//
// Usage (from app/): dart run tool/check_coverage.dart [minPercent] [lcovPath]
import 'dart:io';

import 'check_domain_imports.dart' show isPureScope;

class FileCoverage {
  const FileCoverage(this.path, this.hit, this.found);

  /// Path relative to `lib/`, with forward slashes.
  final String path;
  final int hit;
  final int found;
}

/// Coverage per file in pure scope, from lcov text. Generated files are
/// skipped.
List<FileCoverage> pureCoverage(String lcov) {
  final result = <FileCoverage>[];
  String? path;
  var hit = 0;
  var found = 0;

  for (final raw in lcov.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      path = line.substring(3).replaceAll(r'\', '/');
      hit = 0;
      found = 0;
    } else if (line.startsWith('DA:')) {
      found++;
      if (line.split(',')[1] != '0') hit++;
    } else if (line == 'end_of_record' && path != null) {
      final libIndex = path.indexOf('lib/');
      final rel = libIndex < 0 ? path : path.substring(libIndex + 4);
      final generated =
          rel.endsWith('.g.dart') || rel.endsWith('.freezed.dart');
      if (libIndex >= 0 && isPureScope(rel) && !generated && found > 0) {
        result.add(FileCoverage(rel, hit, found));
      }
      path = null;
    }
  }
  return result..sort((a, b) => a.path.compareTo(b.path));
}

void main(List<String> args) {
  final minPercent = args.isEmpty ? 90.0 : double.parse(args[0]);
  final lcov = File(args.length > 1 ? args[1] : 'coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln(
      '${lcov.path} not found; run flutter test --coverage first.',
    );
    exit(2);
  }

  final files = pureCoverage(lcov.readAsStringSync());
  final hit = files.fold<int>(0, (sum, f) => sum + f.hit);
  final found = files.fold<int>(0, (sum, f) => sum + f.found);
  final percent = found == 0 ? 100.0 : hit * 100 / found;

  for (final f in files) {
    final filePercent = (f.hit * 100 / f.found).toStringAsFixed(1);
    stdout.writeln(
      '${filePercent.padLeft(6)}%  ${f.hit}/${f.found}  ${f.path}',
    );
  }
  stdout.writeln(
    'Domain + core coverage: ${percent.toStringAsFixed(1)}% '
    '($hit/$found lines, minimum $minPercent%)',
  );
  if (percent < minPercent) exit(1);
}
