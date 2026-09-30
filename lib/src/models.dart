enum EnginePreference { auto, local, remote }

enum ThemeChoice { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.pistonBaseUrl,
    required this.pistonToken,
    required this.timeoutSeconds,
    required this.engine,
    required this.theme,
    required this.outputLimitKb,
    this.openAppletId,
  });

  final String pistonBaseUrl;
  final String pistonToken;
  final int timeoutSeconds;
  final EnginePreference engine;
  final ThemeChoice theme;
  final int outputLimitKb;
  final String? openAppletId;

  static const fallback = AppSettings(
    pistonBaseUrl: 'http://127.0.0.1:2000/api/v2',
    pistonToken: '',
    timeoutSeconds: 30,
    engine: EnginePreference.auto,
    theme: ThemeChoice.system,
    outputLimitKb: 200,
  );

  AppSettings copyWith({
    String? pistonBaseUrl,
    String? pistonToken,
    int? timeoutSeconds,
    EnginePreference? engine,
    ThemeChoice? theme,
    int? outputLimitKb,
    String? openAppletId,
    bool clearOpenApplet = false,
  }) {
    return AppSettings(
      pistonBaseUrl: pistonBaseUrl ?? this.pistonBaseUrl,
      pistonToken: pistonToken ?? this.pistonToken,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      engine: engine ?? this.engine,
      theme: theme ?? this.theme,
      outputLimitKb: outputLimitKb ?? this.outputLimitKb,
      openAppletId: clearOpenApplet
          ? null
          : (openAppletId ?? this.openAppletId),
    );
  }

  Map<String, Object?> toJson() => {
    'pistonBaseUrl': pistonBaseUrl,
    'pistonToken': pistonToken,
    'timeoutSeconds': timeoutSeconds,
    'engine': engine.name,
    'theme': theme.name,
    'outputLimitKb': outputLimitKb,
    'openAppletId': openAppletId,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      pistonBaseUrl: json['pistonBaseUrl'] as String? ?? fallback.pistonBaseUrl,
      pistonToken: json['pistonToken'] as String? ?? '',
      timeoutSeconds:
          (json['timeoutSeconds'] as num?)?.toInt() ?? fallback.timeoutSeconds,
      engine:
          EnginePreference.values.asNameMap()[json['engine']] ??
          EnginePreference.auto,
      theme:
          ThemeChoice.values.asNameMap()[json['theme']] ?? ThemeChoice.system,
      outputLimitKb:
          (json['outputLimitKb'] as num?)?.toInt() ?? fallback.outputLimitKb,
      openAppletId: json['openAppletId'] as String?,
    );
  }
}

class Applet {
  Applet({
    required this.id,
    required this.name,
    required this.languageId,
    required this.source,
    required this.stdin,
    required this.args,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  String name;
  String languageId;
  String source;
  String stdin;
  String args;
  bool pinned;
  final DateTime createdAt;
  DateTime updatedAt;

  Applet copyWith({
    String? id,
    String? name,
    String? languageId,
    String? source,
    String? stdin,
    String? args,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Applet(
      id: id ?? this.id,
      name: name ?? this.name,
      languageId: languageId ?? this.languageId,
      source: source ?? this.source,
      stdin: stdin ?? this.stdin,
      args: args ?? this.args,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'languageId': languageId,
    'source': source,
    'stdin': stdin,
    'args': args,
    'pinned': pinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Applet.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return Applet(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '未命名',
      languageId: json['languageId'] as String? ?? 'python',
      source: json['source'] as String? ?? '',
      stdin: json['stdin'] as String? ?? '',
      args: json['args'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}

class RunResult {
  const RunResult({
    required this.engine,
    required this.ok,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.compileOutput,
    required this.elapsedMs,
    required this.timedOut,
    required this.truncated,
    required this.spawnFailed,
    this.message,
  });

  final String engine;
  final bool ok;
  final int? exitCode;
  final String stdout;
  final String stderr;
  final String compileOutput;
  final int elapsedMs;
  final bool timedOut;
  final bool truncated;
  final bool spawnFailed;
  final String? message;

  factory RunResult.message(
    String message, {
    String engine = 'none',
    int elapsedMs = 0,
  }) {
    return RunResult(
      engine: engine,
      ok: false,
      exitCode: null,
      stdout: '',
      stderr: '',
      compileOutput: '',
      elapsedMs: elapsedMs,
      timedOut: false,
      truncated: false,
      spawnFailed: false,
      message: message,
    );
  }

  String get display {
    final buffer = StringBuffer();
    if (message != null && message!.isNotEmpty) {
      buffer.writeln(message);
    }
    if (compileOutput.isNotEmpty) {
      buffer.writeln(compileOutput.trimRight());
    }
    if (stdout.isNotEmpty) buffer.writeln(stdout.trimRight());
    if (stderr.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(stderr.trimRight());
    }
    if (truncated) buffer.writeln('\n… 输出已截断');
    final text = buffer.toString().trimRight();
    return text.isEmpty ? (ok ? '(没有输出)' : '(没有输出)') : text;
  }
}

class RemoteRuntime {
  const RemoteRuntime({
    required this.language,
    required this.version,
    this.aliases = const [],
  });

  final String language;
  final String version;
  final List<String> aliases;

  factory RemoteRuntime.fromJson(Map<String, Object?> json) {
    final rawAliases = json['aliases'];
    return RemoteRuntime(
      language: json['language'] as String? ?? '',
      version: json['version'] as String? ?? '',
      aliases: rawAliases is List
          ? rawAliases.map((e) => '$e').toList()
          : const [],
    );
  }
}

String clip(String text, int max) {
  if (max <= 0 || text.length <= max) return text;
  return '${text.substring(0, max)}\n… 已截断';
}

int compareSemver(String a, String b) {
  final ap = a.split(RegExp(r'[.+-]'));
  final bp = b.split(RegExp(r'[.+-]'));
  final n = ap.length > bp.length ? ap.length : bp.length;
  for (var i = 0; i < n; i++) {
    final ai = i < ap.length ? int.tryParse(ap[i]) ?? 0 : 0;
    final bi = i < bp.length ? int.tryParse(bp[i]) ?? 0 : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}
