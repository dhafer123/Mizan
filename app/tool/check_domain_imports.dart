// Enforces the dependency rule: code under `lib/**/domain/` and `lib/core/`
// (which domain builds on) is pure Dart. It may import only safe `dart:`
// libraries, an allowlist of pure-Dart packages, and other domain/core files.
// Anything else (flutter, drift, dio, http, any plugin) is a violation.
//
// Usage (from app/): dart run tool/check_domain_imports.dart [libDir]
import 'dart:io';

/// Pure-Dart packages that domain code may use. Adding one is a reviewed change.
const allowedPackages = {
  'collection',
  'freezed_annotation',
  'json_annotation',
  'meta',
  'uuid',
};

/// `dart:` libraries that tie code to a platform or to Flutter.
const forbiddenDartLibraries = {
  'dart:ffi',
  'dart:html',
  'dart:io',
  'dart:isolate',
  'dart:js',
  'dart:js_interop',
  'dart:js_util',
  'dart:mirrors',
  'dart:ui',
};

const _packageName = 'mizan';

final _directive = RegExp(
  r'^[ \t]*(?:import|export)\s+([^;]+);',
  multiLine: true,
);
final _quoted = RegExp(r'''['"]([^'"]+)['"]''');

class Violation {
  const Violation(this.file, this.line, this.uri, this.reason);

  final String file;
  final int line;
  final String uri;
  final String reason;

  @override
  String toString() => '$file:$line: "$uri" $reason';
}

/// Whether a path relative to `lib/` must stay pure Dart.
bool isPureScope(String libRelativePath) =>
    libRelativePath.startsWith('core/') || libRelativePath.contains('/domain/');

List<Violation> findViolations(Directory libDir) {
  final root = libDir.absolute.uri;
  final violations = <Violation>[];

  final files =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final fileUri = file.absolute.uri;
    final relPath = fileUri.path.substring(root.path.length);
    if (!isPureScope(relPath)) continue;

    final content = file.readAsStringSync();
    for (final directive in _directive.allMatches(content)) {
      final line =
          '\n'.allMatches(content.substring(0, directive.start)).length + 1;
      // Covers conditional imports too: every quoted URI must be allowed.
      for (final quoted in _quoted.allMatches(directive.group(1)!)) {
        final uri = quoted.group(1)!;
        final reason = _check(uri, fileUri, root);
        if (reason != null) {
          violations.add(Violation('lib/$relPath', line, uri, reason));
        }
      }
    }
  }
  return violations;
}

String? _check(String uri, Uri fileUri, Uri root) {
  if (uri.startsWith('dart:')) {
    final library = uri.split('/').first;
    return forbiddenDartLibraries.contains(library)
        ? 'is a platform library; domain code must be pure Dart'
        : null;
  }

  if (uri.startsWith('package:')) {
    final path = uri.substring('package:'.length);
    final package = path.split('/').first;
    if (package == _packageName) {
      final target = path.substring(package.length + 1);
      return isPureScope(target) ? null : _outsideScope;
    }
    return allowedPackages.contains(package)
        ? null
        : 'is not an allowed package in domain code '
              '(allowed: ${allowedPackages.join(', ')})';
  }

  final resolved = fileUri.resolve(uri);
  if (!resolved.path.startsWith(root.path)) return 'resolves outside lib/';
  return isPureScope(resolved.path.substring(root.path.length))
      ? null
      : _outsideScope;
}

const _outsideScope = 'imports code outside domain/ and core/';

void main(List<String> args) {
  final libDir = Directory(args.isEmpty ? 'lib' : args.first);
  if (!libDir.existsSync()) {
    stderr.writeln('Directory not found: ${libDir.path}');
    exit(2);
  }

  final violations = findViolations(libDir);
  if (violations.isEmpty) {
    stdout.writeln('Domain imports OK.');
    return;
  }
  stderr
    ..writeln('Domain purity check failed (${violations.length}):')
    ..writeAll(violations.map((v) => '  $v\n'));
  exit(1);
}
