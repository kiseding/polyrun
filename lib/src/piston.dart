import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class PistonException implements Exception {
  PistonException(this.message);
  final String message;
  @override
  String toString() => message;
}

String normalizePistonBase(String raw) {
  var base = raw.trim();
  if (base.isEmpty) return base;
  if (!base.contains('://')) base = 'http://$base';
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  for (final suffix in ['/runtimes', '/execute']) {
    if (base.endsWith(suffix)) {
      base = base.substring(0, base.length - suffix.length);
    }
  }
  return base;
}

Uri pistonEndpoint(String base, String tail) {
  return Uri.parse('${normalizePistonBase(base)}/$tail');
}

Map<String, String> pistonHeaders(AppSettings settings, {bool json = false}) {
  final headers = <String, String>{'Accept': 'application/json'};
  if (json) headers['Content-Type'] = 'application/json';
  final token = settings.pistonToken.trim();
  if (token.isNotEmpty) {
    headers['Authorization'] = token.toLowerCase().startsWith('bearer ')
        ? token
        : 'Bearer $token';
  }
  return headers;
}

class PistonApi {
  PistonApi(this._client);

  final http.Client _client;

  Future<List<RemoteRuntime>> fetchRuntimes(AppSettings settings) async {
    final response = await _client
        .get(
          pistonEndpoint(settings.pistonBaseUrl, 'runtimes'),
          headers: pistonHeaders(settings),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode >= 400) {
      throw PistonException(
        '获取运行时失败 HTTP ${response.statusCode}\n${clip(response.body, 800)}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw PistonException('运行时列表不是数组');
    }
    return decoded
        .whereType<Map>()
        .map((item) => RemoteRuntime.fromJson(item.cast<String, Object?>()))
        .where((item) => item.language.isNotEmpty && item.version.isNotEmpty)
        .toList();
  }

  Future<RunResult> execute({
    required AppSettings settings,
    required String language,
    required String version,
    required String fileName,
    required String source,
    required String stdin,
    required List<String> args,
  }) async {
    final watch = Stopwatch()..start();
    final timeoutMs = settings.timeoutSeconds * 1000;
    final payload = jsonEncode({
      'language': language,
      'version': version,
      'files': [
        {'name': fileName, 'content': source},
      ],
      'stdin': stdin,
      'args': args,
      'compile_timeout': timeoutMs,
      'run_timeout': timeoutMs,
    });
    try {
      final response = await _client
          .post(
            pistonEndpoint(settings.pistonBaseUrl, 'execute'),
            headers: pistonHeaders(settings, json: true),
            body: payload,
          )
          .timeout(Duration(seconds: settings.timeoutSeconds + 20));
      return parsePistonResponse(
        status: response.statusCode,
        body: response.body,
        elapsedMs: watch.elapsedMilliseconds,
        limit: settings.outputLimitKb * 1024,
      );
    } on TimeoutException {
      return RunResult.message(
        '连接 Piston 超时',
        engine: 'piston',
        elapsedMs: watch.elapsedMilliseconds,
      );
    } on PistonException catch (error) {
      return RunResult.message(error.message, engine: 'piston');
    } catch (error) {
      return RunResult.message('无法连接 Piston：$error', engine: 'piston');
    }
  }
}

RunResult parsePistonResponse({
  required int status,
  required String body,
  required int elapsedMs,
  required int limit,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    decoded = null;
  }
  final json = decoded is Map ? decoded.cast<String, Object?>() : null;
  if (status >= 400 || json == null) {
    final message = json?['message']?.toString() ?? body;
    return RunResult.message(
      'Piston HTTP $status\n${clip(message, 1200)}',
      engine: 'piston',
      elapsedMs: elapsedMs,
    );
  }
  if (json['message'] != null && json['run'] == null) {
    return RunResult.message(
      json['message'].toString(),
      engine: 'piston',
      elapsedMs: elapsedMs,
    );
  }

  final compile = json['compile'];
  var compileOutput = '';
  int? compileCode;
  if (compile is Map) {
    compileCode = _asInt(compile['code']);
    compileOutput = [
      _asString(compile['stdout']),
      _asString(compile['stderr']),
    ].where((part) => part.isNotEmpty).join('\n');
  }

  final run = json['run'];
  if (run is! Map) {
    final failed = compileCode != null && compileCode != 0;
    return RunResult(
      engine: 'piston',
      ok: !failed,
      exitCode: compileCode,
      stdout: '',
      stderr: '',
      compileOutput: clip(compileOutput, limit),
      elapsedMs: elapsedMs,
      timedOut: false,
      truncated: compileOutput.length > limit,
      spawnFailed: false,
      message: failed ? '编译失败' : null,
    );
  }

  final stdout = _asString(run['stdout']);
  final stderr = _asString(run['stderr']);
  final code = _asInt(run['code']);
  final signal = run['signal'];
  final signalText = signal == null || '$signal' == 'null' ? '' : '$signal';
  final timedOut =
      signalText == 'SIGKILL' || stderr.toLowerCase().contains('timed out');
  final compileFailed = compileCode != null && compileCode != 0;
  final ok = !compileFailed && code == 0 && signalText.isEmpty;
  final clippedOut = clip(stdout, limit);
  final clippedErr = clip(stderr, limit);
  final clippedCompile = clip(compileOutput, limit);
  return RunResult(
    engine: 'piston',
    ok: ok,
    exitCode: code ?? compileCode,
    stdout: clippedOut,
    stderr: clippedErr,
    compileOutput: clippedCompile,
    elapsedMs: elapsedMs,
    timedOut: timedOut,
    truncated:
        clippedOut.length < stdout.length ||
        clippedErr.length < stderr.length ||
        clippedCompile.length < compileOutput.length,
    spawnFailed: false,
    message: compileFailed
        ? '编译失败'
        : timedOut
        ? '运行超时'
        : signalText.isEmpty
        ? null
        : '进程信号 $signalText',
  );
}

String _asString(Object? value) => value == null ? '' : '$value';

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
