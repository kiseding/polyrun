import 'dart:convert';
import 'dart:io';

/// Locate a program on [pathEnv]. GUI apps on macOS often inherit a tiny PATH,
/// so callers should pass [resolvePath] rather than the raw environment.
String? findExecutable(String name, String pathEnv) {
  if (name.isEmpty) return null;
  if (name.contains('/') || name.contains(r'\')) {
    return File(name).existsSync() ? name : null;
  }
  final sep = Platform.isWindows ? ';' : ':';
  final exts = Platform.isWindows
      ? (Platform.environment['PATHEXT'] ?? '.EXE;.CMD;.BAT;.COM')
            .split(';')
            .where((ext) => ext.isNotEmpty)
            .toList()
      : const <String>[''];
  for (final dir in pathEnv.split(sep)) {
    if (dir.isEmpty) continue;
    for (final ext in exts) {
      final candidate = '$dir${Platform.pathSeparator}$name$ext';
      if (File(candidate).existsSync()) return candidate;
    }
    if (Platform.isWindows &&
        File('$dir${Platform.pathSeparator}$name').existsSync()) {
      return '$dir${Platform.pathSeparator}$name';
    }
  }
  return null;
}

/// PATH that includes a login shell plus common SDK install locations.
Future<String> resolvePath() async {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final extras = <String>[
    if (home != null) ...[
      '$home/.local/homebrew/bin',
      '$home/homebrew/bin',
      '$home/.cargo/bin',
      '$home/go/bin',
      '$home/.nimble/bin',
      '$home/flutter/bin',
      '$home/development/flutter/bin',
      '$home/sdk/flutter/bin',
      '$home/.local/bin',
      '$home/bin',
    ],
    '/opt/homebrew/bin',
    '/opt/homebrew/sbin',
    '/usr/local/bin',
    '/usr/bin',
    '/bin',
  ];
  var base = Platform.environment['PATH'] ?? '';
  if (!Platform.isWindows) {
    final login = await _loginPath();
    if (login != null) base = login;
  }
  final sep = Platform.isWindows ? ';' : ':';
  final seen = <String>{};
  final parts = <String>[];
  for (final part in [...extras, ...base.split(sep)]) {
    if (part.isEmpty || !seen.add(part)) continue;
    parts.add(part);
  }
  return parts.join(sep);
}

Future<String?> _loginPath() async {
  for (final shell in ['/bin/zsh', '/bin/bash']) {
    if (!File(shell).existsSync()) continue;
    try {
      final result = await Process.run(shell, [
        '-lc',
        r'printf %s "$PATH"',
      ], stdoutEncoding: utf8).timeout(const Duration(seconds: 5));
      final text = '${result.stdout}'.trim();
      if (result.exitCode == 0 && text.contains('/')) return text;
    } catch (_) {
      continue;
    }
  }
  return null;
}
